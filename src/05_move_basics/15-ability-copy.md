# Copy 能力详解

`copy` 能力允许值被复制（Duplicate），是 Move 四大能力之一。没有 `copy` 能力的类型遵循 **移动语义**（Move Semantics），即值在赋值或传参后原变量将失效。理解 `copy` 能力对于掌握 Move 的所有权模型至关重要，它决定了值能否被安全地重复使用。

## 什么是 Copy

在 Move 中，默认情况下自定义结构体没有 `copy` 能力。当一个值被赋给另一个变量、传递给函数时，原始值会被 **移动**（move），此后不再可用。`copy` 能力改变了这一行为——拥有 `copy` 能力的类型在赋值和传参时会自动复制，原始值保持有效。

### 移动语义 vs 复制语义

没有 `copy` 的类型使用移动语义：

```move
module book::move_semantics;

public struct NoCopy has drop { value: u64 }

#[test]
fun move_invalid_use_after() {
    let a = NoCopy { value: 42 };
    let _b = a;     // a 被移动到 _b
    // let _c = a;  // 编译错误：a 已被移动，不再可用
}
```

拥有 `copy` 的类型使用复制语义：

```move
module book::copy_semantics;

public struct Copyable has copy, drop {
    value: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun copy_both_valid() {
    let a = Copyable { value: 42 };
    let b = a;     // 隐式复制，a 仍然可用
    let c = a;     // 再次复制，a 依然可用
    assert_eq!(a.value, 42);
    assert_eq!(b.value, 42);
    assert_eq!(c.value, 42);
}
```

## 隐式复制与显式复制

### 隐式复制

当拥有 `copy` 能力的值被赋给新变量或传递给函数时，编译器会自动进行隐式复制：

```move
module book::implicit_copy;

public struct Point has copy, drop {
    x: u64,
    y: u64,
}

fun consume_point(_p: Point) {}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun implicit_copy() {
    let p = Point { x: 10, y: 20 };

    let q = p;           // 隐式复制
    consume_point(p);    // 隐式复制后传入函数

    assert_eq!(q.x, 10);  // q 是 p 的副本
}
```

### 显式复制

使用解引用运算符 `*&` 或者 `copy` 关键字，可以进行显式复制，这种写法更加清晰地表达了开发者的意图：

```move
module book::explicit_copy;

public struct Data has copy, drop {
    value: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun explicit_copy() {
    let a = Data { value: 100 };
    let b = *&a;         // 显式复制：先取引用 &a，再解引用 *
    let c = copy a;      // 显示复制：使用 copy 关键字

    assert_eq!(a.value, 100);
    assert_eq!(b.value, 100);
    assert_eq!(c.value, 100);
}
```

`*&` 的语义是：先获取值的引用（`&a`），再通过解引用（`*`）创建一个副本。对于拥有 `copy` 能力的类型，这与隐式复制效果相同，但在代码审查中更容易识别复制操作。

## Copy 与 Drop 的关系

在实践中，拥有 `copy` 能力的类型几乎总是同时拥有 `drop` 能力。原因在于：如果一个值可以被复制但不能被丢弃，那么每次复制都会产生一个新值，而所有这些值都必须被显式消耗，这会导致代码极其繁琐且容易出错。

```move
module book::copy_drop;

public struct CopyDrop has copy, drop {
    value: u64,
}

#[test]
fun copy_drop_both_dropped() {
    let a = CopyDrop { value: 1 };
    let _b = a;     // 复制
    let _c = a;     // 再次复制
    // 函数结束时，a、_b、_c 都会自动 drop，无需手动处理
}
```

> **规则**：如果一个类型拥有 `copy`，通常也应该赋予 `drop`。Move 编译器不会强制要求这一点，但这是社区的最佳实践。

## 原始类型的 Copy 能力

Move 中所有原始类型天然拥有 `copy`（以及 `drop` 和 `store`）能力：

| 类型 | 拥有 copy | 说明 |
|------|----------|------|
| `bool` | ✅ | 布尔值 |
| `u8` ~ `u256` | ✅ | 所有整数类型 |
| `address` | ✅ | 地址类型 |
| `vector<T>` | 当 `T` 有 `copy` 时 | 泛型容器，能力取决于元素类型 |

```move
module book::primitive_copy;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun primitive_copy() {
    let x: u64 = 42;
    let y = x;          // 隐式复制
    let z = *&x;        // 显式复制，也可以使用 copy 关键字
    assert_eq!(x, 42);
    assert_eq!(y, 42);
    assert_eq!(z, 42);

    let v1 = vector[1u64, 2, 3];
    let v2 = v1;         // vector<u64> 有 copy，因为 u64 有 copy
    assert_eq!(v1.length(), 3);
    assert_eq!(v2.length(), 3);
}
```

## 标准库中拥有 Copy 的类型

除了原始类型，标准库中也有一些常用类型拥有 `copy` 能力：

| 类型 | 模块路径 | 说明 |
|------|---------|------|
| `Option<T>` | `std::option` | 当 `T` 有 `copy` 时，`Option<T>` 也有 `copy` |
| `String` | `std::string` | UTF-8 字符串（底层是 `vector<u8>`） |
| `AsciiString` | `std::ascii` | ASCII 字符串 |
| `TypeName` | `std::type_name` | 运行时类型名称 |

```move
module book::stdlib_copy;

use std::string::String;

#[test]
fun stdlib_copy() {
    let name: String = b"Sui".to_string();
    let name_copy = name;           // String 有 copy，可以复制
    assert!(name == name_copy);

    let maybe: Option<u64> = option::some(42);
    let maybe_copy = maybe;         // Option<u64> 有 copy
    assert!(maybe.is_some());
    assert!(maybe_copy.is_some());
}
```

## 结构体字段的约束

当一个结构体声明为 `has copy` 时，它的 **所有字段** 的类型都必须拥有 `copy` 能力。如果任何字段的类型不支持 `copy`，编译器会报错：

```move
module book::copy_fields;

public struct Inner has copy, drop {
    value: u64,
}

public struct Outer has copy, drop {
    inner: Inner,       // Inner 有 copy，合法
    count: u64,         // u64 有 copy，合法
}

// 以下代码无法编译：
// public struct Bad has copy, drop {
//     id: UID,          // UID 没有 copy，编译错误
// }
```

这一规则确保了 `copy` 操作可以递归地复制结构体的每一个字段。

## 完整示例

下面的例子综合展示了 `copy` 能力在实际开发中的使用场景：

```move
module book::copy_example;

use std::string::String;

public struct Config has copy, drop, store {
    name: String,
    max_retries: u64,
    enabled: bool,
}

public fun default_config(): Config {
    Config {
        name: b"default".to_string(),
        max_retries: 3,
        enabled: true,
    }
}

public fun with_name(config: &Config, name: String): Config {
    let mut new_config = *config;    // 显式复制配置
    new_config.name = name;
    new_config
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun config_copy() {
    let base = default_config();
    let custom = with_name(&base, b"custom".to_string());

    // base 未被移动，仍然可用
    assert_eq!(base.name, b"default".to_string());
    assert_eq!(custom.name, b"custom".to_string());
    assert_eq!(base.max_retries, custom.max_retries);
}
```

## 小结

`copy` 能力控制了值是否可以被复制。本节核心要点：

- **移动 vs 复制**：没有 `copy` 的类型遵循移动语义，赋值后原变量失效；有 `copy` 则自动复制
- **隐式复制**：赋值和传参时自动发生
- **显式复制**：使用 `*&value` 语法或 `copy` 关键字，意图更清晰
- **Copy + Drop**：拥有 `copy` 的类型通常也应该拥有 `drop`
- **原始类型**：`bool`、所有整数类型、`address` 天然拥有 `copy`
- **字段约束**：结构体声明 `copy` 时，所有字段类型必须也拥有 `copy`
- **标准库**：`String`、`Option<T>`、`TypeName` 等常用类型拥有 `copy`
