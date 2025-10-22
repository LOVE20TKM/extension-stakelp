// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactoryStakeLp} from "./interface/ILOVE20ExtensionFactoryStakeLp.sol";
import {LOVE20ExtensionStakeLp} from "./LOVE20ExtensionStakeLp.sol";

contract LOVE20ExtensionFactoryStakeLp is ILOVE20ExtensionFactoryStakeLp {
    address public immutable center;

    // tokenAddress => extension[]
    mapping(address => address[]) private _extensions;

    // extension => bool
    mapping(address => bool) private _isExtension;

    // extension => ExtensionParams
    mapping(address => ExtensionParams) internal _extensionParams;

    constructor(address _center) {
        center = _center;
    }

    // ============================================
    // ILOVE20ExtensionFactory INTERFACE
    // ============================================

    function extensionsCount(
        address tokenAddress
    ) external view override returns (uint256) {
        return _extensions[tokenAddress].length;
    }

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view override returns (address) {
        return _extensions[tokenAddress][index];
    }

    function exists(address extension) external view override returns (bool) {
        return _isExtension[extension];
    }

    // ============================================
    // StakeLp FACTORY FUNCTIONS
    // ============================================
    function createExtension(
        address tokenAddress,
        uint256 actionId,
        address anotherTokenAddress,
        uint256 waitingPhases,
        uint256 govRatioMultiplier
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
                tokenAddress,
                actionId,
                anotherTokenAddress,
                waitingPhases,
                govRatioMultiplier
            )
        );
        _extensionParams[extension] = ExtensionParams({
            tokenAddress: tokenAddress,
            actionId: actionId,
            anotherTokenAddress: anotherTokenAddress,
            waitingPhases: waitingPhases,
            govRatioMultiplier: govRatioMultiplier
        });
        _extensions[tokenAddress].push(extension);
        _isExtension[extension] = true;
        emit ExtensionCreated(
            extension,
            tokenAddress,
            actionId,
            anotherTokenAddress,
            waitingPhases,
            govRatioMultiplier
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
            uint256 govRatioMultiplier
        )
    {
        ExtensionParams memory params = _extensionParams[extension];
        return (
            params.tokenAddress,
            params.actionId,
            params.anotherTokenAddress,
            params.waitingPhases,
            params.govRatioMultiplier
        );
    }
}
