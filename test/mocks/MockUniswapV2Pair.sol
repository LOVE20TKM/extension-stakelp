// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockUniswapV2Pair
 * @notice Mock Uniswap V2 pair contract for testing
 */
contract MockUniswapV2Pair is MockERC20 {
    address internal _factory;
    address internal _token0;
    address internal _token1;
    uint112 internal _reserve0;
    uint112 internal _reserve1;
    uint32 internal _blockTimestampLast;

    constructor(address token0_, address token1_) {
        _token0 = token0_;
        _token1 = token1_;
    }

    function setFactory(address factory_) external {
        _factory = factory_;
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function token0() external view returns (address) {
        return _token0;
    }

    function token1() external view returns (address) {
        return _token1;
    }

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        _reserve0 = reserve0_;
        _reserve1 = reserve1_;
        _blockTimestampLast = uint32(block.timestamp);
    }
}
