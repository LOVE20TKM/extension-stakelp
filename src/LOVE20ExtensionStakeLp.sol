// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {ILOVE20ExtensionStakeLp} from "./interface/ILOVE20ExtensionStakeLp.sol";
import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Stake} from "@core/src/interfaces/ILOVE20Stake.sol";
import {ILOVE20Join} from "@core/src/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/src/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/src/interfaces/ILOVE20Mint.sol";

import {IUniswapV2Factory} from "@core/src/uniswap-v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@core/src/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";
import {ArrayUtils} from "@core/src/lib/ArrayUtils.sol";

uint256 constant DEFAULT_JOIN_AMOUNT = 1;

/**
 * @title LOVE20ExtensionStakeLp
 * @notice LP staking extension for LOVE20 protocol with phase-based unlocking and reward distribution
 * @dev Implements ILOVE20Extension interface and integrates with LOVE20 system
 */
contract LOVE20ExtensionStakeLp is ILOVE20ExtensionStakeLp {
    using ArrayUtils for address[];

    address public immutable factory;
    address public immutable tokenAddress;
    uint256 public immutable actionId;
    address public immutable anotherTokenAddress;
    uint256 public immutable waitingPhases;
    uint256 public immutable govRatioMultiplier;
    address public immutable lpTokenAddress;

    bool public initialized;
    ILOVE20Stake public immutable stake;
    ILOVE20Join public immutable join;
    ILOVE20Verify public immutable verify;
    ILOVE20Mint public immutable mint;
    IUniswapV2Pair public immutable pair;
    bool public immutable isTokenAddressTheFirstToken;

    uint256 public totalStakedAmount;
    address[] public stakers;
    // account => StakeInfo
    mapping(address => StakeInfo) internal _stakeInfo;

    // round => reward
    mapping(uint256 => uint256) internal _reward;

    // round => totalScore
    mapping(uint256 => uint256) internal _totalScore;
    // round => account[]
    mapping(uint256 => address[]) internal _accounts;
    // round => score[]
    mapping(uint256 => uint256[]) internal _scores;
    // round => account => score
    mapping(uint256 => mapping(address => uint256)) internal _scoreByAccount;
    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    constructor(
        address factory_,
        address tokenAddress_,
        uint256 actionId_,
        address anotherTokenAddress_,
        uint256 waitingPhases_,
        uint256 govRatioMultiplier_
    ) {
        factory = factory_;
        tokenAddress = tokenAddress_;
        actionId = actionId_;
        anotherTokenAddress = anotherTokenAddress_;
        waitingPhases = waitingPhases_;
        govRatioMultiplier = govRatioMultiplier_;

        ILOVE20ExtensionCenter c = ILOVE20ExtensionCenter(
            ILOVE20ExtensionFactory(factory_).center()
        );
        stake = ILOVE20Stake(c.stakeAddress());
        join = ILOVE20Join(c.joinAddress());
        verify = ILOVE20Verify(c.verifyAddress());
        mint = ILOVE20Mint(c.mintAddress());
        IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(
            c.uniswapV2FactoryAddress()
        );
        lpTokenAddress = uniswapV2Factory.getPair(
            tokenAddress_,
            anotherTokenAddress_
        );
        if (lpTokenAddress == address(0)) {
            revert UniswapV2PairNotCreated();
        }
        pair = IUniswapV2Pair(lpTokenAddress);
        isTokenAddressTheFirstToken = pair.token0() == tokenAddress_;
    }

    modifier onlyCenter() {
        if (msg.sender != ILOVE20ExtensionFactory(factory).center()) {
            revert OnlyCenterCanCall();
        }
        _;
    }

    function initialize() external onlyCenter {
        if (initialized) {
            revert AlreadyInitialized();
        }
        initialized = true;

        ILOVE20ExtensionFactory f = ILOVE20ExtensionFactory(factory);
        ILOVE20ExtensionCenter c = ILOVE20ExtensionCenter(f.center());
        ILOVE20Join j = ILOVE20Join(c.joinAddress());
        j.join(tokenAddress, actionId, DEFAULT_JOIN_AMOUNT, new string[](0));
    }

    // ILOVE20Extension interface
    function center() external view returns (address) {
        return ILOVE20ExtensionFactory(factory).center();
    }

    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    function joinedValue() external view returns (uint256) {
        return _calculateJoinedValue(totalStakedAmount);
    }

    function _calculateJoinedValue(
        uint256 lpAmount
    ) internal view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 totalTokenAmount = (
            isTokenAddressTheFirstToken ? reserve0 : reserve1
        ) * 2;

        uint256 totalLp = pair.totalSupply();
        return (lpAmount * totalTokenAmount) / totalLp;
    }

    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        StakeInfo storage info = _stakeInfo[account];
        return _calculateJoinedValue(info.amount);
    }

    function accountsCount() external view returns (uint256) {
        return stakers.length;
    }

    function accountAtIndex(uint256 index) external view returns (address) {
        return stakers[index];
    }

    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted) {
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // don't know the reward if verify phase is not finished
        if (round >= verify.currentRound()) {
            return (0, false);
        }

        (uint256 totalActionReward, ) = mint.actionRewardByActionIdByAccount(
            tokenAddress,
            round,
            actionId,
            address(this)
        );

        uint256 totalScore = _totalScore[round];
        uint256 score;
        if (totalScore > 0) {
            // already verified
            score = _scoreByAccount[round][account];
        } else {
            // if verify result is not prepared then calculate reward
            (totalScore, score) = _calculateScore(account);
        }
        return ((totalActionReward * score) / totalScore, false);
    }

    function _calculateScore(
        address account
    ) internal view returns (uint256 totalScore, uint256 score) {
        uint256[] memory scores;
        (totalScore, scores) = _calculateScores();
        score = 0;
        for (uint256 i = 0; i < scores.length; i++) {
            if (stakers[i] == account) {
                score = scores[i];
                break;
            }
        }
        return (totalScore, score);
    }

    function _calculateScores()
        internal
        view
        returns (uint256 totalScore, uint256[] memory scores)
    {
        uint256 totalLp = pair.totalSupply();
        uint256 totalGovVotes = stake.govVotesNum(tokenAddress);
        scores = new uint256[](stakers.length);
        for (uint256 i = 0; i < stakers.length; i++) {
            address account = stakers[i];
            uint256 lp = _stakeInfo[account].amount;
            uint256 govVotes = stake.validGovVotes(tokenAddress, account);
            uint256 lpRatio = (lp * 1000000) / totalLp;
            uint256 govVotesRatio = (govVotes * 1000000 * govRatioMultiplier) /
                totalGovVotes;

            uint256 score = lpRatio > govVotesRatio ? govVotesRatio : lpRatio;

            scores[i] = score;
            totalScore += score;
        }
        return (totalScore, scores);
    }

    function claimReward(uint256 round) external returns (uint256 reward) {
        _prepareVerifyResultIfNeeded(round);
        _prepareRewardIfNeeded(round);
        return 0;
    }

    // ------ user operations ------
    function _prepareVerifyResultIfNeeded(uint256 round) internal {
        if (_totalScore[round] > 0) {
            return;
        }
        if (round > verify.currentRound()) {
            return;
        }
        (uint256 totalScore, uint256[] memory scores) = _calculateScores();
        _totalScore[round] = totalScore;
        _scores[round] = scores;
    }
    function _prepareRewardIfNeeded(uint256 round) internal {
        if (_reward[round] > 0) {
            return;
        }
        uint256 totalActionReward = mint.mintActionReward(
            tokenAddress,
            round,
            actionId
        );
        _reward[round] = totalActionReward;
    }

    function stakeLp(uint256 amount) external {
        _prepareVerifyResultIfNeeded(verify.currentRound());

        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        if (amount == 0) {
            revert StakeAmountZero();
        }
        if (info.amount == 0) {
            stakers.push(msg.sender);
        }
        info.amount += amount;
        totalStakedAmount += amount;
        pair.transferFrom(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    function unstakeLp() external {
        _prepareVerifyResultIfNeeded(verify.currentRound());

        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        info.requestedUnstakeRound = join.currentRound();
        totalStakedAmount -= info.amount;
        emit Unstake(msg.sender, info.amount);
    }

    function withdrawLp() external {
        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound == 0) {
            revert UnstakeNotRequested();
        }
        if (join.currentRound() - info.requestedUnstakeRound <= waitingPhases) {
            revert NotEnoughWaitingPhases();
        }
        uint256 amount = info.amount;
        info.amount = 0;
        info.requestedUnstakeRound = 0;
        ArrayUtils.remove(stakers, msg.sender);
        pair.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}
