# 模块导入

Move 的模块系统通过 `use` 语句实现代码复用和依赖管理。导入机制让你可以引用标准库、Sui Framework 以及外部包中定义的类型和函数，而无需在每次使用时写出完整的模块路径。掌握模块导入的各种方式是编写整洁、可维护的 Move 代码的关键。

## 基本导入语法

### 导入整个模块

使用 `use package::module;` 可以导入一个模块，之后通过 `module::member` 的方式访问其成员：

```move
module book::import_module;

use sui::coin;
use sui::sui::SUI;

public fun value(c: &coin::Coin<SUI>): u64 {
    coin::value(c)
}
```

### 导入具体成员

使用 `use package::module::MemberName;` 直接导入模块中的某个类型或函数，之后可以直接使用名称，无需模块前缀：

```move
module book::import_member;

use std::string::String;

public struct Profile has drop {
    name: String,
}
```

## 分组导入

当需要从同一个模块导入多个成员时，可以使用花括号进行分组：

```move
module book::grouped_import;

use sui::coin::{Self, Coin};
use sui::sui::SUI;

public fun coin_value(c: &Coin<SUI>): u64 {
    coin::value(c)
}
```

上例中 `{Self, Coin}` 同时导入了模块本身（`Self` 等价于 `coin`）和 `Coin` 类型。这样既可以使用 `Coin` 类型，也可以通过 `coin::value` 调用模块函数。

### Self 关键字

`Self` 在导入中代表模块本身。使用 `Self` 可以在分组导入中同时引入模块和其成员：

```move
module book::self_import;

use std::string::{Self, String};

public fun create_greeting(): String {
    let bytes = b"Hello, Sui!";
    string::utf8(bytes)
}
```

## 别名导入

使用 `as` 关键字可以为导入的模块或类型指定别名，解决命名冲突或提升可读性：

```move
module book::alias_import;

use std::string::String as UTF8String;
use std::ascii::String as ASCIIString;

public struct Names has drop {
    utf8_name: UTF8String,
    ascii_name: ASCIIString,
}
```

当两个不同模块导出了同名的类型时，别名是避免冲突的唯一方式。

## 从 Sui Framework 导入

Sui Framework 是构建 Sui 智能合约最常用的依赖库。它提供了对象模型、代币系统、事件等核心功能。以下是一些常见的导入：

```move
module book::sui_imports;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::event;
use sui::object;
use sui::transfer;
use sui::tx_context::TxContext;
use std::string::String;
```

### 常用的 Framework 模块

| 包 | 模块 | 用途 |
|-----|------|------|
| `std` | `std::string` | UTF-8 字符串操作 |
| `std` | `std::option` | `Option<T>` 类型 |
| `std` | `std::vector` | 向量操作 |
| `sui` | `sui::object` | 对象创建与操作 |
| `sui` | `sui::transfer` | 对象转移 |
| `sui` | `sui::tx_context` | 交易上下文 |
| `sui` | `sui::coin` | 代币操作 |
| `sui` | `sui::event` | 事件发送 |
| `sui` | `sui::clock` | 链上时钟 |

## 自动导入

Move 编译器会自动导入一些常用的模块和类型，无需手动编写 `use` 语句：

- `std::vector` — 向量模块
- `std::option` — Option 模块
- `std::option::Option` — Option 类型

这意味着你可以直接使用 `vector[]`、`option::some()`、`Option<T>` 等，而无需显式导入。

```move
module book::auto_import;

public struct Container has drop {
    items: vector<u64>,
    label: Option<u64>,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun auto_import() {
    let items = vector[1u64, 2, 3];
    let label = option::some(42u64);

    let c = Container { items, label };
    assert_eq!(c.items.length(), 3);
    assert!(c.label.is_some());
}
```

## 外部依赖

外部包的依赖通过 `Move.toml` 配置文件进行管理。

### Move.toml 中的依赖配置

```toml
[package]
name = "my_project"
edition = "2024"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
book = "0x0"
```

与[第六章 §6.11 · Move 2024 Edition](../06_move_intermediate/11-move-2024.md)一致，本书示例统一使用 `edition = "2024"` 与 `rev = "framework/mainnet"`。若在 **testnet** 上开发，可将 `rev` 改为 `framework/testnet`。若本地 CLI 仍生成 `2024.beta`，可改为 `"2024"`（与迁移期别名等价，见 §6.11 说明）。

定义好依赖后，就可以在代码中导入该依赖包提供的模块。

### CLI v1.45+ 的简化

从 Sui CLI v1.45 版本开始，系统包（`std`、`sui`）会被 **自动包含** 为依赖，无需在 `Move.toml` 中手动添加。这大大简化了新项目的配置。

## 导入位置

`use` 语句通常放在模块声明之后、其他代码之前。虽然 Move 允许在函数内部使用 `use`，但推荐在模块顶部统一管理导入：

```move
module book::import_placement;

// 推荐：在模块顶部统一导入
use std::string::String;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

public struct Token has drop {
    name: String,
}

public fun coin_value(c: &Coin<SUI>): u64 {
    // 也可以在函数内部导入（不推荐）
    // use sui::coin;
    coin::value(c)
}
```

## 完整示例

下面的例子综合展示了各种导入方式的实际用法：

```move
module book::import_example;

use std::string::String;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

public struct MyToken has key {
    id: UID,
    name: String,
}

public fun coin_value(c: &Coin<SUI>): u64 {
    coin::value(c)
}

public fun create_token(name: String, ctx: &mut TxContext): MyToken {
    MyToken {
        id: object::new(ctx),
        name,
    }
}
```

## 小结

模块导入是 Move 代码组织的核心机制。本节核心要点：

- **模块导入**：`use package::module;` 导入模块，通过 `module::member` 访问成员
- **成员导入**：`use package::module::Member;` 直接导入类型或函数
- **分组导入**：`use package::module::{Self, Type1, Type2};` 一次导入多个成员
- **别名**：`use package::module::Type as Alias;` 解决命名冲突
- **Self 关键字**：在分组导入中代表模块本身
- **预导入（Prelude）**：`object`、`transfer`、`TxContext` 及常用 `vector` / `option` 等往往**无需**再 `use`，详见 **[§5.4 默认导入的包与预置名称](04-default-imports.md)**
- **外部依赖**：通过 `Move.toml` 配置，CLI v1.45+ 自动包含系统包
