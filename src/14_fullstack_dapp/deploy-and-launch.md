# 部署测试与上线

本节涵盖从本地开发到 testnet 部署、再到主网上线的完整流程。包括环境配置、部署命令、测试验证和生产上线检查清单。

## 本地开发环境

### 启动本地网络

```bash
# 启动 localnet（带水龙头）
RUST_LOG="off,sui_node=info" sui start --with-faucet --force-regenesis

# 新终端中添加 localnet 环境
sui client new-env --alias localnet --rpc http://127.0.0.1:9000

# 切换到 localnet
sui client switch --env localnet

# 获取测试代币
sui client faucet
```

### 本地发布合约

```bash
cd move/hero

# 构建
sui move build

# 测试
sui move test

# 发布（localnet）
sui client publish --gas-budget 100000000
```

## Testnet 部署

### 配置 testnet 环境

```bash
# 添加 testnet 环境
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443

# 切换到 testnet
sui client switch --env testnet

# 查看当前地址
sui client active-address

# 获取 testnet SUI（水龙头）
sui client faucet
```

### 发布到 testnet

```bash
cd move/hero
sui client publish --gas-budget 100000000
```

从发布输出中记录关键信息：

| 信息 | 来源 |
|------|------|
| **Package ID** | `Published Objects` 部分 |
| **HeroRegistry ID** | `Created Objects` 中类型为 `HeroRegistry` 的对象 |
| **UpgradeCap ID** | `Created Objects` 中类型为 `UpgradeCap` 的对象 |

```bash
# 验证发布的对象
sui client objects
```

### 验证合约功能

```bash
# 铸造英雄
sui client call \
  --package <PACKAGE_ID> \
  --module hero \
  --function new_hero \
  --args "Warrior" 100 <REGISTRY_ID>

# 查看创建的对象
sui client object <HERO_ID>
```

## 前端部署

### 更新前端配置

```typescript
// src/config/constants.ts
export const CONFIG = {
  PACKAGE_ID: '0x<your_package_id>',
  REGISTRY_ID: '0x<your_registry_id>',
  NETWORK: 'testnet' as const,
};
```

### 构建前端

```bash
cd app
pnpm run build
```

### 部署选项

| 平台 | 特点 | 命令 |
|------|------|------|
| Vercel | 自动 CI/CD，适合 React 项目 | `vercel --prod` |
| Walrus Sites | 去中心化托管 | `walrus publish` |
| Cloudflare Pages | CDN 全球分发 | `wrangler pages deploy dist` |

### 部署到 Walrus Sites

```bash
# 安装 Walrus CLI
# 参考 https://docs.walrus.site/

# 发布到 Walrus Sites
walrus sites publish ./dist
```

## 主网部署

### 主网前准备检查清单

#### 合约安全

- [ ] 所有 `public` 函数签名已确认不再变动（升级后不能改）
- [ ] `assert!` 覆盖所有输入验证场景
- [ ] 错误码清晰、唯一、有文档
- [ ] 共享对象的并发访问已考虑
- [ ] 无硬编码的测试地址或密钥
- [ ] 已通过所有单元测试和集成测试
- [ ] 考虑了包升级策略（是否保留 UpgradeCap）

#### 权限管理

- [ ] AdminCap / UpgradeCap 已安全存储
- [ ] 考虑使用多签（Multisig）管理关键权限
- [ ] 明确了升级策略：compatible / additive / immutable

#### 前端

- [ ] Package ID 和对象 ID 已更新为主网地址
- [ ] 网络配置切换到 mainnet
- [ ] 错误处理和用户提示完善
- [ ] 钱包连接支持主流钱包

#### 运维

- [ ] 监控告警已配置
- [ ] 索引器/后端服务已部署
- [ ] 日志收集已配置
- [ ] 回滚方案已准备

### 主网发布流程

```bash
# 1. 切换到主网
sui client switch --env mainnet

# 2. 确认有足够 SUI 支付 gas
sui client gas

# 3. 最终构建和测试
sui move build
sui move test

# 4. 发布
sui client publish --gas-budget 200000000

# 5. 记录所有创建的对象 ID
sui client objects
```

### 发布后验证

```bash
# 验证包已发布
sui client object <PACKAGE_ID>

# 测试核心功能
sui client call \
  --package <PACKAGE_ID> \
  --module hero \
  --function new_hero \
  --args "Genesis Hero" 100 <REGISTRY_ID>
```

## 升级管理

### 保留 UpgradeCap

UpgradeCap 是升级合约的唯一凭证，务必安全保管：

```bash
# 查看 UpgradeCap
sui client object <UPGRADE_CAP_ID>
```

### 升级策略选择

| 策略 | 适用场景 |
|------|---------|
| `compatible`（默认） | 迭代开发阶段 |
| `additive` | 稳定期，只允许添加新功能 |
| `dep_only` | 只允许更新依赖 |
| `immutable` | 永久冻结，不可升级 |

```bash
# 执行升级
sui client upgrade --upgrade-capability <UPGRADE_CAP_ID>

# 如果决定冻结包（不可逆！）
# sui client call --package 0x2 --module package --function make_immutable \
#   --args <UPGRADE_CAP_ID>
```

## 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 交易失败 `InsufficientGas` | gas 预算不足 | 增加 `--gas-budget` |
| 对象未找到 | ID 错误或网络不匹配 | 确认网络和对象 ID |
| 钱包连接失败 | 网络配置不一致 | 检查前端和钱包的网络设置 |
| RPC 超时 | 全节点压力大 | 使用多个 RPC 端点做负载均衡 |
| 交易签名失败 | 钱包版本不兼容 | 更新钱包和 SDK 版本 |

## 小结

部署和上线的核心要点：

- 先在 localnet 充分测试，再部署到 testnet，最后上主网
- 发布合约后仔细记录所有关键对象 ID
- 主网部署前完成安全检查清单
- 妥善保管 UpgradeCap，选择合适的升级策略
- 部署前端时确保配置文件指向正确的网络和合约地址
- 建立监控和告警机制，及时发现和处理线上问题
