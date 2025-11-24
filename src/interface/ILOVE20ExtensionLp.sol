// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionTokenJoinAuto
} from "@extension/src/interface/ILOVE20ExtensionTokenJoinAuto.sol";

interface ILOVE20ExtensionLp is ILOVE20ExtensionTokenJoinAuto {
    // Lp-specific errors (InvalidJoinTokenAddress is inherited from ITokenJoin)
    error InsufficientLpRatio();
    error InsufficientGovVotes();

    // Join-related events and functions are inherited from ILOVE20ExtensionAutoScoreJoin

    // Lp-specific config
    function govRatioMultiplier() external view returns (uint256);
    function lpRatioPrecision() external view returns (uint256);
    function minGovVotes() external view returns (uint256);
}
