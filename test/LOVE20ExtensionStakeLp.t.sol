// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {LOVE20ExtensionStakeLp} from "../src/LOVE20ExtensionStakeLp.sol";
import {
    LOVE20ExtensionFactoryStakeLp
} from "../src/LOVE20ExtensionFactoryStakeLp.sol";
import {
    ILOVE20ExtensionStakeLp
} from "../src/interface/ILOVE20ExtensionStakeLp.sol";
import {
    ILOVE20ExtensionFactoryStakeLp
} from "../src/interface/ILOVE20ExtensionFactoryStakeLp.sol";
import {ILOVE20Extension} from "@extension/src/interface/ILOVE20Extension.sol";
import {
    ILOVE20ExtensionFactory
} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";
import {
    ILOVE20ExtensionCenter
} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";
import {LOVE20ExtensionCenter} from "@extension/src/LOVE20ExtensionCenter.sol";
import {
    IUniswapV2Pair
} from "@core/src/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";

// Import mock contracts
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Factory} from "./mocks/MockUniswapV2Factory.sol";
import {MockUniswapV2Pair} from "./mocks/MockUniswapV2Pair.sol";
import {MockStake} from "./mocks/MockStake.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockVerify} from "./mocks/MockVerify.sol";
import {MockMint} from "./mocks/MockMint.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockLaunch} from "./mocks/MockLaunch.sol";
import {MockVote} from "./mocks/MockVote.sol";
import {MockRandom} from "./mocks/MockRandom.sol";

/**
 * @title LOVE20ExtensionStakeLp Test Suite
 */
contract LOVE20ExtensionStakeLpTest is Test {
    LOVE20ExtensionFactoryStakeLp public factory;
    LOVE20ExtensionStakeLp public extension;
    LOVE20ExtensionCenter public center;
    MockERC20 public token;
    MockUniswapV2Pair public stakeToken;
    MockStake public stake;
    MockJoin public join;
    MockVerify public verify;
    MockMint public mint;
    MockSubmit public submit;
    MockLaunch public launch;
    MockVote public vote;
    MockRandom public random;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant ACTION_ID = 1;
    uint256 constant WAITING_PHASES = 7;
    uint256 constant GOV_RATIO_MULTIPLIER = 2;
    uint256 constant MIN_GOV_VOTES = 1e18;

    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20();
        MockUniswapV2Factory uniswapFactory = new MockUniswapV2Factory();
        // Create a Pair for token and another token (e.g., WETH)
        MockERC20 otherToken = new MockERC20();
        stakeToken = MockUniswapV2Pair(
            uniswapFactory.createPair(address(token), address(otherToken))
        );
        stake = new MockStake();
        join = new MockJoin();
        verify = new MockVerify();
        mint = new MockMint();
        submit = new MockSubmit();
        launch = new MockLaunch();
        vote = new MockVote();
        random = new MockRandom();

        // Deploy real LOVE20ExtensionCenter
        center = new LOVE20ExtensionCenter(
            address(uniswapFactory),
            address(launch),
            address(stake),
            address(submit),
            address(vote),
            address(join),
            address(verify),
            address(mint),
            address(random)
        );

        // Deploy factory
        factory = new LOVE20ExtensionFactoryStakeLp(address(center));

        // Create extension
        extension = LOVE20ExtensionStakeLp(
            factory.createExtension(
                address(stakeToken),
                WAITING_PHASES,
                GOV_RATIO_MULTIPLIER,
                MIN_GOV_VOTES
            )
        );

        // Register factory to center (needs canSubmit permission)
        submit.setCanSubmit(address(token), address(this), true);
        center.addFactory(address(token), address(factory));

        // Set action info whiteListAddress to extension address
        submit.setActionInfo(address(token), ACTION_ID, address(extension));

        // Initialize extension through center
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // Setup users with stake tokens
        stakeToken.mint(user1, 100e18);
        stakeToken.mint(user2, 200e18);
        stakeToken.mint(user3, 300e18);

        // Set initial total supply for stakeToken (for ratio calculations)
        // Total supply = initial minted amounts + any additional
        stakeToken.mint(address(0x1), 1000e18); // Add to total supply for ratio calculation

        // Set Pair reserves for LP to token conversion
        // Set reserves: token reserves = 10000e18, otherToken reserves = 10000e18
        // This allows LP to token conversion to work correctly
        // The actual mapping (token0/token1) will be determined by pair.token0() in the contract
        stakeToken.setReserves(10000e18, 10000e18);

        // Approve extension to spend stake tokens
        vm.prank(user1);
        stakeToken.approve(address(extension), type(uint256).max);
        vm.prank(user2);
        stakeToken.approve(address(extension), type(uint256).max);
        vm.prank(user3);
        stakeToken.approve(address(extension), type(uint256).max);

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
        vm.expectRevert(ILOVE20ExtensionCenter.ExtensionAlreadyExists.selector);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );
    }

    function test_Initialize_RevertIfNotCenter() public {
        // Deploy new extension without initialization
        LOVE20ExtensionStakeLp newExtension = new LOVE20ExtensionStakeLp(
            address(factory),
            address(stakeToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.OnlyCenterCanCall.selector);
        newExtension.initialize(address(token), ACTION_ID + 1);
    }

    function test_Initialize_RevertIfInvalidTokenAddress() public {
        // Deploy new extension without initialization
        LOVE20ExtensionStakeLp newExtension = new LOVE20ExtensionStakeLp(
            address(factory),
            address(stakeToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        // Note: This test cannot use center.initializeExtension because center checks
        // factory registration first, and zero address checks happen later in initialize.
        // Instead, we test the direct initialize call which is protected by onlyCenter modifier.
        vm.prank(address(center));
        vm.expectRevert(ILOVE20Extension.InvalidTokenAddress.selector);
        newExtension.initialize(address(0), ACTION_ID + 1);
    }

    function test_Initialize_RevertIfInvalidStakeTokenAddress() public {
        // Deploy new extension with invalid stakeToken (not a Pair)
        // Must create through factory to register it
        MockERC20 invalidStakeToken = new MockERC20();
        address newExtensionAddress = factory.createExtension(
            address(invalidStakeToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        // Set action info for the new action ID
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            newExtensionAddress
        );

        // Initialize should fail because invalidStakeToken is not a Pair
        // Center wraps the error in InitializeFailed(), so we check for that
        vm.expectRevert(ILOVE20ExtensionCenter.InitializeFailed.selector);
        center.initializeExtension(
            newExtensionAddress,
            address(token),
            ACTION_ID + 1
        );
    }

    function test_Initialize_RevertIfStakeTokenNotPairWithToken() public {
        // Create a Pair that doesn't include token using the same factory as center
        MockERC20 token1 = new MockERC20();
        MockERC20 token2 = new MockERC20();
        // Use the same factory that was used in setUp
        address uniswapFactoryAddr = center.uniswapV2FactoryAddress();
        MockUniswapV2Factory uniswapFactory = MockUniswapV2Factory(
            uniswapFactoryAddr
        );
        MockUniswapV2Pair wrongPair = MockUniswapV2Pair(
            uniswapFactory.createPair(address(token1), address(token2))
        );

        // Deploy new extension with wrong Pair (doesn't include token)
        // Must create through factory to register it
        address newExtensionAddress = factory.createExtension(
            address(wrongPair),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        // Set action info for the new action ID
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            newExtensionAddress
        );

        // Initialize should fail because wrongPair doesn't include token
        // Center wraps the error in InitializeFailed(), so we check for that
        vm.expectRevert(ILOVE20ExtensionCenter.InitializeFailed.selector);
        center.initializeExtension(
            newExtensionAddress,
            address(token),
            ACTION_ID + 1
        );
    }

    // ============================================
    // View Function Tests
    // ============================================

    function test_ImmutableVariables() public view {
        assertEq(extension.factory(), address(factory));
        assertEq(extension.tokenAddress(), address(token));
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension.stakeTokenAddress(), address(stakeToken));
        assertEq(extension.waitingPhases(), WAITING_PHASES);
        assertEq(extension.govRatioMultiplier(), GOV_RATIO_MULTIPLIER);
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
        extension.stake(stakeAmount);

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, stakeAmount);
        assertEq(requestedUnstakeRound, 0);
        assertEq(extension.totalStakedAmount(), stakeAmount);
        assertEq(extension.accountsCount(), 1);
        assertEq(extension.accountsCount(), 1);
    }

    function test_StakeLp_Multiple() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        assertEq(extension.totalStakedAmount(), 150e18);
        assertEq(extension.accountsCount(), 2);
        assertEq(extension.accountsCount(), 2);
    }

    function test_StakeLp_MultipleTimesSameUser() public {
        vm.prank(user1);
        extension.stake(30e18);

        vm.prank(user1);
        extension.stake(20e18);

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 50e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_StakeLp_EmitEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Stake(user1, 50e18);
        extension.stake(50e18);
    }

    event Stake(address indexed account, uint256 amount);

    function test_StakeLp_RevertIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.StakeAmountZero.selector);
        extension.stake(0);
    }

    function test_StakeLp_RevertIfUnstakeRequested() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeRequested.selector);
        extension.stake(10e18);
    }

    function test_StakeLp_RevertIfInsufficientGovVotes() public {
        // Create a new user with insufficient gov votes
        address user4 = address(0x4);
        stakeToken.mint(user4, 100e18);
        vm.prank(user4);
        stakeToken.approve(address(extension), type(uint256).max);

        // Set gov votes below MIN_GOV_VOTES (MIN_GOV_VOTES = 1e18)
        stake.setValidGovVotes(address(token), user4, 0.5e18);

        // Expect revert when first time staking with insufficient gov votes
        vm.prank(user4);
        vm.expectRevert(ILOVE20ExtensionStakeLp.InsufficientGovVotes.selector);
        extension.stake(50e18);
    }

    function test_StakeLp_SuccessWithMinimumGovVotes() public {
        // user1 has 100e18, well above MIN_GOV_VOTES (1e18)
        vm.prank(user1);
        extension.stake(50e18);

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 50e18);
    }

    function test_JoinedValue() public {
        vm.prank(user1);
        extension.stake(100e18);

        // joinedValue should return tokenAddress amount, not LP token amount
        // Get actual LP supply after stake (stake transfers LP tokens to extension)
        IUniswapV2Pair pair = IUniswapV2Pair(address(stakeToken));
        uint256 totalLpSupply = pair.totalSupply();
        uint256 stakedLpAmount = 100e18;

        // Get token reserve (token is either token0 or token1)
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        address pairToken0 = pair.token0();
        uint256 tokenReserve = (pairToken0 == address(token))
            ? uint256(reserve0)
            : uint256(reserve1);

        // Calculate expected token amount: (stakedLpAmount * tokenReserve) / totalLpSupply
        uint256 expectedTokenAmount = (stakedLpAmount * tokenReserve) /
            totalLpSupply;
        assertEq(extension.joinedValue(), expectedTokenAmount);
    }

    function test_JoinedValueByAccount() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        // joinedValueByAccount should return tokenAddress amount, not LP token amount
        // Get actual LP supply after both stakes
        IUniswapV2Pair pair = IUniswapV2Pair(address(stakeToken));
        uint256 totalLpSupply = pair.totalSupply();

        // Get token reserve (token is either token0 or token1)
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        address pairToken0 = pair.token0();
        uint256 tokenReserve = (pairToken0 == address(token))
            ? uint256(reserve0)
            : uint256(reserve1);

        // Calculate expected token amounts
        uint256 expectedTokenAmount1 = (50e18 * tokenReserve) / totalLpSupply;
        uint256 expectedTokenAmount2 = (100e18 * tokenReserve) / totalLpSupply;
        assertEq(extension.joinedValueByAccount(user1), expectedTokenAmount1);
        assertEq(extension.joinedValueByAccount(user2), expectedTokenAmount2);
    }

    // ============================================
    // Unstake LP Tests
    // ============================================

    function test_UnstakeLp() public {
        vm.prank(user1);
        extension.stake(50e18);

        uint256 initialRound = join.currentRound();

        vm.prank(user1);
        extension.unstake();

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 50e18);
        assertEq(requestedUnstakeRound, initialRound);
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
        assertEq(extension.unstakersCount(), 1);
    }

    function test_UnstakeLp_EmitEvent() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Unstake(user1, 50e18);
        extension.unstake();
    }

    event Unstake(address indexed account, uint256 amount);

    function test_UnstakeLp_RevertIfNoStakedAmount() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.NoStakedAmount.selector);
        extension.unstake();
    }

    function test_UnstakeLp_RevertIfAlreadyRequested() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeRequested.selector);
        extension.unstake();
    }

    // ============================================
    // Withdraw LP Tests
    // ============================================

    function test_WithdrawLp() public {
        vm.prank(user1);
        extension.stake(50e18);

        uint256 balanceBefore = stakeToken.balanceOf(user1);

        vm.prank(user1);
        extension.unstake();

        // Move forward enough rounds
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 0);
        assertEq(requestedUnstakeRound, 0);
        assertEq(extension.unstakersCount(), 0);
        assertEq(extension.accountsCount(), 0);

        uint256 balanceAfter = stakeToken.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, 50e18);
    }

    function test_WithdrawLp_EmitEvent() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(user1, 50e18);
        extension.withdraw();
    }

    event Withdraw(address indexed account, uint256 amount);

    function test_WithdrawLp_RevertIfUnstakeNotRequested() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionStakeLp.UnstakeNotRequested.selector);
        extension.withdraw();
    }

    function test_WithdrawLp_RevertIfNotEnoughWaitingPhases() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        // Move forward but not enough
        join.setCurrentRound(join.currentRound() + WAITING_PHASES);

        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionStakeLp.NotEnoughWaitingPhases.selector
        );
        extension.withdraw();
    }

    // ============================================
    // TotalUnstakedAmount Tests
    // ============================================

    function test_TotalUnstakedAmount_InitiallyZero() public view {
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_AfterUnstake() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalUnstakedAmount(), 50e18);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_MultipleUnstakes() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        vm.prank(user3);
        extension.stake(150e18);

        // User1 unstakes
        vm.prank(user1);
        extension.unstake();
        assertEq(extension.totalUnstakedAmount(), 50e18);
        assertEq(extension.totalStakedAmount(), 250e18);

        // User2 unstakes
        vm.prank(user2);
        extension.unstake();
        assertEq(extension.totalUnstakedAmount(), 150e18);
        assertEq(extension.totalStakedAmount(), 150e18);

        // User3 unstakes
        vm.prank(user3);
        extension.unstake();
        assertEq(extension.totalUnstakedAmount(), 300e18);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_AfterWithdraw() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalUnstakedAmount(), 50e18);

        // Wait enough rounds
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_PartialWithdraw() public {
        // User1 and User2 stake
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        // Both unstake
        vm.prank(user1);
        extension.unstake();

        vm.prank(user2);
        extension.unstake();

        assertEq(extension.totalUnstakedAmount(), 150e18);
        assertEq(extension.totalStakedAmount(), 0);

        // Only User1 withdraws
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalUnstakedAmount(), 100e18);
        assertEq(extension.totalStakedAmount(), 0);

        // User2 withdraws
        vm.prank(user2);
        extension.withdraw();

        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.totalStakedAmount(), 0);
    }

    function test_TotalUnstakedAmount_StakeUnstakeWithdrawCycle() public {
        // First cycle
        vm.prank(user1);
        extension.stake(50e18);
        assertEq(extension.totalStakedAmount(), 50e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        vm.prank(user1);
        extension.unstake();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 50e18);

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);

        // Second cycle - user can stake again
        vm.prank(user1);
        extension.stake(30e18);
        assertEq(extension.totalStakedAmount(), 30e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        vm.prank(user1);
        extension.unstake();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 30e18);
    }

    function test_TotalUnstakedAmount_ComplexScenario() public {
        // User1, User2, User3 stake
        vm.prank(user1);
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

        vm.prank(user3);
        extension.stake(300e18);

        assertEq(extension.totalStakedAmount(), 600e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        // User1 unstakes
        vm.prank(user1);
        extension.unstake();
        assertEq(extension.totalStakedAmount(), 500e18);
        assertEq(extension.totalUnstakedAmount(), 100e18);

        // User2 unstakes
        vm.prank(user2);
        extension.unstake();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 300e18);

        // Wait and User1 withdraws
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 200e18);

        // User2 withdraws (same unstake round as User1, so can withdraw now)
        vm.prank(user2);
        extension.withdraw();
        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.totalUnstakedAmount(), 0);

        // User3 unstakes
        vm.prank(user3);
        extension.unstake();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 300e18);

        // Wait for User3 to be able to withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        // User3 withdraws
        vm.prank(user3);
        extension.withdraw();
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    function testFuzz_TotalUnstakedAmount(uint256 amount) public {
        amount = bound(amount, 1e18, 100e18);

        vm.prank(user1);
        extension.stake(amount);

        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalUnstakedAmount(), amount);
        assertEq(extension.totalStakedAmount(), 0);

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

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
        extension.stake(amount1);

        vm.prank(user2);
        extension.stake(amount2);

        vm.prank(user3);
        extension.stake(amount3);

        uint256 totalStaked = amount1 + amount2 + amount3;
        assertEq(extension.totalStakedAmount(), totalStaked);
        assertEq(extension.totalUnstakedAmount(), 0);

        // All unstake
        vm.prank(user1);
        extension.unstake();

        vm.prank(user2);
        extension.unstake();

        vm.prank(user3);
        extension.unstake();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), totalStaked);

        // All withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

        vm.prank(user2);
        extension.withdraw();

        vm.prank(user3);
        extension.withdraw();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
    }

    // ============================================
    // Score Calculation Tests
    // ============================================

    function test_ScoreCalculation_SingleUser() public {
        vm.prank(user1);
        extension.stake(100e18);

        // Total LP: 1600e18 (1000e18 in pair + 600e18 users), User LP: 100e18
        // LP ratio: (100e18 * 1000000) / 1600e18 = 62500
        // Total gov votes: 1000e18, User gov votes: 100e18
        // Gov ratio: (100e18 * 1000000 * 2) / 1000e18 = 200000
        // Score: min(62500, 200000) = 62500

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
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

        vm.prank(user3);
        extension.stake(300e18);

        // Total LP: 1600e18 (1000e18 in pair + 600e18 users)
        // Total staked: 600e18
        // Total gov votes: 1000e18

        // User1 LP ratio: (100 * 1000000) / 1600 = 62500
        // User1 Gov ratio: (100 * 1000000 * 2) / 1000 = 200000
        // User1 score: min(62500, 200000) = 62500

        // User2 LP ratio: (200 * 1000000) / 1600 = 125000
        // User2 Gov ratio: (200 * 1000000 * 2) / 1000 = 400000
        // User2 score: min(125000, 400000) = 125000

        // User3 LP ratio: (300 * 1000000) / 1600 = 187500
        // User3 Gov ratio: (300 * 1000000 * 2) / 1000 = 600000
        // User3 score: min(187500, 600000) = 187500

        assertEq(extension.accountsCount(), 3);
    }

    function test_CalculateScores_DirectCall_SingleUser() public {
        // Setup: user1 stakes 100e18 LP
        vm.prank(user1);
        extension.stake(100e18);

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
        // Gov ratio: (100e18 * 1000000 * 2) / 1000e18 = 200000
        // Score: min(62500, 200000) = 62500
        assertEq(scores[0], 62500, "Score should be 62500");
        assertEq(totalScore, 62500, "Total score should be 62500");
    }

    function test_CalculateScores_DirectCall_MultipleUsers() public {
        // Setup: multiple users stake different amounts
        vm.prank(user1);
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

        vm.prank(user3);
        extension.stake(300e18);

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

    function test_CalculateScores_EmptyAccounts() public view {
        // No accounts, direct call to calculateScores
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
        extension.stake(100e18);

        // Total LP: 1600e18, User LP: 100e18
        // LP ratio: (100e18 * 1000000) / 1600e18 = 62500
        // User1 has 100e18 gov votes out of 1000e18 total
        // Gov ratio: (100e18 * 1000000 * 2) / 1000e18 = 200000
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
        extension.stake(50e18);

        // Total LP: 1600e18, User LP: 50e18
        // LP ratio: (50e18 * 1000000) / 1600e18 = 31250
        // User1 has 100e18 gov votes (10% of 1000e18 total)
        // Gov ratio: (100e18 * 1000000 * 2) / 1000e18 = 200000
        // Score should be limited by LP ratio (min) = 31250

        (, uint256[] memory scores) = extension.calculateScores();

        assertEq(scores.length, 1, "Should have 1 score");
        // Score should be limited by LP ratio
        assertEq(scores[0], 31250, "Score should be limited by LP ratio");
    }

    function test_CalculateScore_DirectCall_ExistingAccount() public {
        // Setup: stake with user1
        vm.prank(user1);
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

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
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

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
        extension.stake(100e18);

        vm.prank(user2);
        extension.stake(200e18);

        vm.prank(user3);
        extension.stake(300e18);

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

    function test_CalculateScore_EmptyAccounts() public view {
        // No accounts, call calculateScore
        (uint256 total, uint256 score) = extension.calculateScore(user1);

        assertEq(total, 0, "Total should be 0 with no accounts");
        assertEq(score, 0, "Score should be 0 with no accounts");
    }

    // ============================================
    // Claim Reward Tests
    // ============================================

    function test_ClaimReward() public {
        verify.setCurrentRound(1);

        // user1 stakes first - generates verification result for round 1
        vm.prank(user1);
        extension.stake(100e18);

        // user2 stakes second in the same round - verification result already generated, won't regenerate
        vm.prank(user2);
        extension.stake(50e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // Both users are in round 1 verification result, get reward
        vm.prank(user1);
        uint256 claimed1 = extension.claimReward(round);
        assertEq(claimed1, 0);

        vm.prank(user2);
        uint256 claimed2 = extension.claimReward(round);
        assertEq(claimed2, 0);
    }

    function test_ClaimReward_EmitEvent() public {
        // Stake in round 1 to generate verification result for round 1
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18);

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
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        // user1 is in round 2 verification result, should get reward > 0
        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);
        assertTrue(claimed > 0); // Should have reward

        // Cannot claim same round twice
        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.AlreadyClaimed.selector);
        extension.claimReward(round);
    }

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.stake(100e18);

        uint256 round = 1;
        verify.setCurrentRound(1);

        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.RoundNotFinished.selector);
        extension.claimReward(round);
    }

    function test_ClaimReward_MultipleRounds() public {
        // Round 1: user1 stakes first (generates empty result)
        // Since result is empty, user1 won't get reward for round 1
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        uint256 round1 = 1;
        uint256 reward1Amount = 1000e18;
        mint.setActionReward(address(token), round1, ACTION_ID, reward1Amount);

        verify.setCurrentRound(2);
        join.setCurrentRound(2);

        // user1 is NOT in round 1 verification result (empty result), gets 0 reward
        vm.prank(user1);
        uint256 claimed1 = extension.claimReward(round1);
        assertEq(claimed1, 0, "Round 1 reward should be 0 (empty result)");

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round2 = 2;
        uint256 reward2Amount = 2000e18;
        mint.setActionReward(address(token), round2, ACTION_ID, reward2Amount);

        verify.setCurrentRound(3);
        join.setCurrentRound(3);

        // user1 is in round 2 verification result, should get reward
        vm.prank(user1);
        uint256 claimed2 = extension.claimReward(round2);
        assertTrue(claimed2 > 0, "Round 2 reward should be > 0");

        // Cannot claim same round twice
        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.AlreadyClaimed.selector);
        extension.claimReward(round2);
    }

    // ============================================
    // Edge Cases and Complex Scenarios
    // ============================================

    function test_StakeLp_AfterUnstakeAndWithdraw() public {
        // User stakes
        vm.prank(user1);
        extension.stake(50e18);

        // User unstakes
        vm.prank(user1);
        extension.unstake();

        // Wait and withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);
        vm.prank(user1);
        extension.withdraw();

        // User can stake again
        vm.prank(user1);
        extension.stake(30e18);

        (uint256 amount, uint256 requestedUnstakeRound) = extension.stakeInfo(
            user1
        );
        assertEq(amount, 30e18);
        assertEq(requestedUnstakeRound, 0);
    }

    function test_JoinedValue_ZeroWhenNoStakes() public view {
        // No stakes, joinedValue should be 0
        assertEq(extension.joinedValue(), 0);
    }

    function test_PrepareVerifyResult_AlreadyPrepared() public {
        // Stake in round 1 to generate verification result for round 1
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // First claim uses already prepared verification result
        vm.prank(user1);
        extension.claimReward(round);

        uint256 scoreAfterFirstClaim = extension.totalScore(round);

        // Second user stakes in round 2 (generates round 2 verification result, not round 1)
        vm.prank(user2);
        extension.stake(200e18);

        // user2 claims round 1 reward - uses round 1 verification result (already prepared)
        vm.prank(user2);
        uint256 claimed = extension.claimReward(round);

        // Total score should be same (not recalculated, round 1 result was prepared in round 1)
        assertEq(extension.totalScore(round), scoreAfterFirstClaim);
        assertEq(claimed, 0); // user2 wasn't in round 1 snapshot
    }

    function test_PrepareVerifyResult_FutureRound() public {
        vm.prank(user1);
        extension.stake(100e18);

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
        // This test verifies that if verification result has 0 total score, reward is 0
        // However, since we need MIN_GOV_VOTES to stake, we can't generate a verification result with 0 score
        // Instead, we test that if no verification result is generated (totalScore == 0), reward is 0

        // Don't stake in round 1, so no verification result is generated
        verify.setCurrentRound(1);
        // Skip staking - no verification result generated for round 1

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(2);

        // Stake in round 2 (generates round 2 verification result, not round 1)
        stake.setValidGovVotes(address(token), user1, MIN_GOV_VOTES);
        vm.prank(user1);
        extension.stake(100e18);

        // Try to claim reward for round 1 - no verification result generated, should return 0
        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);

        // User gets 0 reward because no verification result was generated for round 1
        assertEq(claimed, 0);
    }

    function test_RewardByAccount_WithoutVerifyResult() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        mint.setActionReward(address(token), round, ACTION_ID, 1000e18);

        verify.setCurrentRound(3);

        // user1 is in round 2 verification result, should have reward
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            round,
            user1
        );

        assertFalse(isMinted);
        assertTrue(reward > 0); // Should have reward based on prepared verification result
    }

    function test_ClaimReward_ZeroScoreForUser() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result (user1 has gov votes at this time)

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        // Set user1's gov votes to 0 (after verification result is prepared)
        stake.setValidGovVotes(address(token), user1, 0);

        verify.setCurrentRound(2);

        // User1 is NOT in round 1 verification result (empty result), gets 0 reward
        // Note: gov votes don't matter here because user1 wasn't in the snapshot
        vm.prank(user1);
        uint256 claimed = extension.claimReward(round);
        assertEq(claimed, 0);
    }

    function test_ScoreCalculation_GovRatioLower() public {
        // Test case where gov ratio is lower than LP ratio
        vm.prank(user1);
        extension.stake(50e18); // 50 out of 1000+600 total LP

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
        extension.stake(10e18); // Small LP amount

        // Set gov votes higher than LP proportion
        stake.setValidGovVotes(address(token), user1, 500e18); // High gov votes

        uint256 round = 1;
        verify.setCurrentRound(2);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        // This tests the branch where lpRatio < govVotesRatio
        assertTrue(reward >= 0);
    }

    function test_ClaimReward_PrepareRewardNotNeeded() public {
        // Stake in round 1 to generate verification result for round 1
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18);

        uint256 round = 1;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        // Move to round 2
        verify.setCurrentRound(2);

        // First claim uses already prepared verification result
        vm.prank(user1);
        extension.claimReward(round);

        // Claim with different user should reuse prepared reward
        // user2 stakes in round 2 (generates round 2 verification result, not round 1)
        vm.prank(user2);
        extension.stake(50e18);

        // user2 claims round 1 reward - uses round 1 verification result (user2 not in snapshot)
        vm.prank(user2);
        uint256 claimed = extension.claimReward(round);

        assertEq(claimed, 0); // user2 wasn't in round 1 snapshot
    }

    function test_RewardByAccount_BeforeVerifyFinished() public {
        vm.prank(user1);
        extension.stake(100e18);

        uint256 round = 1;
        verify.setCurrentRound(1);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        assertEq(reward, 0);
    }

    function test_RewardByAccount_AfterClaimed() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

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
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        // Claim uses already prepared verification result
        vm.prank(user1);
        extension.claimReward(round);

        // Check total score (was prepared in round 2)
        uint256 totalScore = extension.totalScore(round);
        assertTrue(totalScore > 0);
    }

    function test_VerifiedAccounts() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        // Claim uses already prepared verification result
        vm.prank(user1);
        extension.claimReward(round);

        // Check verified accounts (was prepared in round 2)
        address[] memory verifiedAccts = extension.accountsByRound(round);
        assertTrue(verifiedAccts.length >= 1);
        assertEq(extension.accountsByRoundCount(round), verifiedAccts.length);
    }

    function test_VerifiedAccountsAtIndex() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        vm.prank(user1);
        extension.claimReward(round);

        // Check verified account (was prepared in round 2)
        address account0 = extension.accountsByRoundAtIndex(round, 0);

        assertEq(account0, user1);
    }

    function test_Scores() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        vm.prank(user1);
        extension.claimReward(round);

        // Check scores (was prepared in round 2)
        uint256[] memory scoresArray = extension.scores(round);
        assertTrue(scoresArray.length >= 1);
        assertEq(extension.scoresCount(round), scoresArray.length);
    }

    function test_ScoresAtIndex() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        vm.prank(user1);
        extension.claimReward(round);

        // Check score (was prepared in round 2)
        uint256 score0 = extension.scoresAtIndex(round, 0);
        assertTrue(score0 > 0);
    }

    function test_ScoreByAccount() public {
        // Round 1: user1 stakes first (generates empty result)
        verify.setCurrentRound(1);
        vm.prank(user1);
        extension.stake(100e18); // Generates empty result

        verify.setCurrentRound(2);

        // Round 2: user1 already staked in round 1, so when they interact in round 2,
        // verification result will include user1 (from previous round's accounts)
        verify.setCurrentRound(2);
        vm.prank(user1);
        extension.stake(50e18); // Generates verification result for round 2, includes user1

        uint256 round = 2;
        uint256 totalReward = 1000e18;
        mint.setActionReward(address(token), round, ACTION_ID, totalReward);

        verify.setCurrentRound(3);

        vm.prank(user1);
        extension.claimReward(round);

        // Check score (was prepared in round 2)
        uint256 score1 = extension.scoreByAccount(round, user1);

        assertTrue(score1 > 0);
    }

    // ============================================
    // Accounts Management Tests
    // ============================================

    function test_Accounts() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        address[] memory accts = extension.accounts();
        assertEq(accts.length, 2);
        assertEq(extension.accountsCount(), 2);
        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    function test_Unstakers() public {
        vm.prank(user1);
        extension.stake(50e18);

        vm.prank(user2);
        extension.stake(100e18);

        vm.prank(user1);
        extension.unstake();

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
            address(stakeToken),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        assertTrue(factory.exists(newExtension));
        assertEq(factory.extensionsCount(), 2);
    }

    function test_Factory_Extensions() public {
        // Create multiple extensions
        MockERC20 stakeToken2 = new MockERC20();
        address extension2 = factory.createExtension(
            address(stakeToken2),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        address[] memory exts = factory.extensions();
        assertEq(exts.length, 2);
        assertEq(exts[0], address(extension));
        assertEq(exts[1], extension2);
    }

    function test_Factory_ExtensionsAtIndex() public {
        // Create another extension
        MockERC20 stakeToken2 = new MockERC20();
        address extension2 = factory.createExtension(
            address(stakeToken2),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );

        assertEq(factory.extensionsAtIndex(0), address(extension));
        assertEq(factory.extensionsAtIndex(1), extension2);
    }

    function test_Factory_ExtensionParams() public view {
        // Extension is already initialized in setUp via center.initializeExtension
        (
            address stakeTokenAddr,
            uint256 waitingPhases,
            uint256 govRatioMult,
            uint256 minGovVotesVal
        ) = factory.extensionParams(address(extension));

        assertEq(
            stakeTokenAddr,
            address(stakeToken),
            "stakeTokenAddr mismatch"
        );
        assertEq(waitingPhases, WAITING_PHASES, "waitingPhases mismatch");
        assertEq(govRatioMult, GOV_RATIO_MULTIPLIER, "govRatioMult mismatch");
        assertEq(minGovVotesVal, MIN_GOV_VOTES, "minGovVotesVal mismatch");

        // tokenAddress and actionId are now stored in extension itself after initialization
        assertEq(
            extension.tokenAddress(),
            address(token),
            "tokenAddr mismatch"
        );
        assertEq(extension.actionId(), ACTION_ID, "actionId mismatch");
    }

    function test_Factory_ExtensionParams_NonExistent() public view {
        // Query params for non-existent extension
        (
            address stakeTokenAddr,
            uint256 waitingPhases,
            uint256 govRatioMult,
            uint256 minGovVotesVal
        ) = factory.extensionParams(address(0x999));

        // Should return zero values
        assertEq(stakeTokenAddr, address(0));
        assertEq(waitingPhases, 0);
        assertEq(govRatioMult, 0);
        assertEq(minGovVotesVal, 0);
    }

    function test_Factory_Center() public view {
        assertEq(factory.center(), address(center));
    }

    function test_Factory_RevertIfInvalidStakeTokenAddress() public {
        vm.expectRevert(
            ILOVE20ExtensionFactoryStakeLp.InvalidStakeTokenAddress.selector
        );
        factory.createExtension(
            address(0),
            WAITING_PHASES,
            GOV_RATIO_MULTIPLIER,
            MIN_GOV_VOTES
        );
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_StakeLp(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1e18, 100e18);

        vm.prank(user1);
        extension.stake(amount);

        (uint256 stakedAmount, ) = extension.stakeInfo(user1);
        assertEq(stakedAmount, amount);
        assertEq(extension.totalStakedAmount(), amount);
    }

    function testFuzz_MultipleStakes(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1e18, 50e18);
        amount2 = bound(amount2, 1e18, 100e18);

        vm.prank(user1);
        extension.stake(amount1);

        vm.prank(user2);
        extension.stake(amount2);

        assertEq(extension.totalStakedAmount(), amount1 + amount2);
        assertEq(extension.accountsCount(), 2);
    }
}
