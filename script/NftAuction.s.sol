// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NftAuction} from "../src/NftAuction.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftAuctionScript is Script {
    NftAuction public implementation;

    // 从环境变量读取喂价合约地址
    address internal ethUsdPriceFeed;
    address internal usdtUsdPriceFeed;
    address internal usdtAddress;

    function setUp() public {
        // 从 .env 或 forge 命令行参数读取喂价合约地址
        ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        usdtUsdPriceFeed = vm.envAddress("USDT_USD_PRICE_FEED");
        usdtAddress = vm.envAddress("USDT_ADDRESS");
    }

    function run() public {
        vm.startBroadcast();

        // 1. 部署逻辑合约
        implementation = new NftAuction();
        console.log("Implementation deployed at:", address(implementation));

        // 2. 编码 initialize() 调用数据
        bytes memory data = abi.encodeCall(NftAuction.initialize, ());

        // 3. 部署代理合约，指向逻辑合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        console.log("Proxy deployed at:", address(proxy));

        // 4. 通过代理合约地址来使用
        NftAuction nftAuction = NftAuction(address(proxy));

        // 5. 注册喂价合约
        // address(0) 代表 ETH
        nftAuction.setPriceFeed(address(0), ethUsdPriceFeed);
        console.log("ETH/USD Price Feed registered:", ethUsdPriceFeed);

        // 注册 USDT 喂价合约
        nftAuction.setPriceFeed(usdtAddress, usdtUsdPriceFeed);
        console.log("USDT/USD Price Feed registered:", usdtUsdPriceFeed);
        console.log("USDT Address:", usdtAddress);

        vm.stopBroadcast();

        console.log("===================================");
        console.log("Deployment Summary:");
        console.log("Implementation:", address(implementation));
        console.log("Proxy (NftAuction):", address(proxy));
        console.log("===================================");
    }
}
