# NFT Auction 智能合约测试报告

Ran 1 test for src/NftAuctionV2.sol:NftAuctionV2
[PASS] test() (gas: 398)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 633.20µs (139.80µs CPU time)

Ran 32 tests for test/NftAuction.t.sol:NftAuctionTest
[PASS] test_CancelAuction_CleansMapping() (gas: 259710)
[PASS] test_CancelAuction_ReturnsNFT() (gas: 256195)
[PASS] test_CancelAuction_RevertIf_AlreadyStarted() (gas: 262065)
[PASS] test_CancelAuction_RevertIf_NotPending() (gas: 281230)
[PASS] test_CancelAuction_RevertIf_NotSeller() (gas: 263123)
[PASS] test_CancelAuction_Success() (gas: 259034)
[PASS] test_CreateAuction_RevertIf_AlreadyInAuction() (gas: 260102)
[PASS] test_CreateAuction_RevertIf_InvalidDuration() (gas: 20793)
[PASS] test_CreateAuction_RevertIf_InvalidPrice() (gas: 20676)
[PASS] test_CreateAuction_RevertIf_NotApproved() (gas: 40441)
[PASS] test_CreateAuction_RevertIf_NotOwner() (gas: 29305)
[PASS] test_CreateAuction_Success() (gas: 273210)
[PASS] test_CreateAuction_TransfersNFTToContract() (gas: 259168)
[PASS] test_EndAuction_CleansMapping() (gas: 650061)
[PASS] test_EndAuction_NoBid_NFTReturned() (gas: 264815)
[PASS] test_EndAuction_RevertIf_AlreadyEnded() (gas: 409390)
[PASS] test_EndAuction_RevertIf_AlreadyEnded_NoBid() (gas: 262441)
[PASS] test_EndAuction_RevertIf_NotEnded() (gas: 292270)
[PASS] test_EndAuction_Success_ERC20() (gas: 440243)
[PASS] test_EndAuction_Success_ETH() (gas: 408649)
[PASS] test_PlaceBid_AutoTransitionsFromPendingToOnGoing() (gas: 378539)
[PASS] test_PlaceBid_MustExceed105Percent() (gas: 446079)
[PASS] test_PlaceBid_RefundsPreviousBidder_ERC20() (gas: 436375)
[PASS] test_PlaceBid_RefundsPreviousBidder_ETH() (gas: 416212)
[PASS] test_PlaceBid_RevertIf_Ended() (gas: 292127)
[PASS] test_PlaceBid_RevertIf_NotStarted() (gas: 270521)
[PASS] test_PlaceBid_RevertIf_SellerBid() (gas: 290858)
[PASS] test_PlaceBid_RevertIf_TooLow() (gas: 301932)
[PASS] test_PlaceBid_Success_ERC20() (gas: 431826)
[PASS] test_PlaceBid_Success_ETH() (gas: 379758)
[PASS] test_UpgradeContract_RevertIf_NotAdmin() (gas: 3600924)
[PASS] test_UpgradeContract_Success() (gas: 3858023)
Suite result: ok. 32 passed; 0 failed; 0 skipped; finished in 30.83ms (237.54ms CPU time)

Ran 2 test suites in 94.74s (31.47ms CPU time): 33 tests passed, 0 failed, 0 skipped (33 total tests)

╭-------------------------------+------------------+------------------+----------------+----------------╮
| File                          | % Lines          | % Statements     | % Branches     | % Funcs        |
+=======================================================================================================+
| script/NftAuction.s.sol       | 0.00% (0/23)     | 0.00% (0/24)     | 100.00% (0/0)  | 0.00% (0/2)    |
|-------------------------------+------------------+------------------+----------------+----------------|
| src/NftAuction.sol            | 98.18% (108/110) | 97.30% (108/111) | 77.03% (57/74) | 100.00% (8/8)  |
|-------------------------------+------------------+------------------+----------------+----------------|
| test/mocks/MockAggregator.sol | 28.57% (4/14)    | 28.57% (2/7)     | 100.00% (0/0)  | 28.57% (2/7)   |
|-------------------------------+------------------+------------------+----------------+----------------|
| test/mocks/MockERC20.sol      | 100.00% (2/2)    | 100.00% (1/1)    | 100.00% (0/0)  | 100.00% (1/1)  |
|-------------------------------+------------------+------------------+----------------+----------------|
| test/mocks/MockMyNft.sol      | 100.00% (4/4)    | 100.00% (4/4)    | 100.00% (0/0)  | 100.00% (1/1)  |
|-------------------------------+------------------+------------------+----------------+----------------|
| Total                         | 77.12% (118/153) | 78.23% (115/147) | 77.03% (57/74) | 63.16% (12/19) |
╰-------------------------------+------------------+------------------+----------------+----------------╯
