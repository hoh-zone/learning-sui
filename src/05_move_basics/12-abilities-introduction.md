# 能力系统概览（Abilities）

能力系统（Abilities）是 Move 语言最独特的类型系统特性之一，它通过四种能力——`copy`、`drop`、`key`、`store`——来精确控制类型的行为。不同于大多数编程语言中类型可以被随意复制和丢弃，Move 要求开发者显式声明类型的行为权限，从而在编译期保障链上资源的安全性。

## 能力声明

能力通过 `has` 关键字声明在结构体定义中：

```move
module book::ability_syntax;

// 同时拥有多个能力，用逗号分隔
public struct Token has key, store {
    id: UID,
    value: u64,
}

// 没有任何能力的结构体
public struct Unique {
    value: u64,
}
```

## 四种能力详解

### copy —— 可复制

拥有 `copy` 能力的类型，其值可以被隐式复制。没有 `copy` 的值在赋值或传参时会被 **移动**（move），原变量将不可再使用：

```move
module book::ability_copy;

public struct Copyable has copy, drop {
    value: u64,
}

public struct NonCopyable has drop {
    value: u64,
}

#[test]
fun copy_vs_move() {
    let a = Copyable { value: 42 };
    let b = a;  // 复制，a 仍然可用
    assert_eq!(a.value, 42);
    assert_eq!(b.value, 42);

    let c = NonCopyable { value: 100 };
    let d = c;  // 移动，c 不再可用
    // assert!(c.value == 100); // 编译错误！c 已被移动
    assert_eq!(d.value, 100);
}
```

### drop —— 可丢弃

拥有 `drop` 能力的类型，其值可以在离开作用域时被自动丢弃。没有 `drop` 的值必须被显式消费（解构或转移）：

```move
module book::ability_drop;

public struct Droppable has drop {
    value: u64,
}

public struct MustUse {
    value: u64,
}

public fun consume(item: MustUse) {
    let MustUse { value: _ } = item; // 必须显式解构
}
```

### key —— 可作为存储键

拥有 `key` 能力的类型可以作为链上对象存在。在 Sui 中，`key` 结构体的第一个字段必须是 `id: UID`：

```move
module book::ability_key;

public struct MyObject has key {
    id: UID,
    data: u64,
}
```

`key` 是将结构体变为 Sui 对象的必要条件。拥有 `key` 的对象可以被转移、共享或冻结。

### store —— 可存储

拥有 `store` 能力的类型可以被存储在其他拥有 `key` 的对象内部。`store` 也是对象能被公开转移（`public_transfer`）的必要条件：

```move
module book::ability_store;

use std::string::String;

public struct Metadata has store, copy, drop {
    name: String,
    version: u64,
}

public struct Container has key, store {
    id: UID,
    metadata: Metadata,  // Metadata 有 store，可以存在对象中
}
```

## 能力组合总览

| 能力组合 | 含义 | 典型用途 |
|----------|------|----------|
| 无能力 | 不可复制、不可丢弃、不可存储 | Hot Potato 模式 |
| `drop` | 可丢弃 | Witness 模式 |
| `copy, drop` | 可复制、可丢弃 | 纯数据/值类型 |
| `key` | 链上对象 | 不可转移的对象 |
| `key, store` | 可转移的链上对象 | NFT、代币等 |
| `store, copy, drop` | 可存储的值类型 | 嵌入对象的元数据 |
| `key, store, copy, drop` | 完全能力对象 | 较少见 |

## 内置类型的能力

所有原始类型天然拥有 `copy`、`drop` 和 `store`：

| 类型 | 能力 |
|------|------|
| `bool` | `copy`, `drop`, `store` |
| `u8` ~ `u256` | `copy`, `drop`, `store` |
| `address` | `copy`, `drop`, `store` |
| `&T`、`&mut T` | `copy`, `drop` |
| `vector<T>` | 取决于 `T` 的能力 |

## 完整示例

```move
module book::abilities_example;

// Has all four abilities - can be copied, dropped, stored as object
public struct FullAbility has key, store, copy, drop {
    id: UID,
    value: u64,
}

// Can be copied and dropped but not stored
public struct Copyable has copy, drop {
    value: u64,
}

// No abilities - Hot Potato! Must be explicitly consumed
public struct HotPotato {
    value: u64,
}

// Only drop - Witness pattern
public struct Witness has drop {}
```

## 能力约束与泛型

在泛型函数或泛型结构体中，可以对类型参数施加能力约束：

```move
module book::ability_constraints;

public struct Box<T: store> has key, store {
    id: UID,
    content: T,
}

public fun unbox<T: store>(box: Box<T>): T {
    let Box { id, content } = box;
    object::delete(id);
    content
}
```

`T: store` 意味着只有拥有 `store` 能力的类型才能放入 `Box` 中。这种约束在编译期就能捕获类型错误。

## 常见设计模式

### Hot Potato 模式

没有任何能力的结构体不能被复制、丢弃或存储，必须在创建它的交易中被显式消费。这个模式常用于强制执行某些操作序列：

```move
module book::hot_potato;

public struct FlashLoan {
    amount: u64,
}

public fun borrow(amount: u64): (u64, FlashLoan) {
    (amount, FlashLoan { amount })
}

public fun repay(loan: FlashLoan, payment: u64) {
    let FlashLoan { amount } = loan;
    assert!(payment >= amount);
}
```

### Witness 模式

只有 `drop` 能力的结构体，通常用于一次性类型证明（One-Time Witness）：

```move
module book::witness;

public struct WITNESS has drop {}
```

## 小结

能力系统是 Move 语言安全性的核心保障。本节核心要点：

- **四种能力**：`copy`（可复制）、`drop`（可丢弃）、`key`（可作为对象）、`store`（可存储）
- 能力通过 `has` 关键字在结构体定义中声明
- 所有原始类型拥有 `copy`、`drop`、`store`
- 没有能力的结构体（Hot Potato）必须被显式消费，确保操作不可跳过
- 只有 `drop` 的结构体（Witness）用于一次性类型证明
- 泛型中可以通过能力约束限制类型参数
- 能力系统在编译期强制执行资源安全规则，防止资产被意外复制或丢弃
