// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionAutoScoreStake
} from "@extension/src/interface/ILOVE20ExtensionAutoScoreStake.sol";

interface ILOVE20ExtensionStakeLp is ILOVE20ExtensionAutoScoreStake {
    // StakeLp-specific errors (stake-related errors are in ILOVE20ExtensionAutoScoreStake)
    error InvalidStakeTokenAddress();

    // Stake-related events and functions are inherited from ILOVE20ExtensionAutoScoreStake

    // StakeLp-specific config
    function govRatioMultiplier() external view returns (uint256);
}
