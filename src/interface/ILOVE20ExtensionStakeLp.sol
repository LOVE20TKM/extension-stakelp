// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "@extension/src/interface/ILOVE20Extension.sol";

interface ILOVE20ExtensionStakeLp is ILOVE20Extension {
    error UniswapV2PairNotCreated();
    error OnlyCenterCanCall();
    error AlreadyInitialized();
    error InvalidTokenAddress();
    error UnstakeRequested();
    error StakeAmountZero();
    error NoStakedAmount();
    error UnstakeNotRequested();
    error NotEnoughWaitingPhases();
    error AlreadyClaimed();
    error RoundNotFinished();
    error InsufficientGovVotes();

    event Stake(address indexed account, uint256 amount);
    event Unstake(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);
    event ClaimReward(
        address indexed account,
        uint256 indexed round,
        uint256 reward
    );

    struct StakeInfo {
        uint256 amount;
        uint256 requestedUnstakeRound;
    }

    function anotherTokenAddress() external view returns (address);
    function waitingPhases() external view returns (uint256);
    function govRatioMultiplier() external view returns (uint256);
    function minGovVotes() external view returns (uint256);
    function lpTokenAddress() external view returns (address);
    function isTokenAddressTheFirstToken() external view returns (bool);

    function stakeLp(uint256 amount) external;
    function unstakeLp() external;
    function withdrawLp() external;

    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound);
    function stakers() external view returns (address[] memory);
    function stakersCount() external view returns (uint256);
    function stakersAtIndex(uint256 index) external view returns (address);

    function unstakers() external view returns (address[] memory);
    function unstakersCount() external view returns (uint256);
    function unstakersAtIndex(uint256 index) external view returns (address);
    function totalStakedAmount() external view returns (uint256);
    function totalUnstakedAmount() external view returns (uint256);
    function totalScore(uint256 round) external view returns (uint256);
    function verifiedAccounts(
        uint256 round
    ) external view returns (address[] memory);
    function verifiedAccountsCount(
        uint256 round
    ) external view returns (uint256);
    function verifiedAccountsAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address);

    function calculateScores()
        external
        view
        returns (uint256 total, uint256[] memory scores);
    function calculateScore(
        address account
    ) external view returns (uint256 total, uint256 score);
    function scores(uint256 round) external view returns (uint256[] memory);
    function scoresCount(uint256 round) external view returns (uint256);
    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256);
    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256);
}
