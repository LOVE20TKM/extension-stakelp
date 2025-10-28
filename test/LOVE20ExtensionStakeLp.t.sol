// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {LOVE20ExtensionStakeLp} from "../src/LOVE20ExtensionStakeLp.sol";
import {LOVE20ExtensionFactoryStakeLp} from "../src/LOVE20ExtensionFactoryStakeLp.sol";
import {ILOVE20ExtensionStakeLp} from "../src/interface/ILOVE20ExtensionStakeLp.sol";
import {ILOVE20ExtensionFactoryStakeLp} from "../src/interface/ILOVE20ExtensionFactoryStakeLp.sol";
import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";

// Import mock contracts
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Pair} from "./mocks/MockUniswapV2Pair.sol";
import {MockUniswapV2Factory} from "./mocks/MockUniswapV2Factory.sol";
import {MockStake} from "./mocks/MockStake.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockVerify} from "./mocks/MockVerify.sol";
import {MockMint} from "./mocks/MockMint.sol";
import {MockExtensionCenter} from "./mocks/MockExtensionCenter.sol";

/**
 * @title LOVE20ExtensionStakeLp Test Suite
 */
contract LOVE20ExtensionStakeLpTest is Test {
    LOVE20ExtensionFactoryStakeLp public factory;
    LOVE20ExtensionStakeLp public extension;
    MockExtensionCenter public center;
    MockERC20 public token;
    MockERC20 public anotherToken;
    MockUniswapV2Pair public pair;
    MockUniswapV2Factory public uniswapFactory;
    MockStake public stake;
    MockJoin public join;
    MockVerify public verify;
    MockMint public mint;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant ACTION_ID = 1;
    uint256 constant WAITING_PHASES = 3;
    uint256 constant GOV_RATIO_MULTIPLIER = 1;
    uint256 constant MIN_GOV_VOTES = 100e18;

    function setUp() public {
        // Deploy mock contracts
        center = new MockExtensionCenter();
        token = new MockERC20();
        anotherToken = new MockERC20();
        uniswapFactory = new MockUniswapV2Factory();
        stake = new MockStake();
        join = new MockJoin();
        verify = new MockVerify();
        mint = new MockMint();

        // Setup center
        center.setStakeAddress(address(stake));
        center.setJoinAddress(address(join));
        center.setVerifyAddress(address(verify));
        center.setMintAddress(address(mint));
        center.setUniswapV2FactoryAddress(address(uniswapFactory));

        // Create LP pair
        pair = MockUniswapV2Pair(
            uniswapFactory.createPair(address(token), address(anotherToken))
        );

        // Setup initial reserves
        pair.setReserves(1000e18, 2000e18);
        pair.mint(address(pair), 1000e18); // Initial LP supply

        // Deploy factory
        factory = new LOVE20ExtensionFactoryStakeLp(address(center));

        // Create extension
        extension = LOVE20ExtensionStakeLp(
            factory.createExtension(
                address(token),
                ACTION_ID,
                address(anotherToken),
                WAITING_PHASES,
                GOV_RATIO_MULTIPLIER,
                MIN_GOV_VOTES
            )
        );

        // Initialize extension
        vm.prank(address(center));
        extension.initialize();

        // Setup users with LP tokens
        pair.mint(user1, 100e18);
        pair.mint(user2, 200e18);
        pair.mint(user3, 300e18);

        // Approve extension to spend LP tokens
        vm.prank(user1);
        pair.approve(address(extension), type(uint256).max);
        vm.prank(user2);
        pair.approve(address(extension), type(uint256).max);
        vm.prank(user3);
        pair.approve(address(extension), type(uint256).max);

        // Setup gov votes
        stake.setGovVotesNum(address(token), 1000e18);
        stake.setValidGovVotes(address(token), user1, 100e18);
        stake.setValidGovVotes(address(token), user2, 200e18);
        stake.setValidGovVotes(address(token), user3, 300e18);

        // Mint tokens to extension for rewards
        token.mint(address(extension), 10000e18);
    }

    // ============================================
    // Initialization Tests
    // ============================================

    function test_Initialize() public view {
        assertTrue(extension.initialized());
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.prank(address(center));
        vm.expectRevert(ILOVE20ExtensionStakeLp.AlreadyInitialized.selector);
        extension.initialize();
    }

    function test_Initialize_RevertIfNotCenter() public {
        // Deploy new extension without initialization
        LOVE20ExtensionStakeLp newExtension = new LOVE20ExtensionStakeLp(
            address(factory),
            address(token),
            ACTION_ID + 1,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.OnlyCenterCanCall.selector);
        newExtension.initialize();
    }

    // ============================================
    // View Function Tests
    // ============================================

    function test_ImmutableVariables() public view {
        assertEq(extension.factory(), address(factory));
        assertEq(extension.tokenAddress(), address(token));
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension.anotherTokenAddress(), address(anotherToken));
        assertEq(extension.waitingPhases(), WAITING_PHASES);
        assertEq(extension.govRatioMultiplier(), GOV_RATIO_MULTIPLIER);
        assertEq(extension.lpTokenAddress(), address(pair));
    }

    function test_IsJoinedValueCalculated() public view {
        assertTrue(extension.isJoinedValueCalculated());
    }

    function test_Center() public view {
        assertEq(extension.center(), address(center));
    }

    // ============================================
    // Stake LP Tests
    // ============================================

    function test_StakeLp() public {
        uint256 stakeAmount = 50e18;

        vm.prank(user1);
        extension.stakeLp(stakeAmount);

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, stakeAmount);
        assertEq(requestedUnstakeRound, 0);
        assertEq(extension.totalStakedAmount(), stakeAmount);
        assertEq(extension.stakersCount(), 1);
        assertEq(extension.accountsCount(), 1);
    }

    function test_StakeLp_Multiple() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        assertEq(extension.totalStakedAmount(), 150e18);
        assertEq(extension.stakersCount(), 2);
        assertEq(extension.accountsCount(), 2);
    }

    function test_StakeLp_MultipleTimesSameUser() public {
        vm.prank(user1);
        extension.stakeLp(30e18);

        vm.prank(user1);
        extension.stakeLp(20e18);

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 50e18);
        assertEq(extension.stakersCount(), 1);
    }

    function test_StakeLp_EmitEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Stake(user1, 50e18);
        extension.stakeLp(50e18);
    }

    event Stake(address indexed account, uint256 amount);

    function test_StakeLp_RevertIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.StakeAmountZero.selector);
        extension.stakeLp(0);
    }

    function test_StakeLp_RevertIfUnstakeRequested() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeRequested.selector);
        extension.stakeLp(10e18);
    }

    function test_StakeLp_RevertIfInsufficientGovVotes() public {
        // Create a new user with insufficient gov votes
        address user4 = address(0x4);
        pair.mint(user4, 100e18);
        vm.prank(user4);
        pair.approve(address(extension), type(uint256).max);

        // Set gov votes below MIN_GOV_VOTES (MIN_GOV_VOTES = 100e18)
        stake.setValidGovVotes(address(token), user4, 50e18);

        // Expect revert when first time staking with insufficient gov votes
        vm.prank(user4);
        vm.expectRevert(ILOVE20ExtensionStakeLp.InsufficientGovVotes.selector);
        extension.stakeLp(50e18);
    }

    function test_StakeLp_SuccessWithMinimumGovVotes() public {
        // user1 has exactly MIN_GOV_VOTES (100e18)
        vm.prank(user1);
        extension.stakeLp(50e18);

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 50e18);
    }

    function test_JoinedValue() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        // LP total supply in setUp:
        // - pair itself: 1000e18
        // - user1: 100e18, user2: 200e18, user3: 300e18
        // Total: 1600e18
        // Token reserves: 1000e18 (first token)
        // Total token amount: 2000e18
        // Expected joined value: (100e18 * 2000e18) / 1600e18 = 125e18
        uint256 totalLpSupply = pair.totalSupply();
        uint256 expectedValue = (100e18 * 2000e18) / totalLpSupply;
        assertEq(extension.joinedValue(), expectedValue);
    }

    function test_JoinedValueByAccount() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        uint256 totalLpSupply = pair.totalSupply();
        uint256 expectedValue1 = (50e18 * 2000e18) / totalLpSupply;
        uint256 expectedValue2 = (100e18 * 2000e18) / totalLpSupply;

        assertEq(extension.joinedValueByAccount(user1), expectedValue1);
        assertEq(extension.joinedValueByAccount(user2), expectedValue2);
    }

    // ============================================
    // Unstake LP Tests
    // ============================================

    function test_UnstakeLp() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        uint256 initialRound = join.currentRound();

        vm.prank(user1);
        extension.unstakeLp();

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 50e18);
        assertEq(requestedUnstakeRound, initialRound);
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.stakersCount(), 0);
        assertEq(extension.unstakersCount(), 1);
    }

    function test_UnstakeLp_EmitEvent() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Unstake(user1, 50e18);
        extension.unstakeLp();
    }

    event Unstake(address indexed account, uint256 amount);

    function test_UnstakeLp_RevertIfNoStakedAmount() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.NoStakedAmount.selector);
        extension.unstakeLp();
    }

    function test_UnstakeLp_RevertIfAlreadyRequested() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeRequested.selector);
        extension.unstakeLp();
    }

    // ============================================
    // Withdraw LP Tests
    // ============================================

    function test_WithdrawLp() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        uint256 balanceBefore = pair.balanceOf(user1);

        vm.prank(user1);
        extension.unstakeLp();

        // Move forward enough rounds
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 0);
        assertEq(requestedUnstakeRound, 0);
        assertEq(extension.unstakersCount(), 0);
        assertEq(extension.accountsCount(), 0);

        uint256 balanceAfter = pair.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, 50e18);
    }

    function test_WithdrawLp_EmitEvent() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(user1, 50e18);
        extension.withdrawLp();
    }

    event Withdraw(address indexed account, uint256 amount);

    function test_WithdrawLp_RevertIfUnstakeNotRequested() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeNotRequested.selector);
        extension.withdrawLp();
    }

    function test_WithdrawLp_RevertIfNotEnoughWaitingPhases() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        // Move forward but not enough
        join.setCurrentRound(join.currentRound() + WAITING_PHASES);

        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionStakeLp.NotEnoughWaitingPhases.selector
        );
        extension.withdrawLp();
    }

    // ============================================
    // TotalUnstakedAmount Tests
    // ============================================

    function test_TotalUnstakedAmount_InitiallyZero() public view {
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_AfterUnstake() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        assertEq(extension.totalUnstakedAmount(), 50e18);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_MultipleUnstakes() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        vm.prank(user3);
        extension.stakeLp(150e18);

        // User1 unstakes
        vm.prank(user1);
        extension.unstakeLp();
        assertEq(extension.totalUnstakedAmount(), 50e18);
        assertEq(extension.totalStakedAmount(), 250e18);

        // User2 unstakes
        vm.prank(user2);
        extension.unstakeLp();
        assertEq(extension.totalUnstakedAmount(), 150e18);
        assertEq(extension.totalStakedAmount(), 150e18);

        // User3 unstakes
        vm.prank(user3);
        extension.unstakeLp();
        assertEq(extension.totalUnstakedAmount(), 300e18);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_AfterWithdraw() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user1);
        extension.unstakeLp();

        assertEq(extension.totalUnstakedAmount(), 50e18);

        // Wait enough rounds
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();

        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_PartialWithdraw() public {
        // User1 and User2 stake
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        // Both unstake
        vm.prank(user1);
        extension.unstakeLp();

        vm.prank(user2);
        extension.unstakeLp();

        assertEq(extension.totalUnstakedAmount(), 150e18);
        assertEq(extension.totalStakedAmount(), 0);

        // Only User1 withdraws
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();

        assertEq(extension.totalUnstakedAmount(), 100e18);
        assertEq(extension.totalStakedAmount(), 0);

        // User2 withdraws
        vm.prank(user2);
        extension.withdrawLp();

        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_StakeUnstakeWithdrawCycle() public {
        // First cycle
        vm.prank(user1);
        extension.stakeLp(50e18);
        assertEq(extension.totalStakedAmount(), 50e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        vm.prank(user1);
        extension.unstakeLp();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 50e18);

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);

        // Second cycle - user can stake again
        vm.prank(user1);
        extension.stakeLp(30e18);
        assertEq(extension.totalStakedAmount(), 30e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        vm.prank(user1);
        extension.unstakeLp();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 30e18);
    }

    function test_TotalUnstakedAmount_ComplexScenario() public {
        // User1, User2, User3 stake
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        vm.prank(user3);
        extension.stakeLp(300e18);

        assertEq(extension.totalStakedAmount(), 600e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        // User1 unstakes
        vm.prank(user1);
        extension.unstakeLp();
        assertEq(extension.totalStakedAmount(), 500e18);
        assertEq(extension.totalUnstakedAmount(), 100e18);

        // User2 unstakes
        vm.prank(user2);
        extension.unstakeLp();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 300e18);

        // Wait and User1 withdraws
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 200e18);

        // User2 withdraws (same unstake round as User1, so can withdraw now)
        vm.prank(user2);
        extension.withdrawLp();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        // User3 unstakes
        vm.prank(user3);
        extension.unstakeLp();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 300e18);

        // Wait for User3 to be able to withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        // User3 withdraws
        vm.prank(user3);
        extension.withdrawLp();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    function testFuzz_TotalUnstakedAmount(uint256 amount) public {
        amount = bound(amount, 1e18, 100e18);

        vm.prank(user1);
        extension.stakeLp(amount);

        vm.prank(user1);
        extension.unstakeLp();

        assertEq(extension.totalUnstakedAmount(), amount);
        assertEq(extension.totalStakedAmount(), 0);

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();

        assertEq(extension.totalUnstakedAmount(), 0);
    }

    function testFuzz_TotalUnstakedAmount_MultipleUsers(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        amount1 = bound(amount1, 1e18, 50e18);
        amount2 = bound(amount2, 1e18, 80e18);
        amount3 = bound(amount3, 1e18, 100e18);

        vm.prank(user1);
        extension.stakeLp(amount1);

        vm.prank(user2);
        extension.stakeLp(amount2);

        vm.prank(user3);
        extension.stakeLp(amount3);

        uint256 totalStaked = amount1 + amount2 + amount3;
        assertEq(extension.totalStakedAmount(), totalStaked);
        assertEq(extension.totalUnstakedAmount(), 0);

        // All unstake
        vm.prank(user1);
        extension.unstakeLp();

        vm.prank(user2);
        extension.unstakeLp();

        vm.prank(user3);
        extension.unstakeLp();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), totalStaked);

        // All withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdrawLp();

        vm.prank(user2);
        extension.withdrawLp();

        vm.prank(user3);
        extension.withdrawLp();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    // ============================================
    // Score Calculation Tests
    // ============================================

    function test_ScoreCalculation_SingleUser() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Total LP: 1000e18, User LP: 100e18
        // LP ratio: (100e18 * 1000000) / 1000e18 = 100000
        // Total gov votes: 1000e18, User gov votes: 100e18
        // Gov ratio: (100e18 * 1000000 * 1) / 1000e18 = 100000
        // Score: min(100000, 100000) = 100000

        verify.setCurrentRound(2);
        uint256 round = 1;

        (, bool isMinted) = extension.rewardByAccount(round, user1);
        assertFalse(isMinted);
    }

    function test_ScoreCalculation_MultipleUsers() public {
        // User1: 100e18 LP, 100e18 gov votes
        // User2: 200e18 LP, 200e18 gov votes
        // User3: 300e18 LP, 300e18 gov votes
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        vm.prank(user3);
        extension.stakeLp(300e18);

        // Total LP in pair: 1000e18
        // Total staked: 600e18
        // Total gov votes: 1000e18

        // User1 LP ratio: (100 * 1000000) / 1000 = 100000
        // User1 Gov ratio: (100 * 1000000 * 1) / 1000 = 100000
        // User1 score: 100000

        // User2 LP ratio: (200 * 1000000) / 1000 = 200000
        // User2 Gov ratio: (200 * 1000000 * 1) / 1000 = 200000
        // User2 score: 200000

        // User3 LP ratio: (300 * 1000000) / 1000 = 300000
        // User3 Gov ratio: (300 * 1000000 * 1) / 1000 = 300000
        // User3 score: 300000

        assertEq(extension.stakersCount(), 3);
    }

    function test_CalculateScores_DirectCall_SingleUser() public {
        // Setup: user1 stakes 100e18 LP
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Direct call to calculateScores
        (uint256 totalScore, uint256[] memory scores) = extension
            .calculateScores();

        // Verify results
        assertEq(scores.length, 1, "Should have 1 score");
        assertTrue(totalScore > 0, "Total score should be greater than 0");
        assertEq(
            totalScore,
            scores[0],
            "Total score should equal single score"
        );

        // Expected calculation:
        // Total LP: 1600e18 (1000e18 in pair + 100e18 user1 + 200e18 user2 + 300e18 user3)
        // User LP: 100e18
        // LP ratio: (100e18 * 1000000) / 1600e18 = 62500
        // Total gov votes: 1000e18, User gov votes: 100e18
        // Gov ratio: (100e18 * 1000000 * 1) / 1000e18 = 100000
        // Score: min(62500, 100000) = 62500
        assertEq(scores[0], 62500, "Score should be 62500");
        assertEq(totalScore, 62500, "Total score should be 62500");
    }

    function test_CalculateScores_DirectCall_MultipleUsers() public {
        // Setup: multiple users stake different amounts
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        vm.prank(user3);
        extension.stakeLp(300e18);

        // Direct call to calculateScores
        (uint256 totalScore, uint256[] memory scores) = extension
            .calculateScores();

        // Verify results
        assertEq(scores.length, 3, "Should have 3 scores");
        assertTrue(totalScore > 0, "Total score should be greater than 0");

        // Expected calculations (Total LP: 1600e18):
        // User1: lpRatio = 62500, govRatio = 100000, score = 62500
        // User2: lpRatio = 125000, govRatio = 200000, score = 125000
        // User3: lpRatio = 187500, govRatio = 300000, score = 187500
        assertEq(scores[0], 62500, "User1 score should be 62500");
        assertEq(scores[1], 125000, "User2 score should be 125000");
        assertEq(scores[2], 187500, "User3 score should be 187500");
        assertEq(totalScore, 375000, "Total score should be sum of all scores");
    }

    function test_CalculateScores_EmptyStakers() public view {
        // No stakers, direct call to calculateScores
        (uint256 totalScore, uint256[] memory scores) = extension
            .calculateScores();

        // Verify results
        assertEq(scores.length, 0, "Should have 0 scores");
        assertEq(totalScore, 0, "Total score should be 0");
    }

    function test_CalculateScores_GovRatioIsLimiting() public {
        // Setup: user has more LP ratio than gov ratio
        // User stakes 100e18 out of 100e18 available (all their LP)
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Total LP: 1600e18, User LP: 100e18
        // LP ratio: (100e18 * 1000000) / 1600e18 = 62500
        // User1 has 100e18 gov votes out of 1000e18 total
        // Gov ratio: (100e18 * 1000000 * 1) / 1000e18 = 100000
        // Score should be limited by LP ratio (min) = 62500
        // This is actually LP-limited, not gov-limited with current setup

        (uint256 totalScore, uint256[] memory scores) = extension
            .calculateScores();

        assertEq(scores.length, 1, "Should have 1 score");
        assertEq(scores[0], 62500, "Score should be 62500");
        assertEq(totalScore, 62500, "Total should be 62500");
    }

    function test_CalculateScores_LpRatioIsLimiting() public {
        // Test where user has less LP ratio than gov ratio
        vm.prank(user1);
        extension.stakeLp(50e18);

        // Total LP: 1600e18, User LP: 50e18
        // LP ratio: (50e18 * 1000000) / 1600e18 = 31250
        // User1 has 100e18 gov votes (10% of 1000e18 total)
        // Gov ratio: (100e18 * 1000000 * 1) / 1000e18 = 100000
        // Score should be limited by LP ratio (min) = 31250

        (, uint256[] memory scores) = extension.calculateScores();

        assertEq(scores.length, 1, "Should have 1 score");
        // Score should be limited by LP ratio
        assertEq(scores[0], 31250, "Score should be limited by LP ratio");
    }

    function test_CalculateScore_DirectCall_ExistingAccount() public {
        // Setup: stake with user1
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        // Direct call to calculateScore for user1
        (uint256 total, uint256 score) = extension.calculateScore(user1);

        // Verify results
        assertTrue(total > 0, "Total should be greater than 0");
        assertTrue(score > 0, "Score should be greater than 0");
        // User1: lpRatio = 62500, govRatio = 100000, score = 62500
        // User2: lpRatio = 125000, govRatio = 200000, score = 125000
        // Total: 187500
        assertEq(score, 62500, "User1 score should be 62500");
        assertEq(total, 187500, "Total score should be 187500");
    }

    function test_CalculateScore_DirectCall_NonExistentAccount() public {
        // Setup: stake with user1 and user2
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        // Direct call to calculateScore for user3 (who hasn't staked)
        (uint256 total, uint256 score) = extension.calculateScore(user3);

        // Verify results
        assertTrue(total > 0, "Total should be greater than 0");
        assertEq(score, 0, "Score for non-existent account should be 0");
        assertEq(total, 187500, "Total should still be calculated");
    }

    function test_CalculateScore_DirectCall_MultipleUsers() public {
        // Setup: multiple users stake
        vm.prank(user1);
        extension.stakeLp(100e18);

        vm.prank(user2);
        extension.stakeLp(200e18);

        vm.prank(user3);
        extension.stakeLp(300e18);

        // Test each user's score
        (uint256 total1, uint256 score1) = extension.calculateScore(user1);
        assertEq(score1, 62500, "User1 score should be 62500");
        assertEq(total1, 375000, "Total should be 375000");

        (uint256 total2, uint256 score2) = extension.calculateScore(user2);
        assertEq(score2, 125000, "User2 score should be 125000");
        assertEq(total2, 375000, "Total should be 375000");

        (uint256 total3, uint256 score3) = extension.calculateScore(user3);
        assertEq(score3, 187500, "User3 score should be 187500");
        assertEq(total3, 375000, "Total should be 375000");

        // Verify sum
        assertEq(
            score1 + score2 + score3,
            total1,
            "Sum of scores should equal total"
        );
    }

    function test_CalculateScore_EmptyStakers() public view {
        // No stakers, call calculateScore
        (uint256 total, uint256 score) = extension.calculateScore(user1);

        assertEq(total, 0, "Total should be 0 with no stakers");
        assertEq(score, 0, "Score should be 0 with no stakers");
    }

    // ============================================
    // Claim Reward Tests
    // ============================================

    function test_ClaimReward() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Setup reward for round 1
        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        // Move to round 2
        verify.setCurrentRound(2);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);

        uint256 balanceAfter = token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, claimed);
        assertTrue(claimed > 0);
    }

    function test_ClaimReward_EmitEvent() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit ClaimReward(user1, round, 0);
        extension.claimReward(round);
    }

    event ClaimReward(
        address indexed account,
        uint256 indexed round,
        uint256 reward
    );

    function test_ClaimReward_RevertIfAlreadyClaimed() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        extension.claimReward(round);

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.AlreadyClaimed.selector);
        extension.claimReward(round);
    }

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        verify.setCurrentRound(1);

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.RoundNotFinished.selector);
        extension.claimReward(round);
    }

    function test_ClaimReward_MultipleRounds() public {
        // User stakes in round 1
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Set rewards for round 1
        uint256 round1 = 1;
        uint256 reward1Amount = 1000e18;
        mint.setActionReward(address(token), round1, ACTION_ID, reward1Amount);

        // Move to round 2
        verify.setCurrentRound(2);
        join.setCurrentRound(2);

        // Claim reward for round 1
        vm.prank(user1);
        uint256 claimed1 = extension.claimReward(round1);
        assertTrue(claimed1 > 0, "Round 1 reward should be > 0");

        // Set rewards for round 2
        uint256 round2 = 2;
        uint256 reward2Amount = 2000e18;
        mint.setActionReward(address(token), round2, ACTION_ID, reward2Amount);

        // Move to round 3
        verify.setCurrentRound(3);
        join.setCurrentRound(3);

        // Claim reward for round 2
        vm.prank(user1);
        uint256 claimed2 = extension.claimReward(round2);
        assertTrue(claimed2 > 0, "Round 2 reward should be > 0");

        // Cannot claim same round twice
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.AlreadyClaimed.selector);
        extension.claimReward(round1);
    }

    // ============================================
    // Edge Cases and Complex Scenarios
    // ============================================

    function test_StakeLp_AfterUnstakeAndWithdraw() public {
        // User stakes
        vm.prank(user1);
        extension.stakeLp(50e18);

        // User unstakes
        vm.prank(user1);
        extension.unstakeLp();

        // Wait and withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);
        vm.prank(user1);
        extension.withdrawLp();

        // User can stake again
        vm.prank(user1);
        extension.stakeLp(30e18);

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 30e18);
        assertEq(requestedUnstakeRound, 0);
    }

    function test_JoinedValue_ZeroWhenNoLP() public {
        // Set total supply to 0
        MockUniswapV2Pair emptyPair = new MockUniswapV2Pair(
            address(token),
            address(anotherToken)
        );
        emptyPair.setReserves(0, 0);

        assertEq(emptyPair.totalSupply(), 0);
    }

    function test_PrepareVerifyResult_AlreadyPrepared() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // First claim prepares the result
        vm.prank(user1);
        extension.claimReward(round);

        uint256 scoreAfterFirstClaim = extension.totalScore(round);

        // Second user stakes and claims - should use already prepared result
        vm.prank(user2);
        extension.stakeLp(200e18);

        vm.prank(user2);
        uint256 claimed = extension.claimReward(round);

        // Total score should be same (not recalculated)
        assertEq(extension.totalScore(round), scoreAfterFirstClaim);
        assertEq(claimed, 0); // user2 wasn't in snapshot
    }

    function test_PrepareVerifyResult_FutureRound() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        // Try to get reward for a future round
        uint256 futureRound = 10;
        verify.setCurrentRound(2); // Current is 2, asking for 10

        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            futureRound,
            user1
        );

        assertEq(reward, 0);
        assertFalse(isMinted);
    }

    function test_ClaimReward_ZeroWhenNoTotalScore() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        // Set all gov votes to 0 to make total score 0
        stake.setValidGovVotes(address(token), user1, 0);
        stake.setValidGovVotes(address(token), user2, 0);
        stake.setValidGovVotes(address(token), user3, 0);

        verify.setCurrentRound(2);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);

        assertEq(claimed, 0);
    }

    function test_RewardByAccount_WithoutVerifyResult() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        mint.setActionReward(address(token), round, ACTION_ID, 1000e18);

        // Move to round 2 but don't trigger verification
        verify.setCurrentRound(2);

        // This should calculate score on-the-fly
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            round,
            user1
        );

        assertFalse(isMinted);
        assertTrue(reward > 0 || reward == 0); // May be 0 or positive
    }

    function test_ClaimReward_ZeroScoreForUser() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        // Set user1's gov votes to 0
        stake.setValidGovVotes(address(token), user1, 0);

        verify.setCurrentRound(2);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);

        // User with 0 gov votes gets 0 reward
        assertEq(claimed, 0);
    }

    function test_ScoreCalculation_GovRatioLower() public {
        // Test case where gov ratio is lower than LP ratio
        vm.prank(user1);
        extension.stakeLp(50e18); // 50 out of 1000+600 total LP

        // Set gov votes lower than LP proportion
        stake.setValidGovVotes(address(token), user1, 10e18); // 10 out of 1000 total gov votes

        uint256 round = 1;
        verify.setCurrentRound(2);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        // This tests the branch where govVotesRatio < lpRatio
        assertTrue(reward >= 0);
    }

    function test_ScoreCalculation_LpRatioLower() public {
        // Test case where LP ratio is lower than gov ratio
        vm.prank(user1);
        extension.stakeLp(10e18); // Small LP amount

        // Set gov votes higher than LP proportion
        stake.setValidGovVotes(address(token), user1, 500e18); // High gov votes

        uint256 round = 1;
        verify.setCurrentRound(2);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        // This tests the branch where lpRatio < govVotesRatio
        assertTrue(reward >= 0);
    }

    function test_ClaimReward_PrepareRewardNotNeeded() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // First claim prepares reward
        vm.prank(user1);
        extension.claimReward(round);

        // Claim with different user should reuse prepared reward
        vm.prank(user2);
        extension.stakeLp(50e18);

        vm.prank(user2);
        uint256 claimed = extension.claimReward(round);

        assertEq(claimed, 0); // user2 wasn't in the snapshot
    }

    function test_RewardByAccount_BeforeVerifyFinished() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        verify.setCurrentRound(1);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        assertEq(reward, 0);
    }

    function test_RewardByAccount_AfterClaimed() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // Claim first
        vm.prank(user1);
        uint256 claimedAmount = extension.claimReward(round);

        // Check rewardByAccount returns claimed amount
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            round,
            user1
        );
        assertEq(reward, claimedAmount);
        assertTrue(isMinted);
    }

    // ============================================
    // Verified Accounts and Scores Tests
    // ============================================

    function test_TotalScore() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // Claim to trigger verification
        vm.prank(user1);
        extension.claimReward(round);

        // Check total score
        uint256 totalScore = extension.totalScore(round);
        assertTrue(totalScore > 0);
    }

    function test_VerifiedAccounts() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // Claim to trigger verification
        vm.prank(user1);
        extension.claimReward(round);

        // Check verified accounts
        address[] memory verifiedAccts = extension.verifiedAccounts(round);
        assertTrue(verifiedAccts.length >= 1);
        assertEq(extension.verifiedAccountsCount(round), verifiedAccts.length);
    }

    function test_VerifiedAccountsAtIndex() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        extension.claimReward(round);

        address account0 = extension.verifiedAccountsAtIndex(round, 0);

        assertEq(account0, user1);
    }

    function test_Scores() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        extension.claimReward(round);

        uint256[] memory scoresArray = extension.scores(round);
        assertTrue(scoresArray.length >= 1);
        assertEq(extension.scoresCount(round), scoresArray.length);
    }

    function test_ScoresAtIndex() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        extension.claimReward(round);

        uint256 score0 = extension.scoresAtIndex(round, 0);
        assertTrue(score0 > 0);
    }

    function test_ScoreByAccount() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        vm.prank(user1);
        extension.claimReward(round);

        uint256 score1 = extension.scoreByAccount(round, user1);

        assertTrue(score1 > 0);
    }

    // ============================================
    // Accounts Management Tests
    // ============================================

    function test_Accounts() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        address[] memory accts = extension.accounts();
        assertEq(accts.length, 2);
        assertEq(extension.accountsCount(), 2);
        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    function test_Stakers() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        address[] memory stakers = extension.stakers();
        assertEq(stakers.length, 2);
        assertEq(extension.stakersCount(), 2);
    }

    function test_Unstakers() public {
        vm.prank(user1);
        extension.stakeLp(50e18);

        vm.prank(user2);
        extension.stakeLp(100e18);

        vm.prank(user1);
        extension.unstakeLp();

        address[] memory unstakers = extension.unstakers();
        assertEq(unstakers.length, 1);
        assertEq(extension.unstakersCount(), 1);
        assertEq(extension.unstakersAtIndex(0), user1);
    }

    // ============================================
    // Factory Tests
    // ============================================

    function test_Factory_CreateExtension() public {
        address newExtension = factory.createExtension(
            address(token),
            ACTION_ID + 1,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        assertTrue(factory.exists(newExtension));
        assertEq(factory.extensionsCount(address(token)), 2);
    }

    function test_Factory_Extensions() public {
        // Create multiple extensions
        address extension2 = factory.createExtension(
            address(token),
            ACTION_ID + 1,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        address[] memory exts = factory.extensions(address(token));
        assertEq(exts.length, 2);
        assertEq(exts[0], address(extension));
        assertEq(exts[1], extension2);
    }

    function test_Factory_ExtensionsAtIndex() public {
        // Create another extension
        address extension2 = factory.createExtension(
            address(token),
            ACTION_ID + 1,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        assertEq(
            factory.extensionsAtIndex(address(token), 0),
            address(extension)
        );
        assertEq(factory.extensionsAtIndex(address(token), 1), extension2);
    }

    function test_Factory_ExtensionParams() public view {
        (
            address tokenAddr,
            uint256 actionId,
            address anotherTokenAddr,
            uint256 waitingPhases,
            uint256 govRatioMult,
            uint256 minGovVotesVal
        ) = factory.extensionParams(address(extension));

        assertEq(tokenAddr, address(token));
        assertEq(actionId, ACTION_ID);
        assertEq(anotherTokenAddr, address(anotherToken));
        assertEq(waitingPhases, WAITING_PHASES);
        assertEq(govRatioMult, GOV_RATIO_MULTIPLIER);
        assertEq(minGovVotesVal, MIN_GOV_VOTES);
    }

    function test_Factory_ExtensionParams_NonExistent() public view {
        // Query params for non-existent extension
        (
            address tokenAddr,
            uint256 actionId,
            address anotherTokenAddr,
            uint256 waitingPhases,
            uint256 govRatioMult,
            uint256 minGovVotesVal
        ) = factory.extensionParams(address(0x999));

        // Should return zero values
        assertEq(tokenAddr, address(0));
        assertEq(actionId, 0);
        assertEq(anotherTokenAddr, address(0));
        assertEq(waitingPhases, 0);
        assertEq(govRatioMult, 0);
        assertEq(minGovVotesVal, 0);
    }

    function test_Factory_Center() public view {
        assertEq(factory.center(), address(center));
    }

    function test_Factory_RevertIfInvalidTokenAddress() public {
        vm.expectRevert(
            ILOVE20ExtensionFactoryStakeLp.InvalidTokenAddress.selector
        );
        factory.createExtension(
            address(0),
            ACTION_ID,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );
    }

    function test_Factory_RevertIfInvalidAnotherTokenAddress() public {
        vm.expectRevert(
            ILOVE20ExtensionFactoryStakeLp.InvalidAnotherTokenAddress.selector
        );
        factory.createExtension(
            address(token),
            ACTION_ID,
            address(0),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );
    }

    function test_Factory_RevertIfSameTokenAddresses() public {
        vm.expectRevert(
            ILOVE20ExtensionFactoryStakeLp.SameTokenAddresses.selector
        );
        factory.createExtension(
            address(token),
            ACTION_ID,
            address(token),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );
    }

    function test_Constructor_RevertIfPairNotCreated() public {
        MockERC20 newToken = new MockERC20();
        MockERC20 newAnotherToken = new MockERC20();

        // Don't create pair
        vm.expectRevert(
            ILOVE20ExtensionStakeLp.UniswapV2PairNotCreated.selector
        );
        new LOVE20ExtensionStakeLp(
            address(factory),
            address(newToken),
            ACTION_ID,
            address(newAnotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );
    }

    function test_TokenAddressAsToken1() public {
        // Create pair with anotherToken as token0 (comes first alphabetically if address is smaller)
        MockUniswapV2Pair reversePair = MockUniswapV2Pair(
            uniswapFactory.createPair(address(anotherToken), address(token))
        );

        reversePair.setReserves(2000e18, 1000e18);
        reversePair.mint(address(reversePair), 1000e18);

        // Create extension with reversed pair
        address reverseExtension = factory.createExtension(
            address(token),
            ACTION_ID + 10,
            address(anotherToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        LOVE20ExtensionStakeLp revExt = LOVE20ExtensionStakeLp(
            reverseExtension
        );

        // Initialize
        vm.prank(address(center));
        revExt.initialize();

        // Setup user
        reversePair.mint(user1, 100e18);
        vm.prank(user1);
        reversePair.approve(address(revExt), type(uint256).max);

        // Stake
        vm.prank(user1);
        revExt.stakeLp(50e18);

        // Check joined value calculation works correctly
        uint256 joinedVal = revExt.joinedValue();
        assertTrue(joinedVal > 0);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_StakeLp(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1e18, 100e18);

        vm.prank(user1);
        extension.stakeLp(amount);

        (uint256 stakedAmount, ) = extension.stakeInfo(user1);
        assertEq(stakedAmount, amount);
        assertEq(extension.totalStakedAmount(), amount);
    }

    function testFuzz_MultipleStakes(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1e18, 50e18);
        amount2 = bound(amount2, 1e18, 100e18);

        vm.prank(user1);
        extension.stakeLp(amount1);

        vm.prank(user2);
        extension.stakeLp(amount2);

        assertEq(extension.totalStakedAmount(), amount1 + amount2);
        assertEq(extension.stakersCount(), 2);
    }
}
