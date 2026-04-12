# 错误处理最佳实践

本节讲解 Move 合约中的错误处理策略。良好的错误处理不仅能帮助调试，还能向用户提供有意义的反馈。我们将介绍错误码设计、分类策略和三条核心规则。

**与全书一致**：新代码请优先使用 **`#[error]` + `vector<u8>`**（Clever Errors），见[第五章 · 断言与中止](../05_move_basics/18-assert-and-abort.md)。下文仍保留 **`u64` 数值码**的写法与分类策略，因为存量合约、按**整数**做前端映射、以及「稳定可枚举码」场景仍常见；**命名规则（`EPascalCase`）与「一义一码」原则**对两种表示法都适用。

## Move 中的错误机制

当执行遇到 `abort` 时，交易失败并返回中止码（abort code）。Move VM 会返回中止交易的模块名称和中止码。但这种行为对调用者来说不够透明，特别是当一个函数包含多个可能中止的调用时。

### 问题场景

```move
module book::module_a;

use book::module_b;

public fun do_something() {
    let field_1 = module_b::get_field(1); // 可能以 abort code 0 中止
    /* ... 大量逻辑 ... */
    let field_2 = module_b::get_field(2); // 可能以 abort code 0 中止
    /* ... 更多逻辑 ... */
    let field_3 = module_b::get_field(3); // 可能以 abort code 0 中止
}
```

如果调用者收到 abort code `0`，无法确定是哪个调用失败了。

## 三条核心规则

### 规则一：处理所有可能的场景

在调用可能中止的函数之前，先用安全的检查函数验证：

```move
module book::module_a;

use book::module_b;

const ENoField: u64 = 0;

public fun do_something() {
    assert!(module_b::has_field(1), ENoField);
    let field_1 = module_b::get_field(1);
    /* ... */
    assert!(module_b::has_field(2), ENoField);
    let field_2 = module_b::get_field(2);
    /* ... */
    assert!(module_b::has_field(3), ENoField);
    let field_3 = module_b::get_field(3);
}
```

通过在每次调用前添加自定义检查，开发者掌握了错误处理的控制权。

### 规则二：使用不同的错误码

为每个失败场景分配唯一的错误码：

```move
module book::module_a;

use book::module_b;

const ENoFieldA: u64 = 0;
const ENoFieldB: u64 = 1;
const ENoFieldC: u64 = 2;

public fun do_something() {
    assert!(module_b::has_field(1), ENoFieldA);
    let field_1 = module_b::get_field(1);
    /* ... */
    assert!(module_b::has_field(2), ENoFieldB);
    let field_2 = module_b::get_field(2);
    /* ... */
    assert!(module_b::has_field(3), ENoFieldC);
    let field_3 = module_b::get_field(3);
}
```

现在调用者可以精确定位问题：abort code `0` 表示 "字段 1 不存在"，`1` 表示 "字段 2 不存在"，依此类推。

### 规则三：返回 bool 而非 assert

不要暴露一个公共的 assert 函数，而是提供返回 bool 的检查函数：

```move
// 不推荐：暴露断言函数
module book::some_app_assert;

const ENotAuthorized: u64 = 0;

public fun do_a() {
    assert_is_authorized();
    // ...
}

/// 不要这样做
public fun assert_is_authorized() {
    assert!(/* 某个条件 */ true, ENotAuthorized);
}
```

```move
// 推荐：暴露布尔函数
module book::some_app;

const ENotAuthorized: u64 = 0;

public fun do_a() {
    assert!(is_authorized(), ENotAuthorized);
    // ...
}

public fun do_b() {
    assert!(is_authorized(), ENotAuthorized);
    // ...
}

/// 返回 bool，让调用者决定如何处理
public fun is_authorized(): bool {
    /* 某个条件 */ true
}

// 内部使用的断言函数仍然可以存在
fun assert_is_authorized() {
    assert!(is_authorized(), ENotAuthorized);
}
```

## 错误码设计规范

### 命名约定

错误常量使用 `EPascalCase` 前缀：

```move
// 正确：EPascalCase
const ENotAuthorized: u64 = 0;
const EInsufficientBalance: u64 = 1;
const EObjectNotFound: u64 = 2;

// 错误：ALL_CAPS 用于普通常量
const NOT_AUTHORIZED: u64 = 0; // 不推荐
```

### 分类编号策略

按模块功能分组分配错误码：

```move
module my_protocol::marketplace;

// 权限错误：0-9
const ENotOwner: u64 = 0;
const ENotAdmin: u64 = 1;
const ENotApproved: u64 = 2;

// 输入验证错误：10-19
const EInvalidPrice: u64 = 10;
const EInvalidQuantity: u64 = 11;
const EInvalidName: u64 = 12;

// 状态错误：20-29
const EAlreadyListed: u64 = 20;
const ENotListed: u64 = 21;
const EAlreadySold: u64 = 22;

// 余额错误：30-39
const EInsufficientBalance: u64 = 30;
const EInsufficientPayment: u64 = 31;

// 版本/系统错误：100+
const EInvalidPackageVersion: u64 = 100;
const EDeprecated: u64 = 101;
```

### 前端错误码映射

```typescript
const ERROR_MESSAGES: Record<number, string> = {
  0: '您没有权限执行此操作',
  1: '需要管理员权限',
  10: '价格无效，请输入正数',
  11: '数量无效',
  20: '该物品已上架',
  21: '该物品未上架',
  30: '余额不足',
  100: '合约版本不兼容，请刷新页面',
};

function getErrorMessage(abortCode: number): string {
  return ERROR_MESSAGES[abortCode] ?? `未知错误 (代码: ${abortCode})`;
}
```

## 高级模式

### 错误上下文包装

当需要区分同一模块中不同位置的相同类型错误时：

```move
const ETransferFailed_SenderCheck: u64 = 40;
const ETransferFailed_ReceiverCheck: u64 = 41;
const ETransferFailed_AmountCheck: u64 = 42;

public fun transfer(
    from: &mut Account,
    to: &mut Account,
    amount: u64,
) {
    assert!(from.is_active(), ETransferFailed_SenderCheck);
    assert!(to.is_active(), ETransferFailed_ReceiverCheck);
    assert!(from.balance >= amount, ETransferFailed_AmountCheck);
    // ...
}
```

### 优雅降级

对于非关键操作，考虑返回结果而非中止：

```move
/// 尝试装备武器，返回操作结果
public fun try_equip_weapon(
    hero: &mut Hero,
    weapon: Weapon,
): (bool, Option<Weapon>) {
    if (hero.weapon.is_some()) {
        // 已有武器，返回失败和未使用的武器
        (false, option::some(weapon))
    } else {
        hero.weapon.fill(weapon);
        (true, option::none())
    }
}
```

## 测试错误处理

对 **`#[error]`** 常量，测试中优先使用 **`#[test, expected_failure]`**（省略 `abort_code`），避免 clever 编码随源码行变化导致脆弱测试。仅当错误为**稳定 `u64` 常量**时，可使用 `expected_failure(abort_code = E...)`。

```move
#[test, expected_failure]
fun unauthorized_access_fails() {
    let ctx = &mut tx_context::dummy();
    unauthorized_action(ctx);
    abort 0xFF // 如果执行到这里说明测试失败
}

#[test]
fun error_returns_correct_code() {
    // 验证 is_authorized 返回正确的布尔值
    assert!(!is_authorized_for(@0x0));
    assert!(is_authorized_for(@0x1));
}
```

## 小结

- 遵循三条核心规则：处理所有场景、使用不同错误码、返回 bool 而非 assert
- 错误常量使用 `EPascalCase` 命名约定
- 按功能分组分配错误码，便于定位和维护
- 在前端维护错误码到用户友好消息的映射
- 提供 `is_*` 检查函数让调用者在中止前验证条件
- 对非关键操作考虑优雅降级（返回结果而非中止）
- 用 `expected_failure` 覆盖错误路径：优先无 `abort_code`（配合 `#[error]`）；稳定 `u64` 码可填 `abort_code`
