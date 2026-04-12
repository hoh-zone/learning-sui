# Move 标准库概览

Move 标准库（Move Standard Library，简称 `std`）是 Move 语言内置的基础工具集，发布在地址 `0x1` 上。它提供了字符串处理、集合操作、序列化、哈希计算等核心功能，是每个 Move 开发者日常使用的基石。了解标准库的模块结构和常用接口，可以避免重复造轮子，写出更高效、更安全的代码。

## 标准库地址

Move 标准库的包地址为 `0x1`，在 `Move.toml` 中通常以命名地址 `std` 引用：

```toml
[addresses]
std = "0x1"
```

在代码中，所有标准库模块都以 `std::` 前缀访问，例如 `std::string`、`std::vector`。

## 常用模块一览

以下是 Move 标准库中最常用的模块及其功能：

| 模块 | 用途 | 主要类型/函数 |
|------|------|-------------|
| `std::string` | UTF-8 字符串操作 | `String`, `utf8()`, `append()`, `length()` |
| `std::ascii` | ASCII 字符串操作 | `String`, `string()`, `length()` |
| `std::option` | 可选值类型 | `Option<T>`, `some()`, `none()`, `is_some()` |
| `std::vector` | 动态数组操作 | `push_back()`, `pop_back()`, `length()` |
| `std::bcs` | BCS 序列化 | `to_bytes()` |
| `std::address` | 地址工具 | `to_string()`, `length()` |
| `std::type_name` | 运行时类型反射 | `TypeName`, `get<T>()`, `into_string()` |
| `std::hash` | 哈希函数 | `sha2_256()`, `sha3_256()` |
| `std::debug` | 调试输出（仅测试） | `print()`, `print_stack_trace()` |

## 字符串模块

### std::string — UTF-8 字符串

`std::string` 提供 UTF-8 编码的字符串类型，是最常用的字符串模块：

```move
module book::std_string_demo;

use std::string::{Self, String};

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun string_demo() {
    let s: String = b"Hello, Move!".to_string();
    assert_eq!(s.length(), 12);

    let mut greeting = b"Hello".to_string();
    greeting.append(b", World!".to_string());
    assert_eq!(greeting, b"Hello, World!".to_string());

    // 安全创建：返回 Option<String>
    let valid = string::try_utf8(b"valid");
    assert!(valid.is_some());
}
```

### std::ascii — ASCII 字符串

`std::ascii` 用于处理纯 ASCII 字符串，限制每个字节在 0~127 范围内：

```move
module book::std_ascii_demo;

use std::ascii;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun ascii_demo() {
    let s = b"Hello".to_ascii_string();
    assert_eq!(ascii::length(&s), 5);
}
```

## 集合与容器模块

### std::vector — 动态数组

`vector` 是 Move 中唯一的原生集合类型，`std::vector` 提供了丰富的操作函数：

```move
module book::std_vector_demo;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun vector_demo() {
    let mut v = vector[10u64, 20, 30];

    v.push_back(40);
    assert_eq!(v.length(), 4);
    assert!(v.contains(&20));

    let last = v.pop_back();
    assert_eq!(last, 40);
}
```

### std::option — 可选值

`Option<T>` 表示一个可能存在也可能不存在的值，是处理缺失值的安全方式：

```move
module book::std_option_demo;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun option_demo() {
    let some_val: Option<u64> = option::some(42);
    let none_val: Option<u64> = option::none();

    assert!(some_val.is_some());
    assert!(none_val.is_none());

    let val = some_val.destroy_some();
    assert_eq!(val, 42);
}
```

## 序列化与哈希

### std::bcs — BCS 序列化

BCS（Binary Canonical Serialization）是 Move 和 Sui 使用的序列化格式。`std::bcs` 可以将任意拥有 `copy` 能力的值转换为字节序列：

```move
module book::std_bcs_demo;

use std::bcs;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun bcs_demo() {
    let value: u64 = 1234;
    let bytes: vector<u8> = bcs::to_bytes(&value);
    assert!(bytes.length() > 0);

    let flag = true;
    let flag_bytes = bcs::to_bytes(&flag);
    assert_eq!(flag_bytes, vector[1u8]); // true 序列化为 [1]
}
```

### std::hash — 哈希函数

标准库提供了两种常用的密码学哈希函数：

```move
module book::std_hash_demo;

use std::hash;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun hash_demo() {
    let data = b"hello";
    let sha2 = hash::sha2_256(data);
    let sha3 = hash::sha3_256(data);

    assert_eq!(sha2.length(), 32); // SHA2-256 输出 32 字节
    assert_eq!(sha3.length(), 32); // SHA3-256 输出 32 字节
    assert!(sha2 != sha3);        // 不同算法，结果不同
}
```

## 类型反射

### std::type_name — 运行时类型信息

`std::type_name` 允许在运行时获取类型的完全限定名称，常用于泛型编程和调试：

```move
module book::std_type_name_demo;

use std::type_name;
use std::ascii::String;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun type_name_demo() {
    let name = type_name::with_defining_ids<u64>();
    let name_str: String = name.into_string();
    assert_eq!(name_str, b"u64".to_ascii_string());
}
```

## 整数工具模块

标准库为每种整数类型提供了实用函数模块：`std::u8`、`std::u16`、`std::u32`、`std::u64`、`std::u128`、`std::u256`。

这些模块提供的常用函数：

| 函数 | 说明 |
|------|------|
| `max(a, b)` | 返回两者中的较大值 |
| `diff(a, b)` | 返回两者的绝对差值 |
| `pow(base, exp)` | 幂运算 |
| `sqrt(n)` | 整数平方根 |

```move
module book::std_integer_demo;

use std::u64;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun integer_utils() {
    assert_eq!(u64::max(10, 20), 20);
    assert_eq!(u64::diff(30, 10), 20);
    assert_eq!(u64::diff(10, 30), 20);  // 绝对差值
    assert_eq!(u64::pow(2, 10), 1024);
    assert_eq!(u64::sqrt(144), 12);
}
```

## 调试模块

### std::debug — 测试专用调试

`std::debug` 仅在测试环境中有效，用于在 `sui move test` 时打印调试信息：

```move
module book::std_debug_demo;

use std::debug;
use std::string::String;

#[test]
fun debug_demo() {
    let value: u64 = 42;
    debug::print(&value);

    let name: String = b"Sui Move".to_string();
    debug::print(&name);

    debug::print_stack_trace();
}
```

> **注意**：`debug::print` 在链上执行时不会产生任何输出，仅用于本地测试调试。

## 隐式导入

编译器会自动导入以下标准库模块，无需在代码中编写 `use` 语句：

- `std::vector` — 向量操作函数
- `std::option` — Option 模块及其函数
- `std::option::Option` — Option 类型

因此，你可以直接在代码中使用 `vector[1, 2, 3]`、`option::some(x)`、`Option<T>` 等。

## 标准库 vs Sui Framework

初学者容易混淆 Move 标准库（`std`，地址 `0x1`）和 Sui Framework（`sui`，地址 `0x2`）。两者的核心区别：

| 特性 | Move 标准库 (`std`) | Sui Framework (`sui`) |
|------|--------------------|-----------------------|
| 地址 | `0x1` | `0x2` |
| 定位 | 语言层面的通用工具 | Sui 链特有的功能 |
| 存储能力 | 无存储相关功能 | 提供对象存储、转移等 |
| 对象模型 | 不涉及 | `UID`、`object`、`transfer` |
| 典型模块 | `string`、`vector`、`option` | `coin`、`transfer`、`clock` |

简单来说，`std` 提供数据处理的基础工具，`sui` 提供链上对象和交易的高级功能。两者互补，共同构成了 Sui Move 的开发基础。

## 小结

Move 标准库是开发 Sui 智能合约的基础工具集。本节核心要点：

- **地址**：标准库位于地址 `0x1`，通过 `std::module` 访问
- **字符串**：`std::string`（UTF-8）和 `std::ascii`（ASCII）两种字符串类型
- **集合**：`std::vector` 提供动态数组，`std::option` 提供可选值
- **序列化**：`std::bcs` 进行 BCS 序列化
- **哈希**：`std::hash` 提供 SHA2-256 和 SHA3-256
- **类型反射**：`std::type_name` 获取运行时类型信息
- **整数工具**：`std::u64` 等模块提供 `max`、`diff`、`pow`、`sqrt`
- **调试**：`std::debug` 仅用于测试时的打印输出
- **隐式导入**：`vector`、`option`、`Option` 自动可用
- **区别 Sui Framework**：`std` 是通用工具，`sui` 提供链上功能
