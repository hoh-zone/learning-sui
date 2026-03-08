# 测试工具函数

除了内置的 `assert!` 宏之外，Move 标准库还提供了常用的测试工具。最重要的工具定义在 `std::unit_test` 模块中。本节将介绍这些工具函数的用法，以及如何设计 `#[test_only]` 辅助函数让测试更高效。

## assert! 宏

`assert!` 是内置的语言特性，是验证测试条件的最基本工具。它接受一个布尔表达式，当表达式为 `false` 时中止执行。

```move
#[test]
fun addition() {
    let sum = 2 + 2;
    assert_eq!(sum, 4);
}
```

在发布的代码中 `assert!` 通常需要第二个参数作为 abort code，但在测试代码中这不是必要的：

```move
// 生产代码中——需要 abort code
assert!(balance >= amount, EInsufficientBalance);

// 测试代码中——abort code 可选
assert!(balance >= amount);
```

## assert_eq! 和 assert_ref_eq!

`assert!` 的局限是：失败时只知道条件为 false，不知道实际值是什么。`assert_eq!` 解决了这个问题——失败时会打印两个比较值：

```move
use std::unit_test::assert_eq;

#[test]
fun test_balance_update() {
    let balance = calculate_balance();
    assert_eq!(balance, 1000); // 失败时显示: "Assertion failed: 750 != 1000"
}
```

按引用比较时使用 `assert_ref_eq!`：

```move
use std::unit_test::assert_ref_eq;

#[test]
fun test_reference_equality() {
    let user = get_user();
    let expected = create_expected_user();
    assert_ref_eq!(&user, &expected);
}
```

## 黑洞函数：destroy

`destroy` 函数可以消耗任何值，无论它具有什么 ability。这对于测试没有 `drop` ability 的类型至关重要：

```move
module book::ticket;

public struct Ticket has key, store {
    id: UID,
    event_id: u64,
    seat: u64,
}

public fun new(event_id: u64, seat: u64, ctx: &mut TxContext): Ticket {
    Ticket { id: object::new(ctx), event_id, seat }
}
```

在测试中使用 `destroy` 清理不可 drop 的值：

```move
use sui::test_utils::destroy;

#[test]
fun ticket_creation() {
    let mut ctx = tx_context::dummy();
    let ticket = ticket::new(1, 42, &mut ctx);

    // 验证通过——但如何处理 ticket？
    destroy(ticket); // 消耗 ticket
}
```

> `destroy` 函数只在测试代码中可用，不能在生产模块中使用。

## 设计 #[test_only] 辅助函数

### 命名规范

建议为仅测试函数添加 `_for_testing` 后缀，便于区分生产代码和测试代码：

```move
#[test_only]
public fun create_wallet_for_testing(balance: u64): Wallet {
    Wallet { balance }
}

#[test_only]
public fun get_balance_for_testing(wallet: &Wallet): u64 {
    wallet.balance
}
```

### 测试辅助模块

可以创建独立的测试辅助模块来集中管理测试工具：

```move
#[test_only]
module book::test_helpers;

use book::game::{Self, GameState};

public fun setup_game_for_testing(ctx: &mut TxContext): GameState {
    let state = game::new(ctx);
    // 设置初始状态...
    state
}

public fun advance_rounds_for_testing(
    state: &mut GameState,
    rounds: u64,
    ctx: &mut TxContext
) {
    let mut i = 0;
    while (i < rounds) {
        game::play_round(state, ctx);
        i = i + 1;
    }
}
```

### 可见性设计

`#[test_only]` 函数通常设为 `public` 或 `public(package)` 可见性，以便其他模块的测试也能调用。由于测试代码在生产构建中被剥离，这不会影响包的公共 API。

```move
#[test_only]
public fun mint_test_coin_for_testing(
    amount: u64,
    ctx: &mut TxContext
): Coin<MY_TOKEN> {
    // 创建测试用代币
    coin::mint_for_testing<MY_TOKEN>(amount, ctx)
}
```

## 小结

- `assert!` 是最基本的断言工具，测试中可省略 abort code
- `assert_eq!` 在失败时打印两个比较值，推荐在测试中优先使用
- `destroy` 函数是"黑洞"，可消耗任何类型的值，解决测试中的清理问题
- 使用 `#[test_only]` 标记辅助函数和模块，建议添加 `_for_testing` 后缀
- 测试辅助函数通常设为 `public` 可见性，方便跨模块测试调用
