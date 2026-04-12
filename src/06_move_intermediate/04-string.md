# 字符串

Move 语言提供了两种字符串类型：`std::string::String`（UTF-8 编码）和 `std::ascii::String`（ASCII 编码）。两者的底层都是 `vector<u8>` 的封装，但在编码验证和使用场景上有所不同。UTF-8 字符串是日常开发中最常用的字符串类型，而 ASCII 字符串适用于需要严格限制字符范围的场景。

## UTF-8 字符串

### 创建字符串

`std::string::String` 是最常用的字符串类型，支持完整的 UTF-8 字符集：

```move
module book::string_create;

use std::string::{Self, String};

#[test]
fun create() {
    // 最常用的方式：字节字面量转换
    let s1: String = b"Hello, Sui!".to_string();

    // 通过 string::utf8 函数创建
    let bytes = b"Hello";
    let s2 = string::utf8(bytes);

    assert_eq!(s1.length(), 11);
    assert_eq!(s2.length(), 5);
}
```

### 安全创建

`string::try_utf8` 返回 `Option<String>`，在输入不是合法 UTF-8 时不会 abort，而是返回 `none`：

```move
module book::string_safe;

use std::string;

#[test]
fun try_utf8() {
    let valid = string::try_utf8(b"valid utf8");
    assert!(valid.is_some());

    let invalid = string::try_utf8(vector[0xFF, 0xFE]);
    assert!(invalid.is_none());
}
```

## 常用字符串操作

### 拼接与子串

```move
module book::string_ops;

use std::string::String;

#[test]
fun ops() {
    let mut str = b"Hello".to_string();
    let world = b", World!".to_string();

    // 拼接（会修改原字符串）
    str.append(world);
    assert_eq!(str, b"Hello, World!".to_string());
    assert_eq!(str.length(), 13);

    // 提取子串（按字节索引）
    let hello = str.sub_string(0, 5);
    assert_eq!(hello, b"Hello".to_string());

    let world_part = str.sub_string(7, 13);
    assert_eq!(world_part, b"World!".to_string());
}
```

### 长度与空值检查

```move
module book::string_check;

use std::string::String;

#[test]
fun length() {
    let s = b"Sui Move".to_string();
    assert_eq!(s.length(), 8);
    assert!(!s.is_empty());

    let empty: String = b"".to_string();
    assert_eq!(empty.length(), 0);
    assert!(empty.is_empty());
}
```

### 获取底层字节

`bytes()` 方法返回字符串底层 `vector<u8>` 的不可变引用：

```move
module book::string_bytes;

use std::string::String;

#[test]
fun bytes() {
    let s: String = b"ABC".to_string();
    let bytes: &vector<u8> = s.bytes();

    assert_eq!(bytes.length(), 3);
    assert_eq!(bytes[0], 65);  // 'A' 的 ASCII 值
    assert_eq!(bytes[1], 66);  // 'B'
    assert_eq!(bytes[2], 67);  // 'C'
}
```

### 插入与删除

```move
module book::string_insert;

use std::string::String;

#[test]
fun insert() {
    let mut s = b"Hello World".to_string();

    // insert: 在指定字节位置插入另一个字符串
    s.insert(5, b",".to_string());
    assert_eq!(s, b"Hello, World".to_string());
}
```

## UTF-8 的限制

`length()` 返回的是 **字节数**，而非字符数。对于多字节 UTF-8 字符（如中文），字节数和字符数不同：

```move
module book::string_utf8_limit;

use std::string::String;

#[test]
fun utf8_length() {
    let ascii_str: String = b"Hello".to_string();
    assert!(ascii_str.length() == 5);  // 5 个 ASCII 字符 = 5 字节

    // 注意：sub_string 按字节索引操作
    // 如果在多字节字符的中间截断，会导致非法 UTF-8
    // 因此在处理非 ASCII 字符时需格外小心
}
```

> **注意**：Move 的字符串 API 基于字节操作，不支持字符级别的访问。在处理包含非 ASCII 字符（如中文、emoji）的字符串时，需要特别注意字节边界问题。

## ASCII 字符串

### 创建和使用

`std::ascii::String` 严格限制每个字节在 0~127 范围内：

```move
module book::ascii_example;

use std::ascii;

#[test]
fun ascii() {
    // 使用 to_ascii_string 创建
    let s = b"Hello, ASCII!".to_ascii_string();
    assert!(ascii::length(&s) == 13);

    // 安全创建：返回 Option
    let valid = ascii::try_string(b"valid");
    assert!(valid.is_some());

    // 包含非 ASCII 字节的输入会返回 none
    let invalid = ascii::try_string(vector[200u8]);
    assert!(invalid.is_none());
}
```

### UTF-8 与 ASCII 的选择

| 特性 | `std::string::String` | `std::ascii::String` |
|------|----------------------|---------------------|
| 编码 | UTF-8 | ASCII (0~127) |
| 字符范围 | 全 Unicode | 仅英文字母、数字、基本符号 |
| 底层类型 | `vector<u8>` | `vector<u8>` |
| 常见用途 | 用户输入、显示文本 | 标识符、协议字段 |
| 创建方式 | `b"...".to_string()` | `b"...".to_ascii_string()` |

在大多数场景下，推荐使用 UTF-8 的 `std::string::String`。ASCII 字符串主要用于那些需要严格限制字符范围的场景，例如 URL、标识符等。

## 字符串与字节向量的转换

字符串本质上是带有编码验证的 `vector<u8>` 封装：

```move
module book::string_conversion;

use std::string::{Self, String};

#[test]
fun conversion() {
    // 字节向量 -> 字符串
    let bytes = b"Hello";
    let s: String = string::utf8(bytes);

    // 字符串 -> 字节向量引用
    let bytes_ref: &vector<u8> = s.bytes();
    assert!(bytes_ref == &b"Hello");

    // 字符串 -> 字节向量（消耗字符串）
    let owned_bytes: vector<u8> = s.into_bytes();
    assert!(owned_bytes == b"Hello");
}
```

## 完整示例

```move
module book::string_example;

use std::string::String;

#[test]
fun string_example() {
    let mut str = b"Hello".to_string();
    let world = b", World!".to_string();

    // 拼接
    str.append(world);
    assert_eq!(str.length(), 13);

    // 子串
    let hello = str.sub_string(0, 5);
    assert_eq!(hello, b"Hello".to_string());

    // 空值检查
    assert!(!str.is_empty());

    // 安全创建
    let valid = std::string::try_utf8(b"valid utf8");
    assert!(valid.is_some());

    // 获取字节
    let bytes: &vector<u8> = str.bytes();
    assert_eq!(bytes.length(), 13);
}
```

## 小结

字符串是 Move 中处理文本数据的核心类型。本节核心要点：

- **两种字符串**：`std::string::String`（UTF-8）和 `std::ascii::String`（ASCII）
- **底层结构**：都是 `vector<u8>` 的封装，带有编码验证
- **创建方式**：`b"text".to_string()` 创建 UTF-8，`string::try_utf8()` 安全创建
- **常用操作**：`append()` 拼接、`sub_string()` 子串、`length()` 长度、`is_empty()` 检查空值
- **字节访问**：`bytes()` 获取底层字节引用，`into_bytes()` 转换为字节向量
- **UTF-8 限制**：`length()` 返回字节数而非字符数，无字符级别访问
- **ASCII 字符串**：适用于标识符等需要限制字符范围的场景
- **选择建议**：大多数情况下使用 UTF-8 字符串
