// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {NftAuction} from "../src/NftAuction.sol";

contract NftAuctionScript is Script {
    NftAuction public nftAuction;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        nftAuction = new NftAuction();

        vm.stopBroadcast();
    }
}
