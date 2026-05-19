// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NftAuction} from "../src/NftAuction.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestAggregator} from "../src/test/TestAggregator.sol";
import {TestERC20} from "../src/test/TestERC20.sol";
import {TestMyNft} from "../src/test/TestMyNft.sol";

contract NftAuctionScript is Script {
    NftAuction public implementation;
    TestAggregator public ethUsdAggregator;
    TestAggregator public usdtUsdAggregator;
    TestERC20 public usdt;
    TestMyNft public myNft;

    function setUp() public {
        // 不再需要从环境变量读取地址
    }

    function run() public {
        vm.startBroadcast();

        // 1. 部署 ETH/USD 喂价合约 (价格: 3000 USD, 8位精度)
        ethUsdAggregator = new TestAggregator(3000 * 10 ** 8);
        console.log("ETH/USD Aggregator deployed at:", address(ethUsdAggregator));

        // 2. 部署 USDT/USD 喂价合约 (价格: 1 USD, 8位精度)
        usdtUsdAggregator = new TestAggregator(1 * 10 ** 8);
        console.log("USDT/USD Aggregator deployed at:", address(usdtUsdAggregator));

        // 3. 部署 USDT 代币合约
        usdt = new TestERC20();
        console.log("USDT deployed at:", address(usdt));

        // 4. 部署测试 NFT 合约
        myNft = new TestMyNft();
        console.log("TestMyNft deployed at:", address(myNft));

        // 5. 部署 NftAuction 逻辑合约
        implementation = new NftAuction();
        console.log("NftAuction Implementation deployed at:", address(implementation));

        // 6. 编码 initialize() 调用数据
        bytes memory data = abi.encodeCall(NftAuction.initialize, ());

        // 7. 部署代理合约，指向逻辑合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        console.log("ERC1967Proxy deployed at:", address(proxy));

        // 8. 通过代理合约地址来使用
        NftAuction nftAuction = NftAuction(address(proxy));

        // 9. 注册 ETH/USD 喂价合约 (address(0) 代表 ETH)
        nftAuction.setPriceFeed(address(0), address(ethUsdAggregator));
        console.log("ETH/USD Price Feed registered:", address(ethUsdAggregator));

        // 10. 注册 USDT/USD 喂价合约
        nftAuction.setPriceFeed(address(usdt), address(usdtUsdAggregator));
        console.log("USDT/USD Price Feed registered:", address(usdtUsdAggregator));

        // 11. Mint 测试代币给部署者 (1000 USDT)
        uint256 mintAmount = 1000 * 10 ** 6; // USDT 6位精度
        usdt.mint(msg.sender, mintAmount);
        console.log("Minted 1000 USDT to deployer:", msg.sender);

        // 12. Mint 测试 NFT 给部署者 (tokenId = 0)
        uint256 tokenId = myNft.mint(msg.sender);
        console.log("Minted NFT tokenId", tokenId, "to deployer:", msg.sender);

        vm.stopBroadcast();

        console.log("===================================");
        console.log("Deployment Summary:");
        console.log("ETH/USD Aggregator:", address(ethUsdAggregator));
        console.log("USDT/USD Aggregator:", address(usdtUsdAggregator));
        console.log("USDT Token:", address(usdt));
        console.log("TestMyNft:", address(myNft));
        console.log("NftAuction Implementation:", address(implementation));
        console.log("NftAuction Proxy:", address(proxy));
        console.log("Deployer:", msg.sender);
        console.log("===================================");
    }
}
