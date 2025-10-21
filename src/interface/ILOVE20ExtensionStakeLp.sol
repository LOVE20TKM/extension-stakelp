// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "@extension/src/interface/ILOVE20Extension.sol";

interface ILOVE20ExtensionStakeLp is ILOVE20Extension {
    error UniswapV2PairNotCreated();
    error OnlyCenterCanCall();
    error AlreadyInitialized();
    error UnstakeRequested();
    error StakeAmountZero();
    error UnstakeNotRequested();
    error NotEnoughWaitingPhases();

    event Stake(address indexed account, uint256 amount);
    event Unstake(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    struct StakeInfo {
        uint256 amount;
        uint256 requestedUnstakeRound;
    }

    function anotherTokenAddress() external view returns (address);
    function waitingPhases() external view returns (uint256);
    function govRatioMultiplier() external view returns (uint256);

    function stakeLp(uint256 amount) external;
    function unstakeLp() external;
    function withdrawLp() external;
}
