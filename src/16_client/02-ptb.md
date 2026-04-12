# 可编程交易块（PTB）

可编程交易块（Programmable Transaction Blocks, PTBs）是 Sui 的核心特性之一，允许在单个交易中原子地执行多个操作。PTB 无需修改智能合约就能在客户端灵活组合多个 Move 调用，极大地提升了效率和用户体验。

## PTB 概念

### 传统方式 vs PTB

**传统方式**（两笔独立交易）：

```
交易 1: 拆分代币 → 等待确认
交易 2: 转移拆分出的代币 → 等待确认
```

问题：非原子执行、Gas 更高、错误处理复杂。

**PTB 方式**（单笔交易）：

```
交易: [拆分代币] → [转移代币]    // 原子执行
```

优势：原子性（全成功或全失败）、更低 Gas、更简单。

### PTB 的优势

1. **原子性**：所有操作要么全部成功，要么全部回滚
2. **低 Gas**：一笔交易比多笔交易更省 Gas
3. **可组合**：无需合约间直接依赖就能组合调用
4. **灵活性**：无需升级合约即可创建新的操作流程

## 命令类型

PTB 支持以下命令类型：

### MoveCall

调用 Move 函数：

```typescript
const tx = new Transaction();

const hero = tx.moveCall({
  target: `${PACKAGE_ID}::hero::mint_hero`,
  arguments: [],
});
```

### SplitCoins

从一个代币中拆分出新的代币：

```typescript
const tx = new Transaction();

// 从 Gas 代币中拆分出 1 SUI
const coin = tx.splitCoins(tx.gas, [1_000_000_000]);
```

### MergeCoins

合并多个同类型代币：

```typescript
const tx = new Transaction();

tx.mergeCoins(tx.object(coinId1), [tx.object(coinId2), tx.object(coinId3)]);
```

### TransferObjects

转移对象到指定地址：

```typescript
const tx = new Transaction();

const hero = tx.moveCall({
  target: `${PACKAGE_ID}::hero::mint_hero`,
  arguments: [],
});

tx.transferObjects([hero], "0xRECIPIENT_ADDRESS");
```

### MakeMoveVec

创建 Move vector：

```typescript
const tx = new Transaction();

const vec = tx.makeMoveVec({
  type: "u64",
  elements: [tx.pure.u64(1), tx.pure.u64(2), tx.pure.u64(3)],
});
```

## 构建 PTB

### 基本结构

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});
const keypair = Ed25519Keypair.fromSecretKey(secretKey);

const tx = new Transaction();

// 添加命令
// ...

const result = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

if (result.$kind === "FailedTransaction") {
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}

await client.waitForTransaction({ digest: result.Transaction.digest });
```

### 传递参数

```typescript
const tx = new Transaction();

// 纯值参数
tx.moveCall({
  target: `${PACKAGE_ID}::game::set_name`,
  arguments: [
    tx.object(heroId),         // 对象参数
    tx.pure.string("Hero #1"), // 字符串参数
    tx.pure.u64(100),          // 数值参数
    tx.pure.bool(true),        // 布尔参数
    tx.pure.address("0xABC"),  // 地址参数
  ],
});
```

### 链式操作

PTB 的真正强大之处在于链式操作——前一个命令的返回值可以作为后一个命令的输入：

```typescript
const tx = new Transaction();

// 步骤 1: 铸造 Hero
const hero = tx.moveCall({
  target: `${PACKAGE_ID}::hero::mint_hero`,
  arguments: [],
});

// 步骤 2: 铸造 Sword
const sword = tx.moveCall({
  target: `${PACKAGE_ID}::blacksmith::new_sword`,
  arguments: [
    tx.pure.string("Excalibur"),
    tx.pure.u64(100),
  ],
});

// 步骤 3: 装备（使用前两步的返回值）
tx.moveCall({
  target: `${PACKAGE_ID}::hero::equip_sword`,
  arguments: [hero, sword],
});

// 步骤 4: 转移
tx.transferObjects([hero], account.address);
```

## CLI 中的 PTB

Sui CLI 也支持直接执行 PTB：

### 拆分并转移

```bash
sui client ptb \
    --split-coins @$COIN_ID [1000000000] \
    --assign coin \
    --transfer-objects [coin] @RECIPIENT_ADDRESS
```

### 复杂 PTB

```bash
sui client ptb \
    --move-call $PKG::hero::mint_hero \
    --assign hero \
    --move-call $PKG::blacksmith::new_sword \
        '"Excalibur"' 100 \
    --assign sword \
    --move-call $PKG::hero::equip_sword hero sword \
    --transfer-objects [hero] @MY_ADDRESS
```

## 动态合约组合

PTB 最强大的能力是在客户端动态组合多个合约调用，无需合约之间存在直接依赖：

```typescript
const tx = new Transaction();

// 调用天气预言机
const weather = tx.moveCall({
  target: `${WEATHER_PKG}::oracle::get_weather`,
  arguments: [tx.object(oracleId)],
});

// 调用姓名索引器
const name = tx.moveCall({
  target: `${NAMES_PKG}::indexer::get_name`,
  arguments: [tx.object(indexerId), tx.pure.address(userAddr)],
});

// 调用年龄计算器
const age = tx.moveCall({
  target: `${AGE_PKG}::calculator::calculate_age`,
  arguments: [tx.pure.u64(birthYear)],
});

// 组合所有信息发出事件
tx.moveCall({
  target: `${EVENT_PKG}::emitter::emit_greeting`,
  arguments: [name, age, weather],
});
```

这些合约之间没有任何依赖关系，但通过 PTB 可以在客户端自由组合。

## 处理执行结果

```typescript
const result = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
  include: {
    effects: true,
    balanceChanges: true,
    objectTypes: true,
    events: true,
  },
});

// 必须按 result.$kind 检查成功或失败
if (result.$kind === "FailedTransaction") {
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}

const txResult = result.Transaction;
console.log("Transaction succeeded!", txResult.digest);

// 查看余额变化、事件等（若 include 中已请求）
const balanceChanges = txResult.balanceChanges;
const events = txResult.events;
await client.waitForTransaction({ digest: txResult.digest });
```

## 小结

- PTB 允许在单笔交易中原子地执行多个操作，降低 Gas 并简化错误处理
- 支持 MoveCall、SplitCoins、MergeCoins、TransferObjects 等命令类型
- 命令之间可链式传递返回值，实现复杂的操作流程
- 支持在客户端动态组合不同合约的调用，无需合约间直接依赖
- CLI 和 TypeScript SDK 都支持构建和执行 PTB
