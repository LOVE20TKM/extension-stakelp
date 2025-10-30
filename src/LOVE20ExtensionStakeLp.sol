// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionStakeLp} from "./interface/ILOVE20ExtensionStakeLp.sol";
import {LOVE20ExtensionBase} from "@extension/src/LOVE20ExtensionBase.sol";
import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";
import {IUniswapV2Factory} from "@core/src/uniswap-v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@core/src/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";
import {ILOVE20Token} from "@core/src/interfaces/ILOVE20Token.sol";
import {ArrayUtils} from "@core/src/lib/ArrayUtils.sol";

/**
 * @title LOVE20ExtensionStakeLp
 * @notice LP staking extension for LOVE20 protocol with phase-based unlocking and reward distribution
 * @dev Extends LOVE20ExtensionBase and implements ILOVE20ExtensionStakeLp interface
 */
contract LOVE20ExtensionStakeLp is
    LOVE20ExtensionBase,
    ILOVE20ExtensionStakeLp
{
    using ArrayUtils for address[];

    // ============================================
    // STATE VARIABLES
    // ============================================

    address public immutable anotherTokenAddress;
    uint256 public immutable waitingPhases;
    uint256 public immutable govRatioMultiplier;
    uint256 public immutable minGovVotes;
    address public lpTokenAddress;

    IUniswapV2Pair internal _pair;
    bool internal _isTokenAddressTheFirstToken;

    uint256 public totalStakedAmount;
    uint256 public totalUnstakedAmount;
    address[] internal _stakers;
    address[] internal _unstakers;
    // account => StakeInfo
    mapping(address => StakeInfo) internal _stakeInfo;

    // round => totalScore
    mapping(uint256 => uint256) internal _totalScore;
    // round => account[]
    mapping(uint256 => address[]) internal _verifiedAccounts;
    // round => score[]
    mapping(uint256 => uint256[]) internal _scores;
    // round => account => score
    mapping(uint256 => mapping(address => uint256)) internal _scoreByAccount;
    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(
        address factory_,
        address anotherTokenAddress_,
        uint256 waitingPhases_,
        uint256 govRatioMultiplier_,
        uint256 minGovVotes_
    ) LOVE20ExtensionBase(factory_) {
        anotherTokenAddress = anotherTokenAddress_;
        waitingPhases = waitingPhases_;
        govRatioMultiplier = govRatioMultiplier_;
        minGovVotes = minGovVotes_;
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @dev Hook called after base initialization
    /// Sets up LP token pair and joins the action
    function _afterInitialize() internal override {
        // Initialize LP token pair after tokenAddress is set
        IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(
            ILOVE20ExtensionCenter(center()).uniswapV2FactoryAddress()
        );
        lpTokenAddress = uniswapV2Factory.getPair(
            tokenAddress,
            anotherTokenAddress
        );
        if (lpTokenAddress == address(0)) {
            revert UniswapV2PairNotCreated();
        }
        _pair = IUniswapV2Pair(lpTokenAddress);
        _isTokenAddressTheFirstToken = _pair.token0() == tokenAddress;
    }

    // ============================================
    // ILOVE20EXTENSION INTERFACE IMPLEMENTATION
    // ============================================

    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    function joinedValue() external view returns (uint256) {
        return _calculateJoinedValue(totalStakedAmount);
    }

    function _calculateJoinedValue(
        uint256 lpAmount
    ) internal view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = _pair.getReserves();
        uint256 totalTokenAmount = (
            _isTokenAddressTheFirstToken ? reserve0 : reserve1
        ) * 2;

        uint256 totalLp = _pair.totalSupply();
        if (totalLp == 0) {
            return 0;
        }
        return (lpAmount * totalTokenAmount) / totalLp;
    }

    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        StakeInfo storage info = _stakeInfo[account];
        return _calculateJoinedValue(info.amount);
    }

    // accounts(), accountsCount(), accountAtIndex() are inherited from LOVE20ExtensionBase

    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted) {
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // don't know the reward if verify phase is not finished
        if (round >= _verify.currentRound()) {
            return (0, false);
        }

        (uint256 totalActionReward, ) = _mint.actionRewardByActionIdByAccount(
            tokenAddress,
            round,
            actionId,
            address(this)
        );

        uint256 total = _totalScore[round];
        uint256 score;
        if (total > 0) {
            // already verified
            score = _scoreByAccount[round][account];
        } else {
            // if verify result is not prepared then calculate reward
            (total, score) = calculateScore(account);
        }

        if (total == 0) {
            return (0, false);
        }
        return ((totalActionReward * score) / total, false);
    }

    function calculateScore(
        address account
    ) public view returns (uint256 total, uint256 score) {
        uint256[] memory scoresCalculated;
        (total, scoresCalculated) = calculateScores();
        score = 0;
        for (uint256 i = 0; i < scoresCalculated.length; i++) {
            if (_stakers[i] == account) {
                score = scoresCalculated[i];
                break;
            }
        }
        return (total, score);
    }

    function calculateScores()
        public
        view
        returns (uint256 totalCalculated, uint256[] memory scoresCalculated)
    {
        uint256 totalLp = _pair.totalSupply();
        uint256 totalGovVotes = _stake.govVotesNum(tokenAddress);

        // Return empty if no LP or no gov votes
        if (totalLp == 0 || totalGovVotes == 0) {
            return (0, new uint256[](0));
        }

        scoresCalculated = new uint256[](_stakers.length);
        for (uint256 i = 0; i < _stakers.length; i++) {
            address account = _stakers[i];
            uint256 lp = _stakeInfo[account].amount;
            uint256 govVotes = _stake.validGovVotes(tokenAddress, account);
            uint256 lpRatio = (lp * 1000000) / totalLp;
            uint256 govVotesRatio = (govVotes * 1000000 * govRatioMultiplier) /
                totalGovVotes;

            uint256 score = lpRatio > govVotesRatio ? govVotesRatio : lpRatio;

            scoresCalculated[i] = score;
            totalCalculated += score;
        }
        return (totalCalculated, scoresCalculated);
    }

    function claimReward(uint256 round) external returns (uint256 reward) {
        // Check if already claimed
        if (_claimedReward[round][msg.sender] > 0) {
            revert AlreadyClaimed();
        }

        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare verify result and reward
        _prepareVerifyResultIfNeeded(round);
        _prepareRewardIfNeeded(round);

        // Calculate reward for the user
        uint256 total = _totalScore[round];
        if (total == 0) {
            return 0;
        }

        uint256 score = _scoreByAccount[round][msg.sender];
        if (score == 0) {
            return 0;
        }

        uint256 totalActionReward = _reward[round];
        reward = (totalActionReward * score) / total;

        if (reward == 0) {
            return 0;
        }

        // Update claimed reward
        _claimedReward[round][msg.sender] = reward;

        // Transfer reward to user
        if (reward > 0) {
            ILOVE20Token token = ILOVE20Token(tokenAddress);
            token.transfer(msg.sender, reward);
        }

        emit ClaimReward(msg.sender, round, reward);
        return reward;
    }

    // ------ user operations ------
    function _prepareVerifyResultIfNeeded(uint256 round) internal {
        if (_totalScore[round] > 0) {
            return;
        }
        if (round > _verify.currentRound()) {
            return;
        }
        (
            uint256 totalCalculated,
            uint256[] memory scoresCalculated
        ) = calculateScores();
        _totalScore[round] = totalCalculated;
        _scores[round] = scoresCalculated;
        // Save accounts snapshot and score mapping for this round
        _verifiedAccounts[round] = _stakers;
        for (uint256 i = 0; i < _verifiedAccounts[round].length; i++) {
            _scoreByAccount[round][
                _verifiedAccounts[round][i]
            ] = scoresCalculated[i];
        }
    }

    function stakeLp(uint256 amount) external {
        _prepareVerifyResultIfNeeded(_verify.currentRound());

        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        if (amount == 0) {
            revert StakeAmountZero();
        }

        bool isNewStaker = info.amount == 0;
        if (isNewStaker) {
            // Check if msg.sender has sufficient governance votes on first stake
            uint256 userGovVotes = _stake.validGovVotes(
                tokenAddress,
                msg.sender
            );
            if (userGovVotes < minGovVotes) {
                revert InsufficientGovVotes();
            }

            _stakers.push(msg.sender);
            _addAccount(msg.sender);
        }

        info.amount += amount;
        totalStakedAmount += amount;
        _pair.transferFrom(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    function unstakeLp() external {
        _prepareVerifyResultIfNeeded(_verify.currentRound());

        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.amount == 0) {
            revert NoStakedAmount();
        }
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        info.requestedUnstakeRound = _join.currentRound();
        totalStakedAmount -= info.amount;
        totalUnstakedAmount += info.amount;

        // Move from stakers to unstakers
        ArrayUtils.remove(_stakers, msg.sender);
        _unstakers.push(msg.sender);

        emit Unstake(msg.sender, info.amount);
    }

    function withdrawLp() external {
        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound == 0) {
            revert UnstakeNotRequested();
        }
        if (
            _join.currentRound() - info.requestedUnstakeRound <= waitingPhases
        ) {
            revert NotEnoughWaitingPhases();
        }
        uint256 amount = info.amount;
        info.amount = 0;
        info.requestedUnstakeRound = 0;
        totalUnstakedAmount -= amount;

        // Remove from unstakers and accounts (no longer in stakers or unstakers)
        ArrayUtils.remove(_unstakers, msg.sender);
        _removeAccount(msg.sender);

        _pair.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    // ------ view functions ------
    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound) {
        return (
            _stakeInfo[account].amount,
            _stakeInfo[account].requestedUnstakeRound
        );
    }

    function stakers() external view returns (address[] memory) {
        return _stakers;
    }

    function stakersCount() external view returns (uint256) {
        return _stakers.length;
    }

    function stakersAtIndex(uint256 index) external view returns (address) {
        return _stakers[index];
    }

    function unstakers() external view returns (address[] memory) {
        return _unstakers;
    }

    function unstakersCount() external view returns (uint256) {
        return _unstakers.length;
    }

    function unstakersAtIndex(uint256 index) external view returns (address) {
        return _unstakers[index];
    }

    function totalScore(uint256 round) external view returns (uint256) {
        return _totalScore[round];
    }

    function verifiedAccounts(
        uint256 round
    ) external view returns (address[] memory) {
        return _verifiedAccounts[round];
    }

    function verifiedAccountsCount(
        uint256 round
    ) external view returns (uint256) {
        return _verifiedAccounts[round].length;
    }

    function verifiedAccountsAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address) {
        return _verifiedAccounts[round][index];
    }

    function scores(uint256 round) external view returns (uint256[] memory) {
        return _scores[round];
    }

    function scoresCount(uint256 round) external view returns (uint256) {
        return _scores[round].length;
    }

    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256) {
        return _scores[round][index];
    }

    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256) {
        return _scoreByAccount[round][account];
    }
}
