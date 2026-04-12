# 枚举

枚举（Enum）是一种能表示多个变体（Variant）的类型，每个变体可以携带不同的数据。枚举是 Move 2024 引入的重要特性，极大地增强了类型系统的表达能力。

## 基本语法

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

## 带数据的变体

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

## 能力声明

枚举可以声明能力，但所有变体中携带的数据类型必须满足这些能力的要求：

```move
module book::enum_abilities;

public enum Status has copy, drop, store {
    Active,
    Inactive,
    Suspended { reason: vector<u8> },
}
```

## 实例化枚举

使用 `EnumName::VariantName` 语法创建枚举实例：

```move
module book::enum_instantiate;

public enum Color has copy, drop {
    Red,
    Green,
    Blue,
    Custom { r: u8, g: u8, b: u8 },
}

#[test]
fun instantiate() {
    let _red = Color::Red;
    let _custom = Color::Custom { r: 128, g: 0, b: 255 };
}
```

## 枚举的限制

- 一个枚举最多可以有 **100 个变体**
- **不支持递归枚举**（变体不能包含自身类型）
- 枚举的变体访问是 **模块内部** 的（类似结构体字段），外部模块不能直接构造或解构变体

## 小结

- **定义**：`public enum Name has abilities { Variant1, Variant2(Type), Variant3 { field: Type } }`
- **变体形式**：无数据、位置参数、命名字段
- **实例化**：`EnumName::VariantName` 或带数据形式
- **限制**：最多 100 个变体、不支持递归、变体访问仅限模块内部
