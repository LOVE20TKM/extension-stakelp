// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactoryStakeLp} from "./interface/ILOVE20ExtensionFactoryStakeLp.sol";
import {LOVE20ExtensionFactoryBase} from "@extension/src/LOVE20ExtensionFactoryBase.sol";
import {LOVE20ExtensionStakeLp} from "./LOVE20ExtensionStakeLp.sol";

contract LOVE20ExtensionFactoryStakeLp is
    LOVE20ExtensionFactoryBase,
    ILOVE20ExtensionFactoryStakeLp
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
        address stakeTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    ) external returns (address extension) {
        // Validate parameters
        if (stakeTokenAddress == address(0)) {
            revert InvalidStakeTokenAddress();
        }

        extension = address(
            new LOVE20ExtensionStakeLp(
                address(this),
                stakeTokenAddress,
                waitingPhases,
                govRatioMultiplier,
                minGovVotes
            )
        );

        // Store extension parameters
        _extensionParams[extension] = ExtensionParams({
            stakeTokenAddress: stakeTokenAddress,
            waitingPhases: waitingPhases,
            govRatioMultiplier: govRatioMultiplier,
            minGovVotes: minGovVotes
        });

        // Register extension in base contract
        _registerExtension(extension);

        emit ExtensionCreated(
            extension,
            stakeTokenAddress,
            waitingPhases,
            govRatioMultiplier,
            minGovVotes
        );

        return extension;
    }

    /// @inheritdoc ILOVE20ExtensionFactoryStakeLp
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
        )
    {
        ExtensionParams memory params = _extensionParams[extension];
        return (
            params.stakeTokenAddress,
            params.waitingPhases,
            params.govRatioMultiplier,
            params.minGovVotes
        );
    }
}
