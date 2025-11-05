// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {MockUniswapV2Pair} from "./MockUniswapV2Pair.sol";

/**
 * @title MockUniswapV2Factory
 * @notice Mock Uniswap V2 factory contract for testing
 */
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) internal _pairs;

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        pair = address(new MockUniswapV2Pair(tokenA, tokenB));
        MockUniswapV2Pair(pair).setFactory(address(this));
        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }
}
