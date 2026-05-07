// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    uint256 private price;
    uint8 private priceDecimals;

    constructor(uint256 _price, uint8 _decimals) {
        price = _price;
        priceDecimals = _decimals;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, int256(price), 0, block.timestamp, 0);
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function decimals() external view override returns (uint8) {
        return priceDecimals;
    }

    function description() external view override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, int256(price), 0, block.timestamp, 0);
    }
}
