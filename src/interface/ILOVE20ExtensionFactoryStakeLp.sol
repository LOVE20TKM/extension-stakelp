// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";

interface ILOVE20ExtensionFactoryStakeLp is ILOVE20ExtensionFactory {
    /// @notice Extension creation parameters
    struct ExtensionParams {
        address stakeTokenAddress;
        uint256 waitingPhases;
        uint256 govRatioMultiplier;
        uint256 minGovVotes;
    }

    // ============================================
    // ERRORS
    // ============================================

    error InvalidTokenAddress();
    error InvalidStakeTokenAddress();

    // ============================================
    // EVENTS
    // ============================================

    event ExtensionCreated(
        address extension,
        address stakeTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    );

    function createExtension(
        address stakeTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    ) external returns (address extension);

    /// @notice Get extension parameters
    /// @dev tokenAddress and actionId are read from the extension contract itself
    ///      (only available after initialization), other params are stored at creation
    /// @param extension The extension address
    /// @return stakeTokenAddress The staking token address
    /// @return waitingPhases The waiting phases for unstaking
    /// @return govRatioMultiplier The governance ratio multiplier
    /// @return minGovVotes The minimum governance votes required
    function extensionParams(
        address extension
    )
        external
        view
        returns (
            address stakeTokenAddress,
            uint256 waitingPhases,
            uint256 govRatioMultiplier,
            uint256 minGovVotes
        );
}
