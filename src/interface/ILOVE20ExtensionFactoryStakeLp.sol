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
        uint256 minGovVotes;
    }

    // ============================================
    // ERRORS
    // ============================================

    error InvalidTokenAddress();
    error InvalidAnotherTokenAddress();
    error SameTokenAddresses();

    // ============================================
    // EVENTS
    // ============================================

    event ExtensionCreated(
        address extension,
        address indexed tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    );

    function createExtension(
        address tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    ) external returns (address extension);

    function extensionParams(
        address extension
    )
        external
        view
        returns (
            address tokenAddress,
            uint256 actionId,
            address anotherTokenAddress,
            uint256 waitingPhases,
            uint256 govRatioMultiplier,
            uint256 minGovVotes
        );
}
