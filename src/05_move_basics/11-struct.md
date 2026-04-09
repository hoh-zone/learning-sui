# 结构体（Struct）

结构体（Struct）是 Move 语言中定义自定义类型的核心机制，也是类型系统的基本构建块。通过结构体，开发者可以将多个不同类型的数据组合成一个有意义的整体。在 Sui 中，链上对象本质上就是带有 `key` 能力的结构体。

## 定义结构体

结构体使用 `struct` 关键字定义，可以附带能力声明和字段列表：

```move
module book::struct_definition;

use std::string::String;

public struct Profile has key, store {
    id: UID,
    name: String,
    age: u8,
    is_active: bool,
}
```

### 语法结构

```
[public] struct 名称 [has 能力列表] {
    字段名1: 类型1,
    字段名2: 类型2,
    ...
}
```

- `public` 修饰符使类型对外可见（字段仍然是私有的）
- `has` 后面跟能力列表，详见能力系统章节
- 字段类型可以是任何合法的 Move 类型，包括其他结构体

### 命名规范

- 结构体名使用 **PascalCase**（大驼峰）：`MyStruct`、`TokenBalance`
- 字段名使用 **snake_case**（蛇形）：`total_supply`、`is_active`

## 嵌套结构体

结构体的字段可以包含其他结构体类型，但 **不允许递归引用自身**：

```move
module book::struct_examples;

use std::string::String;

public struct Artist has copy, drop {
    name: String,
}

public struct Record has copy, drop {
    title: String,
    artist: Artist,
    year: u16,
    is_debut: bool,
    edition: Option<u16>,
}
```

## 创建实例

通过结构体名称和字段赋值来创建实例。所有字段都必须赋值：

```move
module book::struct_create;

use std::string::String;

public struct Point has copy, drop {
    x: u64,
    y: u64,
}

public struct NamedPoint has copy, drop {
    name: String,
    point: Point,
}

#[test]
fun create() {
    let origin = Point { x: 0, y: 0 };
    let p = Point { x: 10, y: 20 };

    let named = NamedPoint {
        name: b"Center".to_string(),
        point: origin,
    };
}
```

当变量名与字段名相同时，可以使用简写语法：

```move
module book::struct_shorthand;

public struct Pair has copy, drop {
    first: u64,
    second: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun shorthand() {
    let first = 10u64;
    let second = 20u64;
    let pair = Pair { first, second }; // 等价于 Pair { first: first, second: second }
    assert_eq!(pair.first, 10);
}
```

## 字段访问

使用 `.` 运算符访问结构体字段。**字段访问仅限于定义该结构体的模块内部**：

```move
module book::struct_access;

use std::string::String;

public struct Artist has copy, drop {
    name: String,
}

public struct Record has copy, drop {
    title: String,
    artist: Artist,
    year: u16,
    is_debut: bool,
    edition: Option<u16>,
}

public fun new_artist(name: String): Artist {
    Artist { name }
}

public fun new_record(
    title: String,
    artist: Artist,
    year: u16,
    is_debut: bool,
    edition: Option<u16>,
): Record {
    Record { title, artist, year, is_debut, edition }
}

public fun artist_name(artist: &Artist): &String {
    &artist.name
}

public fun record_year(record: &Record): u16 {
    record.year
}
```

## 解构（Unpacking）

解构可以将结构体的字段值提取到独立变量中。这是访问结构体内部数据的另一种方式：

```move
module book::struct_unpack;

use std::string::String;

public struct Artist has copy, drop {
    name: String,
}

public struct Record has copy, drop {
    title: String,
    artist: Artist,
    year: u16,
    is_debut: bool,
    edition: Option<u16>,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun struct_unpack() {
    let artist = Artist { name: b"The Beatles".to_string() };
    let record = Record {
        title: b"Abbey Road".to_string(),
        artist,
        year: 1969,
        is_debut: false,
        edition: option::none(),
    };

    assert_eq!(record.year, 1969);
    assert_eq!(record.is_debut, false);

    // Unpacking
    let Record { title: _, artist: _, year, is_debut: _, edition: _ } = record;
    assert_eq!(year, 1969);
}
```

### 忽略不需要的字段

解构时，对于不需要的字段，使用 `_` 前缀或直接用 `_` 来忽略，也可以用 `..` 来一次性忽略多个值：

```move
module book::struct_ignore;

public struct Config has copy, drop {
    width: u64,
    height: u64,
    depth: u64,
    color: u8,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun ignore_fields() {
    let config = Config { width: 100, height: 200, depth: 50, color: 3 };

    // 只关心 width 和 height
    // let Config { width, height, depth: _, color: _ } = config; // 使用 _ 逐个忽略
    let Config { width, height, .. } = config; // 使用 .. 一次性忽略多个值
    assert_eq!(width, 100);
    assert_eq!(height, 200);
    
    // 使用 .. 忽略时，.. 可以出现在任意位置，如：
    // let Config { .., width, height } = config;
    // let Config { width, .., height } = config;
}
```

## 无能力结构体的约束

没有任何能力的结构体不能被丢弃，必须显式处理（解构）。这是 Move 资源安全性的重要保障：

```move
module book::struct_no_ability;

public struct Receipt {
    amount: u64,
    paid: bool,
}

public fun create_receipt(amount: u64): Receipt {
    Receipt { amount, paid: false }
}

public fun consume_receipt(receipt: Receipt) {
    let Receipt { amount: _, paid: _ } = receipt; // 必须解构
}
```

如果尝试忽略没有 `drop` 能力的结构体实例，编译器会报错。这一特性常用于实现 **Hot Potato** 模式，确保某些操作必须被完成。

## 可变字段

对于可变引用的结构体，可以直接修改其字段值：

```move
module book::struct_mut;

public struct Balance has copy, drop {
    value: u64,
}

public fun increase(balance: &mut Balance, amount: u64) {
    balance.value = balance.value + amount;
}

public fun decrease(balance: &mut Balance, amount: u64) {
    assert!(balance.value >= amount);
    balance.value = balance.value - amount;
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun mut_fields() {
    let mut bal = Balance { value: 100 };
    increase(&mut bal, 50);
    assert_eq!(bal.value, 150);
    decrease(&mut bal, 30);
    assert_eq!(bal.value, 120);
}
```

## 小结

结构体是 Move 类型系统的核心。本节核心要点：

- 使用 `struct` 关键字定义自定义类型，字段可以是任何合法类型（不支持递归）
- 结构体类型默认私有，`public struct` 使类型可见，但 **字段始终私有**
- 创建实例需要提供所有字段值，支持变量名与字段名相同时的简写语法
- 字段访问（`.`运算符）仅限于定义该结构体的模块内部
- 解构（unpacking）可以提取字段值，不需要的字段用 `_` 或 `..` 忽略
- 没有能力的结构体不能被丢弃，必须显式解构——这是 Move 资源安全性的基石
