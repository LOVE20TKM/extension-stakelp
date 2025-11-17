// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionFactoryLp
} from "./interface/ILOVE20ExtensionFactoryLp.sol";
import {
    LOVE20ExtensionFactoryBase
} from "@extension/src/LOVE20ExtensionFactoryBase.sol";
import {LOVE20ExtensionLp} from "./LOVE20ExtensionLp.sol";

contract LOVE20ExtensionFactoryLp is
    LOVE20ExtensionFactoryBase,
    ILOVE20ExtensionFactoryLp
{
    // ============================================
    // STATE VARIABLES
    // ============================================

    // extension => ExtensionParams
    mapping(address => ExtensionParams) internal _extensionParams;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(address _center) LOVE20ExtensionFactoryBase(_center) {}

    // ============================================
    // StakeLp FACTORY FUNCTIONS
    // ============================================
    function createExtension(
        address joinTokenAddress,
        uint256 waitingBlocks,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    ) external returns (address extension) {
        // Validate parameters
        if (joinTokenAddress == address(0)) {
            revert InvalidJoinTokenAddress();
        }

        extension = address(
            new LOVE20ExtensionLp(
                address(this),
                joinTokenAddress,
                waitingBlocks,
                govRatioMultiplier,
                minGovVotes
            )
        );

        // Store extension parameters
        _extensionParams[extension] = ExtensionParams({
            joinTokenAddress: joinTokenAddress,
            waitingBlocks: waitingBlocks,
            govRatioMultiplier: govRatioMultiplier,
            minGovVotes: minGovVotes
        });

        // Register extension in base contract
        _registerExtension(extension);

        emit ExtensionCreated(
            extension,
            joinTokenAddress,
            waitingBlocks,
            govRatioMultiplier,
            minGovVotes
        );

        return extension;
    }

    /// @inheritdoc ILOVE20ExtensionFactoryLp
    function extensionParams(
        address extension
    )
        external
        view
        returns (
            address joinTokenAddress,
            uint256 waitingBlocks,
            uint256 govRatioMultiplier,
            uint256 minGovVotes
        )
    {
        ExtensionParams memory params = _extensionParams[extension];
        return (
            params.joinTokenAddress,
            params.waitingBlocks,
            params.govRatioMultiplier,
            params.minGovVotes
        );
    }
}
