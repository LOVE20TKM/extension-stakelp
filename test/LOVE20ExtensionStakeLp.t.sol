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
    ILOVE20ExtensionAutoScoreStake
} from "@extension/src/interface/ILOVE20ExtensionAutoScoreStake.sol";
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
 * @notice Tests for LP-specific functionality
 * @dev Basic stake/unstake/withdraw tests are covered in lib/extension/test/LOVE20ExtensionSimpleStake.t.sol
 *      This test suite focuses on LP-specific features:
 *      - LP token validation
 *      - LP to token conversion (joinedValue)
 *      - govRatioMultiplier in score calculation
 *      - Factory with LP-specific parameters
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
    // Initialization Tests (LP-specific validation)
    // ============================================

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
    // View Function Tests (LP-specific)
    // ============================================

    function test_ImmutableVariables_GovRatioMultiplier() public view {
        // Test LP-specific parameter
        assertEq(extension.govRatioMultiplier(), GOV_RATIO_MULTIPLIER);
        // Basic immutable variables are tested in base contract
        assertEq(extension.stakeTokenAddress(), address(stakeToken));
        assertEq(extension.waitingPhases(), WAITING_PHASES);
    }

    function test_IsJoinedValueCalculated() public view {
        // LP extension should calculate joined value
        assertTrue(extension.isJoinedValueCalculated());
    }

    // ============================================
    // LP to Token Conversion Tests (joinedValue)
    // ============================================
    // Note: Basic stake/unstake/withdraw functionality is tested in base contract

    function test_JoinedValue() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

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
        extension.stake(50e18, new string[](0));

        vm.prank(user2);
        extension.stake(100e18, new string[](0));

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
    // Score Calculation Tests (LP-specific with govRatioMultiplier)
    // ============================================
    // Note: Basic score calculation is tested in base contract
    // This section tests LP-specific scoring logic with govRatioMultiplier

    function test_CalculateScores_DirectCall_SingleUser() public {
        // Setup: user1 stakes 100e18 LP
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

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
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user3);
        extension.stake(300e18, new string[](0));

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

    function test_CalculateScores_LpRatioIsLimiting() public {
        // Test where user has less LP ratio than gov ratio
        vm.prank(user1);
        extension.stake(50e18, new string[](0));

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
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

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
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

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
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user3);
        extension.stake(300e18, new string[](0));

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
    // Integration Test - Verify Score Calculation with Rewards
    // ============================================
    // Note: Basic claim reward tests are in base contract
    // This test verifies that LP-specific scoring integrates correctly with rewards

    function test_JoinedValue_ZeroWhenNoStakes() public view {
        // LP-specific: verify joinedValue is 0 when no stakes
        assertEq(extension.joinedValue(), 0);
    }

    function test_ScoreCalculation_WithGovRatioMultiplier() public {
        // Test LP-specific scoring with govRatioMultiplier
        vm.prank(user1);
        extension.stake(50e18, new string[](0));

        // Set gov votes
        stake.setValidGovVotes(address(token), user1, 10e18);

        (uint256 total, uint256 score) = extension.calculateScore(user1);

        // Verify score is calculated with govRatioMultiplier
        assertTrue(score > 0);
        assertTrue(total > 0);
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
}
