// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NftAuctionV2} from "../src/NftAuctionV2.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockAggregator} from "./mocks/MockAggregator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockMyNft} from "./mocks/MockMyNft.sol";
import {NftAuction} from "../src/NftAuction.sol";
import {Test} from "forge-std/Test.sol";

contract NftAuctionTest is Test {

    // ============ 合约 ============
    NftAuction public nftAuction;
    MockERC20 public token;
    MockMyNft public nft;
    MockAggregator public ethPriceFeed;  // 8位精度
    MockAggregator public usdtPriceFeed;    // 8位精度

    //  ========= 拍卖合约的管理员、卖家、买家1、买家2 ========
    address public admin;
    address public seller;
    address public buyer1;
    address public buyer2;

    // ============ 常量 ============
    uint256 constant TOKEN_ID = 0;
    uint256 constant START_PRICE = 100; // 100 美元
    uint256 constant START_TIME = 0; // 推迟启动的时间
    uint256 constant DURATION_HOURS = 24; // 拍卖持续的时间
    int256 constant ETH_PRICE = 231812345678; // $2318.12
    int256 constant USDT_PRICE = 100000000; // $1.00

    // ============ 事件 ============
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 startTime,
        uint256 duration
    );
    event AuctionCancelled(uint256 indexed auctionId);
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        address tokenAddress,
        uint256 tokenAmount
    );
    event NewHighestBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bid,
        uint256 bidAmount
    );

    // setUp函数，在每个测试前执行
    function setUp() public {
        // 1.部署价格预言机：ETH $2318.12, USDT $1.00
        ethPriceFeed = new MockAggregator(ETH_PRICE);
        usdtPriceFeed = new MockAggregator(USDT_PRICE);
        // 2. 部署 TestERC20.sol 和 MockERC721
        token = new MockERC20();
        nft = new MockMyNft();

        // 3.部署拍卖合约（UUPS 代理模式）
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new NftAuction()),
            abi.encodeWithSignature("initialize()")
        );

        // 将部署的代理合约地址赋给被测试合约，类似类型转换
        nftAuction = NftAuction(address(proxy));
        admin = nftAuction.admin();

        // 3.配置价格预言机
        vm.prank(admin);
        nftAuction.setPriceFeed(address(0), address(ethPriceFeed));
        vm.prank(admin);
        nftAuction.setPriceFeed(address(token), address(usdtPriceFeed));

        // 5. 设置账户
        seller = makeAddr("seller");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        // 6. 发钱
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        // 7. 发 USDT 1W美元
        token.mint(buyer1, 10000 * 10 ** 6);
        token.mint(buyer2, 10000 * 10 ** 6);

        // 给卖家铸造个NFT
        vm.prank(seller);
        uint256 actualTokenId = nft.mint(seller);
        assertEq(TOKEN_ID, actualTokenId, "tokenId should be 0"); // 断言是 0

        // 5.授权操作
        vm.prank(seller);
        nft.approve(address(nftAuction), TOKEN_ID);
        vm.prank(buyer1);
        token.approve(address(nftAuction), type(uint256).max);
        vm.prank(buyer2);
        token.approve(address(nftAuction), type(uint256).max);
    }

    // ============================================================
    // Helper 函数
    // ============================================================

    /// @dev 创建拍卖（默认参数），返回 auctionId
    function _createAuction() internal returns (uint256) {
        return _createAuction(START_PRICE, 0, DURATION_HOURS);
    }

    /// @dev 创建拍卖（自定义参数）
    function _createAuction(
        uint256 startPrice,
        uint256 delayHours,
        uint256 durationHours
    ) internal returns (uint256 auctionId) {
        vm.prank(seller);
        auctionId = nftAuction.createAuction(
            address(nft),
            TOKEN_ID,
            startPrice,
            delayHours,
            durationHours
        );
    }

    /// @dev 快进到拍卖开始后
    function _warpToStart() internal {
        vm.warp(block.timestamp + START_TIME + 1 hours);
    }

    /// @dev 快进到拍卖结束后
    function _warpToEnd() internal {
        vm.warp(block.timestamp + (DURATION_HOURS + 1) * 1 hours);
    }

    /// @dev 前一个人用 ETH 出价
    function _placeEthBid(uint256 auctionId, address bidder, uint256 amount) internal {
        vm.prank(bidder);
        nftAuction.placeBid{value: amount}(auctionId, amount, address(0));
    }

    /// @dev 前一个人用 USDT 出价
    function _placeUsdtBid(uint256 auctionId, address bidder, uint256 amount) internal {
        vm.prank(bidder);
        nftAuction.placeBid(auctionId, amount, address(token));
    }

    function _approveNft(address owner, uint256 tokenId) internal {
        vm.prank(owner);
        nft.approve(address(nftAuction), tokenId);
    }

    function _revokeNft(address owner, uint256 tokenId) internal {
        vm.prank(owner);
        nft.approve(address(0), tokenId);
    }

    function _approveToken(address owner, uint256 amount) internal {
        vm.prank(owner);
        token.approve(address(nftAuction), amount);
    }

    function _revokeToken(address owner, uint256 amount) internal {
        vm.prank(owner);
        token.approve(address(0), amount);
    }
    // ============================================================
    // createAuction 测试
    // ============================================================

    function test_CreateAuction_Success() public {
        uint256 expectedStartTime = block.timestamp + START_TIME;
        vm.expectEmit(true, true, true, true);
        // 验证事件被触发
        emit AuctionCreated(0, seller, address(nft), TOKEN_ID, START_PRICE, block.timestamp, DURATION_HOURS);

        vm.prank(seller);
        uint256 auctionId = nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, DURATION_HOURS);
        // 验证nft转移到了拍卖合约
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "nft not transfer to nftAuction");
        // 验证拍卖id第一个是0
        assertEq(auctionId, 0);
        // 验证映射被记录
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), true);
        (
            address seller_,
            address nftContract_,
            uint256 tokenId_,
            uint256 startPrice_,
            uint256 startTime_,
            uint256 duration_,
            NftAuction.Status currentStatus_,
            uint256 highestBid_,
            address highestBidder_,
            uint256 highestBidAmount_,
            address tokenAddress_
        ) = nftAuction.auctions(auctionId);
        // 验证auction的数据是否符合预期
        assertEq(seller_, seller, "seller mismatch");
        assertEq(nftContract_, address(nft), "nftContract mismatch");
        assertEq(tokenId_, TOKEN_ID, "tokenId mismatch");
        assertEq(startPrice_, START_PRICE, "startPrice mismatch");
        assertEq(startTime_, expectedStartTime, "startTime mismatch");
        assertEq(duration_, DURATION_HOURS * 1 hours, "duration mismatch");
        // 因为startTime是0 表示立即开始
        assertEq(uint256(currentStatus_), uint256(NftAuction.Status.OnGoing), "currentStatus mismatch");
        assertEq(highestBid_, 0, "highestBid mismatch");
        assertEq(highestBidder_, address(0), "highestBidder mismatch");
        assertEq(highestBidAmount_, 0, "highestBidAmount mismatch");
        assertEq(tokenAddress_, address(0), "tokenAddress mismatch");
    }

    function test_CreateAuction_RevertIf_NotOwner() public {
        vm.prank(admin);
        vm.expectRevert("you are not the owner of this nft");
        nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, DURATION_HOURS);
    }

    function test_CreateAuction_RevertIf_NotApproved() public {
        _revokeNft(seller, TOKEN_ID);
        vm.prank(seller);
        vm.expectRevert("Marketplace not approved");
        nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, DURATION_HOURS);
    }

    function test_CreateAuction_RevertIf_AlreadyInAuction() public {
        _createAuction(100, 0, 24);
        vm.prank(seller);
        vm.expectRevert("NFT already in auction");
        nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, DURATION_HOURS);
    }

    function test_CreateAuction_RevertIf_InvalidPrice() public {
        vm.prank(seller);
        vm.expectRevert("start price invalid");
        nftAuction.createAuction(address(nft), TOKEN_ID, 0, 0, DURATION_HOURS);
    }

    function test_CreateAuction_RevertIf_InvalidDuration() public {
        vm.prank(seller);
        vm.expectRevert("_durationHours invalid");
        nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, 0);
    }

    function test_CreateAuction_TransfersNFTToContract() public {
        assertEq(nft.ownerOf(TOKEN_ID), seller);
        vm.prank(seller);
        nftAuction.createAuction(address(nft), TOKEN_ID, START_PRICE, 0, DURATION_HOURS);
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction));
    }

//    // ============================================================
//    // placeBid 测试
//    // ============================================================

    function test_PlaceBid_Success_ETH() public {
        uint256 auctionId = _createAuction();
        (, int256 _answer, , ,) = ethPriceFeed.latestRoundData();
        // 假设出价1ETH
        uint256 bidAmount = 1 * 10 ** 18;
        require(_answer > 0, "Price must be positive");
        uint256 highestBid = bidAmount * uint256(_answer) / 10 ** 18;
        vm.expectEmit(true, true, true, true);
        emit NewHighestBid(auctionId, buyer1, highestBid, bidAmount);
        vm.prank(buyer1);
        vm.warp(block.timestamp + 1);
        nftAuction.placeBid{value: bidAmount}(auctionId, bidAmount, address(0));
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 highestBid_,
            address highestBidder_,
            uint256 highestBidAmount_,
            address tokenAddress_
        ) = nftAuction.auctions(auctionId);
        assertEq(highestBid_, highestBid, "highestBid mismatch");
        assertEq(highestBidder_, buyer1, "highestBidder mismatch");
        assertEq(highestBidAmount_, bidAmount, "highestBidAmount mismatch");
        assertEq(tokenAddress_, address(0), "tokenAddress mismatch");
    }

    function test_PlaceBid_Success_ERC20() public {
        uint256 auctionId = _createAuction();
        (, int256 answer, , ,) = usdtPriceFeed.latestRoundData();
        // 假设出价101USDT
        uint256 bidAmount = 101 * 10 ** 6;
        require(answer > 0, "Price must be positive");
        uint256 highestBid = bidAmount * uint256(answer) / 10 ** 6;
        vm.expectEmit(true, true, true, true);
        emit NewHighestBid(auctionId, buyer2, highestBid, bidAmount);
        vm.prank(buyer2);
        vm.warp(block.timestamp + 1);
        nftAuction.placeBid(auctionId, bidAmount, address(token));
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 highestBid_,
            address highestBidder_,
            uint256 highestBidAmount_,
            address tokenAddress_
        ) = nftAuction.auctions(auctionId);
        assertEq(highestBid_, highestBid, "highestBid mismatch");
        assertEq(highestBidder_, buyer2, "highestBidder mismatch");
        assertEq(highestBidAmount_, bidAmount, "highestBidAmount mismatch");
        assertEq(tokenAddress_, address(token), "tokenAddress mismatch");
    }

    function test_PlaceBid_RevertIf_TooLow() public {
        uint256 auctionId = _createAuction();
        vm.prank(buyer1);
        vm.expectRevert("Bid too low");
        vm.warp(block.timestamp + 1);
        nftAuction.placeBid{value: 100}(auctionId, 100, address(0));
    }

    function test_PlaceBid_RevertIf_SellerBid() public {
        uint256 auctionId = _createAuction();
        vm.warp(block.timestamp + 1);
        vm.expectRevert("seller can not bid");
        vm.deal(seller, 100 ether);
        vm.prank(seller);
        nftAuction.placeBid{value: 1 * 10 ** 18}(auctionId, 1 * 10 ** 18, address(0));
    }

    function test_PlaceBid_RevertIf_NotStarted() public {
        uint256 auctionId = _createAuction(10, 1, 24);
        vm.prank(buyer1);
        vm.expectRevert("Not started yet");
        nftAuction.placeBid{value: 1 * 10 ** 18}(auctionId, 1 * 10 ** 18, address(0));
    }

    function test_PlaceBid_RevertIf_Ended() public {
        uint256 auctionId = _createAuction(10, 1, 24);
        vm.prank(buyer1);
        vm.expectRevert("Time Invalid");
        vm.warp(block.timestamp + 25 * 1 hours);
        nftAuction.placeBid{value: 1 * 10 ** 18}(auctionId, 1 * 10 ** 18, address(0));
    }

    function test_PlaceBid_RefundsPreviousBidder_ETH() public {
        uint256 auctionId = _createAuction();
        vm.warp(block.timestamp + 1);
        // 预言机获取价格
        (, int256 _answer, , ,) = ethPriceFeed.latestRoundData();
        // buyer1出价
        _placeEthBid(auctionId, buyer1, 1 ether);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 firstHighestBid_,
            address firstHighestBidder_,
            uint256 firstHighestBidAmount_,

        ) = nftAuction.auctions(auctionId);
        uint256 firstHighestBid = 1 ether * uint256(_answer) / 10 ** 18;
        assertEq(buyer1.balance, 99 ether, "buyer1 balance mismatch");
        assertEq(buyer2.balance, 100 ether, "buyer2 balance mismatch");
        assertEq(firstHighestBid_, firstHighestBid, "firstHighestBid mismatch");
        assertEq(firstHighestBidder_, buyer1, "firstHighestBidder mismatch");
        assertEq(firstHighestBidAmount_, 1 ether, "firstHighestBidAmount mismatch");
        // buyer2出价
        _placeEthBid(auctionId, buyer2, 2 ether);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 secondHighestBid_,
            address secondHighestBidder_,
            uint256 secondHighestBidAmount_,

        ) = nftAuction.auctions(auctionId);
        uint256 secondHighestBid = 2 ether * uint256(_answer) / 10 ** 18;
        assertEq(buyer1.balance, 100 ether, "buyer1 balance mismatch");
        assertEq(buyer2.balance, 98 ether, "buyer2 balance mismatch");
        assertEq(secondHighestBid_, secondHighestBid, "secondHighestBid mismatch");
        assertEq(secondHighestBidder_, buyer2, "secondHighestBidder mismatch");
        assertEq(secondHighestBidAmount_, 2 ether, "secondHighestBidAmount mismatch");
    }

    function test_PlaceBid_RefundsPreviousBidder_ERC20() public {
        uint256 auctionId = _createAuction();
        vm.warp(block.timestamp + 1);
        // 预言机获取价格
        (, int256 _answer, , ,) = usdtPriceFeed.latestRoundData();
        _placeUsdtBid(auctionId, buyer1, 101 * 10 ** 6);
        uint256 price = 101 * 10 ** 6 * uint256(_answer) / 10 ** 6;
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 firstHighestBid_,
            address firstHighestBidder_,
            uint256 firstHighestBidAmount_,
            address firstTokenAddress_
        ) = nftAuction.auctions(auctionId);
        assertEq(token.balanceOf(buyer1), 10000 * 10 ** 6 - 101 * 10 ** 6, "buyer1 balance mismatch");
        assertEq(token.balanceOf(buyer2), 10000 * 10 ** 6, "buyer2 balance mismatch");
        assertEq(firstHighestBid_, price, "firstHighestBid mismatch");
        assertEq(firstHighestBidder_, buyer1, "firstHighestBidder mismatch");
        assertEq(firstHighestBidAmount_, 101 * 10 ** 6, "firstHighestBidAmount mismatch");
        assertEq(firstTokenAddress_, address(token), "tokenAddress mismatch");
    }

    function test_PlaceBid_MustExceed105Percent() public {
        uint256 auctionId = _createAuction();
        vm.warp(block.timestamp + 1);
        // 预言机获取价格
        (, int256 _answer, , ,) = usdtPriceFeed.latestRoundData();
        _placeUsdtBid(auctionId, buyer1, 101 * 10 ** 6);
        uint256 price = 101 * 10 ** 6 * uint256(_answer) / 10 ** 6;
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 firstHighestBid_,
            address firstHighestBidder_,
            uint256 firstHighestBidAmount_,
            address firstTokenAddress_
        ) = nftAuction.auctions(auctionId);
        assertEq(token.balanceOf(buyer1), 10000 * 10 ** 6 - 101 * 10 ** 6, "buyer1 balance mismatch");
        assertEq(token.balanceOf(buyer2), 10000 * 10 ** 6, "buyer2 balance mismatch");
        assertEq(firstHighestBid_, price, "firstHighestBid mismatch");
        assertEq(firstHighestBidder_, buyer1, "firstHighestBidder mismatch");
        assertEq(firstHighestBidAmount_, 101 * 10 ** 6, "firstHighestBidAmount mismatch");
        assertEq(firstTokenAddress_, address(token), "tokenAddress mismatch");
        vm.expectRevert("Bid too low");
        _placeUsdtBid(auctionId, buyer2, 102 * 10 ** 6);
    }

    function test_PlaceBid_AutoTransitionsFromPendingToOnGoing() public {
        uint256 auctionId = _createAuction(100, 1, 24);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentState_,
            ,
            ,
            ,

        ) = nftAuction.auctions(auctionId);
        assertEq(uint256(currentState_), uint256(NftAuction.Status.Pending), "currentState mismatch");
        vm.warp(block.timestamp + 2 * 1 hours);
        _placeEthBid(auctionId, buyer1, 1 ether);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentStateNew_,
            ,
            ,
            ,

        ) = nftAuction.auctions(auctionId);
        assertEq(uint256(currentStateNew_), uint256(NftAuction.Status.OnGoing), "currentStateNew mismatch");
    }

    // ============================================================
    // endAuction 测试
    // ============================================================

    function test_EndAuction_Success_ETH() public {
        // 检查初始状态
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");

        // 创建拍卖
        uint256 auctionId = _createAuction();
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");

        // 记录余额
        uint256 sellerBalanceBefore = address(seller).balance;

        // 出价
        vm.warp(block.timestamp + 1);
        _placeEthBid(auctionId, buyer1, 1 ether);

        // 快进时间到拍卖结束
        vm.warp(block.timestamp + 25 * 1 hours);

        // 结束拍卖
        nftAuction.endAuction(auctionId);

        // 获取拍卖信息
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentStateNew_,
            ,
            address finalHighestBidder_,
            uint256 finalHighestBidAmount_,
        ) = nftAuction.auctions(auctionId);

        // 断言
        assertEq(uint256(currentStateNew_), uint256(NftAuction.Status.Ended), "final state mismatch");
        assertEq(nft.ownerOf(TOKEN_ID), buyer1, "final nft owner mismatch");
        assertEq(finalHighestBidder_, buyer1, "highest bidder mismatch");
        assertEq(finalHighestBidAmount_, 1 ether, "bid amount mismatch");
        assertEq(address(seller).balance - sellerBalanceBefore, 1 ether, "seller balance not match");
    }

    function test_EndAuction_Success_ERC20() public {
        // 检查初始状态
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");

        // 创建拍卖
        uint256 auctionId = _createAuction();
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // 出价
        vm.warp(block.timestamp + 1);
        _placeUsdtBid(auctionId, buyer2, 200 * 10 ** 6);

        // 快进时间到拍卖结束
        vm.warp(block.timestamp + 25 * 1 hours);

        // 结束拍卖
        nftAuction.endAuction(auctionId);

        // 获取拍卖信息
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentStateNew_,
            ,
            address finalHighestBidder_,
            uint256 finalHighestBidAmount_,
        ) = nftAuction.auctions(auctionId);

        // 断言
        assertEq(uint256(currentStateNew_), uint256(NftAuction.Status.Ended), "final state mismatch");
        assertEq(nft.ownerOf(TOKEN_ID), buyer2, "final nft owner mismatch");
        assertEq(finalHighestBidder_, buyer2, "highest bidder mismatch");
        assertEq(finalHighestBidAmount_, 200 * 10 ** 6, "bid amount mismatch");
        assertEq(token.balanceOf(seller) - sellerBalanceBefore, 200 * 10 ** 6, "seller ERC20 balance not match");
        assertEq(token.balanceOf(buyer2), 10000 * 10 ** 6 - 200 * 10 ** 6, "buyer2 ERC20 balance not match");
    }

    function test_EndAuction_NoBid_NFTReturned() public {
        // 检查初始状态
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");

        // 创建拍卖
        uint256 auctionId = _createAuction();
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");
        vm.warp(block.timestamp + 25 * 1 hours);
        nftAuction.endAuction(auctionId);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentStateNew_,
            ,
            ,
            ,
        ) = nftAuction.auctions(auctionId);
        assertEq(uint256(currentStateNew_), uint256(NftAuction.Status.NoBid), "final state mismatch");
        assertEq(nft.ownerOf(TOKEN_ID), seller, "final nft owner mismatch");
    }

    function test_EndAuction_RevertIf_NotEnded() public {
        // 检查初始状态
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");

        // 创建拍卖
        uint256 auctionId = _createAuction();
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");
        vm.warp(block.timestamp + 22 * 1 hours);
        vm.expectRevert("Auction not ended");
        nftAuction.endAuction(auctionId);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            NftAuction.Status currentStateNew_,
            ,
            ,
            ,
        ) = nftAuction.auctions(auctionId);
        assertEq(uint256(currentStateNew_), uint256(NftAuction.Status.OnGoing), "final state mismatch");
    }

    function test_EndAuction_RevertIf_AlreadyEnded() public {
        // ====== 场景1：有人出价，正常结束后再次调用 ======
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");

        uint256 auctionId = _createAuction();
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");

        // 出价
        vm.warp(block.timestamp + 1);
        _placeEthBid(auctionId, buyer1, 1 ether);

        // 快进到拍卖结束
        vm.warp(block.timestamp + 25 * 1 hours);

        // 第一次结束拍卖 - 应该成功
        nftAuction.endAuction(auctionId);

        // 验证状态已经是 Ended
        (,,,,,, NftAuction.Status status_,,,,) = nftAuction.auctions(auctionId);
        assertEq(uint256(status_), uint256(NftAuction.Status.Ended), "status should be Ended");

        // 第二次结束拍卖 - 应该 revert
        vm.expectRevert("Auction already ended or cancelled");
        nftAuction.endAuction(auctionId);
    }

    function test_EndAuction_RevertIf_AlreadyEnded_NoBid() public {
        // ====== 场景2：无人出价，流拍结束后再次调用 ======
        uint256 auctionId = _createAuction();

        // 快进到拍卖结束，无人出价
        vm.warp(block.timestamp + 25 * 1 hours);

        // 第一次结束拍卖 - 流拍
        nftAuction.endAuction(auctionId);

        // 验证状态是 NoBid
        (,,,,,, NftAuction.Status status_,,,,) = nftAuction.auctions(auctionId);
        assertEq(uint256(status_), uint256(NftAuction.Status.NoBid), "status should be NoBid");

        // 第二次结束拍卖 - 应该 revert
        vm.expectRevert("Auction already ended or cancelled");
        nftAuction.endAuction(auctionId);
    }

    function test_EndAuction_CleansMapping() public {
        // ====== 场景1：有人出价，正常结束后映射被清理 ======
        uint256 auctionId = _createAuction();

        // 创建后映射应该是 true
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), true, "mapping should be true after create");

        // 出价 + 快进到结束
        vm.warp(block.timestamp + 1);
        _placeEthBid(auctionId, buyer1, 1 ether);
        vm.warp(block.timestamp + 25 * 1 hours);

        // 结束拍卖
        nftAuction.endAuction(auctionId);

        // 映射应该被清理为 false
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), false, "mapping should be false after end");

        // ====== 场景2：无人出价，流拍后映射被清理 ======
        // 需要重新铸造一个 NFT（因为上一个已经转给 buyer1 了）
        vm.prank(seller);
        uint256 tokenId2 = nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(nftAuction), tokenId2);

        uint256 auctionId2 = nftAuction.nextAuctionId();
        vm.prank(seller);
        nftAuction.createAuction(address(nft), tokenId2, START_PRICE, 0, DURATION_HOURS);

        // 创建后映射应该是 true
        assertEq(nftAuction.nftToken2AuctionId(address(nft), tokenId2), true, "mapping should be true after create");

        // 快进到结束（无人出价）
        vm.warp(block.timestamp + 25 * 1 hours);
        nftAuction.endAuction(auctionId2);

        // 映射应该被清理为 false
        assertEq(nftAuction.nftToken2AuctionId(address(nft), tokenId2), false, "mapping should be false after noBid end");
    }

    // ============================================================
    // cancelAuction 测试
    // ============================================================

    function test_CancelAuction_Success() public {
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");
        uint256 auctionId = _createAuction(START_PRICE, 2, DURATION_HOURS);
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");
        vm.prank(seller);
        nftAuction.cancelAuction(auctionId);
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), false, "mapping should be false after cancelAuction success end");
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner should be seller after cancelAuction success end");
    }

    function test_CancelAuction_RevertIf_NotSeller() public {
        uint256 auctionId = _createAuction(START_PRICE, 2, DURATION_HOURS);
        vm.expectRevert("Only seller");
        vm.prank(buyer1);
        nftAuction.cancelAuction(auctionId);
    }

    function test_CancelAuction_RevertIf_AlreadyStarted() public {
        uint256 auctionId = _createAuction(START_PRICE, 2, DURATION_HOURS);
        vm.prank(seller);
        vm.expectRevert("Already started");
        vm.warp(block.timestamp + 3 * 1 hours);
        nftAuction.cancelAuction(auctionId);
    }

    function test_CancelAuction_RevertIf_NotPending() public {
        uint256 auctionId = _createAuction(START_PRICE, 0, DURATION_HOURS);
        vm.prank(seller);
        vm.expectRevert("Must be Pending");
        nftAuction.cancelAuction(auctionId);
    }

    function test_CancelAuction_CleansMapping() public {
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");
        uint256 auctionId = _createAuction(START_PRICE, 2, DURATION_HOURS);
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "after createAuction nft owner mismatch");
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), true, "after createAuction mapping should be true");
        vm.prank(seller);
        nftAuction.cancelAuction(auctionId);
        assertEq(nftAuction.nftToken2AuctionId(address(nft), TOKEN_ID), false, "mapping should be false after cancelAuction success end");
    }

    function test_CancelAuction_ReturnsNFT() public {
        assertEq(nft.ownerOf(TOKEN_ID), seller, "nft owner mismatch");
        uint256 auctionId = _createAuction(START_PRICE, 2, DURATION_HOURS);
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction), "nft ownerOf should be nftAuction after createAuction");
        vm.prank(seller);
        nftAuction.cancelAuction(auctionId);
        assertEq(nft.ownerOf(TOKEN_ID), address(seller), "nft ownerOf should be seller after cancelAuction success end");
    }

    // ============================================================
    // 升级测试
    // ============================================================

    function test_UpgradeContract_Success() public {
        // 1. 升级前先写入状态，验证数据存在
        _createAuction();
        assertEq(nftAuction.nextAuctionId(), 1, "nextAuctionId should be 1");
        assertEq(nftAuction.admin(), admin, "admin mismatch");

        // 2. 部署 V2 逻辑合约
        NftAuctionV2 v2 = new NftAuctionV2();

        // 3. admin 执行升级
        vm.prank(admin);
        nftAuction.upgradeToAndCall(address(v2),"");

        // 4. 验证旧数据保持不变（代理地址不变，存储不变）
        // 需要用 V2 的接口去访问（但这里 NftAuctionV2 继承自 NftAuction，
        // 所以 nftAuction 变量仍然可以调用 NftAuction 的方法）
        assertEq(nftAuction.nextAuctionId(), 1, "nextAuctionId preserved");
        assertEq(nftAuction.admin(), admin, "admin preserved");

        // 5. 验证新功能可用（将 nftAuction cast 为 V2）
        NftAuctionV2 v2Proxy = NftAuctionV2(address(nftAuction));
        assertEq(v2Proxy.test(), 1, "V2 new function should work");
    }

    function test_UpgradeContract_RevertIf_NotAdmin() public {
        NftAuctionV2 v2 = new NftAuctionV2();

        // 非 admin（seller）尝试升级
        vm.prank(seller);
        vm.expectRevert("Only admin can upgrade");
        nftAuction.upgradeToAndCall(address(v2),"");
    }


}
