// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockVerify
 * @notice Mock Verify contract for testing
 */
contract MockVerify {
    uint256 internal _currentRound = 1;

    function setCurrentRound(uint256 round) external {
        _currentRound = round;
    }

    function currentRound() external view returns (uint256) {
        return _currentRound;
    }
}
