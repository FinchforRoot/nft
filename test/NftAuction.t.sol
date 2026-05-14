// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockAggregator} from "./mocks/MockAggregator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockMyNft} from "./mocks/MockMyNft.sol";
import {NftAuction} from "../src/NftAuction.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

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
        // 2. 部署 MockERC20 和 MockERC721
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

    function _approveNFT(address owner, uint256 tokenId) internal {
        vm.prank(owner);
        nft.approve(address(nftAuction), tokenId);
    }

    function _revokeNFT(address owner, uint256 tokenId) internal {
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
        assertEq(nft.ownerOf(TOKEN_ID), address(nftAuction));
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
        assertEq(duration_, DURATION_HOURS, "duration mismatch");
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
        _revokeNFT(seller, TOKEN_ID);
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
            address firstTokenAddress_
        ) = nftAuction.actions(auctionId);
        assertEq(buyer1.balance, 99 ether, "buyer1 balance mismatch");
        assertEq(buyer2.balance, 100 ether, "buyer2 balance mismatch");
        assertEq(firstHighestBid_, firstHighestBid, "firstHighestBid mismatch");
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
            address secondTokenAddress_
        ) = nftAuction.actions(auctionId);
        assertEq(buyer1.balance, 100 ether, "buyer1 balance mismatch");
        assertEq(buyer2.balance, 98 ether, "buyer2 balance mismatch");

        // 执行前
        uint256 buyer1balanceBefore = buyer1.balance;
        console.log("buyer1 ETH before:", buyer1balanceBefore);
        vm.prank(buyer1);
        vm.warp(block.timestamp + 1);
        nftAuction.placeBid{value: 1 * 10 ** 17}(auctionId, 1 * 10 ** 17, address(0));
        // 执行后
        uint256 buyer1balanceAfter = buyer1.balance;
        console.log("buyer1 ETH after:", buyer1balanceAfter);

        // 然后继续测试buyer2出价
        uint256 buyer2balanceBefore = buyer2.balance;
        console.log("buyer2 ETH before:", buyer2balanceBefore);
        vm.prank(buyer2);
        nftAuction.placeBid{value: 2 * 10 ** 17}(auctionId, 2 * 10 ** 17, address(0));
        uint256 buyer2balanceAfter = buyer2.balance;
        console.log("buyer2 ETH after:", buyer2balanceAfter);

        uint256 balanceAfterBuyer2 = buyer1.balance;
        console.log("buyer1 ETH after Buyer2 bid:", balanceAfterBuyer2);

    }

//    function test_PlaceBid_RefundsPreviousBidder_ERC20() public {
//        // TODO: 实现
//    }
//
//    function test_PlaceBid_MustExceed105Percent() public {
//        // TODO: 实现
//    }
//
//    function test_PlaceBid_AutoTransitionsFromPendingToOnGoing() public {
//        // TODO: 实现
//    }
//
//    // ============================================================
//    // endAuction 测试
//    // ============================================================
//
//    function test_EndAuction_Success_ETH() public {
//        // TODO: 实现
//    }
//
//    function test_EndAuction_Success_ERC20() public {
//        // TODO: 实现
//    }
//
//    function test_EndAuction_NoBid_NFTReturned() public {
//        // TODO: 实现
//    }
//
//    function test_EndAuction_RevertIf_NotEnded() public {
//        // TODO: 实现
//    }
//
//    function test_EndAuction_RevertIf_AlreadyEnded() public {
//        // TODO: 实现
//    }
//
//    function test_EndAuction_CleansMapping() public {
//        // TODO: 实现
//    }
//
//    // ============================================================
//    // cancelAuction 测试
//    // ============================================================
//
//    function test_CancelAuction_Success() public {
//        // TODO: 实现
//    }
//
//    function test_CancelAuction_RevertIf_NotSeller() public {
//        // TODO: 实现
//    }
//
//    function test_CancelAuction_RevertIf_AlreadyStarted() public {
//        // TODO: 实现
//    }
//
//    function test_CancelAuction_RevertIf_NotPending() public {
//        // TODO: 实现
//    }
//
//    function test_CancelAuction_CleansMapping() public {
//        // TODO: 实现
//    }
//
//    function test_CancelAuction_ReturnsNFT() public {
//        // TODO: 实现
//    }
//
//    // ============================================================
//    // 升级测试（可选）
//    // ============================================================
//
//    function test_UpgradeContract_Success() public {
//        // TODO: 实现
//    }
//
//    function test_UpgradeContract_RevertIf_NotAdmin() public {
//        // TODO: 实现
//    }


}
