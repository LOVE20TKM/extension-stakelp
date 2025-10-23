// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionStakeLp} from "./interface/ILOVE20ExtensionStakeLp.sol";
import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Stake} from "@core/src/interfaces/ILOVE20Stake.sol";
import {ILOVE20Join} from "@core/src/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/src/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/src/interfaces/ILOVE20Mint.sol";
import {ILOVE20Token} from "@core/src/interfaces/ILOVE20Token.sol";

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
    address[] internal _accounts;
    address[] internal _stakers;
    address[] internal _unstakers;
    // account => StakeInfo
    mapping(address => StakeInfo) internal _stakeInfo;

    // round => reward
    mapping(uint256 => uint256) internal _reward;

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

    function accounts() external view returns (address[] memory) {
        return _accounts;
    }

    function accountsCount() external view returns (uint256) {
        return _accounts.length;
    }

    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts[index];
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

        uint256 total = _totalScore[round];
        uint256 score;
        if (total > 0) {
            // already verified
            score = _scoreByAccount[round][account];
        } else {
            // if verify result is not prepared then calculate reward
            (total, score) = _calculateScore(account);
        }

        if (total == 0) {
            return (0, false);
        }
        return ((totalActionReward * score) / total, false);
    }

    function _calculateScore(
        address account
    ) internal view returns (uint256 total, uint256 score) {
        uint256[] memory scoresCalculated;
        (total, scoresCalculated) = _calculateScores();
        score = 0;
        for (uint256 i = 0; i < scoresCalculated.length; i++) {
            if (_stakers[i] == account) {
                score = scoresCalculated[i];
                break;
            }
        }
        return (total, score);
    }

    function _calculateScores()
        internal
        view
        returns (uint256 totalCalculated, uint256[] memory scoresCalculated)
    {
        uint256 totalLp = pair.totalSupply();
        uint256 totalGovVotes = stake.govVotesNum(tokenAddress);

        // Return empty if no LP or no gov votes
        if (totalLp == 0 || totalGovVotes == 0) {
            return (0, new uint256[](0));
        }

        scoresCalculated = new uint256[](_stakers.length);
        for (uint256 i = 0; i < _stakers.length; i++) {
            address account = _stakers[i];
            uint256 lp = _stakeInfo[account].amount;
            uint256 govVotes = stake.validGovVotes(tokenAddress, account);
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
        if (round >= verify.currentRound()) {
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
        if (round > verify.currentRound()) {
            return;
        }
        (
            uint256 totalCalculated,
            uint256[] memory scoresCalculated
        ) = _calculateScores();
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

        bool isNewStaker = info.amount == 0;
        if (isNewStaker) {
            _stakers.push(msg.sender);
            _accounts.push(msg.sender);
            // Add account to Center
            ILOVE20ExtensionCenter c = ILOVE20ExtensionCenter(
                ILOVE20ExtensionFactory(factory).center()
            );
            c.addAccount(tokenAddress, actionId, msg.sender);
        }

        info.amount += amount;
        totalStakedAmount += amount;
        pair.transferFrom(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    function unstakeLp() external {
        _prepareVerifyResultIfNeeded(verify.currentRound());

        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.amount == 0) {
            revert NoStakedAmount();
        }
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        info.requestedUnstakeRound = join.currentRound();
        totalStakedAmount -= info.amount;

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
        if (join.currentRound() - info.requestedUnstakeRound <= waitingPhases) {
            revert NotEnoughWaitingPhases();
        }
        uint256 amount = info.amount;
        info.amount = 0;
        info.requestedUnstakeRound = 0;

        // Remove from unstakers and accounts (no longer in stakers or unstakers)
        ArrayUtils.remove(_unstakers, msg.sender);
        ArrayUtils.remove(_accounts, msg.sender);

        // Remove account from Center
        ILOVE20ExtensionCenter c = ILOVE20ExtensionCenter(
            ILOVE20ExtensionFactory(factory).center()
        );
        c.removeAccount(tokenAddress, actionId, msg.sender);

        pair.transfer(msg.sender, amount);
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
