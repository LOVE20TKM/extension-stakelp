// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ILOVE20ExtensionScore
} from "@extension/src/interface/ILOVE20ExtensionScore.sol";

interface ILOVE20ExtensionStakeLp is ILOVE20ExtensionScore {
    // Common errors (OnlyCenterCanCall, AlreadyInitialized, InvalidTokenAddress)
    // are defined in LOVE20ExtensionBase

    // StakeLp-specific errors
    error UnstakeRequested();
    error StakeAmountZero();
    error NoStakedAmount();
    error UnstakeNotRequested();
    error NotEnoughWaitingPhases();
    error InsufficientGovVotes();
    error InvalidStakeTokenAddress();

    event Stake(address indexed account, uint256 amount);
    event Unstake(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    struct StakeInfo {
        uint256 amount;
        uint256 requestedUnstakeRound;
    }

    function stakeTokenAddress() external view returns (address);
    function waitingPhases() external view returns (uint256);
    function govRatioMultiplier() external view returns (uint256);
    function minGovVotes() external view returns (uint256);

    function stake(uint256 amount) external;
    function unstake() external;
    function withdraw() external;

    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound);
    // stakers() related functions removed - use accounts(), accountsCount(), accountAtIndex() from ILOVE20Extension instead

    function unstakers() external view returns (address[] memory);
    function unstakersCount() external view returns (uint256);
    function unstakersAtIndex(uint256 index) external view returns (address);
    function totalStakedAmount() external view returns (uint256);
    function totalUnstakedAmount() external view returns (uint256);

    // Note: Score-related functions (totalScore, accountsByRound, calculateScores,
    // calculateScore, scores, scoreByAccount) are inherited from ILOVE20ExtensionScore
}
