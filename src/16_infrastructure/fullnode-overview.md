# 全节点概述

本节介绍 Sui 全节点的架构、运行方式以及 RPC 端点。全节点是 Sui 网络的核心基础设施，为 dApp 提供数据查询、交易提交和事件订阅等服务。

## 什么是全节点

Sui 全节点存储完整的区块链状态，但不参与共识。它的主要职责是：

- 提供 JSON-RPC 和 GraphQL API
- 验证和转发交易
- 存储和索引链上数据
- 提供事件流订阅

```
┌─────────────────────────────────────────────┐
│             Sui 网络架构                      │
├─────────────────────────────────────────────┤
│                                               │
│  验证者（Validators）  ← 参与共识              │
│       │                                       │
│       ▼                                       │
│  全节点（Full Nodes）  ← 同步状态、提供 API    │
│       │                                       │
│       ▼                                       │
│  DApp / SDK / 浏览器   ← 查询数据、提交交易    │
│                                               │
└─────────────────────────────────────────────┘
```

## 公共 RPC 端点

| 网络 | RPC URL |
|------|---------|
| Mainnet | `https://fullnode.mainnet.sui.io:443` |
| Testnet | `https://fullnode.testnet.sui.io:443` |
| Devnet | `https://fullnode.devnet.sui.io:443` |
| Localnet | `http://127.0.0.1:9000` |

### 使用 SDK 连接

```typescript
import { SuiGrpcClient } from '@mysten/sui/grpc';

const client = new SuiGrpcClient({
  network: 'mainnet',
  baseUrl: 'https://fullnode.mainnet.sui.io:443',
});

const chainId = await client.getChainIdentifier();
console.log('Chain ID:', chainId);
```

## 运行自己的全节点

### 硬件要求

| 资源 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 8 核 | 16 核 |
| 内存 | 128 GB | 256 GB |
| 存储 | 4 TB NVMe SSD | 8 TB NVMe SSD |
| 网络 | 1 Gbps | 10 Gbps |

### 使用 Docker 运行

```bash
# 下载最新配置
curl -fLJ -o fullnode.yaml \
  https://github.com/MystenLabs/sui/raw/main/crates/sui-config/data/fullnode-template.yaml

# 下载创世纪文件
curl -fLJ -o genesis.blob \
  https://github.com/MystenLabs/sui-genesis/raw/main/mainnet/genesis.blob

# 启动全节点
docker run -d \
  --name sui-fullnode \
  -p 9000:9000 \
  -v $(pwd)/fullnode.yaml:/opt/sui/config/fullnode.yaml \
  -v $(pwd)/genesis.blob:/opt/sui/config/genesis.blob \
  -v $(pwd)/suidb:/opt/sui/db \
  mysten/sui-node:mainnet \
  /opt/sui/bin/sui-node --config-path /opt/sui/config/fullnode.yaml
```

## RPC 方法概览

### 对象查询

```typescript
// 查询单个对象
const obj = await client.core.getObject({
  objectId: '0x...',
  include: { content: true, owner: true, type: true },
});

// 批量查询对象
const objects = await client.core.getObjects({
  objectIds: ['0x...', '0x...'],
  include: { content: true },
});

// 查询拥有的对象
const owned = await client.core.listOwnedObjects({
  owner: '0x...',
  filter: { StructType: '0x...::hero::Hero' },
  include: { content: true },
});
```

### 交易查询

```typescript
// 查询交易详情
const tx = await client.core.getTransaction({
  digest: '...',
  include: {
    effects: true,
    transaction: true,
    events: true,
    balanceChanges: true,
  },
});

// 查询交易历史（具体 API 以当前 SDK 为准）
const txs = await client.queryTransactionBlocks({
  filter: { FromAddress: '0x...' },
  order: 'descending',
  limit: 10,
});
```

### 事件查询

```typescript
// 查询事件
const events = await client.queryEvents({
  query: {
    MoveEventType: `${PACKAGE_ID}::hero::HeroCreated`,
  },
  order: 'descending',
  limit: 50,
});

// 订阅事件（WebSocket）
const unsubscribe = await client.subscribeEvent({
  filter: {
    MoveEventType: `${PACKAGE_ID}::hero::HeroCreated`,
  },
  onMessage: (event) => {
    console.log('New event:', event);
  },
});
```

## 数据查询限制

### 公共节点限制

| 限制 | 值 |
|------|---|
| 请求频率 | 通常 100 req/s |
| 单次查询对象数 | 50 |
| 事件查询最大返回数 | 50 |
| WebSocket 连接 | 有限制 |

### 应对策略

| 问题 | 解决方案 |
|------|---------|
| 需要高频查询 | 运行自己的全节点 |
| 需要历史数据 | 使用自定义索引器 |
| 需要复杂查询 | 使用 GraphQL API |
| 需要实时推送 | 使用 gRPC 事件流 |

## 动态字段查询

```typescript
// 查询动态字段
const dynamicFields = await client.core.listDynamicFields({
  parentId: '0x...',
});

// 查询特定动态字段
const field = await client.core.getDynamicField({
  parentId: '0x...',
  name: {
    type: 'u64',
    value: '0',
  },
});
```

## Dry Run 交易

在提交前模拟交易执行：

```typescript
const tx = new Transaction();
// ... 构造交易

const dryRunResult = await client.core.simulateTransaction({
  transaction: await tx.build({ client }),
});

console.log('Status:', dryRunResult.effects.status);
console.log('Gas used:', dryRunResult.effects.gasUsed);
```

## 小结

- 全节点是 Sui 网络的基础设施层，提供 RPC、GraphQL 和事件流服务
- 公共 RPC 端点适合开发测试，生产环境建议运行自己的全节点
- RPC 提供对象、交易和事件的丰富查询接口
- 公共节点有速率限制，高级需求需要自定义索引器或自建节点
- Dry Run 可以在不消耗 gas 的情况下模拟交易执行
