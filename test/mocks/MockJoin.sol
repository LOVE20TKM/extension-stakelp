// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockJoin
 * @notice Mock Join contract for testing
 */
contract MockJoin {
    uint256 internal _currentRound = 1;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        internal _amounts;

    function join(
        address,
        uint256,
        uint256,
        string[] memory
    ) external pure returns (bool) {
        return true;
    }

    function setCurrentRound(uint256 round) external {
        _currentRound = round;
    }

    function currentRound() external view returns (uint256) {
        return _currentRound;
    }

    function amountByActionIdByAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (uint256) {
        return _amounts[tokenAddress][actionId][account];
    }
}
