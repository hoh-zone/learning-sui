# DeepBook 链上订单簿

本节介绍 DeepBook——Sui 上的去中心化链上订单簿（CLOB）。DeepBook 提供完全透明的链上交易撮合，支持限价单、市价单和闪电贷等高级功能。

## 设计理念

### 为什么是链上订单簿

传统 DEX（如 AMM）的局限性：

| 方面 | AMM | 链上订单簿（DeepBook） |
|------|-----|----------------------|
| 价格发现 | 由公式决定 | 由市场供需决定 |
| 滑点 | 大额交易滑点高 | 深度足够时滑点小 |
| 做市方式 | 提供流动性 | 挂限价单 |
| 资本效率 | 较低 | 较高 |

### Sui 的优势

- **并行执行**：不同交易对可以并行处理
- **低延迟**：亚秒级确认
- **低费用**：适合高频交易
- **PTB**：一笔交易完成复杂操作

## 核心概念

### 流动性池（Pool）

每个交易对对应一个 Pool 共享对象：

```move
// DeepBook 池结构（简化）
public struct Pool<phantom BaseAsset, phantom QuoteAsset> has key {
    id: UID,
    bids: CritbitTree<TickLevel>,  // 买单
    asks: CritbitTree<TickLevel>,  // 卖单
    tick_size: u64,                // 最小价格变动
    lot_size: u64,                 // 最小数量变动
}
```

### 账户（Account）

用户需要创建账户来管理余额：

```typescript
import { Transaction } from '@mysten/sui/transactions';

const DEEPBOOK_PACKAGE = '0x...';

// 创建交易账户
function createAccount(tx: Transaction) {
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::create_account`,
  });
}
```

## 下单操作

### 限价单

```typescript
function placeLimitOrder(
  tx: Transaction,
  poolId: string,
  price: number,
  quantity: number,
  isBid: boolean,
  accountCap: string,
) {
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::place_limit_order`,
    arguments: [
      tx.object(poolId),
      tx.pure.u64(price),
      tx.pure.u64(quantity),
      tx.pure.bool(isBid),
      tx.pure.u64(0), // expire_timestamp (0 = no expiry)
      tx.pure.u8(0),  // restriction (0 = no restriction)
      tx.object('0x6'), // Clock
      tx.object(accountCap),
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });
}
```

### 市价单

```typescript
function placeMarketOrder(
  tx: Transaction,
  poolId: string,
  quantity: number,
  isBid: boolean,
  accountCap: string,
  baseCoin: string,
  quoteCoin: string,
) {
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::place_market_order`,
    arguments: [
      tx.object(poolId),
      tx.object(accountCap),
      tx.pure.u64(quantity),
      tx.pure.bool(isBid),
      tx.object(baseCoin),
      tx.object(quoteCoin),
      tx.object('0x6'), // Clock
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });
}
```

### 撤单

```typescript
function cancelOrder(
  tx: Transaction,
  poolId: string,
  orderId: string,
  accountCap: string,
) {
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::cancel_order`,
    arguments: [
      tx.object(poolId),
      tx.pure.u128(orderId),
      tx.object(accountCap),
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });
}
```

## 查询订单簿

### 获取最佳买卖价

```typescript
async function getBestPrices(client: import("@mysten/sui/grpc").SuiGrpcClient, poolId: string) {
  const pool = await client.core.getObject({
    objectId: poolId,
    include: { content: true },
  });

  // 解析订单簿数据
  // ...
}
```

### 查询用户订单

```typescript
function getUserOrders(
  tx: Transaction,
  poolId: string,
  accountCap: string,
) {
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::list_open_orders`,
    arguments: [
      tx.object(poolId),
      tx.object(accountCap),
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });
}
```

## 闪电贷

DeepBook 支持闪电贷——在一笔交易中借入和归还流动性：

```typescript
function flashLoan(tx: Transaction, poolId: string, amount: number) {
  // 借入
  const [coin, receipt] = tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::borrow_flashloan`,
    arguments: [
      tx.object(poolId),
      tx.pure.u64(amount),
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });

  // 在这里使用借入的资金进行套利等操作
  // ...

  // 归还（必须在同一笔交易中）
  tx.moveCall({
    target: `${DEEPBOOK_PACKAGE}::clob::return_flashloan`,
    arguments: [
      tx.object(poolId),
      coin,
      receipt, // Hot Potato，确保必须归还
    ],
    typeArguments: ['0x2::sui::SUI', '0x...::usdc::USDC'],
  });
}
```

## 做市策略示例

```typescript
async function simpleMarketMaker(
  client: import("@mysten/sui/grpc").SuiGrpcClient,
  keypair: Ed25519Keypair,
  poolId: string,
  accountCap: string,
  spread: number,
) {
  // 获取中间价
  const midPrice = await getMidPrice(client, poolId);

  const tx = new Transaction();

  // 挂买单（中间价 - 价差/2）
  placeLimitOrder(
    tx, poolId,
    midPrice - spread / 2,
    1000, // 数量
    true, // is_bid
    accountCap,
  );

  // 挂卖单（中间价 + 价差/2）
  placeLimitOrder(
    tx, poolId,
    midPrice + spread / 2,
    1000,
    false, // is_ask
    accountCap,
  );

  await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });
}
```

## 小结

- DeepBook 是 Sui 上的完全去中心化链上订单簿
- 支持限价单、市价单和闪电贷等高级交易功能
- Sui 的并行执行和低延迟使链上订单簿成为可能
- 通过 PTB 可以在一笔交易中组合多个交易操作
- 闪电贷利用 Hot Potato 模式确保借入的资金必须在同一交易中归还
- 做市商可以利用 DeepBook API 实现自动化做市策略
