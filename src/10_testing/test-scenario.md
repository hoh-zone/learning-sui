# Test Scenario

`test_scenario` 模块来自 Sui Framework，提供了在测试中模拟多交易场景的能力。它维护一个全局对象池视图，允许你测试对象如何在多个交易中被创建、转移和访问。这是 Sui Move 测试框架中最强大的工具之一。

## 启动和结束场景

测试场景以 `test_scenario::begin` 开始，接受发送者地址作为参数。场景必须以 `test_scenario::end` 结束以清理资源：

```move
use sui::test_scenario;

#[test]
fun basic_scenario() {
    let alice = @0xA;

    let mut scenario = test_scenario::begin(alice);

    // ... 执行操作 ...

    scenario.end();
}
```

> 每个测试中应只有一个 scenario。在同一测试中创建多个 scenario 可能产生意外结果。

## 交易模拟

使用 `next_tx` 推进到指定发送者的新交易。在前一个交易中转移的对象在下一个交易中变为可用：

```move
use sui::test_scenario;

#[test]
fun multi_transaction() {
    let alice = @0xA;
    let bob = @0xB;

    let mut scenario = test_scenario::begin(alice);

    // 第一笔交易：alice 创建对象

    // 推进到第二笔交易，bob 作为发送者
    let _effects = scenario.next_tx(bob);

    // ... bob 现在可以访问转移给他的对象 ...

    scenario.end();
}
```

> 在交易中转移的对象只有在调用 `next_tx` 后才可用。你不能在同一笔交易中访问刚转移的对象。

## 访问拥有的对象

转移到某地址的对象可以用 `take_from_sender` 或 `take_from_address` 获取，用完后通过 `return_to_sender` 或 `return_to_address` 归还：

```move
module book::test_scenario_example;

public struct Item has key, store {
    id: UID,
    value: u64,
}

public fun create(value: u64, ctx: &mut TxContext): Item {
    Item { id: object::new(ctx), value }
}

public fun value(item: &Item): u64 { item.value }

#[test]
fun take_and_return() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let mut scenario = test_scenario::begin(alice);

    // 交易 1：创建一个 Item 并转移给 alice
    {
        let item = create(100, scenario.ctx());
        transfer::public_transfer(item, alice);
    };

    // 交易 2：alice 取出该 Item
    scenario.next_tx(alice);
    {
        let item = scenario.take_from_sender<Item>();
        assert_eq!(item.value(), 100);
        scenario.return_to_sender(item);
    };

    scenario.end();
}
```

### 按 ID 取对象

当存在多个同类型对象时，使用 `take_from_sender_by_id` 取出特定对象：

```move
#[test]
fun take_by_id() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let mut scenario = test_scenario::begin(alice);

    let item1 = create(100, scenario.ctx());
    let item2 = create(200, scenario.ctx());
    let id1 = object::id(&item1);

    transfer::public_transfer(item1, alice);
    transfer::public_transfer(item2, alice);

    scenario.next_tx(alice);
    {
        let item = scenario.take_from_sender_by_id<Item>(id1);
        assert_eq!(item.value(), 100);
        scenario.return_to_sender(item);
    };

    scenario.end();
}
```

### 检查对象是否存在

```move
// 在取对象前可以检查是否存在
assert!(scenario.has_most_recent_for_sender<Item>());
```

## 访问共享对象

共享对象使用 `take_shared` 获取，必须用 `return_shared` 归还：

```move
module book::shared_counter;

public struct Counter has key {
    id: UID,
    value: u64,
}

public fun create(ctx: &mut TxContext) {
    transfer::share_object(Counter {
        id: object::new(ctx),
        value: 0,
    })
}

public fun increment(counter: &mut Counter) {
    counter.value = counter.value + 1;
}

public fun value(counter: &Counter): u64 { counter.value }

#[test]
fun shared_object() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let bob = @0xB;
    let mut scenario = test_scenario::begin(alice);

    // Alice 创建共享计数器
    create(scenario.ctx());

    // Bob 递增
    scenario.next_tx(bob);
    {
        let mut counter = scenario.take_shared<Counter>();
        counter.increment();
        assert_eq!(counter.value(), 1);
        test_scenario::return_shared(counter);
    };

    // Alice 再次递增
    scenario.next_tx(alice);
    {
        let mut counter = scenario.take_shared<Counter>();
        counter.increment();
        assert_eq!(counter.value(), 2);
        test_scenario::return_shared(counter);
    };

    scenario.end();
}
```

## 访问不可变对象

冻结的对象使用 `take_immutable` 获取，用 `return_immutable` 归还：

```move
module book::immutable_config;

public struct Config has key {
    id: UID,
    max_value: u64,
}

public fun create(max_value: u64, ctx: &mut TxContext) {
    transfer::freeze_object(Config {
        id: object::new(ctx),
        max_value,
    })
}

public fun max_value(config: &Config): u64 { config.max_value }

#[test]
fun immutable_object() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let mut scenario = test_scenario::begin(alice);

    create(1000, scenario.ctx());

    scenario.next_tx(alice);
    {
        let config = scenario.take_immutable<Config>();
        assert_eq!(config.max_value(), 1000);
        test_scenario::return_immutable(config);
    };

    scenario.end();
}
```

## 读取交易效果（Transaction Effects）

`next_tx` 和 `end` 都返回 `TransactionEffects`，包含交易期间发生的信息：

```move
#[test]
fun transaction_effects() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let bob = @0xB;
    let mut scenario = test_scenario::begin(alice);

    let item1 = create(100, scenario.ctx());
    let item2 = create(200, scenario.ctx());
    transfer::public_transfer(item1, alice);
    transfer::public_transfer(item2, bob);

    let effects = scenario.next_tx(alice);

    assert_eq!(effects.created().length(), 2);
    assert_eq!(effects.transferred_to_account().size(), 2);
    assert_eq!(effects.num_user_events(), 0);

    scenario.end();
}
```

### 效果字段一览

| 方法 | 返回类型 | 描述 |
| --- | --- | --- |
| `created()` | `vector<ID>` | 本交易创建的对象 |
| `written()` | `vector<ID>` | 本交易修改的对象 |
| `deleted()` | `vector<ID>` | 本交易删除的对象 |
| `transferred_to_account()` | `VecMap<ID, address>` | 转移到地址的对象 |
| `shared()` | `vector<ID>` | 本交易共享的对象 |
| `frozen()` | `vector<ID>` | 本交易冻结的对象 |
| `num_user_events()` | `u64` | 发出的事件数 |

## Epoch 和时间操作

使用 `next_epoch` 和 `later_epoch` 测试依赖时间的逻辑：

```move
#[test]
fun epoch_advancement() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let alice = @0xA;
    let mut scenario = test_scenario::begin(alice);

    assert_eq!(scenario.ctx().epoch(), 0);

    scenario.next_epoch(alice);
    assert_eq!(scenario.ctx().epoch(), 1);

    // 同时推进 epoch 和时间
    scenario.later_epoch(1000, alice);
    assert_eq!(scenario.ctx().epoch(), 2);
    assert_eq!(scenario.ctx().epoch_timestamp_ms(), 1000);

    scenario.end();
}
```

## 完整示例：代币转移流程

```move
module book::simple_token;

public struct Token has key, store {
    id: UID,
    amount: u64,
}

public fun mint(amount: u64, ctx: &mut TxContext): Token {
    Token { id: object::new(ctx), amount }
}

public fun amount(token: &Token): u64 { token.amount }

#[test]
fun token_transfer_flow() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let admin = @0xAD;
    let alice = @0xA;
    let bob = @0xB;

    let mut scenario = test_scenario::begin(admin);

    // Admin 为 alice 铸造代币
    {
        let token = mint(1000, scenario.ctx());
        transfer::public_transfer(token, alice);
    };

    // Alice 接收并转移给 bob
    scenario.next_tx(alice);
    {
        assert!(scenario.has_most_recent_for_sender<Token>());
        let token = scenario.take_from_sender<Token>();
        assert_eq!(token.amount(), 1000);
        transfer::public_transfer(token, bob);
    };

    // Bob 接收代币
    scenario.next_tx(bob);
    {
        let token = scenario.take_from_sender<Token>();
        assert_eq!(token.amount(), 1000);
        scenario.return_to_sender(token);
    };

    scenario.end();
}
```

## 函数速查表

| 函数 | 用途 |
| --- | --- |
| `begin(sender)` | 启动新场景 |
| `end(scenario)` | 结束场景并获取最终效果 |
| `next_tx(scenario, sender)` | 推进到下一笔交易 |
| `ctx(scenario)` | 获取 TxContext 可变引用 |
| `take_from_sender<T>` | 从发送者取出拥有的对象 |
| `return_to_sender(obj)` | 归还对象给发送者 |
| `take_shared<T>` | 取出共享对象 |
| `return_shared(obj)` | 归还共享对象 |
| `take_immutable<T>` | 取出不可变对象 |
| `return_immutable(obj)` | 归还不可变对象 |
| `create_system_objects` | 创建 Clock、Random、DenyList |
| `next_epoch` | 推进到下一个 epoch |
| `later_epoch(ms, sender)` | 推进 epoch 并设置时间 |

## 小结

- `test_scenario` 是 Sui Move 中模拟多交易场景的核心工具
- 使用 `begin`/`end` 创建和结束场景，`next_tx` 推进交易
- 对象按所有权类型分别用 `take_from_sender`、`take_shared`、`take_immutable` 获取
- `TransactionEffects` 提供交易结果的详细信息
- `next_epoch` 和 `later_epoch` 用于测试时间相关逻辑
