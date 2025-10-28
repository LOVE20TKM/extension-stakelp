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
        address tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier,
        uint256 minGovVotes
    ) external returns (address extension) {
        // Validate parameters
        if (tokenAddress == address(0)) {
            revert InvalidTokenAddress();
        }
        if (anotherTokenAddress == address(0)) {
            revert InvalidAnotherTokenAddress();
        }
        if (tokenAddress == anotherTokenAddress) {
            revert SameTokenAddresses();
        }

        extension = address(
            new LOVE20ExtensionStakeLp(
                address(this),
                anotherTokenAddress,
                waitingPhases,
                govRatioMultiplier,
                minGovVotes
            )
        );

        // Store extension parameters
        _extensionParams[extension] = ExtensionParams({
            tokenAddress: tokenAddress,
            actionId: actionId,
            anotherTokenAddress: anotherTokenAddress,
            waitingPhases: waitingPhases,
            govRatioMultiplier: govRatioMultiplier,
            minGovVotes: minGovVotes
        });

        // Register extension in base contract
        _registerExtension(tokenAddress, extension);

        emit ExtensionCreated(
            extension,
            tokenAddress,
            actionId,
            anotherTokenAddress,
            waitingPhases,
            govRatioMultiplier,
            minGovVotes
        );

        return extension;
    }

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
        )
    {
        ExtensionParams memory params = _extensionParams[extension];
        return (
            params.tokenAddress,
            params.actionId,
            params.anotherTokenAddress,
            params.waitingPhases,
            params.govRatioMultiplier,
            params.minGovVotes
        );
    }
}
