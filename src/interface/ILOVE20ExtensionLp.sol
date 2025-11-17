// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionAutoScoreJoin
} from "@extension/src/interface/ILOVE20ExtensionAutoScoreJoin.sol";

interface ILOVE20ExtensionLp is ILOVE20ExtensionAutoScoreJoin {
    // StakeLp-specific errors (join-related errors are in ILOVE20ExtensionAutoScoreJoin)
    error InvalidJoinTokenAddress();

    // Join-related events and functions are inherited from ILOVE20ExtensionAutoScoreJoin

    // StakeLp-specific config
    function govRatioMultiplier() external view returns (uint256);
}
