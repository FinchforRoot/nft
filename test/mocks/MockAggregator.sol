// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {

    int256 answer;

    constructor(int256 _answer) {
        answer = _answer;
    }

    function decimals() external view override returns (uint8){
        return 18;
    }

    function description() external view override returns (string memory){
        return "a test price feeder";
    }

    function version() external view override returns (uint256){
        return 0;
    }

    function getRoundData(
        uint80 _roundId
    ) external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return (0, answer, 0, 0, 0);
    }

    function latestRoundData()
    external
    view
    override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return (0, answer, 0, 0, 0);
    }

    function setPrice(int256 _answer) public {
        answer = _answer;
    }

}