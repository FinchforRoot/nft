// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TestAggregator is AggregatorV3Interface {

    int256 public answer;

    // 根据传入的answer初始化，直接定死返回的价格对照结果，例如1btc = 10000usd
    constructor(int256 _answer) {
        answer = _answer;
    }

    function decimals() external pure override returns (uint8){
        return 8;
    }

    function description() external pure override returns (string memory){
        return "a test price feeder";
    }

    function version() external pure override returns (uint256){
        return 0;
    }

    function getRoundData(uint80) external view override returns (uint80 roundId, int256 _answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return (0, answer, 0, 0, 0);
    }

    function latestRoundData()
    external
    view
    override returns (uint80 roundId, int256 _answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return (0, answer, 0, 0, 0);
    }

    function setPrice(int256 _answer) public {
        answer = _answer;
    }

}