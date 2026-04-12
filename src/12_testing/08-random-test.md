# 随机输入测试

Move 编译器支持通过 `#[random_test]` 属性运行带有随机输入的测试。这实现了基于属性的测试（Property-based Testing），让测试使用随机生成的值多次运行，自动发现你可能想不到的边界情况。

> `#[random_test]` 是编译器的测试输入特性，与链上随机性的 `sui::random` 模块是不同的概念。

## 基本用法

用 `#[random_test]` 标记函数并声明原始类型参数。测试运行器会在运行时为每个参数生成随机值：

```move
module book::math;

public fun safe_add(a: u64, b: u64): u64 {
    if (a > 0xFFFFFFFFFFFFFFFF - b) {
        0xFFFFFFFFFFFFFFFF // 饱和到最大值
    } else {
        a + b
    }
}

#[random_test]
fun safe_add_never_overflows(a: u64, b: u64) {
    let result = safe_add(a, b);
    // 结果应始终 >= 两个输入（无溢出回绕）
    assert!(result >= a && result >= b);
}
```

## 支持的类型

| 类型 | 生成范围 |
| --- | --- |
| `u8`, `u16`, `u32`, `u64`, `u128`, `u256` | 类型的完整范围 |
| `bool` | `true` 或 `false` |
| `address` | 随机 32 字节地址 |
| `vector<T>` | 随机长度、随机元素 |

其中 `vector<T>` 的 `T` 必须是原始类型或另一个 vector。

## 实用技巧

### 约束大整数

如果函数期望较小的值，使用小类型并做类型转换：

```move
#[random_test]
fun with_bounded_input(small: u8) {
    let bounded = (small as u64) % 100; // 0-99 范围
    // ... 使用 bounded 值测试
}
```

### 避免无界 vector

`vector<u8>` 可能生成非常大的 vector，导致测试缓慢或 Gas 错误。优先使用固定大小的输入：

```move
// 避免：可能生成巨大 vector
#[random_test]
fun bad(v: vector<u8>) { /* ... */ }

// 更好：控制大小
#[random_test]
fun good(a: u8, b: u8, c: u8) {
    let v = vector[a, b, c];
    // ... 使用已知大小的 vector 测试
}
```

### 与定向测试互补

随机测试发现意外的边界情况，但可能遗漏特定场景。与定向单元测试配合使用：

```move
use std::unit_test::assert_eq;

// 定向测试：特定场景
#[test]
fun add_zero() {
    assert_eq!(safe_add(std::u64::max(), 0), std::u64::max());
}

// 随机测试：通用属性
#[random_test]
fun add_commutative(a: u64, b: u64) {
    assert_eq!(safe_add(a, b), safe_add(b, a));
}
```

### 使用 assert_eq! 改善调试

随机测试失败时，你需要知道哪些值导致了失败。`assert_eq!` 会在失败时打印两个比较值：

```move
use std::unit_test::assert_eq;

#[random_test]
fun double(value: u64) {
    let doubled = value * 2;
    // 失败时显示: "Assertion failed: <actual> != <expected>"
    assert_eq!(doubled / 2, value);
}
```

## 控制测试运行

### 迭代次数

默认情况下随机测试会以不同输入运行多次。使用 `--rand-num-iters` 控制迭代次数：

```bash
# 每个随机测试运行 100 次
sui move test --rand-num-iters 100
```

### 可复现的种子

当随机测试失败时，输出会包含种子和复现说明：

```
┌── test_that_failed ────── (seed = 2033439370411573084)
│ ...
│ This test uses randomly generated inputs. Rerun with
│ `sui move test test_that_failed --seed 2033439370411573084`
│ to recreate this test failure.
└──────────────────
```

使用提供的种子精确复现失败：

```bash
sui move test test_that_failed --seed 2033439370411573084
```

## 局限性

- **无范围约束**：不能直接限制随机值到特定范围，需用取模或类型转换
- **Vector 大小**：无法控制生成的 vector 长度

## 小结

- 使用 `#[random_test]`（非 `#[test]`）启用函数参数的随机化输入
- 参数必须是原始类型或原始类型的 vector
- 使用小类型和类型转换约束输入，避免极端值
- 使用 `assert_eq!` 获得更好的失败诊断信息
- 通过 `--rand-num-iters` 控制迭代次数，`--seed` 复现失败
- 随机测试是定向单元测试的补充，而非替代
