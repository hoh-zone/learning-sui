# Epoch 与时间

在区块链智能合约中，时间是一个重要但复杂的概念。Sui 提供了两种获取时间信息的方式：基于 **Epoch** 的粗粒度时间和基于 **Clock** 对象的毫秒级精确时间。理解两者的区别和适用场景，是实现时间相关业务逻辑（如锁仓、拍卖、限时活动）的关键。

## Epoch 概述

### 什么是 Epoch

Epoch 是 Sui 网络的运行周期单位。每个 epoch 大约持续 **24 小时**（具体时长由网络治理决定）。在每个 epoch 结束时，网络会进行验证者集合更新、质押奖励分配等操作。

每个 epoch 有一个递增的编号（从 0 开始），以及一个起始时间戳。

### 从 TxContext 获取 Epoch 信息

TxContext 提供了两个与 epoch 相关的方法：

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `ctx.epoch()` | `u64` | 当前 epoch 编号 |
| `ctx.epoch_timestamp_ms()` | `u64` | 当前 epoch 的开始时间戳（毫秒） |

```move
module examples::epoch_demo;

public struct EpochInfo has key {
    id: UID,
    epoch_number: u64,
    epoch_start_ms: u64,
    recorded_by: address,
}

public fun record_current_epoch(ctx: &mut TxContext) {
    let info = EpochInfo {
        id: object::new(ctx),
        epoch_number: ctx.epoch(),
        epoch_start_ms: ctx.epoch_timestamp_ms(),
        recorded_by: ctx.sender(),
    };
    transfer::transfer(info, ctx.sender());
}
```

### Epoch 的特点

- **粗粒度**：一个 epoch 约 24 小时，无法精确到秒或毫秒
- **稳定性**：在同一个 epoch 内，`ctx.epoch()` 和 `ctx.epoch_timestamp_ms()` 返回固定值
- **低开销**：从 TxContext 读取，不需要额外的共享对象输入
- **适用场景**：锁仓周期、质押奖励计算、功能开关等对时间精度要求不高的场景

### 基于 Epoch 的锁仓示例

```move
module examples::epoch_lock;

public struct EpochVault has key {
    id: UID,
    owner: address,
    amount: u64,
    lock_until_epoch: u64,
}

/// 创建一个按 epoch 锁定的金库
public fun create_vault(
    amount: u64,
    lock_epochs: u64,
    ctx: &mut TxContext,
) {
    let vault = EpochVault {
        id: object::new(ctx),
        owner: ctx.sender(),
        amount,
        lock_until_epoch: ctx.epoch() + lock_epochs,
    };
    transfer::transfer(vault, ctx.sender());
}

/// 到达指定 epoch 后才能解锁
public fun unlock(vault: EpochVault, ctx: &TxContext): u64 {
    assert!(ctx.epoch() >= vault.lock_until_epoch, 0);
    assert!(ctx.sender() == vault.owner, 1);

    let EpochVault { id, owner: _, amount, lock_until_epoch: _ } = vault;
    id.delete();
    amount
}

/// 查询剩余锁定 epoch 数
public fun remaining_epochs(vault: &EpochVault, ctx: &TxContext): u64 {
    if (ctx.epoch() >= vault.lock_until_epoch) {
        0
    } else {
        vault.lock_until_epoch - ctx.epoch()
    }
}
```

## Clock 对象

### 什么是 Clock

`sui::clock::Clock` 是一个**系统级共享对象**，位于固定地址 `0x6`。它由 Sui 系统在每个 checkpoint 时更新，提供**毫秒级精度**的时间戳，比 epoch 时间戳精确得多。

### Clock 的特性

| 特性 | 说明 |
|------|------|
| 地址 | 固定为 `0x6` |
| 类型 | 共享不可变对象 |
| 引用方式 | 只能以不可变引用 `&Clock` 传入 |
| 精度 | 毫秒级 |
| 更新频率 | 每个 checkpoint 更新一次 |

> **重要**：Clock 对象只能以 `&Clock`（不可变引用）的形式在交易中使用。你不能获取 `&mut Clock`，因为它由系统独占更新。

### 使用 Clock

```move
module examples::clock_demo;

use sui::clock::Clock;

public struct TimestampRecord has key {
    id: UID,
    recorded_at_ms: u64,
    recorder: address,
}

/// 记录当前精确时间戳
public fun record_time(clock: &Clock, ctx: &mut TxContext) {
    let record = TimestampRecord {
        id: object::new(ctx),
        recorded_at_ms: clock.timestamp_ms(),
        recorder: ctx.sender(),
    };
    transfer::transfer(record, ctx.sender());
}

/// 检查是否已过指定时间
public fun has_elapsed(clock: &Clock, since_ms: u64, duration_ms: u64): bool {
    clock.timestamp_ms() >= since_ms + duration_ms
}
```

### 时间锁定金库

```move
module examples::time_lock;

use sui::clock::Clock;

public struct TimeLock has key {
    id: UID,
    unlock_time_ms: u64,
    content: vector<u8>,
    creator: address,
}

/// 创建一个时间锁定的金库
public fun create_lock(
    clock: &Clock,
    lock_duration_ms: u64,
    content: vector<u8>,
    ctx: &mut TxContext,
) {
    let lock = TimeLock {
        id: object::new(ctx),
        unlock_time_ms: clock.timestamp_ms() + lock_duration_ms,
        content,
        creator: ctx.sender(),
    };
    transfer::transfer(lock, ctx.sender());
}

/// 只有时间到达后才能解锁
public fun unlock(lock: TimeLock, clock: &Clock): vector<u8> {
    assert!(clock.timestamp_ms() >= lock.unlock_time_ms, 0);
    let TimeLock { id, unlock_time_ms: _, content, creator: _ } = lock;
    id.delete();
    content
}

/// 查询当前 epoch 信息
public fun current_epoch(ctx: &TxContext): u64 {
    ctx.epoch()
}
```

## Epoch vs Clock 对比

| 维度 | Epoch | Clock |
|------|-------|-------|
| 精度 | ~24 小时 | 毫秒级 |
| 来源 | TxContext（自动提供） | Clock 共享对象（需作为参数传入） |
| 开销 | 极低（无额外输入） | 需要输入共享对象（可能影响并行） |
| 稳定性 | 同一 epoch 内值不变 | 每个 checkpoint 更新 |
| 适用场景 | 锁仓周期、奖励计算 | 拍卖、限时活动、精确计时 |

### 选择建议

- 如果业务逻辑只需要"大约几天"的时间粒度，使用 **epoch**
- 如果需要"几秒到几小时"的精确计时，使用 **Clock**
- 如果同时需要两者，可以在同一个函数中同时使用 `&Clock` 和 `&TxContext`

## 实际应用场景

### 限时拍卖

```move
module examples::auction;

use sui::clock::Clock;
use sui::event;

public struct AuctionCreated has copy, drop {
    auction_id: ID,
    end_time_ms: u64,
}

public struct BidPlaced has copy, drop {
    auction_id: ID,
    bidder: address,
    amount: u64,
}

public struct Auction has key {
    id: UID,
    seller: address,
    highest_bid: u64,
    highest_bidder: address,
    end_time_ms: u64,
    settled: bool,
}

public fun create_auction(
    clock: &Clock,
    duration_ms: u64,
    starting_bid: u64,
    ctx: &mut TxContext,
) {
    let end_time = clock.timestamp_ms() + duration_ms;
    let auction = Auction {
        id: object::new(ctx),
        seller: ctx.sender(),
        highest_bid: starting_bid,
        highest_bidder: @0x0,
        end_time_ms: end_time,
        settled: false,
    };

    event::emit(AuctionCreated {
        auction_id: object::id(&auction),
        end_time_ms: end_time,
    });

    transfer::share_object(auction);
}

public fun place_bid(
    auction: &mut Auction,
    bid_amount: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(!auction.settled, 0);
    assert!(clock.timestamp_ms() < auction.end_time_ms, 1);
    assert!(bid_amount > auction.highest_bid, 2);

    auction.highest_bid = bid_amount;
    auction.highest_bidder = ctx.sender();

    event::emit(BidPlaced {
        auction_id: object::id(auction),
        bidder: ctx.sender(),
        amount: bid_amount,
    });
}

public fun settle(auction: &mut Auction, clock: &Clock) {
    assert!(!auction.settled, 0);
    assert!(clock.timestamp_ms() >= auction.end_time_ms, 1);
    auction.settled = true;
}
```

### 冷却期机制

```move
module examples::cooldown;

use sui::clock::Clock;

public struct Player has key {
    id: UID,
    last_action_ms: u64,
    cooldown_ms: u64,
    action_count: u64,
}

public fun create_player(cooldown_ms: u64, ctx: &mut TxContext) {
    let player = Player {
        id: object::new(ctx),
        last_action_ms: 0,
        cooldown_ms,
        action_count: 0,
    };
    transfer::transfer(player, ctx.sender());
}

public fun perform_action(player: &mut Player, clock: &Clock) {
    let now = clock.timestamp_ms();
    assert!(now >= player.last_action_ms + player.cooldown_ms, 0);

    player.last_action_ms = now;
    player.action_count = player.action_count + 1;
}

public fun time_until_ready(player: &Player, clock: &Clock): u64 {
    let ready_time = player.last_action_ms + player.cooldown_ms;
    let now = clock.timestamp_ms();
    if (now >= ready_time) {
        0
    } else {
        ready_time - now
    }
}
```

## 小结

Sui 提供了两种互补的时间机制。**Epoch** 来自 TxContext，表示网络运行周期（约 24 小时），适合粗粒度的时间逻辑，且无额外开销。**Clock** 是位于地址 `0x6` 的系统共享对象，提供毫秒级精度的时间戳，适合拍卖、冷却期、精确限时等场景，但需要作为 `&Clock` 引用传入函数。选择时间机制时，应根据业务需求的精度要求来决定：周期性逻辑优先使用 epoch，精确计时逻辑使用 Clock。两种机制可以在同一函数中组合使用。
