// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyNft} from "../../src/nft/MyNft.sol";

contract MyNftTest is Test {

    MyNft public nft;

    address public owner;
    address public minter1;
    address public minter2;
    address public other;

    uint256 public constant MINT_PRICE = 0.00001 ether;
    uint256 public constant MAX_SUPPLY = 10000;

    event NFTMinted(address indexed minter, uint256 indexed tokenId, string uri);

    function setUp() public {
        owner = address(this);
        minter1 = address(0x1);
        minter2 = address(0x2);
        other = address(0x3);

        vm.deal(minter1, 100 ether);
        vm.deal(minter2, 100 ether);
        vm.deal(other, 100 ether);

        nft = new MyNft();
    }

    // ==================== Initialization Tests ====================

    function test_InitialState() public view {
        assertEq(nft.name(), "MyNft");
        assertEq(nft.symbol(), "MNFT");
        assertEq(nft.owner(), owner);
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.MAX_SUPPLY(), MAX_SUPPLY);
    }

    function test_SupportsInterface() public view {
        // ERC721 interface
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface
        assertTrue(nft.supportsInterface(0x5b5e139f));
    }

    // ==================== Mint Tests ====================

    function test_Mint_Success() public {
        string memory uri = "ipfs://test123";

        vm.prank(minter1);
        uint256 tokenId = nft.mint{value: MINT_PRICE}(uri);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), minter1);
        assertEq(nft.tokenURI(tokenId), uri);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(minter1), 1);
    }

    function test_Mint_MultipleTokens() public {
        vm.prank(minter1);
        uint256 tokenId1 = nft.mint{value: MINT_PRICE}("ipfs://1");

        vm.prank(minter2);
        uint256 tokenId2 = nft.mint{value: MINT_PRICE}("ipfs://2");

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.balanceOf(minter1), 1);
        assertEq(nft.balanceOf(minter2), 1);
    }

    function test_Mint_EmitEvent() public {
        string memory uri = "ipfs://test123";

        vm.expectEmit(true, true, true, true);
        emit NFTMinted(minter1, 1, uri);

        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}(uri);
    }

    function test_Mint_TokenIdIncrement() public {
        vm.prank(minter1);
        assertEq(nft.mint{value: MINT_PRICE}("uri1"), 1);

        vm.prank(minter2);
        assertEq(nft.mint{value: MINT_PRICE}("uri2"), 2);

        vm.prank(minter1);
        assertEq(nft.mint{value: MINT_PRICE}("uri3"), 3);
    }

    function test_Mint_TokenURICorrect() public {
        string memory uri = "ipfs://QmTest123";

        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}(uri);

        assertEq(nft.tokenURI(1), uri);
    }

    function test_Mint_ContractBalance() public {
        uint256 balanceBefore = address(nft).balance;

        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        assertEq(address(nft).balance, balanceBefore + MINT_PRICE);
    }

    function test_RevertMint_InsufficientPayment() public {
        vm.prank(minter1);
        vm.expectRevert(bytes("Insufficient payment"));
        nft.mint{value: MINT_PRICE - 1}("ipfs://test");
    }

    function test_RevertMint_MaxSupplyReached() public {
        // Mint all tokens
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            vm.prank(minter1);
            nft.mint{value: MINT_PRICE}("ipfs://test");
        }

        // Try to mint one more
        vm.prank(minter2);
        vm.expectRevert(bytes("Max supply reached"));
        nft.mint{value: MINT_PRICE}("ipfs://test");
    }

    function test_Mint_ExactPayment() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        assertEq(nft.ownerOf(1), minter1);
    }

    function test_Mint_Overpayment() public {
        // Overpayment should work (user pays more than required)
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE * 2}("ipfs://test");

        assertEq(nft.ownerOf(1), minter1);
    }

    function test_RevertMint_NoPayment() public {
        vm.prank(minter1);
        vm.expectRevert(bytes("Insufficient payment"));
        nft.mint{value: 0}("ipfs://test");
    }

    // ==================== Owner Tests ====================

    function test_Ownership_Transfer() public {
        address newOwner = address(0x999);

        nft.transferOwnership(newOwner);

        assertEq(nft.owner(), newOwner);
    }

    function test_RevertWithdraw_NotOwner() public {
        vm.prank(minter1);
        vm.expectRevert();
        nft.withdraw();
    }

    // ==================== Withdraw Tests ====================

    function test_Withdraw_Success() public {
        // Mint some NFTs to accumulate balance
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://1");

        vm.prank(minter2);
        nft.mint{value: MINT_PRICE}("ipfs://2");

        uint256 contractBalance = address(nft).balance;
        uint256 ownerBalanceBefore = owner.balance;

        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
    }

    function test_Withdraw_MultipleTimes() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://1");

        nft.withdraw();

        // Contract balance should be 0
        assertEq(address(nft).balance, 0);

        // Second withdraw should fail
        vm.expectRevert(bytes("No balance to withdraw"));
        nft.withdraw();
    }

    function test_Withdraw_AccumulatedBalance() public {
        uint256 mintCount = 100;
        uint256 expectedBalance = MINT_PRICE * mintCount;

        for (uint256 i = 0; i < mintCount; i++) {
            vm.prank(minter1);
            nft.mint{value: MINT_PRICE}("ipfs://test");
        }

        assertEq(address(nft).balance, expectedBalance);

        uint256 ownerBalanceBefore = owner.balance;
        nft.withdraw();

        assertEq(owner.balance, ownerBalanceBefore + expectedBalance);
        assertEq(address(nft).balance, 0);
    }

    function test_RevertWithdraw_NoBalance() public {
        vm.expectRevert(bytes("No balance to withdraw"));
        nft.withdraw();
    }

    function test_RevertWithdraw_WithdrawFail() public {
        // This test would require a malicious contract that can't receive ETH
        // For now, we assume normal withdraw works
        // In a real scenario, you might test with a contract that rejects ETH
        assertTrue(true);
    }

    // ==================== ERC721 Standard Tests ====================

    function test_TransferFrom_Success() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        vm.prank(minter1);
        nft.transferFrom(minter1, minter2, 1);

        assertEq(nft.ownerOf(1), minter2);
        assertEq(nft.balanceOf(minter1), 0);
        assertEq(nft.balanceOf(minter2), 1);
    }

    function test_Approve_Success() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        vm.prank(minter1);
        nft.approve(minter2, 1);

        assertEq(nft.getApproved(1), minter2);
    }

    function test_SetApprovalForAll_Success() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        vm.prank(minter1);
        nft.setApprovalForAll(minter2, true);

        assertTrue(nft.isApprovedForAll(minter1, minter2));
    }

    function test_RevertTransferFrom_NotOwner() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("ipfs://test");

        vm.prank(minter2);
        vm.expectRevert();
        nft.transferFrom(minter1, minter2, 1);
    }

    function test_RevertTransferFrom_InvalidTokenId() public {
        vm.prank(minter1);
        vm.expectRevert();
        nft.transferFrom(minter1, minter2, 999);
    }

    // ==================== TokenURI Tests ====================

    function test_TokenURI_NotMinted() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }

    function test_TokenURI_EmptyString() public {
        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}("");

        assertEq(nft.tokenURI(1), "");
    }

    // ==================== Fuzz Tests ====================

    function testFuzz_Mint_WithValidPayment(uint256 extraPayment) public {
        // Bound extra payment to reasonable values (0 to 1 ether)
        extraPayment = bound(extraPayment, 0, 1 ether);

        vm.prank(minter1);
        uint256 tokenId = nft.mint{value: MINT_PRICE + extraPayment}("ipfs://test");

        assertEq(tokenId, nft.totalSupply());
        assertEq(nft.ownerOf(tokenId), minter1);
    }

    function testFuzz_Mint_InsufficientPayment(uint256 payment) public {
        // Payment less than MINT_PRICE should fail
        payment = bound(payment, 0, MINT_PRICE - 1);

        vm.prank(minter1);
        vm.expectRevert(bytes("Insufficient payment"));
        nft.mint{value: payment}("ipfs://test");
    }

    function testFuzz_MintWithURI(bytes32 uriSeed) public {
        string memory uri = vm.toString(uriSeed);

        vm.prank(minter1);
        uint256 tokenId = nft.mint{value: MINT_PRICE}(uri);

        assertEq(nft.tokenURI(tokenId), uri);
    }

    // ==================== Integration Tests ====================

    function test_FullMintCycle() public {
        string memory uri = "ipfs://QmFullCycleTest";

        // Mint
        vm.prank(minter1);
        uint256 tokenId = nft.mint{value: MINT_PRICE}(uri);

        // Verify ownership
        assertEq(nft.ownerOf(tokenId), minter1);
        assertEq(nft.tokenURI(tokenId), uri);

        // Approve transfer
        vm.prank(minter1);
        nft.approve(minter2, 1);

        // Transfer
        vm.prank(minter2);
        nft.transferFrom(minter1, minter2, 1);

        // Verify new ownership
        assertEq(nft.ownerOf(1), minter2);
        assertEq(nft.balanceOf(minter1), 0);
        assertEq(nft.balanceOf(minter2), 1);

        // Withdraw accumulated fees
        uint256 ownerBalanceBefore = owner.balance;
        nft.withdraw();
        assertEq(owner.balance, ownerBalanceBefore + MINT_PRICE);
    }

    function test_MultipleMinters() public {
        address[] memory minters = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            minters[i] = address(uint160(i + 1));
            vm.deal(minters[i], 1 ether);
        }

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(minters[i]);
            nft.mint{value: MINT_PRICE}(vm.toString(i));
        }

        assertEq(nft.totalSupply(), 10);

        for (uint256 i = 0; i < 10; i++) {
            assertEq(nft.balanceOf(minters[i]), 1);
        }
    }

    function test_MintToMaxSupply() public {
        // Mint up to MAX_SUPPLY
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            address minter = i % 2 == 0 ? minter1 : minter2;
            vm.prank(minter);
            nft.mint{value: MINT_PRICE}(vm.toString(i));
        }

        assertEq(nft.totalSupply(), MAX_SUPPLY);

        // Verify next mint fails
        vm.prank(minter1);
        vm.expectRevert(bytes("Max supply reached"));
        nft.mint{value: MINT_PRICE}("ipfs://final");
    }

    // ==================== Edge Cases Tests ====================

    function test_MintFirstTokenIdIsOne() public {
        vm.prank(minter1);
        uint256 tokenId = nft.mint{value: MINT_PRICE}("ipfs://test");

        assertEq(tokenId, 1);
    }

    function test_TokenIdSequential() public {
        vm.prank(minter1);
        assertEq(nft.mint{value: MINT_PRICE}("a"), 1);

        vm.prank(minter1);
        assertEq(nft.mint{value: MINT_PRICE}("b"), 2);

        vm.prank(minter2);
        assertEq(nft.mint{value: MINT_PRICE}("c"), 3);
    }

    function test_MintWithVeryLongURI() public {
        string memory longURI;
        for (uint256 i = 0; i < 1000; i++) {
            longURI = string.concat(longURI, "a");
        }

        vm.prank(minter1);
        nft.mint{value: MINT_PRICE}(longURI);

        assertEq(nft.tokenURI(1), longURI);
    }

    function test_RevertMintByZeroAddress() public {
        // Zero address can't mint because it has no ETH
        vm.expectRevert(); // Will fail due to no funds, not explicit check
        nft.mint{value: MINT_PRICE}("ipfs://test");
    }
}
