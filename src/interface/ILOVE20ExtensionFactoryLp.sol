// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionFactory
} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";

interface ILOVE20ExtensionFactoryLp is ILOVE20ExtensionFactory {
    /// @notice Extension creation parameters
    struct ExtensionParams {
        address joinTokenAddress; // Token address for joining actions
        uint256 waitingBlocks; // Number of blocks to wait before unstaking
        uint256 govRatioMultiplier; // Governance ratio multiplier
        uint256 minGovVotes; // Minimum governance votes required
        uint256 lpRatioPrecision; // LP ratio precision for minimum participation requirement
    }

    // ============================================
    // ERRORS
    // ============================================

    error InvalidJoinTokenAddress();

    // ============================================
    // EVENTS
    // ============================================

    event ExtensionCreated(
        address extension,
        address joinTokenAddress,
        uint256 waitingBlocks,
        uint256 govRatioMultiplier,
        uint256 minGovVotes,
        uint256 lpRatioPrecision
    );

    function createExtension(
        address joinTokenAddress,
        uint256 waitingBlocks,
        uint256 govRatioMultiplier,
        uint256 minGovVotes,
        uint256 lpRatioPrecision
    ) external returns (address extension);

    /// @notice Get extension parameters
    /// @dev tokenAddress and actionId are read from the extension contract itself
    ///      (only available after initialization), other params are stored at creation
    /// @param extension The extension address
    /// @return joinTokenAddress The join token address for participating in actions
    /// @return waitingBlocks The waiting blocks for unstaking
    /// @return govRatioMultiplier The governance ratio multiplier
    /// @return minGovVotes The minimum governance votes required
    /// @return lpRatioPrecision The LP ratio precision for minimum participation requirement
    function extensionParams(
        address extension
    )
        external
        view
        returns (
            address joinTokenAddress,
            uint256 waitingBlocks,
            uint256 govRatioMultiplier,
            uint256 minGovVotes,
            uint256 lpRatioPrecision
        );
}
