# 交易上下文 TxContext

TxContext（交易上下文）是 Sui Move 中每笔交易的运行时环境信息载体。它由 Sui 虚拟机在交易执行前自动创建，包含发送者地址、交易哈希、epoch 信息等关键数据。几乎所有需要创建对象或读取交易信息的函数都需要接收 TxContext 参数。

## TxContext 结构

TxContext 是一个定义在 `sui::tx_context` 模块中的结构体，其内部字段如下：

| 字段 | 类型 | 说明 |
|------|------|------|
| `sender` | `address` | 交易发送者的地址 |
| `tx_hash` | `vector<u8>` | 当前交易的哈希值 |
| `epoch` | `u64` | 当前 epoch 编号 |
| `epoch_timestamp_ms` | `u64` | 当前 epoch 开始时的时间戳（毫秒） |
| `ids_created` | `u64` | 本次交易中已创建的对象 ID 数量 |

> **重要**：TxContext **不能被手动构造**。它由 Sui 虚拟机在交易执行时自动创建并注入到入口函数中。开发者只能通过函数参数接收它，不能使用结构体字面量来创建。

## 函数签名规则

TxContext 在函数签名中有严格的位置要求——它**必须是最后一个参数**。

```move
module examples::ctx_rules;

// 正确：TxContext 是最后一个参数
public fun correct_usage(value: u64, ctx: &mut TxContext) {
    let _ = value;
    let _ = ctx;
}

// 以下写法会导致编译错误：
// public fun wrong_usage(ctx: &mut TxContext, value: u64) { ... }
```

TxContext 可以作为不可变引用（`&TxContext`）或可变引用（`&mut TxContext`）传入。选择哪种取决于你是否需要修改它的状态（主要是 `ids_created` 计数器）。

## 读取交易信息

TxContext 提供了多个方法来读取当前交易的上下文信息。这些方法只需要不可变引用 `&TxContext`。

### sender()

返回当前交易的发送者地址。这是最常用的方法之一，用于权限检查、记录操作者等场景。

```move
module examples::tx_context_demo;

public struct Receipt has key {
    id: UID,
    buyer: address,
    epoch: u64,
    timestamp_ms: u64,
}

/// 演示从 TxContext 读取信息
public fun create_receipt(ctx: &mut TxContext): Receipt {
    Receipt {
        id: object::new(ctx),
        buyer: ctx.sender(),
        epoch: ctx.epoch(),
        timestamp_ms: ctx.epoch_timestamp_ms(),
    }
}

/// 生成唯一的订单 ID
public fun generate_order_id(ctx: &mut TxContext): address {
    tx_context::fresh_object_address(ctx)
}
```

### epoch() 和 epoch_timestamp_ms()

- `ctx.epoch()` — 返回当前 epoch 编号，`u64` 类型
- `ctx.epoch_timestamp_ms()` — 返回当前 epoch 开始时的 Unix 时间戳（毫秒），`u64` 类型

注意 `epoch_timestamp_ms` 返回的是 **epoch 开始时的时间戳**，而非交易执行时的精确时间。如果需要更高精度的时间，应使用 `sui::clock::Clock`（参见 [Epoch 与时间](05-epoch-and-time.md) 一章）。

```move
module examples::epoch_check;

public struct EpochRecord has key {
    id: UID,
    recorded_epoch: u64,
    recorded_timestamp: u64,
}

public fun record_epoch(ctx: &mut TxContext) {
    let record = EpochRecord {
        id: object::new(ctx),
        recorded_epoch: ctx.epoch(),
        recorded_timestamp: ctx.epoch_timestamp_ms(),
    };
    transfer::transfer(record, ctx.sender());
}

/// 限制只能在特定 epoch 之后调用
public fun only_after_epoch(required_epoch: u64, ctx: &TxContext) {
    assert!(ctx.epoch() >= required_epoch, 0);
}
```

## 可变引用与对象创建

当你需要创建新的对象时，TxContext 必须以 `&mut TxContext` 的形式传入。这是因为 `object::new(ctx)` 会递增 `ids_created` 计数器，以此生成全局唯一的对象 ID。

### 工作原理

每次调用 `object::new(ctx)` 时：
1. 使用 `tx_hash` 和当前 `ids_created` 值计算出一个唯一地址
2. 将 `ids_created` 加 1
3. 返回一个新的 `UID`

这种机制确保了在同一笔交易中创建的多个对象拥有不同的 ID。

```move
module examples::multi_create;

public struct Token has key {
    id: UID,
    index: u64,
}

/// 在一笔交易中创建多个对象，每个都有唯一的 ID
public fun batch_create(count: u64, recipient: address, ctx: &mut TxContext) {
    let mut i = 0;
    while (i < count) {
        let token = Token {
            id: object::new(ctx),  // 每次调用都递增 ids_created
            index: i,
        };
        transfer::transfer(token, recipient);
        i = i + 1;
    };
}
```

### 何时使用 &TxContext vs &mut TxContext

| 引用类型 | 适用场景 |
|---------|---------|
| `&TxContext` | 只读取交易信息（sender、epoch 等） |
| `&mut TxContext` | 需要创建对象（调用 `object::new`）或生成唯一地址 |

一般建议：如果不确定是否需要可变引用，**优先使用 `&mut TxContext`**，因为它向后兼容——当函数内部后续需要创建对象时，不需要修改函数签名。

## fresh_object_address()

`tx_context::fresh_object_address()` 使用与 `object::new()` 相同的算法生成一个唯一地址，但不会创建 `UID`。它适用于需要唯一标识符但不需要完整对象的场景。

```move
module examples::unique_id;

use std::string::String;

public struct Order has key {
    id: UID,
    order_ref: address,  // 唯一的订单引用号
    item: String,
    quantity: u64,
}

public fun place_order(
    item: String,
    quantity: u64,
    ctx: &mut TxContext,
) {
    let order = Order {
        id: object::new(ctx),
        order_ref: tx_context::fresh_object_address(ctx),
        item,
        quantity,
    };
    transfer::transfer(order, ctx.sender());
}
```

## 实际应用模式

### 权限控制

利用 `ctx.sender()` 实现简单的所有者权限验证：

```move
module examples::owner_check;

public struct Vault has key {
    id: UID,
    owner: address,
    balance: u64,
}

public fun create_vault(ctx: &mut TxContext) {
    let vault = Vault {
        id: object::new(ctx),
        owner: ctx.sender(),
        balance: 0,
    };
    transfer::share_object(vault);
}

public fun deposit(vault: &mut Vault, amount: u64) {
    vault.balance = vault.balance + amount;
}

/// 只有 owner 可以提取
public fun withdraw(vault: &mut Vault, amount: u64, ctx: &TxContext): u64 {
    assert!(vault.owner == ctx.sender(), 0);
    assert!(vault.balance >= amount, 1);
    vault.balance = vault.balance - amount;
    amount
}
```

### 基于 Epoch 的逻辑

利用 epoch 实现基于时间周期的业务逻辑：

```move
module examples::epoch_staking;

public struct Stake has key {
    id: UID,
    staker: address,
    amount: u64,
    start_epoch: u64,
    lock_epochs: u64,
}

public fun stake(amount: u64, lock_epochs: u64, ctx: &mut TxContext) {
    let s = Stake {
        id: object::new(ctx),
        staker: ctx.sender(),
        amount,
        start_epoch: ctx.epoch(),
        lock_epochs,
    };
    transfer::transfer(s, ctx.sender());
}

public fun unstake(stake: Stake, ctx: &TxContext): u64 {
    let Stake { id, staker: _, amount, start_epoch, lock_epochs } = stake;
    assert!(ctx.epoch() >= start_epoch + lock_epochs, 0);
    id.delete();
    amount
}
```

## 小结

TxContext 是 Sui Move 交易执行的核心上下文对象，由虚拟机自动创建，不可手动构造。它提供了 `sender()`、`epoch()`、`epoch_timestamp_ms()` 等方法来读取当前交易的运行时信息。当需要创建新对象时，必须以 `&mut TxContext` 形式传入，因为 `object::new()` 会修改其内部的 `ids_created` 计数器。TxContext 必须作为函数的**最后一个参数**。`fresh_object_address()` 可以在不创建完整 UID 的情况下生成唯一地址。在实际开发中，TxContext 最常用于获取发送者地址进行权限控制，以及创建新的 Sui 对象。
