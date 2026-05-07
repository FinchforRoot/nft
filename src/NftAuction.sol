// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NftAuction is Initializable, UUPSUpgradeable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // 拍卖结构
    struct Auction {
        // 卖家
        address seller;
        // NFT合约地址
        address nftContract;
        // NFT的tokenId
        uint256 tokenId;
        // 起拍价,单位美元
        uint256 startPrice;
        // 拍卖开始时间
        uint256 startTime;
        // 持续时间
        uint256 duration;
        // 拍卖当前状态
        Status currentStatus;
        // 最高价格
        uint256 highestBid;
        // 最高出价者
        address highestBidder;
        // 出价代币数量
        uint256 highestBidAmount;
        // address(0) 表示 ETH,其他地址表示 ERC20 代币合约
        address tokenAddress;
    }

    // 状态
    enum Status {
        Pending, //未开始
        OnGoing, //进行中
        Ended, //已结束
        NoBid, //流拍
        Cancelled //已取消
    }

    // NFT拍卖合集 第一层 key：NFT 合约地址 第二层 key：NFT 的 tokenId 值：拍卖ID（uint256）
    mapping(address => mapping(uint256 => uint256)) public nftToken2AuctionId;
    // 拍卖集合
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖的id
    uint256 public nextAuctionId;
    // 代币地址和价格数据源映射
    mapping(address => AggregatorV3Interface) public priceFeeds;
    // 管理员
    address public admin;

    // 创建竞拍
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 startTime,
        uint256 duration
    );
    // 取消竞拍
    event AuctionCancelled(uint256 indexed auctionId);
    // 竞拍结束
    event AuctionEnded(
        uint256 indexed auctionId,  // 拍卖品id
        address indexed winner, // 获胜者地址
        uint256 winningBid,  // 获胜金额【美元】
        address tokenAddress,      // 代币地址
        uint256 tokenAmount         // 代币数量
    );
    // 出价事件
    event NewHighestBid(
        uint256 indexed auctionId,  // 拍卖品id
        address indexed bidder, // 拍卖者地址
        uint256 bid,    // 出价金额【美元】
        uint256 bidAmount // 代币数量【ETH/ERC20】
    );

    function initialize() public initializer {
        admin = msg.sender;
    }

    function _authorizeUpgrade(address) internal view override {
        // 只允许 admin 升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    /**
     * 
     * @dev 查询指定代币的最新链上价格
     * @param _tokenAddress 要查询价格的代币合约地址（例如 USDT 的合约地址，或 ETH 用 address(0) 表示）
     * @notice 根据传入的代币地址，从对应的 Chainlink 喂价合约中获取最新的链上价格
     * @return answer 该代币对美元的当前价格，精度为 8 位小数（例如 231812345678 表示 2318.12345678 美元）
     */
    function getChainlinkDataFeedLatestAnswer(
        address _tokenAddress
    ) public view returns (int){
        AggregatorV3Interface priceFeed = priceFeeds[_tokenAddress];
        // prettier-ignore
        (
        /* uint80 roundId */,
            int256 answer,
        /*uint256 startedAt*/,
        /*uint256 updatedAt*/,
        /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return answer;
    }

    // 注册喂价合约
    function setPriceFeed(address _token, address _feed) external {
        require(msg.sender == admin, "Only admin");
        priceFeeds[_token] = AggregatorV3Interface(_feed);
    }

    // 创建拍卖
    function createAuction(
        address _nftContract, //NFT合约地址
        uint256 _tokenId,   //NFT的tokenId
        uint256 _startPrice,    //起拍价
        uint256 _delayHours,    //拍卖开始前的延迟时间，单位小时 [0-24]
        uint256 _durationHours  //拍卖持续时间，单位小时[0-24]
    ) public {
        // 先检查nft合约地址合法
        require(_nftContract != address(0), "nft address invalid");
        // 起拍价必须大于0
        require(_startPrice > 0, "start price invalid");
        // 业务设置允许推迟拍卖，为0表示立即开始，上限是24小时后开启拍卖
        require(
            _delayHours >= 0 && _delayHours <= 24 * 1 hours,
            "_delayHours invalid"
        );
        // 拍卖持续时间为1-24小时
        require(
            _durationHours >= 1 * 1 hours && _durationHours <= 24 * 1 hours,
            "_durationHours invalid"
        );
        IERC721 nft = IERC721(_nftContract);
        // 校验这个nft是否已经上架
        uint256 existingId = nftToken2AuctionId[_nftContract][_tokenId];
        // 已上架过的NFT不能再次拍卖
        require(existingId == 0, "NFT already in auction");
        // 校验nft是调用者的
        require(
            nft.ownerOf(_tokenId) == msg.sender,
            "you are not the owner of this nft"
        );
        // 校验该NFT是否已经授权给了本合约
        require(
            nft.getApproved(_tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );
        uint256 _startTime = block.timestamp + _delayHours;
        // 创建拍卖
        uint256 auctionId = nextAuctionId++;
        // 转移nft到合约
        nft.transferFrom(msg.sender, address(this), _tokenId);
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            startPrice: _startPrice,
            startTime: _startTime,
            duration: _durationHours * 1 hours,
            currentStatus: Status.Pending,
            highestBid: 0,
            highestBidder: address(0),
            highestBidAmount: 0,
            tokenAddress: address(0)
        });

        // 记录某个NFT是否处于拍卖中
        nftToken2AuctionId[_nftContract][_tokenId] = auctionId;

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _nftContract,
            _tokenId,
            _startPrice,
            _startTime,
            _durationHours
        );
    }

    // 参与竞拍
    /**
    校验拍卖存在

    校验状态为 OnGoing

    校验时间戳是否有效

    校验卖家不能自己出价

    计算最低出价美元价值

    校验出价金额是否满足竞拍要求

    收新买家的钱

    更新状态（bidToken + highestBidAmount + highestBid + highestBidder）

    退款给前买家（如果有）

    发事件
     */
    function placeBid(uint256 _auctionId, uint256 _bidAmount, address _tokenAddress) external payable nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.seller != address(0), "auction not exist");
        // 自动状态转换
        if (auction.currentStatus == Status.Pending) {
            require(block.timestamp >= auction.startTime, "Not started yet");
            auction.currentStatus = Status.OnGoing;
        }
        require(auction.currentStatus == Status.OnGoing, "auction not on going");
        require(auction.startTime < block.timestamp && auction.startTime + auction.duration > block.timestamp, "Time Invalid");
        require(auction.seller != msg.sender, "seller can not bid");
        require(address(priceFeeds[_tokenAddress]) != address(0), "Price feed not registered");
        uint256 previousBid = auction.highestBid;
        // 计算最小的出价
        uint256 minPrice;
        if (previousBid == 0) {
            minPrice = auction.startPrice;
        } else {
            minPrice = auction.highestBid * 105 / 100;
        }
        // 计算出价，转换为美元
        uint256 payValue;
        if (_tokenAddress != address(0)) {
            // 是ERC20代币
            payValue = _bidAmount * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress)) / 10 ** 8;
        } else {
            require(msg.value == _bidAmount, "ETH bid amount mismatch");
            _bidAmount = msg.value;
            payValue = _bidAmount * uint(getChainlinkDataFeedLatestAnswer(address(0))) / 10 ** 18;
        }
        // 出价必须大于计算的最小出价
        require(payValue >= minPrice, "Bid too low");

        // 1. 先把要退款的信息保存到临时变量（因为后面要覆盖）
        address previousBidder = auction.highestBidder;
        uint256 previousAmount = auction.highestBidAmount;
        address previousToken = auction.tokenAddress;

        // 2. 先更新状态（覆盖旧数据）
        auction.highestBid = payValue;
        auction.highestBidder = msg.sender;
        auction.highestBidAmount = _bidAmount;
        auction.tokenAddress = _tokenAddress;

        // 3. 收新买家的钱
        if (_tokenAddress != address(0)) {
            // 收款：从msg.sender转代币到合约
            bool received = IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _bidAmount);
            require(received, "ERC20 transfer failed");
        } else {
            // ETH：msg.value已经自动转入合约
        }

        // 4. 再转账(先判断之前有人出过价)
        if (previousBidder != address(0)) {
            // 判断是否是ETH出价
            if (previousToken == address(0)) {
                // eth退款
                (bool success,) = payable(previousBidder).call{value: previousAmount}("");
                require(success, "Transfer failed");
            } else {
                // ERC20退款
                bool success = IERC20(previousToken).transfer(previousBidder, previousAmount);
                require(success, "ERC20 refund failed");
            }
        }

        emit NewHighestBid(_auctionId, msg.sender, payValue, _bidAmount);

    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) external nonReentrant {
        Auction storage auction = auctions[_auctionId];
        address seller = auction.seller;

        // 先验证拍卖存在
        require(seller != address(0), "auction not exist");
        // 验证是否到了结束时间
        require(block.timestamp >= auction.startTime + auction.duration, "Auction not ended");
        require(auction.currentStatus == Status.OnGoing || auction.currentStatus == Status.Pending,
            "Auction already ended or cancelled");
        address nftAddress = auction.nftContract;
        address highestBidder = auction.highestBidder;
        uint256 highestBidAmount = auction.highestBidAmount;
        uint256 tokenId = auction.tokenId;
        address tokenAddress = auction.tokenAddress;
        // 如果出价者为0，更新状态为流拍
        if (auction.highestBidder == address(0)) {
            auction.currentStatus = Status.NoBid;
            // 将seller抵押的NFT退还
            IERC721(nftAddress).safeTransferFrom(address(this), seller, tokenId);
            emit AuctionEnded(_auctionId, address(0), 0, address(0), 0);
            return;
        }

        // 否则更新为结束[先更新为结束状态]
        auction.currentStatus = Status.Ended;

        // 再进行资产转移
        if (tokenAddress == address(0)) {
            // 转ETH给卖家
            (bool success,) = seller.call{value: highestBidAmount}("");
            require(success, "Transfer to seller failed");
        } else {
            // 转ERC20给卖家
            IERC20 token = IERC20(tokenAddress);
            bool success = token.transfer(seller, highestBidAmount);
            require(success, "ERC20 transfer failed");
        }
        // 将出价的amount转移给卖家，将nft转移给最高出价的买家
        IERC721(nftAddress).safeTransferFrom(address(this), highestBidder, tokenId);
        // 发送拍卖结束事件
        emit AuctionEnded(_auctionId, highestBidder, auction.highestBid, auction.tokenAddress, auction.highestBidAmount);

    }

    /**
     * @dev 取消拍卖
     * @param _auctionId 拍卖id
     * @notice 只有卖家可以在拍卖未开始前操作
     */
    function cancelAuction(uint256 _auctionId) external nonReentrant {
        // 验证拍卖ID有效
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        // 验证拍卖存在（通过检查seller不为零地址）
        require(auction.seller != address(0), "Auction not exist");
        // 只有卖家可以取消
        require(msg.sender == auction.seller, "Only seller");
        // 状态必须是Pending
        require(auction.currentStatus == Status.Pending, "Must be Pending");
        // 必须在开始时间之前
        require(block.timestamp < auction.startTime, "Already started");
        // 更新状态
        auction.currentStatus = Status.Cancelled;
        // 退回NFT
        IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        emit AuctionCancelled(_auctionId);
    }
}
