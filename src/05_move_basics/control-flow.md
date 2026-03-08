# 控制流

控制流语句决定程序的执行路径。Move 支持 `if/else` 条件分支、`while` 循环、`loop` 无限循环，以及 `break`、`continue`、`return` 等流程控制关键字。与大多数语言不同的是，Move 中的 `if/else` 是 **表达式**，可以返回值，这使得代码更加简洁优雅。

## if/else 条件表达式

### 基本语法

`if` 表达式根据布尔条件选择执行路径：

```move
module book::if_basic;

public fun is_positive(n: u64): bool {
    if (n > 0) {
        true
    } else {
        false
    }
}

#[test]
fun if_positive() {
    assert!(is_positive(10));
    assert!(!is_positive(0));
}
```

### 作为表达式使用

`if/else` 可以返回值，此时两个分支的返回类型必须一致：

```move
module book::if_expression;

public fun abs_diff(a: u64, b: u64): u64 {
    if (a > b) { a - b } else { b - a }
}

public fun max(a: u64, b: u64): u64 {
    if (a >= b) { a } else { b }
}

public fun describe(n: u64): vector<u8> {
    if (n == 0) {
        b"zero"
    } else if (n < 10) {
        b"small"
    } else if (n < 100) {
        b"medium"
    } else {
        b"large"
    }
}

#[test]
fun expression_if() {
    assert_eq!(abs_diff(10, 3), 7);
    assert_eq!(abs_diff(3, 10), 7);
    assert_eq!(max(5, 8), 8);
    assert_eq!(describe(0), b"zero");
    assert_eq!(describe(5), b"small");
    assert_eq!(describe(50), b"medium");
    assert_eq!(describe(200), b"large");
}
```

### 无 else 分支

当 `if` 不作为表达式使用时（即不返回值），可以省略 `else` 分支：

```move
module book::if_no_else;

#[test]
fun no_else() {
    let mut result = 0u64;
    let condition = true;

    if (condition) {
        result = 42;
    };

    assert_eq!(result, 42);
}
```

## while 循环

`while` 在条件为 `true` 时重复执行循环体：

```move
module book::while_loop;

public fun sum_to_n(n: u64): u64 {
    let mut i = 0u64;
    let mut sum = 0u64;
    while (i <= n) {
        sum = sum + i;
        i = i + 1;
    };
    sum
}

public fun factorial(n: u64): u64 {
    let mut result = 1u64;
    let mut i = 2u64;
    while (i <= n) {
        result = result * i;
        i = i + 1;
    };
    result
}

#[test]
fun while_sum_factorial() {
    assert_eq!(sum_to_n(10), 55);
    assert_eq!(sum_to_n(0), 0);
    assert_eq!(factorial(5), 120);
    assert_eq!(factorial(1), 1);
}
```

> **注意**：`while` 循环的尾部需要加分号 `;`，因为循环本身是一条语句。

## loop 无限循环

`loop` 创建一个无限循环，必须通过 `break` 或 `return` 退出：

```move
module book::loop_example;

public fun find_first_divisible(v: &vector<u64>, divisor: u64): Option<u64> {
    let mut i = 0;
    loop {
        if (i >= v.length()) {
            break option::none()
        };
        if (v[i] % divisor == 0) {
            break option::some(v[i])
        };
        i = i + 1;
    }
}

#[test]
fun loop_find() {
    let nums = vector[7u64, 11, 15, 22, 31];
    let result = find_first_divisible(&nums, 5);
    assert_eq!(result, option::some(15));

    let no_match = find_first_divisible(&nums, 13);
    assert!(no_match.is_none());
}
```

### loop + break 返回值

`loop` 配合 `break` 可以返回值，这让它可以作为表达式使用：

```move
module book::loop_break_value;

#[test]
fun break_value() {
    let mut i = 0u64;
    let result = loop {
        if (i * i > 100) {
            break i  // 返回第一个平方大于 100 的数
        };
        i = i + 1;
    };

    assert_eq!(result, 11); // 11 * 11 = 121 > 100
}
```

## break 和 continue

### break — 提前退出循环

```move
module book::break_example;

#[test]
fun break_early() {
    let mut sum = 0u64;
    let mut i = 0;

    while (i < 100) {
        if (sum > 50) {
            break       // 总和超过 50 时退出
        };
        sum = sum + i;
        i = i + 1;
    };

    assert!(sum > 50);
}
```

### continue — 跳过当前迭代

```move
module book::continue_example;

#[test]
fun continue_even_sum() {
    let mut sum = 0u64;
    let mut i = 0;

    // 只累加偶数
    while (i < 10) {
        i = i + 1;
        if (i % 2 != 0) {
            continue  // 跳过奇数
        };
        sum = sum + i;
    };

    assert_eq!(sum, 30); // 2 + 4 + 6 + 8 + 10 = 30
}
```

## return — 提前返回

`return` 可以在函数中任意位置提前返回值：

```move
module book::return_example;

public fun find_first_even(v: &vector<u64>): Option<u64> {
    let mut i = 0;
    while (i < v.length()) {
        if (v[i] % 2 == 0) {
            return option::some(v[i])  // 找到偶数，立即返回
        };
        i = i + 1;
    };
    option::none()  // 没有找到
}

public fun validate_range(value: u64, min: u64, max: u64): bool {
    if (value < min) return false;
    if (value > max) return false;
    true
}

#[test]
fun return_find_even() {
    let nums = vector[1u64, 3, 5, 4, 7];
    let first_even = find_first_even(&nums);
    assert_eq!(first_even, option::some(4));

    let no_even = find_first_even(&vector[1u64, 3, 5]);
    assert!(no_even.is_none());

    assert!(validate_range(5, 1, 10));
    assert!(!validate_range(15, 1, 10));
}
```

## Gas 消耗与无限循环

在区块链环境中，每条指令都会消耗 Gas。如果循环没有正确的退出条件，将会耗尽所有 Gas 并导致交易失败：

```move
module book::gas_warning;

// ⚠️ 危险：无限循环会耗尽 Gas
// fun infinite() {
//     loop {
//         // 没有 break，Gas 耗尽后 abort
//     };
// }

public fun safe_loop(limit: u64): u64 {
    let mut count = 0u64;
    loop {
        if (count >= limit) break count;
        count = count + 1;
    }
}

#[test]
fun safe_loop_ok() {
    assert_eq!(safe_loop(100), 100);
}
```

> **最佳实践**：始终确保循环有明确的退出条件。使用 `while` 时检查边界条件，使用 `loop` 时确保有 `break` 或 `return`。

## 综合示例

下面的例子综合展示了各种控制流语句的配合使用：

```move
module book::control_flow_example;

public fun abs_diff(a: u64, b: u64): u64 {
    if (a > b) { a - b } else { b - a }
}

public fun sum_to_n(n: u64): u64 {
    let mut i = 0u64;
    let mut sum = 0u64;
    while (i <= n) {
        sum = sum + i;
        i = i + 1;
    };
    sum
}

public fun find_first_even(v: &vector<u64>): Option<u64> {
    let mut i = 0;
    loop {
        if (i >= v.length()) {
            return option::none()
        };
        if (v[i] % 2 == 0) {
            return option::some(v[i])
        };
        i = i + 1;
    }
}

public fun sum_even_numbers(v: &vector<u64>): u64 {
    let mut sum = 0u64;
    let mut i = 0;
    while (i < v.length()) {
        i = i + 1;
        if (v[i - 1] % 2 != 0) {
            continue
        };
        sum = sum + v[i - 1];
    };
    sum
}

#[test]
fun control_flow_all() {
    assert_eq!(abs_diff(10, 3), 7);
    assert_eq!(abs_diff(3, 10), 7);
    assert_eq!(sum_to_n(10), 55);

    let nums = vector[1u64, 3, 5, 4, 7];
    let first_even = find_first_even(&nums);
    assert_eq!(first_even, option::some(4));

    let mixed = vector[1u64, 2, 3, 4, 5, 6];
    assert_eq!(sum_even_numbers(&mixed), 12); // 2 + 4 + 6
}
```

## 小结

控制流是程序逻辑的基本构建块。本节核心要点：

- **if/else**：条件分支，可以作为表达式返回值，两个分支的类型必须一致
- **while**：条件循环，条件为 `true` 时重复执行
- **loop**：无限循环，必须通过 `break` 或 `return` 退出
- **break**：提前退出循环，可以携带返回值
- **continue**：跳过当前迭代的剩余部分
- **return**：提前退出函数并返回值
- **Gas 安全**：循环必须有明确的退出条件，避免无限循环导致 Gas 耗尽
