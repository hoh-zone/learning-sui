# 模拟 TxContext

大多数创建对象或与用户交互的 Move 函数都需要 `TxContext` 参数。交易执行时其值由运行时提供，但在测试中你需要自行创建和传递。`sui::tx_context` 模块提供了多个工具函数来满足这一需求。本节将详细介绍如何在测试中创建和操控交易上下文。

## 创建 Dummy 上下文

最简单的方式是 `tx_context::dummy()`，它创建一个具有默认值的上下文——发送者为零地址、epoch 为 0、固定的交易哈希：

```move
use std::unit_test::assert_eq;

#[test]
fun create_object() {
    let mut ctx = tx_context::dummy();
    let obj = my_module::new(&mut ctx);

    assert_eq!(ctx.sender(), @0); // 默认发送者是 0x0
    // ...
}
```

这对大多数不关心具体上下文值的测试来说已足够。

## 自定义上下文

当需要指定发送者、epoch 或时间戳时，使用 `tx_context::new`：

```move
use std::unit_test::assert_eq;

#[test]
fun with_specific_sender() {
    let sender = @0xA;
    let tx_hash = x"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532";
    let epoch = 5;
    let epoch_timestamp_ms = 1234567890000;
    let ids_created = 0;

    let mut ctx = tx_context::new(
        sender,
        tx_hash,
        epoch,
        epoch_timestamp_ms,
        ids_created,
    );

    assert_eq!(ctx.sender(), @0xA);
    assert_eq!(ctx.epoch(), 5);
}
```

### 使用 new_from_hint 简化哈希

`tx_hash` 必须恰好 32 字节。使用 `new_from_hint` 可从简单整数生成唯一哈希：

```move
#[test]
fun with_hint() {
    let mut ctx = tx_context::new_from_hint(
        @0xA,    // sender
        42,      // hint（用于生成唯一的 tx_hash）
        5,       // epoch
        1000,    // epoch_timestamp_ms
        0,       // ids_created
    );
    // ...
}
```

## 追踪创建的对象

在测试对象创建时，你可能需要验证创建了多少对象，或获取最后创建的对象 ID：

```move
use std::unit_test::assert_eq;

#[test]
fun object_creation_count() {
    let mut ctx = tx_context::dummy();

    assert_eq!(ctx.ids_created(), 0);

    let obj1 = my_module::new(&mut ctx);
    assert_eq!(ctx.ids_created(), 1);

    let obj2 = my_module::new(&mut ctx);
    assert_eq!(ctx.ids_created(), 2);

    let last_id = ctx.last_created_object_id();
    // ...
}
```

## 模拟时间和 Epoch

对于依赖时间或 epoch 变化的测试，使用递增函数：

```move
use std::unit_test::assert_eq;

#[test]
fun time_dependent_logic() {
    let mut ctx = tx_context::dummy();

    // 初始状态
    assert_eq!(ctx.epoch(), 0);
    assert_eq!(ctx.epoch_timestamp_ms(), 0);

    // 模拟 epoch 变化
    ctx.increment_epoch_number();
    assert_eq!(ctx.epoch(), 1);

    // 模拟时间流逝（增加 1 天的毫秒数）
    ctx.increment_epoch_timestamp(24 * 60 * 60 * 1000);
    assert_eq!(ctx.epoch_timestamp_ms(), 86_400_000);
}
```

## 完全控制：create

需要完全控制所有上下文字段（包括 Gas 相关参数）时，使用 `tx_context::create`：

```move
use std::unit_test::assert_eq;

#[test]
fun with_full_context() {
    let ctx = &tx_context::create(
        @0xA,                                        // sender
        tx_context::dummy_tx_hash_with_hint(1),      // tx_hash
        10,                                          // epoch
        1700000000000,                               // epoch_timestamp_ms
        0,                                           // ids_created
        1000,                                        // reference_gas_price
        1500,                                        // gas_price
        10_000_000,                                  // gas_budget
        option::none(),                              // sponsor
    );

    assert_eq!(ctx.gas_budget(), 10_000_000);
}
```

## 函数速查表

| 函数 | 用途 |
| --- | --- |
| `dummy()` | 快速创建简单测试用上下文 |
| `new()` | 自定义 sender、epoch 或时间戳 |
| `new_from_hint()` | 类似 `new` 但从整数生成 tx_hash |
| `create()` | 完全控制包括 Gas 参数在内的所有字段 |
| `ids_created()` | 检查已创建的对象数量 |
| `last_created_object_id()` | 获取最近创建的对象 ID |
| `increment_epoch_number()` | 模拟 epoch 推进 |
| `increment_epoch_timestamp()` | 模拟时间流逝 |

## 小结

- `tx_context::dummy()` 适合大多数简单测试，创建零地址发送者的默认上下文
- `tx_context::new()` 和 `new_from_hint()` 用于需要特定发送者或时间的场景
- `tx_context::create()` 提供完全控制，包括 Gas 预算和赞助者
- 这些工具仅适合简单单元测试；多交易场景应使用 Test Scenario
