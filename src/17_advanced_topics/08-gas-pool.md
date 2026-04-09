# Sui Gas Pool — 赞助交易服务

Sui Gas Pool 是 Mysten Labs 开源的<b>赞助交易（Sponsored Transaction）</b>基础设施服务。它管理一个由赞助者地址持有的 Gas Coin 池，通过 API 为用户交易提供 Gas 代付，让用户无需持有 SUI 即可与 DApp 交互。

## 为什么需要 Gas Pool

传统区块链上，用户必须先持有原生代币才能发起交易，这形成了巨大的入门门槛。Gas Pool 让 DApp 开发者可以为用户代付 Gas 费用：

```
┌──────────┐     ①构建交易(无Gas)    ┌──────────────┐
│   用户    │ ──────────────────────→ │  应用服务器   │
│  (无SUI)  │                        │              │
└──────────┘                        └──────┬───────┘
     ↑                                     │
     │  ④签名后发回                    ②预留Gas Coin
     │                                     ↓
     │                              ┌──────────────┐
     │                              │  Gas Pool    │
     │                              │  (赞助者)     │
     └──────────────────────────────┤              │
        ⑤完整交易→链上执行            └──────────────┘
                                         ③返回Gas信息
```

| 场景 | 说明 |
|------|------|
| **新用户引导** | 用户无需购买 SUI 即可体验 DApp |
| **游戏** | 玩家操作由游戏方代付 Gas |
| **企业应用** | 企业为员工/客户承担链上费用 |
| **空投活动** | 领取方无需持币即可 claim |

## 架构概览

Gas Pool 由三个核心组件构成：

```
                    ┌─────────────────────────────────────┐
                    │         Gas Pool 集群               │
                    │                                     │
┌──────────┐       │  ┌──────────┐    ┌──────────────┐  │     ┌──────────┐
│  应用    │ HTTP  │  │ Gas Pool │    │    Redis     │  │     │ Sui      │
│  服务器  │──────→│  │ Server   │←──→│  (状态存储)   │  │────→│ Fullnode │
│          │       │  │ (可多实例) │    └──────────────┘  │     └──────────┘
└──────────┘       │  └────┬─────┘                      │
                    │       │                             │
                    │  ┌────┴─────┐                      │
                    │  │ KMS      │                      │
                    │  │ Sidecar  │                      │
                    │  │ (签名服务) │                      │
                    │  └──────────┘                      │
                    └─────────────────────────────────────┘
```

| 组件 | 作用 | 扩展性 |
|------|------|--------|
| **Gas Pool Server** | 核心服务，处理 Gas 预留和交易执行 | 可水平扩展（多实例共享 Redis） |
| **Redis** | 存储 Gas Coin 状态、预留队列、过期管理 | 每个 Gas Pool 一个实例 |
| **KMS Sidecar**（可选） | 外部密钥管理签名（如 AWS KMS） | 每个 Gas Pool 一个实例 |

## 安装

### 前置要求

- **Rust 1.90+**
- **Redis**（本地开发或生产部署）
- **Sui Fullnode** RPC 端点

### 从源码构建

```bash
git clone https://github.com/MystenLabs/sui-gas-pool.git
cd sui-gas-pool

cargo build --release
```

构建产物：
- `target/release/sui-gas-station` — 主服务
- `target/release/tool` — CLI 工具

### Docker 构建

```bash
cd docker
./build.sh
```

## 配置

### 生成示例配置

```bash
# 使用本地密钥签名
cargo run --bin tool generate-sample-config --config-path config.yaml

# 使用 KMS Sidecar 签名
cargo run --bin tool generate-sample-config --config-path config.yaml --with-sidecar-signer
```

### 配置文件详解

```yaml
# 签名配置
signer-config:
  # 方式一：本地密钥（开发用）
  local:
    keypair: "suiprivkey1..."

  # 方式二：KMS Sidecar（生产用）
  # sidecar:
  #   sidecar_url: "http://localhost:3000/aws-kms"

# API 服务配置
rpc-host-ip: 0.0.0.0
rpc-port: 9527

# Prometheus 指标端口
metrics-port: 9184

# Redis 存储配置
gas-pool-config:
  redis:
    redis_url: "redis://127.0.0.1:6379"
    connection-timeout-ms: 5000
    response-timeout-ms: 5000
    number-of-retries: 3

# Sui 全节点 RPC
fullnode-url: "https://fullnode.testnet.sui.io:443"

# Gas Coin 初始化配置
coin-init-config:
  # 每个 Gas Coin 的目标余额（MIST），0.1 SUI = 100000000
  target-init-balance: 100000000
  # 定期检查新资金的间隔（秒）
  refresh-interval-sec: 86400

# 每日 Gas 使用上限（MIST），1.5 SUI = 1500000000000
daily-gas-usage-cap: 1500000000000

# 单次请求最大 SUI 数量（默认 2 SUI）
# max-sui-per-request: 2000000000

# 高级水龙头模式（发送方=赞助方，Gas Coin 可用于转账）
# advanced-faucet-mode: false
```

### 关键配置项说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `signer-config` | 签名方式：`local`（本地密钥）或 `sidecar`（KMS） | 必填 |
| `rpc-port` | API 服务端口 | 9527 |
| `metrics-port` | Prometheus 指标端口 | 9184 |
| `redis_url` | Redis 连接地址 | 必填 |
| `fullnode-url` | Sui Fullnode RPC 地址 | 必填 |
| `target-init-balance` | 每个 Gas Coin 目标余额（MIST） | 必填 |
| `refresh-interval-sec` | 资金刷新检查间隔 | 86400 |
| `daily-gas-usage-cap` | 每日 Gas 使用上限（MIST） | 必填 |
| `max-sui-per-request` | 单次预留最大 SUI | 2 SUI |
| `advanced-faucet-mode` | 水龙头模式 | false |

## 部署流程

### 1. 创建赞助者地址

```bash
sui client new-address ed25519
```

记录生成的地址和密钥。这个地址将专门用作 Gas 赞助，**不要用于其他用途**。

### 2. 为赞助者充值

向赞助者地址转入足够的 SUI：

```bash
# testnet 可使用水龙头
sui client faucet --address <sponsor_address>

# mainnet 需要手动转账
sui client transfer-sui --to <sponsor_address> --amount 1000000000 --sui-coin-object-id <coin_id>
```

### 3. 部署 Redis

```bash
# Docker 方式
docker run -d --name gas-pool-redis -p 6379:6379 redis:7

# 或使用系统包管理器
brew install redis && brew services start redis  # macOS
```

### 4. 编写配置文件

参考上方的配置模板，创建 `config.yaml`。

### 5. 设置认证 Token

```bash
export GAS_STATION_AUTH="your-secret-bearer-token"
```

### 6. 启动服务

```bash
./target/release/sui-gas-station --config-path config.yaml
```

首次启动时，Gas Pool 会自动将赞助者地址持有的大额 SUI Coin 拆分成多个小额 Coin（每个目标余额由 `target-init-balance` 决定），以支持并行赞助。

## API 使用

所有 API 请求需在 Header 中携带认证 Token：

```
Authorization: Bearer <GAS_STATION_AUTH>
```

### 健康检查

```bash
# 基本健康检查（无需认证）
curl http://localhost:9527/

# 版本信息（无需认证）
curl http://localhost:9527/version

# 完整健康检查（需要认证）
curl -X POST http://localhost:9527/debug_health_check \
  -H "Authorization: Bearer $GAS_STATION_AUTH"
```

### 预留 Gas Coin

```bash
curl -X POST http://localhost:9527/v1/reserve_gas \
  -H "Authorization: Bearer $GAS_STATION_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "gas_budget": 100000000,
    "reserve_duration_secs": 60
  }'
```

**请求参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `gas_budget` | u64 | Gas 预算（MIST） |
| `reserve_duration_secs` | u64 | 预留时长（最长 600 秒） |

**响应：**

```json
{
  "result": {
    "sponsor_address": "0xabc...",
    "reservation_id": 42,
    "gas_coins": [
      {
        "objectId": "0x123...",
        "version": "5",
        "digest": "abc123..."
      }
    ]
  },
  "error": null
}
```

### 执行交易

```bash
curl -X POST http://localhost:9527/v1/execute_tx \
  -H "Authorization: Bearer $GAS_STATION_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "reservation_id": 42,
    "tx_bytes": "<base64 编码的 TransactionData>",
    "user_sig": "<base64 编码的用户签名>",
    "options": {
      "showEffects": true,
      "showBalanceChanges": true
    }
  }'
```

**请求参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `reservation_id` | u64 | 预留时返回的 ID |
| `tx_bytes` | String | Base64 编码的 BCS 序列化交易数据 |
| `user_sig` | String | Base64 编码的用户签名 |
| `options` | Object | 可选，控制返回内容 |

**响应选项：**

| 选项 | 说明 |
|------|------|
| `showEffects` | 返回交易效果 |
| `showBalanceChanges` | 返回余额变化 |
| `showObjectChanges` | 返回对象变化 |
| `showEvents` | 返回事件 |
| `showInput` | 返回交易输入 |
| `showRawEffects` | 返回原始效果 |
| `showRawInput` | 返回原始输入 |

## TypeScript 集成示例

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { toBase64 } from "@mysten/sui/utils";

const GAS_POOL_URL = "http://localhost:9527";
const GAS_POOL_AUTH = "your-secret-bearer-token";
const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

async function sponsoredTransaction(userKeypair: Ed25519Keypair) {
  const userAddress = userKeypair.toSuiAddress();

  // 1. 构建交易（不设置 Gas）
  const tx = new Transaction();
  tx.setSender(userAddress);
  tx.moveCall({
    target: "0xPACKAGE::module::function",
    arguments: [],
  });
  const txBytes = await tx.build({ client });

  // 2. 向 Gas Pool 预留 Gas
  const reserveRes = await fetch(`${GAS_POOL_URL}/v1/reserve_gas`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${GAS_POOL_AUTH}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      gas_budget: 50000000,
      reserve_duration_secs: 60,
    }),
  });
  const reserveData = await reserveRes.json();
  const { reservation_id, sponsor_address, gas_coins } = reserveData.result;

  // 3. 用预留的 Gas Coin 重新构建交易
  const sponsoredTx = new Transaction();
  sponsoredTx.setSender(userAddress);
  sponsoredTx.setGasOwner(sponsor_address);
  sponsoredTx.setGasPayment(gas_coins);
  sponsoredTx.setGasBudget(50000000);
  sponsoredTx.moveCall({
    target: "0xPACKAGE::module::function",
    arguments: [],
  });
  const sponsoredTxBytes = await sponsoredTx.build({ client });

  // 4. 用户签名
  const userSig = await userKeypair.signTransaction(sponsoredTxBytes);

  // 5. 发送到 Gas Pool 执行
  const executeRes = await fetch(`${GAS_POOL_URL}/v1/execute_tx`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${GAS_POOL_AUTH}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      reservation_id,
      tx_bytes: toBase64(sponsoredTxBytes),
      user_sig: userSig.signature,
      options: { showEffects: true },
    }),
  });
  const result = await executeRes.json();
  console.log("交易结果:", result);
}
```

## KMS Sidecar 配置（生产环境）

生产环境建议使用 AWS KMS 等外部密钥管理服务，避免在服务器上存储明文私钥。

项目提供了一个 TypeScript 示例 Sidecar：

```bash
cd sample_kms_sidecar
npm install
```

设置 AWS 环境变量：

```bash
export AWS_KMS_KEY_ID="arn:aws:kms:us-east-1:123456789:key/abc-def"
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
```

启动 Sidecar：

```bash
npx ts-node index.ts
```

Sidecar 提供两个端点：

| 端点 | 说明 |
|------|------|
| `GET /aws-kms/get-pubkey-address` | 获取 KMS 密钥对应的 Sui 地址 |
| `POST /aws-kms/sign-transaction` | 使用 KMS 签署交易 |

在 Gas Pool 配置中引用：

```yaml
signer-config:
  sidecar:
    sidecar_url: "http://localhost:3000/aws-kms"
```

## 运维与监控

### Prometheus 指标

Gas Pool 在 `metrics-port`（默认 9184）暴露 Prometheus 指标：

**请求指标：**

| 指标 | 说明 |
|------|------|
| `num_reserve_gas_requests` | 预留请求总数 |
| `num_successful_reserve_gas_requests` | 成功的预留请求数 |
| `num_execute_tx_requests` | 执行请求总数 |
| `num_successful_execute_tx_requests` | 成功的执行请求数 |

**池状态指标：**

| 指标 | 说明 |
|------|------|
| `gas_pool_available_gas_coin_count` | 可用 Gas Coin 数量 |
| `gas_pool_available_gas_total_balance` | 可用 Gas 总余额 |
| `daily_gas_usage` | 当日 Gas 使用量 |
| `num_expired_gas_coins` | 过期归还的 Coin 数量 |

**性能指标：**

| 指标 | 说明 |
|------|------|
| `reserve_gas_latency` | 预留请求延迟 |
| `transaction_signing_latency` | 交易签名延迟 |
| `transaction_execution_latency` | 交易执行延迟 |

### CLI 健康检查

```bash
# 基本健康检查
cargo run --bin tool cli check-station-health \
  --gas-station-url http://localhost:9527

# 完整端到端检查
cargo run --bin tool cli check-station-end-to-end-health \
  --gas-station-url http://localhost:9527 \
  --auth-token "$GAS_STATION_AUTH"
```

### 压力测试

```bash
cargo run --release --bin tool benchmark \
  --gas-station-url http://localhost:9527 \
  --auth-token "$GAS_STATION_AUTH" \
  --reserve-duration-sec 20 \
  --num-clients 100 \
  --benchmark-mode reserve-only
```

## 限制与约束

| 约束 | 值 |
|------|-----|
| 单次预留最大 Gas Coin 数 | 256 个 |
| 单交易最大输入对象数 | 50 个 |
| 最长预留时间 | 600 秒（10 分钟） |
| 单次请求最大 SUI | 2 SUI（可配置） |
| 每日 Gas 上限 | 配置决定，午夜重置 |

## 安全注意事项

1. **专用地址**：赞助者地址应专门用于 Gas Pool，不要用于其他交易
2. **Token 保密**：`GAS_STATION_AUTH` 只应在内部服务器使用，不要暴露给前端
3. **KMS 签名**：生产环境强烈建议使用 KMS Sidecar，避免明文私钥
4. **每日上限**：合理设置 `daily-gas-usage-cap` 防止资金耗尽
5. **水龙头模式**：`advanced-faucet-mode` 有更高的资金风险，谨慎使用

## 小结

Sui Gas Pool 是实现赞助交易的完整基础设施方案：

- **降低门槛**：用户无需持有 SUI 即可使用 DApp
- **高并发**：通过 Coin 拆分和 Redis 状态管理支持大规模并发赞助
- **水平扩展**：多个 Server 实例共享同一 Redis，轻松扩容
- **安全签名**：支持 AWS KMS 等外部密钥管理，保护赞助者私钥
- **可观测**：内置 Prometheus 指标，便于监控和告警
- **资金管控**：每日上限、单次上限、自动过期回收，防止资金耗尽

对于需要优化用户体验的 DApp，Gas Pool 是不可或缺的基础设施组件。
