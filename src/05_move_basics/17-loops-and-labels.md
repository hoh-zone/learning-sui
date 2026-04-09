# 循环与带标签控制流

Move 支持 `while` 条件循环、`loop` 无限循环，以及 `break`、`continue`、`return` 等流程控制。在嵌套循环或块中，可以使用 **标签** 精确指定跳转目标。

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

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun while_sum() {
    assert_eq!(sum_to_n(10), 55);
}
```

> **注意**：`while` 循环的尾部需要加分号 `;`，因为循环本身是一条语句。

## loop 无限循环

`loop` 创建一个无限循环，必须通过 `break` 或 `return` 退出。配合 `break` 可以返回值，作为表达式使用：

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
```

## break 和 continue

`break` 提前退出循环，可携带返回值；`continue` 跳过当前迭代的剩余部分：

```move
module book::break_continue;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun break_early() {
    let mut sum = 0u64;
    let mut i = 0;
    while (i < 100) {
        if (sum > 50) break;
        sum = sum + i;
        i = i + 1;
    };
    assert_eq!(sum, 55);
}

#[test]
fun continue_even_sum() {
    let mut sum = 0u64;
    let mut i = 0;
    while (i < 10) {
        i = i + 1;
        if (i % 2 != 0) continue;
        sum = sum + i;
    };
    assert_eq!(sum, 30); // 2 + 4 + 6 + 8 + 10
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
            return option::some(v[i])
        };
        i = i + 1;
    };
    option::none()
}
```

## Gas 消耗与无限循环

在区块链环境中，每条指令都会消耗 Gas。循环必须有明确的退出条件，避免无限循环导致 Gas 耗尽。

## 带标签的控制流

在嵌套循环或块中，可以用 **标签** 精确指定 `break`、`continue` 或 `return` 的目标，格式为 `'label:`。

### 循环标签

给 `loop` 或 `while` 加上标签后，`break 'label value` 会直接跳出到该标签对应的循环并携带返回值；`continue 'label` 会跳到该循环的下一次迭代：

```move
module book::labeled_loop;

public fun sum_until_threshold(input: &vector<vector<u64>>, threshold: u64): u64 {
    let mut sum = 0u64;
    let mut i = 0u64;
    let len = input.length();

    'outer: loop {
        if (i >= len) break sum;
        let vec = &input[i];
        let mut j = 0u64;
        while (j < vec.length()) {
            let v_entry = vec[j];
            if (sum + v_entry < threshold) {
                sum = sum + v_entry;
            } else {
                break 'outer sum
            };
            j = j + 1;
        };
        i = i + 1;
    }
}
```

### 块标签与 return

给**块**加标签后，可以在块内使用 `return 'label value` 从该块“返回”一个值，作为整个块表达式的值。`return` 只能用于块标签；`break`/`continue` 只能用于循环标签。

## 小结

- **while**：条件循环，尾部需加分号
- **loop**：无限循环，必须通过 `break` 或 `return` 退出；`break` 可携带返回值
- **break / continue / return**：控制流程
- **标签**：`'label:` 用于循环或块，精确指定跳转目标
- **Gas 安全**：循环必须有明确退出条件
