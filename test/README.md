# LOVE20ExtensionStakeLp 测试文档

## 概述

本测试套件为 `LOVE20ExtensionStakeLp` 合约提供了全面的单元测试覆盖，包括正常功能测试、边界条件测试和错误处理测试。

## 测试统计

- **总测试数**: 43
- **通过率**: 100%
- **包含模糊测试**: 2 个
- **测试合约**: LOVE20ExtensionStakeLpTest

## 测试分类

### 1. 初始化测试 (3 个)

- ✅ `test_Initialize` - 验证合约初始化
- ✅ `test_Initialize_RevertIfAlreadyInitialized` - 验证重复初始化会回滚
- ✅ `test_Initialize_RevertIfNotCenter` - 验证只有 center 可以初始化

### 2. 视图函数测试 (4 个)

- ✅ `test_ImmutableVariables` - 验证不可变变量正确设置
- ✅ `test_IsJoinedValueCalculated` - 验证 joinedValue 计算标志
- ✅ `test_Center` - 验证 center 地址返回
- ✅ `test_JoinedValue_ZeroWhenNoLP` - 验证无 LP 时的边界情况

### 3. LP 质押测试 (7 个)

- ✅ `test_StakeLp` - 基本质押功能
- ✅ `test_StakeLp_Multiple` - 多用户质押
- ✅ `test_StakeLp_MultipleTimesSameUser` - 同一用户多次质押
- ✅ `test_StakeLp_EmitEvent` - 验证事件发出
- ✅ `test_StakeLp_RevertIfAmountZero` - 零金额质押回滚
- ✅ `test_StakeLp_RevertIfUnstakeRequested` - 已请求解押时质押回滚
- ✅ `test_StakeLp_AfterUnstakeAndWithdraw` - 提取后可重新质押

### 4. LP 解押测试 (5 个)

- ✅ `test_UnstakeLp` - 基本解押功能
- ✅ `test_UnstakeLp_EmitEvent` - 验证事件发出
- ✅ `test_UnstakeLp_RevertIfNoStakedAmount` - 无质押时解押回滚
- ✅ `test_UnstakeLp_RevertIfAlreadyRequested` - 重复请求解押回滚
- ✅ `test_Unstakers` - 验证 unstakers 列表管理

### 5. LP 提取测试 (4 个)

- ✅ `test_WithdrawLp` - 基本提取功能
- ✅ `test_WithdrawLp_EmitEvent` - 验证事件发出
- ✅ `test_WithdrawLp_RevertIfUnstakeNotRequested` - 未请求解押时提取回滚
- ✅ `test_WithdrawLp_RevertIfNotEnoughWaitingPhases` - 等待期不足时提取回滚

### 6. Joined Value 计算测试 (2 个)

- ✅ `test_JoinedValue` - 验证总 joined value 计算
- ✅ `test_JoinedValueByAccount` - 验证每个账户的 joined value 计算

### 7. 奖励相关测试 (5 个)

- ✅ `test_ClaimReward` - 基本奖励领取
- ✅ `test_ClaimReward_EmitEvent` - 验证事件发出
- ✅ `test_ClaimReward_MultipleRounds` - 多轮奖励领取
- ✅ `test_ClaimReward_RevertIfAlreadyClaimed` - 重复领取回滚
- ✅ `test_ClaimReward_RevertIfRoundNotFinished` - 轮次未结束时领取回滚

### 8. 分数计算测试 (3 个)

- ✅ `test_ScoreCalculation_SingleUser` - 单用户分数计算
- ✅ `test_ScoreCalculation_MultipleUsers` - 多用户分数计算
- ✅ `test_RewardByAccount_BeforeVerifyFinished` - 验证轮次结束前的奖励查询

### 9. 账户管理测试 (2 个)

- ✅ `test_Accounts` - 验证账户列表管理
- ✅ `test_Stakers` - 验证 stakers 列表管理

### 10. 工厂合约测试 (6 个)

- ✅ `test_Factory_CreateExtension` - 创建扩展
- ✅ `test_Factory_ExtensionParams` - 验证扩展参数
- ✅ `test_Factory_RevertIfInvalidTokenAddress` - 无效 token 地址回滚
- ✅ `test_Factory_RevertIfInvalidAnotherTokenAddress` - 无效配对 token 地址回滚
- ✅ `test_Factory_RevertIfSameTokenAddresses` - 相同 token 地址回滚
- ✅ `test_Constructor_RevertIfPairNotCreated` - Uniswap 配对未创建时回滚

### 11. 模糊测试 (2 个)

- ✅ `testFuzz_StakeLp(uint256)` - 随机金额质押测试 (256 次运行)
- ✅ `testFuzz_MultipleStakes(uint256,uint256)` - 多用户随机金额质押测试 (256 次运行)

## Mock 合约

测试套件包含以下 Mock 合约以模拟外部依赖：

1. **MockERC20** - 模拟 ERC20 代币
2. **MockUniswapV2Pair** - 模拟 Uniswap V2 LP 代币
3. **MockUniswapV2Factory** - 模拟 Uniswap V2 工厂
4. **MockStake** - 模拟质押合约
5. **MockJoin** - 模拟加入合约
6. **MockVerify** - 模拟验证合约
7. **MockMint** - 模拟铸造合约
8. **MockExtensionCenter** - 模拟扩展中心合约

## 运行测试

```bash
# 运行所有测试
forge test

# 运行测试并显示详细输出
forge test -vv

# 运行特定测试
forge test --match-test test_StakeLp

# 运行测试并生成 gas 报告
forge test --gas-report

# 运行测试并显示覆盖率
forge coverage
```

## 测试覆盖的关键功能

### 核心功能

- ✅ LP 代币质押
- ✅ LP 代币解押（带等待期）
- ✅ LP 代币提取
- ✅ 奖励计算与分配
- ✅ 分数计算（基于 LP 比例和治理投票）

### 安全性

- ✅ 权限控制（仅 center 可初始化）
- ✅ 重入保护（状态先更新）
- ✅ 金额验证
- ✅ 轮次验证
- ✅ 解押等待期验证

### 边界条件

- ✅ 零金额处理
- ✅ 重复操作防护
- ✅ 空列表处理
- ✅ 除零保护（totalSupply == 0）

## 注意事项

1. 所有测试都使用 Foundry 测试框架
2. 使用 Solidity 0.8.17 编译
3. 测试中使用了 vm.prank 来模拟不同用户的调用
4. 模糊测试使用了合理的金额边界（1e18 到 100e18）

## Gas 优化

测试显示的平均 gas 消耗：

- **stakeLp**: ~283,191 gas
- **unstakeLp**: ~204,000 gas
- **withdrawLp**: ~55,274 gas
- **claimReward**: ~174,657 gas

## 未来改进建议

1. 添加集成测试，测试与实际 LOVE20 系统的交互
2. 添加压力测试，测试大量用户同时操作的情况
3. 添加更多边界条件测试
4. 考虑添加快照测试来验证状态变化
