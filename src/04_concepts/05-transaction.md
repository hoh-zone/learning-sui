# 交易（Transaction）

交易（Transaction）是改变 Sui 区块链状态的唯一方式。无论是转移对象、调用智能合约函数，还是发布新的 Move 包，都必须通过交易来完成。理解交易的结构和生命周期，是掌握 Sui 开发的关键。

## 交易的结构

一笔 Sui 交易由以下几个核心部分组成：

```
Transaction {
    sender:    发送者地址（签名者）
    commands:  操作命令列表
    inputs:    输入参数（纯值参数 + 对象参数）
    gas:       Gas 支付信息（Gas 对象、价格、预算）
}
```

### 发送者（Sender）

每笔交易都有一个发送者，即签署并提交交易的账户地址。发送者必须用对应的私钥对交易进行签名。

### 命令（Commands）

交易可以包含一个或多个命令，按顺序执行。Sui 支持的命令类型：

| 命令 | 说明 |
|------|------|
| `MoveCall` | 调用已发布包中的 Move 函数 |
| `TransferObjects` | 将一个或多个对象转移给指定地址 |
| `SplitCoins` | 从一个 Coin 中拆分出指定金额 |
| `MergeCoins` | 将多个同类型 Coin 合并为一个 |
| `Publish` | 发布一个新的 Move 包 |
| `Upgrade` | 升级一个已发布的 Move 包 |
| `MakeMoveVec` | 创建一个 Move 向量 |

### 输入（Inputs）

交易的输入分为两类：

#### 纯值参数（Pure Arguments）

可以直接传入交易的基础值类型：

| 类型 | 示例 |
|------|------|
| `bool` | `true`, `false` |
| 整数类型 | `u8`, `u16`, `u32`, `u64`, `u128`, `u256` |
| `address` | `0xa11ce...` |
| `String` | `"hello"` |
| `vector<T>` | `vector[1, 2, 3]` |
| `Option<T>` | `some(42)`, `none` |
| `ID` | 对象标识符 |

#### 对象参数（Object Arguments）

链上对象需要根据其所有权类型以不同方式传入：

| 对象类型 | 传入方式 | 说明 |
|----------|----------|------|
| 拥有的对象（Owned） | 按引用或按值 | 只有所有者可以使用 |
| 共享对象（Shared） | 按可变引用 | 任何人都可以使用 |
| 冻结对象（Frozen/Immutable） | 按不可变引用 | 任何人都可以读取 |

## 交易命令详解

### MoveCall — 调用 Move 函数

最常用的命令，用于调用链上已发布包中的函数：

```move
module marketplace::shop;

use sui::coin::Coin;
use sui::sui::SUI;

public struct Item has key, store {
    id: UID,
    name: vector<u8>,
}

public fun purchase(
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): Item {
    // 验证支付金额、处理业务逻辑...
    let item = Item {
        id: object::new(ctx),
        name: b"Rare Sword",
    };
    transfer::public_transfer(payment, @0xSHOP_OWNER);
    item
}
```

### SplitCoins — 拆分代币

从一个 Coin 对象中拆分出指定金额。`Gas` 是一个特殊的关键字，表示交易的 Gas 支付 Coin：

```
SplitCoins(Gas, [1000])
// 从 Gas Coin 中拆分出 1000 MIST
```

### MergeCoins — 合并代币

将多个同类型 Coin 合并为一个：

```
MergeCoins(dest_coin, [coin_a, coin_b])
// 将 coin_a 和 coin_b 合并到 dest_coin 中
```

### TransferObjects — 转移对象

将对象转移给指定地址：

```
TransferObjects([object_a, object_b], recipient)
// 将 object_a 和 object_b 转移给 recipient
```

## 交易示例

以下是一个在市场中购买物品的完整交易伪代码：

```
Inputs:
  - sender = 0xa11ce

Commands:
  - payment = SplitCoins(Gas, [1000])
  - item = MoveCall(0xAAA::market::purchase, [payment])
  - TransferObjects([item], sender)
```

这笔交易执行了三步操作：

1. 从 Gas Coin 中拆分出 1000 MIST 作为支付
2. 调用市场合约的 `purchase` 函数，传入支付 Coin，获取物品
3. 将获得的物品转移给自己（发送者）

使用 Sui TypeScript SDK 构建同样的交易：

```typescript
const tx = new Transaction();

const [payment] = tx.splitCoins(tx.gas, [1000]);
const [item] = tx.moveCall({
    target: '0xAAA::market::purchase',
    arguments: [payment],
});
tx.transferObjects([item], tx.pure.address('0xa11ce'));
```

## 交易的生命周期

一笔交易从构建到最终确认，经历以下阶段：

```
构建（Construct）
    ↓
签名（Sign）
    ↓
提交（Submit）
    ↓
执行（Execute）
    ↓
产生效果（Effects）
```

### 1. 构建

开发者使用 SDK 或 CLI 构建交易，指定命令、输入和 Gas 参数。

### 2. 签名

发送者使用私钥对交易进行数字签名。

### 3. 提交

将签名后的交易提交给 Sui 验证者节点。

### 4. 执行

验证者验证签名和交易合法性后，执行交易中的命令序列。

### 5. 产生效果

交易执行完成后产生 **交易效果（Transaction Effects）**，记录交易的所有结果。

## 交易效果（Transaction Effects）

每笔交易执行后都会产生一组效果，详细记录了交易的执行结果：

| 字段 | 说明 |
|------|------|
| **Transaction Digest** | 交易的唯一哈希标识符 |
| **Status** | 执行状态：成功（success）或失败（failure） |
| **Created Objects** | 本次交易新创建的对象列表 |
| **Mutated Objects** | 本次交易修改的对象列表 |
| **Deleted Objects** | 本次交易删除的对象列表 |
| **Gas Cost Summary** | Gas 费用明细 |
| **Events** | 交易中发出的事件列表 |
| **Balance Changes** | 各账户的余额变动 |

使用 CLI 查看交易效果：

```bash
sui client tx-block <TRANSACTION_DIGEST>
```

## Gas 机制

Gas 是执行交易所需的费用，以 Sui 的最小单位 **MIST** 计价：

```
1 SUI = 1,000,000,000 MIST（10^9 MIST）
```

### Gas 的组成

每笔交易需要指定三个 Gas 相关参数：

| 参数 | 说明 |
|------|------|
| **Gas 对象** | 用于支付 Gas 费的 Coin 对象 |
| **Gas 预算（Gas Budget）** | 交易愿意支付的最大 Gas 量（MIST） |
| **Gas 价格（Gas Price）** | 每单位计算的价格，不低于网络参考价格 |

### Gas 费用明细

交易执行后的 Gas 费用包含以下几部分：

| 费用类型 | 说明 |
|----------|------|
| **计算费用（Computation Cost）** | 执行交易中命令所消耗的计算资源 |
| **存储费用（Storage Cost）** | 新创建或扩大的对象所需的链上存储费用 |
| **存储退款（Storage Rebate）** | 删除或缩小对象时返还的存储费用 |

实际扣除的 Gas 费用计算公式：

```
实际费用 = 计算费用 + 存储费用 - 存储退款
```

### Gas 预算

如果交易执行的实际费用超过了设定的 Gas 预算，交易将失败并回滚所有操作，但 Gas 费用仍会被扣除。因此建议设置合理的 Gas 预算：

```bash
# CLI 会自动估算 Gas，一般无需写 --gas-budget
sui client call --package 0xPKG --module shop --function purchase \
    --args 0xCOIN_ID
```

## 可编程交易块（PTB）

Sui 的一大特色是**可编程交易块**（Programmable Transaction Block, PTB）。一笔交易可以包含多个命令，这些命令按顺序执行，前一个命令的输出可以作为后一个命令的输入：

```
Commands:
  1. coin = SplitCoins(Gas, [5000])
  2. nft = MoveCall(0xBBB::nft::mint, ["My NFT"])
  3. MoveCall(0xCCC::auction::bid, [nft, coin])
```

PTB 的优势：

- **原子性**：所有命令要么全部成功，要么全部失败
- **组合性**：可以在一笔交易中调用多个不同包的函数
- **高效性**：减少了多次交易的网络往返开销
- **数据流转**：前一个命令的返回值可以直接传给后续命令

## 小结

交易是 Sui 区块链上改变状态的唯一方式。一笔交易包含发送者、命令列表、输入参数和 Gas 支付信息。Sui 提供了 `MoveCall`、`TransferObjects`、`SplitCoins` 等多种命令类型，并通过可编程交易块（PTB）实现了多命令的原子组合。交易执行后会产生包含状态变更、Gas 费用、事件等信息的交易效果。Gas 以 MIST 为单位计价（1 SUI = 10^9 MIST），由计算费用、存储费用和存储退款三部分组成。
