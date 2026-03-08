# 断言与中止

Move 语言中的错误处理机制与大多数编程语言截然不同：它没有 `try/catch` 异常捕获机制。当出现错误时，交易要么完全成功，要么通过中止（abort）回滚所有状态变更。`abort` 用于立即中止执行，`assert!` 宏则提供了一种便捷的条件检查方式——当条件不满足时自动中止。

## abort 关键字

### 基本用法

`abort` 是 Move 的关键字，用于立即停止当前交易的执行。它接受一个 `u64` 类型的错误码作为参数：

```move
module book::abort_basic;

const ENotAllowed: u64 = 0;

public fun only_positive(value: u64): u64 {
    if (value == 0) {
        abort ENotAllowed
    };
    value
}

#[test, expected_failure(abort_code = ENotAllowed)]
fun abort_on_zero() {
    only_positive(0);
}
```

当 `abort` 被触发时，当前交易的所有状态变更都会被撤销，链上不会留下任何修改痕迹，但消耗的 gas 费不会退还。

### abort 的语法形式

`abort` 可以作为表达式使用。由于它永远不会返回值，可以用在任何需要表达式的地方：

```move
module book::abort_expr;

const EInvalidChoice: u64 = 0;

public fun describe(choice: u8): vector<u8> {
    if (choice == 1) {
        b"Option A"
    } else if (choice == 2) {
        b"Option B"
    } else {
        abort EInvalidChoice
    }
}

#[test]
fun describe_ok() {
    assert_eq!(describe(1), b"Option A");
    assert_eq!(describe(2), b"Option B");
}
```

## assert! 宏

### 基本用法

`assert!` 是一个内置宏，它检查一个布尔条件，如果条件为 `false`，则以给定的错误码中止执行：

```move
module book::assert_basic;

const ENotAuthorized: u64 = 0;
const EInvalidAmount: u64 = 1;

public fun transfer_tokens(
    sender: address,
    admin: address,
    amount: u64,
) {
    assert!(sender == admin, ENotAuthorized);
    assert!(amount > 0, EInvalidAmount);
    // 主要逻辑在这里...
}

#[test]
fun valid_transfer() {
    transfer_tokens(@0x1, @0x1, 100);
}

#[test, expected_failure(abort_code = ENotAuthorized)]
fun not_authorized() {
    transfer_tokens(@0x1, @0x2, 100);
}

#[test, expected_failure(abort_code = EInvalidAmount)]
fun invalid_amount() {
    transfer_tokens(@0x1, @0x1, 0);
}
```

`assert!` 本质上是 `if (!condition) abort code` 的语法糖，让代码更加简洁易读。

### 单参数 assert!

在测试中，`assert!` 可以只传一个参数，省略错误码。此时如果条件为 `false`，将以默认错误码中止：

```move
module book::assert_single;

#[test]
fun assert_single_arg() {
    let x = 42;
    assert!(x == 42);       // 仅检查条件，无自定义错误码
    assert!(x > 0);
    assert!(x != 100);
}
```

## 错误常量约定

### 命名规范

Move 社区约定使用 `E` 前缀加大驼峰命名法（EPascalCase）来定义错误常量，类型统一为 `u64`：

```move
module book::error_conventions;

const ENotOwner: u64 = 0;
const EInsufficientBalance: u64 = 1;
const EItemNotFound: u64 = 2;
const EAlreadyExists: u64 = 3;
const EExpired: u64 = 4;

public fun check_owner(caller: address, owner: address) {
    assert!(caller == owner, ENotOwner);
}

public fun check_balance(balance: u64, required: u64) {
    assert!(balance >= required, EInsufficientBalance);
}
```

每个模块内的错误码通常从 0 开始递增，确保每个错误码在模块内是唯一的。

### Move 2024 #[error] 属性

Move 2024 引入了 `#[error]` 属性，允许错误常量使用 `vector<u8>` 类型来提供人类可读的错误信息：

```move
module book::error_attribute;

#[error]
const ECustomNotFound: vector<u8> = b"The requested item was not found";

#[error]
const EInvalidInput: vector<u8> = b"Input validation failed: value out of range";

public fun find_item(id: u64): u64 {
    if (id == 0) {
        abort ECustomNotFound
    };
    id
}

public fun validate(value: u64) {
    assert!(value <= 1000, EInvalidInput);
}

#[test, expected_failure(abort_code = ECustomNotFound)]
fun not_found() {
    find_item(0);
}
```

使用 `#[error]` 属性后，当交易失败时，错误信息会包含在执行结果中，方便开发者和用户理解失败原因。

## 错误处理的最佳实践

### 前置断言模式

最佳实践是将所有的断言检查放在函数主逻辑之前，这样可以在执行任何状态变更前就发现问题，即"先验证，后执行"：

```move
module book::abort_example;

const ENotAuthorized: u64 = 0;
const EInvalidAmount: u64 = 1;
const EInsufficientBalance: u64 = 2;

#[error]
const ECustomError: vector<u8> = b"This is a custom error message";

public fun transfer_tokens(
    sender: address,
    admin: address,
    amount: u64,
) {
    // 所有断言在前
    assert!(sender == admin, ENotAuthorized);
    assert!(amount > 0, EInvalidAmount);
    // 主要逻辑在后...
}

public fun must_be_positive(value: u64): u64 {
    if (value == 0) {
        abort EInvalidAmount
    };
    value
}

#[test]
fun assert_ok() {
    let result = must_be_positive(42);
    assert_eq!(result, 42);
}

#[test, expected_failure(abort_code = EInvalidAmount)]
fun abort_zero() {
    must_be_positive(0);
}
```

### 交易的原子性

由于 Move 没有 `try/catch` 机制，整个交易是原子性的：

- **全部成功**：所有操作都执行完毕，状态变更生效
- **全部回滚**：只要有一个 `abort` 被触发，所有状态变更都被撤销

这种设计简化了安全模型——开发者不需要担心部分执行导致的不一致状态：

```move
module book::atomic_example;

const EStepOneFailed: u64 = 0;
const EStepTwoFailed: u64 = 1;

public fun multi_step_operation(a: u64, b: u64) {
    // 步骤一
    assert!(a > 0, EStepOneFailed);

    // 步骤二
    assert!(b > a, EStepTwoFailed);

    // 如果执行到这里，说明所有检查都通过了
    // 实际操作逻辑...
}

#[test]
fun success() {
    multi_step_operation(5, 10);
}

#[test, expected_failure(abort_code = EStepTwoFailed)]
fun step_two_fails() {
    // 即使步骤一通过了，步骤二失败也会回滚所有变更
    multi_step_operation(5, 3);
}
```

## 小结

Move 的错误处理机制简洁而强大。`abort` 立即中止执行并回滚所有状态变更，`assert!` 宏提供了简洁的条件检查语法。错误常量使用 `E` 前缀的驼峰命名，Move 2024 还引入了 `#[error]` 属性支持可读的错误信息。由于没有 `try/catch` 机制，交易具有完全的原子性——要么全部成功，要么全部回滚。最佳实践是将断言检查放在函数主逻辑之前，确保"先验证，后执行"。
