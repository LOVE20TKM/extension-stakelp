// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockMint
 * @notice Mock Mint contract for testing
 */
contract MockMint {
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        internal _actionReward;

    function setActionReward(
        address tokenAddress,
        uint256 round,
        uint256 actionId,
        uint256 reward
    ) external {
        _actionReward[tokenAddress][round][actionId] = reward;
    }

    function actionRewardByActionIdByAccount(
        address tokenAddress,
        uint256 round,
        uint256 actionId,
        address
    ) external view returns (uint256, bool) {
        return (_actionReward[tokenAddress][round][actionId], true);
    }

    function mintActionReward(
        address tokenAddress,
        uint256 round,
        uint256 actionId
    ) external view returns (uint256) {
        return _actionReward[tokenAddress][round][actionId];
    }
}
