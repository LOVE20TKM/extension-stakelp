// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionStakeLp} from "./interface/ILOVE20ExtensionStakeLp.sol";
import {
    LOVE20ExtensionAutoScoreStake
} from "@extension/src/LOVE20ExtensionAutoScoreStake.sol";
import {
    LOVE20ExtensionAutoScore
} from "@extension/src/LOVE20ExtensionAutoScore.sol";
import {LOVE20ExtensionBase} from "@extension/src/LOVE20ExtensionBase.sol";
import {
    ILOVE20ExtensionAutoScoreStake
} from "@extension/src/interface/ILOVE20ExtensionAutoScoreStake.sol";
import {
    ILOVE20ExtensionAutoScore
} from "@extension/src/interface/ILOVE20ExtensionAutoScore.sol";
import {ILOVE20Extension} from "@extension/src/interface/ILOVE20Extension.sol";
import {
    ILOVE20ExtensionCenter
} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";
import {
    IERC20
} from "@extension/lib/core/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    IUniswapV2Pair
} from "@core/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";

contract LOVE20ExtensionStakeLp is
    LOVE20ExtensionAutoScoreStake,
    ILOVE20ExtensionStakeLp
{
    // ============================================
    // STATE VARIABLES
    // ============================================

    uint256 public immutable govRatioMultiplier;

    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 govRatioMultiplier_,
        uint256 minGovVotes_
    )
        LOVE20ExtensionAutoScoreStake(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {
        govRatioMultiplier = govRatioMultiplier_;
    }

    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public override(ILOVE20Extension, LOVE20ExtensionBase) {
        super.initialize(tokenAddress_, actionId_);
        _validateStakeToken();
    }

    function _validateStakeToken() internal view {
        address uniswapV2FactoryAddress = ILOVE20ExtensionCenter(center())
            .uniswapV2FactoryAddress();

        try IUniswapV2Pair(stakeTokenAddress).factory() returns (
            address pairFactory
        ) {
            if (pairFactory != uniswapV2FactoryAddress) {
                revert ILOVE20ExtensionStakeLp.InvalidStakeTokenAddress();
            }
        } catch {
            revert ILOVE20ExtensionStakeLp.InvalidStakeTokenAddress();
        }
        address pairToken0;
        address pairToken1;
        try IUniswapV2Pair(stakeTokenAddress).token0() returns (
            address token0
        ) {
            pairToken0 = token0;
        } catch {
            revert ILOVE20ExtensionStakeLp.InvalidStakeTokenAddress();
        }
        try IUniswapV2Pair(stakeTokenAddress).token1() returns (
            address token1
        ) {
            pairToken1 = token1;
        } catch {
            revert ILOVE20ExtensionStakeLp.InvalidStakeTokenAddress();
        }
        if (pairToken0 != tokenAddress && pairToken1 != tokenAddress) {
            revert ILOVE20ExtensionStakeLp.InvalidStakeTokenAddress();
        }
    }

    // ============================================
    // ILOVE20EXTENSION INTERFACE IMPLEMENTATION
    // ============================================

    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    function _lpToTokenAmount(
        uint256 lpAmount
    ) internal view returns (uint256) {
        if (lpAmount == 0) {
            return 0;
        }

        IUniswapV2Pair pair = IUniswapV2Pair(stakeTokenAddress);

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 totalLp = pair.totalSupply();

        if (totalLp == 0) {
            return 0;
        }

        address pairToken0 = pair.token0();
        uint256 tokenReserve = (pairToken0 == tokenAddress)
            ? uint256(reserve0)
            : uint256(reserve1);

        return (lpAmount * tokenReserve) / totalLp;
    }

    function joinedValue() external view returns (uint256) {
        return _lpToTokenAmount(totalStakedAmount);
    }

    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        ILOVE20ExtensionAutoScoreStake.StakeInfo storage info = _stakeInfo[
            account
        ];
        return _lpToTokenAmount(info.amount);
    }

    // ============================================
    // ILOVE20ExtensionAutoScore IMPLEMENTATION
    // ============================================

    function calculateScore(
        address account
    )
        public
        view
        override(ILOVE20ExtensionAutoScore, LOVE20ExtensionAutoScore)
        returns (uint256 total, uint256 score)
    {
        uint256[] memory scoresCalculated;
        (total, scoresCalculated) = calculateScores();
        score = 0;
        for (uint256 i = 0; i < scoresCalculated.length; i++) {
            if (_accounts[i] == account) {
                score = scoresCalculated[i];
                break;
            }
        }
        return (total, score);
    }

    function calculateScores()
        public
        view
        override(ILOVE20ExtensionAutoScore, LOVE20ExtensionAutoScore)
        returns (uint256 totalCalculated, uint256[] memory scoresCalculated)
    {
        uint256 totalTokenSupply = _stakeToken.totalSupply();
        uint256 totalGovVotes = _stake.govVotesNum(tokenAddress);

        if (totalTokenSupply == 0 || totalGovVotes == 0) {
            return (0, new uint256[](0));
        }

        scoresCalculated = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 stakedAmount = _stakeInfo[account].amount;
            uint256 govVotes = _stake.validGovVotes(tokenAddress, account);

            uint256 tokenRatio = (stakedAmount * 1000000) / totalTokenSupply;

            uint256 govVotesRatio = (govVotes * 1000000 * govRatioMultiplier) /
                totalGovVotes;

            uint256 score = tokenRatio > govVotesRatio
                ? govVotesRatio
                : tokenRatio;

            scoresCalculated[i] = score;
            totalCalculated += score;
        }
        return (totalCalculated, scoresCalculated);
    }
}
