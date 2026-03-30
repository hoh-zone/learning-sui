# Option 类型

`Option<T>` 表示一个可能存在也可能不存在的值，借鉴自 Rust 语言的设计理念。它是处理缺失值的安全方式——与使用哨兵值（如 0 或 -1 表示"无"）不同，`Option` 在类型层面强制开发者处理值可能不存在的情况。在 Sui Move 中，`Option` 广泛用于可选的结构体字段、函数返回值等场景。

## 基本概念

### 内部实现

`Option<Element>` 的底层实现是一个最多包含一个元素的 `vector<Element>`：

- `option::some(value)` — 创建包含值的 Option（vector 长度为 1）
- `option::none()` — 创建空的 Option（vector 长度为 0）

这种实现方式简洁高效，复用了 vector 的内存管理机制。

### 隐式导入

`Option` 类型和 `option` 模块由编译器自动导入，无需手动编写 `use` 语句即可直接使用：

```move
module book::option_auto;

public struct Example has drop {
    value: Option<u64>,  // 直接使用，无需 use std::option
}

#[test]
fun auto_import() {
    let some_val = option::some(42u64);  // 直接使用 option::some
    let none_val: Option<u64> = option::none();

    assert!(some_val.is_some());
    assert!(none_val.is_none());
}
```

## 创建 Option

```move
module book::option_create;

use std::string::String;

#[test]
fun create() {
    // 创建包含值的 Option
    let some_int = option::some(42u64);
    let some_bool = option::some(true);
    let some_string = option::some(b"hello".to_string());

    // 创建空的 Option
    let none_int: Option<u64> = option::none();
    let none_string: Option<String> = option::none();

    assert!(some_int.is_some());
    assert!(none_int.is_none());
}
```

## 检查 Option 状态

`is_some()` 和 `is_none()` 用于检查 Option 是否包含值：

```move
module book::option_check;

#[test]
fun check() {
    let has_value = option::some(100u64);
    let no_value: Option<u64> = option::none();

    assert!(has_value.is_some());     // true
    assert!(!has_value.is_none());    // false

    assert!(no_value.is_none());      // true
    assert!(!no_value.is_some());     // false
}
```

## 提取 Option 中的值

### borrow — 不可变借用

`borrow()` 返回内部值的不可变引用。如果 Option 为空，会触发 abort：

```move
module book::option_borrow;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun borrow() {
    let opt = option::some(42u64);
    let value_ref: &u64 = opt.borrow();
    assert_eq!(*value_ref, 42);
}
```

### borrow_mut — 可变借用

`borrow_mut()` 返回内部值的可变引用，允许直接修改 Option 中的值：

```move
module book::option_borrow_mut;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun borrow_mut() {
    let mut opt = option::some(10u64);
    let value_ref = opt.borrow_mut();
    *value_ref = 20;

    assert_eq!(*opt.borrow(), 20);
}
```

### extract — 取出并清空

`extract()` 从 Option 中取出值，Option 变为 `none`。值被移出后 Option 仍然存在但为空：

```move
module book::option_extract;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun extract() {
    let mut opt = option::some(42u64);
    let value = opt.extract();

    assert_eq!(value, 42);
    assert!(opt.is_none());  // 提取后变为 none
}
```

### destroy_some — 销毁并取值

`destroy_some()` 销毁 Option 并返回内部的值。与 `extract` 不同的是，它会消耗整个 Option：

```move
module book::option_destroy_some;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun destroy_some() {
    let opt = option::some(42u64);
    let value = opt.destroy_some();
    assert_eq!(value, 42);
    // opt 已被销毁，不再可用
}
```

### get_with_default — 带默认值的获取

`get_with_default()` 在 Option 有值时返回该值的副本，为空时返回提供的默认值：

```move
module book::option_default;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun default() {
    let some_val = option::some(42u64);
    let none_val: Option<u64> = option::none();

    let a = some_val.get_with_default(0);  // 返回 42
    let b = none_val.get_with_default(0);  // 返回默认值 0

    assert_eq!(a, 42);
    assert_eq!(b, 0);
}
```

## 销毁 Option

### destroy_none — 销毁空 Option

`destroy_none()` 销毁一个空的 Option。如果 Option 包含值，会触发 abort：

```move
module book::option_destroy_none;

#[test]
fun destroy_none() {
    let empty: Option<u64> = option::none();
    empty.destroy_none();  // 安全销毁空 Option
}
```

## 修改 Option

### fill 和 swap

```move
module book::option_modify;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun fill_swap() {
    let mut opt: Option<u64> = option::none();

    // fill：向空 Option 中填入值
    opt.fill(100);
    assert_eq!(*opt.borrow(), 100);

    // swap：替换 Option 中的值，返回旧值
    let old = opt.swap(200);
    assert_eq!(old, 100);
    assert_eq!(*opt.borrow(), 200);
}
```

## 常见使用场景

### 可选的结构体字段

`Option` 最常见的用途是表示结构体中的可选字段：

```move
module book::option_example;

use std::string::String;

public struct UserProfile has drop {
    name: String,
    middle_name: Option<String>,
    bio: Option<String>,
}

public fun new_profile(name: String): UserProfile {
    UserProfile {
        name,
        middle_name: option::none(),
        bio: option::none(),
    }
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun option_profile() {
    let mut profile = new_profile(b"Alice".to_string());

    assert!(profile.middle_name.is_none());

    // 设置中间名
    profile.middle_name = option::some(b"Marie".to_string());
    assert!(profile.middle_name.is_some());

    // 借用内部值
    let middle = profile.middle_name.borrow();
    assert_eq!(*middle, b"Marie".to_string());

    // 获取带默认值的字段
    let bio = profile.bio.get_with_default(b"No bio".to_string());
    assert_eq!(bio, b"No bio".to_string());
}
```

### 安全的查找操作

在集合中查找元素时，使用 `Option` 表示可能找不到的情况：

```move
module book::option_search;

public fun find_index(v: &vector<u64>, target: u64): Option<u64> {
    let mut i = 0;
    while (i < v.length()) {
        if (v[i] == target) {
            return option::some(i)
        };
        i = i + 1;
    };
    option::none()
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun find() {
    let nums = vector[10u64, 20, 30, 40];

    let found = find_index(&nums, 30);
    assert!(found.is_some());
    assert_eq!(found.destroy_some(), 2);

    let not_found = find_index(&nums, 99);
    assert!(not_found.is_none());
}
```

## Option 的能力

`Option<T>` 的能力取决于内部元素类型 `T`：

| T 的能力 | Option\<T\> 拥有的能力 |
|---------|----------------------|
| `copy` | `Option<T>` 有 `copy` |
| `drop` | `Option<T>` 有 `drop` |
| `store` | `Option<T>` 有 `store` |

```move
module book::option_abilities;

public struct Copyable has copy, drop { value: u64 }

#[test]
fun option_copy() {
    let opt = option::some(Copyable { value: 42 });
    let opt_copy = opt;       // Option<Copyable> 有 copy
    assert!(opt.is_some());   // 原值仍然可用
    assert!(opt_copy.is_some());
}
```

## 小结

`Option` 是 Move 中处理可选值的标准方式。本节核心要点：

- **概念**：`Option<T>` 表示"有值"或"无值"，底层通过 `vector<T>` 实现
- **创建**：`option::some(value)` 创建有值，`option::none()` 创建空值
- **检查**：`is_some()` 和 `is_none()` 判断状态
- **提取**：`borrow()` 借用、`extract()` 取出、`destroy_some()` 销毁并取值
- **默认值**：`get_with_default()` 安全获取，避免 abort
- **修改**：`fill()` 填入值、`swap()` 替换值
- **隐式导入**：`Option` 类型和 `option` 模块自动可用，无需 `use`
- **常见场景**：可选结构体字段、安全的查找/返回操作
