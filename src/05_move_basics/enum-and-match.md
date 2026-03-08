# 枚举与模式匹配

枚举（Enum）是一种能表示多个变体（Variant）的类型，每个变体可以携带不同的数据。配合 `match` 表达式进行模式匹配，可以安全、优雅地处理不同情况。枚举和模式匹配是 Move 2024 引入的重要特性，借鉴了 Rust 的设计，极大地增强了类型系统的表达能力。

## 枚举定义

### 基本语法

枚举使用 `public enum` 关键字定义，每个变体用逗号分隔：

```move
module book::enum_basic;

public enum Direction has copy, drop {
    North,
    South,
    East,
    West,
}

#[test]
fun direction() {
    let d = Direction::North;
    let _e = Direction::East;
}
```

### 带数据的变体

变体可以携带数据，支持两种形式：

- **位置参数**：`Variant(Type)` — 类似元组
- **命名字段**：`Variant { field: Type }` — 类似结构体

```move
module book::enum_data;

use std::string::String;

public enum Shape has copy, drop {
    Circle(u64),                           // 位置参数：半径
    Rectangle { width: u64, height: u64 }, // 命名字段
    Point,                                 // 无数据
}

public enum Message has copy, drop {
    Quit,
    Text(String),
    Move { x: u64, y: u64 },
}
```

### 能力声明

枚举可以声明能力，但所有变体中携带的数据类型必须满足这些能力的要求：

```move
module book::enum_abilities;

public enum Status has copy, drop, store {
    Active,
    Inactive,
    Suspended { reason: vector<u8> },
}
```

### 枚举的限制

- 一个枚举最多可以有 **100 个变体**
- **不支持递归枚举**（变体不能包含自身类型）
- 枚举的变体访问是 **模块内部** 的（类似结构体字段访问规则），外部模块不能直接构造或解构变体

## 实例化枚举

使用 `EnumName::VariantName` 语法创建枚举实例：

```move
module book::enum_instantiate;

use std::string::String;

public enum Color has copy, drop {
    Red,
    Green,
    Blue,
    Custom { r: u8, g: u8, b: u8 },
}

#[test]
fun instantiate() {
    let _red = Color::Red;
    let _green = Color::Green;
    let _custom = Color::Custom { r: 128, g: 0, b: 255 };
}
```

## match 表达式

### 基本模式匹配

`match` 表达式根据枚举的变体进行分支处理：

```move
module book::match_basic;

public enum Coin has copy, drop {
    Penny,
    Nickel,
    Dime,
    Quarter,
}

public fun value_in_cents(coin: &Coin): u64 {
    match (coin) {
        Coin::Penny => 1,
        Coin::Nickel => 5,
        Coin::Dime => 10,
        Coin::Quarter => 25,
    }
}

#[test]
fun match_value() {
    let penny = Coin::Penny;
    let quarter = Coin::Quarter;
    assert_eq!(value_in_cents(&penny), 1);
    assert_eq!(value_in_cents(&quarter), 25);
}
```

### 穷尽性检查

`match` 必须 **穷尽** 所有可能的变体。如果遗漏了某个变体，编译器会报错：

```move
module book::match_exhaustive;

public enum Light has copy, drop {
    Red,
    Yellow,
    Green,
}

public fun can_go(light: &Light): bool {
    match (light) {
        Light::Red => false,
        Light::Yellow => false,
        Light::Green => true,
        // 如果删掉其中任何一行，编译器都会报错
    }
}
```

### 通配符模式

使用 `_` 匹配所有未显式列出的变体：

```move
module book::match_wildcard;

public enum Priority has copy, drop {
    Critical,
    High,
    Medium,
    Low,
    Trivial,
}

public fun is_urgent(p: &Priority): bool {
    match (p) {
        Priority::Critical => true,
        Priority::High => true,
        _ => false,       // 其他所有变体都不紧急
    }
}

#[test]
fun wildcard() {
    assert!(is_urgent(&Priority::Critical));
    assert!(!is_urgent(&Priority::Low));
    assert!(!is_urgent(&Priority::Trivial));
}
```

### 解构变体数据

在 `match` 中可以解构变体携带的数据：

```move
module book::match_destructure;

use std::string::String;

public enum Event has copy, drop {
    Click { x: u64, y: u64 },
    KeyPress(u8),
    TextInput(String),
    Close,
}

public fun describe(event: &Event): String {
    match (event) {
        Event::Click { x: _, y: _ } => b"click".to_string(),
        Event::KeyPress(_code) => b"key".to_string(),
        Event::TextInput(_text) => b"text".to_string(),
        Event::Close => b"close".to_string(),
    }
}

public fun get_click_x(event: &Event): Option<u64> {
    match (event) {
        Event::Click { x, y: _ } => option::some(*x),
        _ => option::none(),
    }
}

#[test]
fun destructure() {
    let click = Event::Click { x: 100, y: 200 };
    assert_eq!(describe(&click), b"click".to_string());
    assert_eq!(get_click_x(&click), option::some(100));

    let close = Event::Close;
    assert!(get_click_x(&close).is_none());
}
```

### 忽略字段

使用 `..` 可以忽略命名字段变体中的所有字段：

```move
module book::match_ignore;

public enum Color has copy, drop {
    Red,
    Green,
    Blue,
    Custom { r: u8, g: u8, b: u8 },
}

public fun is_red(c: &Color): bool {
    match (c) {
        Color::Red => true,
        _ => false,
    }
}

public fun color_name(c: &Color): vector<u8> {
    match (c) {
        Color::Red => b"Red",
        Color::Green => b"Green",
        Color::Blue => b"Blue",
        Color::Custom { .. } => b"Custom",  // 忽略所有字段
    }
}
```

## match 作为表达式

`match` 是表达式，可以返回值。所有分支的返回类型必须一致：

```move
module book::match_expression;

public enum Season has copy, drop {
    Spring,
    Summer,
    Autumn,
    Winter,
}

public fun temperature(s: &Season): u64 {
    match (s) {
        Season::Spring => 20,
        Season::Summer => 35,
        Season::Autumn => 15,
        Season::Winter => 0,
    }
}

#[test]
fun expression() {
    let summer = Season::Summer;
    let temp = temperature(&summer);
    assert_eq!(temp, 35);
}
```

## 常见模式

### is_variant 检查函数

为枚举提供 `is_xxx` 方法来检查当前是哪个变体：

```move
module book::enum_is_check;

public enum Status has copy, drop {
    Active,
    Paused,
    Stopped,
}

public fun is_active(s: &Status): bool {
    match (s) { Status::Active => true, _ => false }
}

public fun is_paused(s: &Status): bool {
    match (s) { Status::Paused => true, _ => false }
}

public fun is_stopped(s: &Status): bool {
    match (s) { Status::Stopped => true, _ => false }
}

#[test]
fun is_check() {
    let s = Status::Active;
    assert!(is_active(&s));
    assert!(!is_paused(&s));
    assert!(!is_stopped(&s));
}
```

### try_into 转换函数

提供安全的类型转换，当变体不匹配时返回 `Option::none()`：

```move
module book::enum_try_into;

public enum Value has copy, drop {
    Integer(u64),
    Boolean(bool),
    Text(vector<u8>),
}

public fun try_as_integer(v: &Value): Option<u64> {
    match (v) {
        Value::Integer(n) => option::some(*n),
        _ => option::none(),
    }
}

public fun try_as_boolean(v: &Value): Option<bool> {
    match (v) {
        Value::Boolean(b) => option::some(*b),
        _ => option::none(),
    }
}

#[test]
fun try_into() {
    let val = Value::Integer(42);
    assert_eq!(try_as_integer(&val), option::some(42));
    assert!(try_as_boolean(&val).is_none());
}
```

## 完整示例

```move
module book::enum_example;

use std::string::String;

public enum Color has copy, drop {
    Red,
    Green,
    Blue,
    Custom { r: u8, g: u8, b: u8 },
}

public fun color_name(c: &Color): String {
    match (c) {
        Color::Red => b"Red".to_string(),
        Color::Green => b"Green".to_string(),
        Color::Blue => b"Blue".to_string(),
        Color::Custom { .. } => b"Custom".to_string(),
    }
}

public fun is_red(c: &Color): bool {
    match (c) {
        Color::Red => true,
        _ => false,
    }
}

public fun to_rgb(c: &Color): vector<u8> {
    match (c) {
        Color::Red => vector[255u8, 0, 0],
        Color::Green => vector[0u8, 255, 0],
        Color::Blue => vector[0u8, 0, 255],
        Color::Custom { r, g, b } => vector[*r, *g, *b],
    }
}

#[test]
fun enum_example() {
    let red = Color::Red;
    let custom = Color::Custom { r: 128, g: 0, b: 255 };

    assert!(is_red(&red));
    assert!(!is_red(&custom));
    assert_eq!(color_name(&red), b"Red".to_string());
    assert_eq!(color_name(&custom), b"Custom".to_string());

    let rgb = to_rgb(&red);
    assert_eq!(rgb, vector[255u8, 0, 0]);

    let custom_rgb = to_rgb(&custom);
    assert_eq!(custom_rgb, vector[128u8, 0, 255]);
}
```

## 小结

枚举和模式匹配为 Move 提供了强大的类型表达能力。本节核心要点：

- **枚举定义**：`public enum Name has abilities { Variant1, Variant2(Type), Variant3 { field: Type } }`
- **变体形式**：无数据、位置参数、命名字段三种形式
- **实例化**：`EnumName::VariantName` 或 `EnumName::VariantName { field: value }`
- **match 表达式**：必须穷尽所有变体，支持通配符 `_`
- **解构**：在 match 中绑定变体携带的数据，`..` 忽略所有字段
- **作为表达式**：match 可以返回值，分支类型必须一致
- **常见模式**：`is_variant` 检查函数、`try_into` 安全转换
- **限制**：最多 100 个变体，不支持递归，变体访问仅限模块内部
