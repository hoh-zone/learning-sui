# 使用系统对象

某些测试需要系统对象如 `Clock`、`Random` 或 `DenyList`。这些对象在网络上拥有固定地址，在创世时创建。但在测试中它们默认不存在，因此 Sui Framework 提供了 `#[test_only]` 函数来创建和操控它们。

## Clock

`Clock` 提供当前网络时间戳。使用 `clock::create_for_testing` 创建，并通过测试专用函数操控时间：

```move
use std::unit_test::assert_eq;
use sui::clock;
use sui::test_utils::destroy;

#[test]
fun clock() {
    let mut ctx = tx_context::dummy();
    let mut clock = clock::create_for_testing(&mut ctx);

    // 初始时间为 0
    assert_eq!(clock.timestamp_ms(), 0);

    // 增加时间（毫秒）
    clock.increment_for_testing(1000);
    assert_eq!(clock.timestamp_ms(), 1000);

    // 设置绝对时间（必须 >= 当前时间）
    clock.set_for_testing(5000);
    assert_eq!(clock.timestamp_ms(), 5000);

    // 清理——Clock 没有 drop ability
    destroy(clock);
}
```

### 在 Test Scenario 中共享 Clock

```move
#[test]
fun shared_clock() {
    let mut ctx = tx_context::dummy();
    let clock = clock::create_for_testing(&mut ctx);
    clock.share_for_testing();
}
```

## Random

`Random` 对象提供链上随机性。推荐的做法是让核心逻辑接受 `RandomGenerator` 参数，这样在单元测试中可以直接创建 generator，绕过 `Random` 对象：

```move
use sui::random::{Self, Random, RandomGenerator};

entry fun my_entry_function(r: &Random, ctx: &mut TxContext) {
    let mut gen = random::new_generator(r, ctx);
    let result = inner_function(&mut gen);
    result.destroy_or!(abort);
}

public(package) fun inner_function(gen: &mut RandomGenerator): Option<u64> {
    if (gen.generate_bool()) {
        option::some(gen.generate_u64())
    } else {
        option::none()
    }
}

#[test]
fun simple_random() {
    // 确定性结果，总是相同的值
    let mut gen = random::new_generator_for_testing();
    assert!(inner_function(&mut gen).is_none());

    // 确定性结果（相同种子可复现）
    let seed = b"Arbitrary seed bytes";
    let mut gen = random::new_generator_from_seed_for_testing(seed);
    assert!(inner_function(&mut gen).is_some());
}
```

### 在 Test Scenario 中使用完整 Random 对象

```move
use sui::random::{Self, Random};
use sui::test_scenario;

#[test]
fun random_shared() {
    let mut scenario = test_scenario::begin(@0x0);

    random::create_for_testing(scenario.ctx());
    scenario.next_tx(@0x0);

    let mut random = scenario.take_shared<Random>();

    // 初始化随机状态（使用前必须）
    random.update_randomness_state_for_testing(
        0,
        x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
        scenario.ctx(),
    );

    my_entry_function(&random, scenario.ctx());

    test_scenario::return_shared(random);
    scenario.end();
}
```

## DenyList

`DenyList` 用于受监管代币的地址黑名单。使用 `new_for_testing` 创建本地实例，或 `create_for_testing` 创建共享实例：

```move
use sui::deny_list;
use sui::test_scenario;
use sui::test_utils::destroy;

#[test]
fun deny_list() {
    let mut scenario = test_scenario::begin(@0x0);

    // 创建本地实例用于简单测试
    let deny_list = deny_list::new_for_testing(scenario.ctx());
    destroy(deny_list);

    // 或创建共享的 DenyList
    deny_list::create_for_testing(scenario.ctx());
    scenario.next_tx(@0x0);
    // ... take_shared 并使用

    scenario.end();
}
```

## Coin 和 Balance

使用 `coin::mint_for_testing` 和 `balance::create_for_testing` 创建测试用代币：

```move
use std::unit_test::assert_eq;
use sui::coin;
use sui::balance;
use sui::sui::SUI;

#[test]
fun coins() {
    let mut ctx = tx_context::dummy();

    // 创建任意类型的代币
    let coin = coin::mint_for_testing<SUI>(1000, &mut ctx);
    assert_eq!(coin.value(), 1000);

    // 销毁并取回值
    let value = coin.burn_for_testing();
    assert_eq!(value, 1000);

    // 直接创建 Balance
    let balance = balance::create_for_testing<SUI>(500);
    let value = balance.destroy_for_testing();
    assert_eq!(value, 500);
}
```

## 一次创建所有系统对象

在 Test Scenario 中使用 `create_system_objects` 一次性创建所有系统对象（Clock、Random、DenyList）：

```move
use sui::clock::Clock;
use sui::random::Random;
use sui::deny_list::DenyList;
use sui::test_scenario;

#[test]
fun with_all_system_objects() {
    let mut scenario = test_scenario::begin(@0xA);

    // 一次性创建 Clock、Random 和 DenyList
    scenario.create_system_objects();
    scenario.next_tx(@0xA);

    let clock = scenario.take_shared<Clock>();
    let random = scenario.take_shared<Random>();
    let deny_list = scenario.take_shared<DenyList>();

    // ... 使用这些对象 ...

    test_scenario::return_shared(clock);
    test_scenario::return_shared(random);
    test_scenario::return_shared(deny_list);

    scenario.end();
}
```

> 测试中创建的系统对象不会拥有与活跃网络上相同的固定地址。使用 `take_shared<T>()` 按类型而非按 ID 来访问它们。

## 速查表

| 对象 | 创建方式 | 测试专用功能 |
| --- | --- | --- |
| `Clock` | `clock::create_for_testing(ctx)` | `increment_for_testing`, `set_for_testing` |
| `Random` | `random::create_for_testing(ctx)` | `update_randomness_state_for_testing` |
| `RandomGenerator` | `random::new_generator_for_testing()` | `new_generator_from_seed_for_testing` |
| `DenyList` | `deny_list::create_for_testing(ctx)` | `new_for_testing` |
| `Coin<T>` | `coin::mint_for_testing<T>(value, ctx)` | `burn_for_testing` |
| `Balance<T>` | `balance::create_for_testing<T>(value)` | `destroy_for_testing` |
| 全部系统对象 | `scenario.create_system_objects()` | 创建 Clock、Random、DenyList |

## 小结

- 系统对象在测试中默认不存在，需要通过 `*_for_testing` 函数创建
- `Clock` 可通过 `increment_for_testing` 和 `set_for_testing` 操控时间
- `Random` 推荐通过 `RandomGenerator` 方式测试，避免 `entry` 函数的限制
- `coin::mint_for_testing` 和 `balance::create_for_testing` 是创建测试代币的便捷方式
- `create_system_objects` 可在 Test Scenario 中一次性创建所有系统对象
