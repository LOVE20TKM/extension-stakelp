// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {LOVE20ExtensionStakeLp} from "../src/LOVE20ExtensionStakeLp.sol";
import {LOVE20ExtensionFactoryStakeLp} from "../src/LOVE20ExtensionFactoryStakeLp.sol";
import {ILOVE20ExtensionStakeLp} from "../src/interface/ILOVE20ExtensionStakeLp.sol";
import {ILOVE20ExtensionFactoryStakeLp} from "../src/interface/ILOVE20ExtensionFactoryStakeLp.sol";
import {ILOVE20ExtensionFactory} from "@extension/src/interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";

/**
 * @title Mock contracts for testing
 */
contract MockERC20 {
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }
}

contract MockUniswapV2Pair is MockERC20 {
    address internal _token0;
    address internal _token1;
    uint112 internal _reserve0;
    uint112 internal _reserve1;
    uint32 internal _blockTimestampLast;

    constructor(address token0_, address token1_) {
        _token0 = token0_;
        _token1 = token1_;
    }

    function token0() external view returns (address) {
        return _token0;
    }

    function token1() external view returns (address) {
        return _token1;
    }

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        _reserve0 = reserve0_;
        _reserve1 = reserve1_;
        _blockTimestampLast = uint32(block.timestamp);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) internal _pairs;

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        pair = address(new MockUniswapV2Pair(tokenA, tokenB));
        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }
}

contract MockStake {
    mapping(address => uint256) internal _govVotesNum;
    mapping(address => mapping(address => uint256)) internal _validGovVotes;

    function setGovVotesNum(address tokenAddress, uint256 amount) external {
        _govVotesNum[tokenAddress] = amount;
    }

    function setValidGovVotes(
        address tokenAddress,
        address account,
        uint256 amount
    ) external {
        _validGovVotes[tokenAddress][account] = amount;
    }

    function govVotesNum(address tokenAddress) external view returns (uint256) {
        return _govVotesNum[tokenAddress];
    }

    function validGovVotes(
        address tokenAddress,
        address account
    ) external view returns (uint256) {
        return _validGovVotes[tokenAddress][account];
    }
}

contract MockJoin {
    uint256 internal _currentRound = 1;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        internal _amounts;

    function join(
        address,
        uint256,
        uint256,
        string[] memory
    ) external pure returns (bool) {
        return true;
    }

    function setCurrentRound(uint256 round) external {
        _currentRound = round;
    }

    function currentRound() external view returns (uint256) {
        return _currentRound;
    }

    function amountByActionIdByAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (uint256) {
        return _amounts[tokenAddress][actionId][account];
    }
}

contract MockVerify {
    uint256 internal _currentRound = 1;

    function setCurrentRound(uint256 round) external {
        _currentRound = round;
    }

    function currentRound() external view returns (uint256) {
        return _currentRound;
    }
}

contract MockMint {
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        internal _actionReward;

    function setActionReward(
        address tokenAddress,
        uint256 round,
        uint256 actionId,
        uint256 reward
    ) external {
        _actionReward[tokenAddress][round][actionId] = reward;
    }

    function actionRewardByActionIdByAccount(
        address tokenAddress,
        uint256 round,
        uint256 actionId,
        address
    ) external view returns (uint256, bool) {
        return (_actionReward[tokenAddress][round][actionId], true);
    }

    function mintActionReward(
        address tokenAddress,
        uint256 round,
        uint256 actionId
    ) external view returns (uint256) {
        return _actionReward[tokenAddress][round][actionId];
    }
}

contract MockExtensionCenter is ILOVE20ExtensionCenter {
    address internal _stakeAddress;
    address internal _joinAddress;
    address internal _verifyAddress;
    address internal _mintAddress;
    address internal _uniswapV2FactoryAddress;
    mapping(address => mapping(uint256 => address[])) internal _accounts;

    function setStakeAddress(address addr) external {
        _stakeAddress = addr;
    }

    function setJoinAddress(address addr) external {
        _joinAddress = addr;
    }

    function setVerifyAddress(address addr) external {
        _verifyAddress = addr;
    }

    function setMintAddress(address addr) external {
        _mintAddress = addr;
    }

    function setUniswapV2FactoryAddress(address addr) external {
        _uniswapV2FactoryAddress = addr;
    }

    function stakeAddress() external view returns (address) {
        return _stakeAddress;
    }

    function joinAddress() external view returns (address) {
        return _joinAddress;
    }

    function verifyAddress() external view returns (address) {
        return _verifyAddress;
    }

    function mintAddress() external view returns (address) {
        return _mintAddress;
    }

    function uniswapV2FactoryAddress() external view returns (address) {
        return _uniswapV2FactoryAddress;
    }

    function addAccount(
        address _tokenAddress,
        uint256 _actionId,
        address _account
    ) external {
        _accounts[_tokenAddress][_actionId].push(_account);
    }

    function removeAccount(
        address _tokenAddress,
        uint256 _actionId,
        address _account
    ) external {
        address[] storage accts = _accounts[_tokenAddress][_actionId];
        for (uint256 i = 0; i < accts.length; i++) {
            if (accts[i] == _account) {
                accts[i] = accts[accts.length - 1];
                accts.pop();
                break;
            }
        }
    }

    function accounts(
        address _tokenAddress,
        uint256 _actionId
    ) external view returns (address[] memory) {
        return _accounts[_tokenAddress][_actionId];
    }

    // Unimplemented functions from interface
    function factories(address) external pure returns (address[] memory) {
        return new address[](0);
    }

    function factoriesCount(address) external pure returns (uint256) {
        return 0;
    }

    function factoriesAtIndex(
        address,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function addFactory(address, address) external {}

    function existsFactory(address, address) external pure returns (bool) {
        return false;
    }

    function initializeExtension(address) external {}

    function extension(address, uint256) external pure returns (address) {
        return address(0);
    }

    function extensionInfo(
        address
    ) external pure returns (address tokenAddr, uint256 actionIdNum) {
        return (address(0), 0);
    }

    function extensions(address) external pure returns (address[] memory) {
        return new address[](0);
    }

    function extensionsCount(address) external pure returns (uint256) {
        return 0;
    }

    function extensionsAtIndex(
        address,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function accountsCount(address, uint256) external pure returns (uint256) {
        return 0;
    }

    function accountsAtIndex(
        address,
        uint256,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function isAccountJoined(
        address,
        uint256,
        address
    ) external pure returns (bool) {
        return false;
    }

    function actionIdsByAccount(
        address,
        address
    ) external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function actionIdsByAccountCount(
        address,
        address
    ) external pure returns (uint256) {
        return 0;
    }

    function actionIdsByAccountAtIndex(
        address,
        address,
        uint256
    ) external pure returns (uint256) {
        return 0;
    }

    function tokenAddress() external pure returns (address) {
        return address(0);
    }

    function submitAddress() external pure returns (address) {
        return address(0);
    }

    function launchAddress() external pure returns (address) {
        return address(0);
    }

    function voteAddress() external pure returns (address) {
        return address(0);
    }

    function randomAddress() external pure returns (address) {
        return address(0);
    }
}

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
                GOV_RATIO_MULTIPLIER
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
            GOV_RATIO_MULTIPLIER
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

    function test_RewardByAccount_BeforeVerifyFinished() public {
        vm.prank(user1);
        extension.stakeLp(100e18);

        uint256 round = 1;
        verify.setCurrentRound(1);

        (uint256 reward, ) = extension.rewardByAccount(round, user1);
        assertEq(reward, 0);
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
            GOV_RATIO_MULTIPLIER
        );

        assertTrue(factory.exists(newExtension));
        assertEq(factory.extensionsCount(address(token)), 2);
    }

    function test_Factory_ExtensionParams() public view {
        (
            address tokenAddr,
            uint256 actionId,
            address anotherTokenAddr,
            uint256 waitingPhases,
            uint256 govRatioMult
        ) = factory.extensionParams(address(extension));

        assertEq(tokenAddr, address(token));
        assertEq(actionId, ACTION_ID);
        assertEq(anotherTokenAddr, address(anotherToken));
        assertEq(waitingPhases, WAITING_PHASES);
        assertEq(govRatioMult, GOV_RATIO_MULTIPLIER);
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
            GOV_RATIO_MULTIPLIER
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
            GOV_RATIO_MULTIPLIER
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
            GOV_RATIO_MULTIPLIER
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
            GOV_RATIO_MULTIPLIER
        );
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
