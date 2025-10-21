// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";

interface ILOVE20ExtensionFactoryStakeLp is ILOVE20ExtensionFactory {
    /// @notice Extension creation parameters
    struct ExtensionParams {
        address tokenAddress;
        uint256 actionId;
        address anotherTokenAddress;
        uint256 waitingPhases;
        uint256 govRatioMultiplier;
    }
    // ============================================
    // EVENTS
    // ============================================

    event ExtensionCreated(
        address extension,
        address indexed tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier
    );

    function createExtension(
        address tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier
    ) external returns (address extension);
}
