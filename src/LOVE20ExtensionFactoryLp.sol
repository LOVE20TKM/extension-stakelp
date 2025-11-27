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
    // Lp FACTORY FUNCTIONS
    // ============================================
    function createExtension(
        address tokenAddress,
        address joinTokenAddress,
        uint256 waitingBlocks,
        uint256 govRatioMultiplier,
        uint256 minGovVotes,
        uint256 lpRatioPrecision
    ) external returns (address extension) {
        // Validate parameters
        if (joinTokenAddress == address(0)) {
            revert InvalidJoinTokenAddress();
        }

        extension = address(
            new LOVE20ExtensionLp(
                address(this),
                tokenAddress,
                joinTokenAddress,
                waitingBlocks,
                govRatioMultiplier,
                minGovVotes,
                lpRatioPrecision
            )
        );

        // Store extension parameters
        _extensionParams[extension] = ExtensionParams({
            tokenAddress: tokenAddress,
            joinTokenAddress: joinTokenAddress,
            waitingBlocks: waitingBlocks,
            govRatioMultiplier: govRatioMultiplier,
            minGovVotes: minGovVotes,
            lpRatioPrecision: lpRatioPrecision
        });

        // Register extension in base contract
        _registerExtension(extension);

        emit ExtensionCreated(
            extension,
            tokenAddress,
            joinTokenAddress,
            waitingBlocks,
            govRatioMultiplier,
            minGovVotes,
            lpRatioPrecision
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
            address tokenAddress,
            address joinTokenAddress,
            uint256 waitingBlocks,
            uint256 govRatioMultiplier,
            uint256 minGovVotes,
            uint256 lpRatioPrecision
        )
    {
        ExtensionParams memory params = _extensionParams[extension];
        return (
            params.tokenAddress,
            params.joinTokenAddress,
            params.waitingBlocks,
            params.govRatioMultiplier,
            params.minGovVotes,
            params.lpRatioPrecision
        );
    }
}
