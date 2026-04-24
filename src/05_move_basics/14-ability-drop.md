# Drop 能力详解

`drop` 能力决定了结构体实例是否可以被自动丢弃（忽略）。当一个值离开作用域或被赋值覆盖时，如果该类型拥有 `drop` 能力，值会被自动清理；否则编译器会要求开发者显式处理该值。这一机制是 Move 保障数字资产安全的重要组成部分。

## 默认行为：不可丢弃

在 Move 中，结构体默认 **没有** `drop` 能力。这意味着编译器会跟踪每一个实例的生命周期，确保它不会被静默地丢弃：

```move
module book::no_drop;

public struct NoDrop {
    value: u64,
}

public fun create(): NoDrop {
    NoDrop { value: 42 }
}

// 如果函数中创建了 NoDrop 实例但没有处理，编译器会报错
// fun bad_example() {
//     let item = NoDrop { value: 42 };
//     // 编译错误：item 没有 drop 能力，不能被忽略
// }

public fun consume(item: NoDrop) {
    let NoDrop { value: _ } = item; // 必须显式解构
}
```

## 添加 drop 能力

通过 `has drop` 让结构体可以被自动丢弃：

```move
module book::with_drop;

public struct Droppable has drop {
    value: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun auto_drop() {
    let _item = Droppable { value: 42 };
    // 函数结束时，_item 自动被丢弃，无需任何处理
}

#[test]
fun reassign_drops_old() {
    let mut x = Droppable { value: 1 };
    x = Droppable { value: 2 }; // 旧值自动被丢弃
    assert_eq!(x.value, 2);
}
```

## 完整示例

```move
module book::drop_example;

// Without drop - compilation error if ignored
public struct NoDrop {
    value: u64,
}

// With drop - can be safely ignored
public struct Droppable has drop {
    value: u64,
}

#[test]
fun drop_vs_no_drop() {
    // This works - Droppable is automatically dropped
    let _ = Droppable { value: 42 };

    // To use NoDrop, we must explicitly unpack it
    let no_drop = NoDrop { value: 100 };
    let NoDrop { value: _ } = no_drop; // must unpack
}
```

## 安全性价值

`drop` 的设计初衷是保护数字资产。考虑以下场景：

```move
module book::asset_safety;

public struct Coin {
    value: u64,
}

public fun mint(value: u64): Coin {
    Coin { value }
}

public fun burn(coin: Coin): u64 {
    let Coin { value } = coin;
    value
}
```

因为 `Coin` 没有 `drop` 能力，它不能被"凭空消失"。如果函数接收了一个 `Coin` 却没有处理它，编译器会立即报错。这确保了代币不会在转账或交易过程中意外丢失。

## 原生类型的 drop 能力

所有原生类型都拥有 `drop` 能力：

| 类型 | 拥有 drop |
|------|-----------|
| `bool` | ✅ |
| `u8`、`u16`、`u32`、`u64`、`u128`、`u256` | ✅ |
| `address` | ✅ |
| `vector<T>`（当 `T` 有 `drop` 时） | ✅ |

## 标准库中拥有 drop 的类型

以下常用标准库类型拥有 `drop` 能力：

| 类型 | 条件 |
|------|------|
| `Option<T>` | 当 `T` 有 `drop` 时 |
| `String` | 始终有 `drop` |
| `TypeName` | 始终有 `drop` |
| `VecSet<T>` | 当 `T` 有 `drop` 时 |
| `VecMap<K, V>` | 当 `K` 和 `V` 都有 `drop` 时 |

## Witness 模式

Witness（见证者）模式是 `drop` 能力最经典的应用之一。Witness 是一个 **只有 `drop` 能力** 的结构体，通常没有字段（或只有空字段），用于在类型层面进行身份证明：

```move
module book::witness_pattern;

public struct MY_TOKEN has drop {}

public fun create_currency(witness: MY_TOKEN) {
    let MY_TOKEN {} = witness;
    // 使用 witness 证明调用者有权创建此类型的货币
    // witness 被解构后自动丢弃
}
```

### One-Time Witness（OTW）

在 Sui 中，One-Time Witness 是一种特殊的 Witness，它只在模块初始化函数 `init` 中被创建一次，保证了某些操作（如代币发行）全局唯一：

```move
module book::otw_example;

public struct OTW_EXAMPLE has drop {}

fun init(witness: OTW_EXAMPLE) {
    // witness 由系统自动创建并传入，全局只有一次
    // 用于初始化代币、NFT 集合等需要唯一性保证的操作
    let OTW_EXAMPLE {} = witness;
}
```

OTW 的命名规则：类型名必须与模块名相同（全大写），且结构体只有 `drop` 能力、没有字段。

## 条件 drop

对于包含泛型字段的结构体，`drop` 能力取决于所有字段类型是否都拥有 `drop`：

```move
module book::conditional_drop;

public struct Wrapper<T: drop> has drop {
    inner: T,
}

public struct Container<T> {
    content: T,
}

// Wrapper<u64> 有 drop，因为 u64 有 drop
// Container<u64> 没有 drop，因为 Container 本身没有声明 drop
```

## 小结

`drop` 能力是 Move 资源安全模型的关键组成部分。本节核心要点：

- **默认不可丢弃**：结构体默认没有 `drop`，必须显式处理每一个实例
- **添加 `drop`**：通过 `has drop` 允许实例在离开作用域时自动清理
- **安全保障**：不可丢弃的类型确保数字资产不会意外消失
- **原生类型**：所有内置类型（bool、整数、address）天然拥有 `drop`
- **标准库**：`Option<T>`、`String` 等常用类型也拥有 `drop`（可能依赖于泛型参数）
- **Witness 模式**：只有 `drop` 能力的空结构体，用于类型级别的身份证明
- **OTW 模式**：Sui 特有的一次性见证者，保证操作的全局唯一性
