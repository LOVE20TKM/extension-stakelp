// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@core/script/BaseScript.sol";
import {LOVE20ExtensionFactoryStakeLp} from "../src/LOVE20ExtensionFactoryStakeLp.sol";

/**
 * @title DeployLOVE20ExtensionFactoryStakeLp
 * @notice Script for deploying LOVE20ExtensionFactoryStakeLp contract
 * @dev Reads extensionCenterAddress from address.extension.center.params and writes deployed address to address.extension.factory.stakelp.params
 */
contract DeployLOVE20ExtensionFactoryStakeLp is BaseScript {
    address public extensionFactoryStakeLpAddress;

    /**
     * @notice Deploy LOVE20ExtensionFactoryStakeLp with extensionCenterAddress from address.extension.center.params
     * @dev The required center address is read from the network's address.extension.center.params file
     */
    function run() external {
        // Read extensionCenterAddress from address.extension.center.params
        address extensionCenterAddress = readAddressParamsFile(
            "address.extension.center.params",
            "extensionCenterAddress"
        );

        // Validate address
        require(
            extensionCenterAddress != address(0),
            "extensionCenterAddress not found"
        );

        // Deploy LOVE20ExtensionFactoryStakeLp
        vm.startBroadcast();
        extensionFactoryStakeLpAddress = address(
            new LOVE20ExtensionFactoryStakeLp(extensionCenterAddress)
        );
        vm.stopBroadcast();

        // Log deployment info if enabled
        if (!hideLogs) {
            console.log(
                "LOVE20ExtensionFactoryStakeLp deployed at:",
                extensionFactoryStakeLpAddress
            );
            console.log("Constructor parameters:");
            console.log("  extensionCenterAddress:", extensionCenterAddress);
        }

        // Update address file
        updateParamsFile(
            "address.extension.factory.stakelp.params",
            "extensionFactoryStakeLpAddress",
            vm.toString(extensionFactoryStakeLpAddress)
        );
    }
}
