# 好的测试特征

编写测试是一回事，编写 _好的_ 测试是另一回事。一个仅仅存在但无法真正发现 bug 的测试套件只会带来虚假的安全感。本节将介绍区分高效测试与形式测试的原则和实践，帮助你写出简洁、可读、可维护的智能合约测试。

## 好测试的特征

### 1. 测试应当简洁

每个测试应简短明了，聚焦于单一行为或场景。避免编写过长、过于复杂的测试。

### 2. 测试应当可读

测试是代码行为的文档。任何人阅读测试时都应能快速理解：正在测试什么场景、期望的结果是什么。推荐使用 Arrange-Act-Assert 模式：

```move
#[test]
fun add_increases_balance_by_specified_amount() {
    // Arrange: 准备初始状态
    let mut balance = balance::new(100);

    // Act: 执行被测操作
    balance.add(50);

    // Assert: 验证期望结果
    assert_eq!(balance.value(), 150);
}
```

### 3. 每个测试只测一件事

每个测试应验证单一行为。当测试失败时，你应立即知道是什么出了问题。

```move
module book::single_responsibility;

public struct Counter has copy, drop { value: u64 }

public fun increment(c: &mut Counter) { c.value = c.value + 1; }
public fun decrement(c: &mut Counter) { c.value = c.value - 1; }

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun increment_adds_one() {
    let mut counter = Counter { value: 0 };
    counter.increment();
    assert_eq!(counter.value, 1);
}

#[test]
fun decrement_subtracts_one() {
    let mut counter = Counter { value: 1 };
    counter.decrement();
    assert_eq!(counter.value, 0);
}
```

## 测试什么

### 测试合约行为，而非实现

关注函数的可观察行为——它返回什么、产生什么副作用——而非内部实现细节。这允许你在重构实现时不破坏测试。

### 测试边界条件

边界条件是 bug 的高发区。对于数值运算应考虑：

- 零值
- 最大值（`U64_MAX`、`U128_MAX`）
- 边界条件（off-by-one 错误）
- 空集合

```move
module book::edge_cases;

public fun safe_divide(a: u64, b: u64): u64 {
    if (b == 0) return 0;
    a / b
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun divide_normal_case() {
    assert_eq!(safe_divide(10, 2), 5);
}

#[test]
fun divide_by_zero_returns_zero() {
    assert_eq!(safe_divide(10, 0), 0);
}

#[test]
fun divide_zero_by_nonzero() {
    assert_eq!(safe_divide(0, 5), 0);
}
```

### 测试异常路径

验证代码在非法输入下是否正确失败。使用 `#[expected_failure]` 验证函数是否以正确的错误码中止：

```move
module book::error_conditions;

const EInsufficientBalance: u64 = 1;

public struct Wallet has copy, drop { balance: u64 }

public fun withdraw(wallet: &mut Wallet, amount: u64) {
    assert!(wallet.balance >= amount, EInsufficientBalance);
    wallet.balance = wallet.balance - amount;
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun withdraw_succeeds_with_sufficient_balance() {
    let mut wallet = Wallet { balance: 100 };
    wallet.withdraw(50);
    assert_eq!(wallet.balance, 50);
}

#[test, expected_failure(abort_code = EInsufficientBalance)]
fun withdraw_fails_with_insufficient_balance() {
    let mut wallet = Wallet { balance: 50 };
    wallet.withdraw(100);
}
```

## 测试组织

### 使用描述性命名

测试名称应描述场景和预期结果。推荐命名规范：`test_<函数>_<场景>_<预期结果>`。

```move
// 好的命名
fun withdraw_with_zero_balance_aborts() { ... }
fun transfer_to_self_succeeds() { ... }

// 差的命名
fun test1() { ... }
fun withdraw() { ... }
```

### 分组组织测试

按函数或特性逻辑分组测试。在 Move 中，可以将测试放在与被测代码相同的模块中，也可以放在独立的 `tests/` 目录中的 `*_tests.move` 文件里。

## 测试金字塔

一个平衡的测试套件通常遵循测试金字塔：

1. **单元测试**（基础）：大量小型、快速的测试，验证独立的函数
2. **集成测试**（中间）：较少的测试，验证组件如何协同工作
3. **端到端测试**（顶部）：少量测试，验证完整的用户场景

在 Move 中所有测试都以单元测试形式实现，但通过 Test Scenario 可以在单个测试中测试多个交易和用户操作。

## 常见测试错误

### 只测试正常路径

不要只测试代码在一切正确时的表现。务必测试非法输入、边界条件和错误情况下的行为。

### 过度模拟

虽然隔离性很重要，但过度模拟可能导致测试通过但真实集成却失败。在单元测试和使用真实组件的集成测试之间取得平衡。

### 忽视测试维护

测试也是代码。保持它们整洁，删除过时的测试，在需求变更时更新它们。被忽视的测试套件会成为负担而非资产。

## 追求合理的覆盖率

高测试覆盖率是积极的指标，但不应成为编写测试的唯一目标。仅为提高覆盖率而存在的测试——却不验证有意义的行为——只会带来虚假的信心。**先写有意义的测试，好的覆盖率自然而来。**

## 小结

- 好的测试应简洁、可读、每次只测一件事
- 遵循 Arrange-Act-Assert 模式组织测试代码
- 全面测试正常路径、异常路径和边界条件
- 使用描述性命名，按功能分组组织测试
- 追求合理覆盖率但不以数字为目标，测试也需要维护
