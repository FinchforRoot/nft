// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {NftAuction} from "../src/NftAuction.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftAuctionScript is Script {
    NftAuction public implementation;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 1. 部署逻辑合约
        implementation = new NftAuction();

        // 2. 编码 initialize() 调用数据
        bytes memory data = abi.encodeCall(NftAuction.initialize, ());

        // 3.部署代理合约，指向逻辑合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        // 4. 通过代理合约地址来使用
        NftAuction nftAuction = NftAuction(address(proxy));

        vm.stopBroadcast();
    }
}
