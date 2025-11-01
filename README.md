# LOVE20 Extension - StakeLP

基于 LOVE20 扩展协议的 LP 质押扩展合约，自动生成验证结果，用于激励社群共建指定 LP 的流动性池。

## 功能特性

- LP 代币质押：质押以获得被验证并获得激励的资格
- 激励分配：对未申请解锁的地址，根据 `MIN(治理票占比 * 倍数, LP 占比)` 权重分配激励
- LP 代币解锁：申请解锁需等待完整的 n 个阶段后，可取回质押的 lp 代币，申请解锁后，将无法被验证并获得激励

## 验证触发点

下述 3 种情况，若遇到第 n 轮的验证结果未生成，则会立即先生成，再完成后续交互

- 第 n 轮验证阶段质押 LP 代币
- 第 n 轮验证阶段解除质押 LP 代币
- 铸造第 n 轮的激励，且当前最新的验证阶段所在轮次 > n

## 合约部署

### 快速部署

```bash
cd script/deploy
source one_click_deploy.sh <network>
source 10_addFactory.sh # 需有推举权的地址发起
```

可用网络：`anvil`、`thinkium70001_public`、`thinkium70001_public_test`

### 详细说明

查看 [部署脚本文档](script/deploy/README.md) 了解更多信息。

## 合约架构

- **LOVE20ExtensionFactoryStakeLp**: 工厂合约，用于创建和管理 StakeLp 扩展实例
- **LOVE20ExtensionStakeLp**: LP 质押扩展合约实现
