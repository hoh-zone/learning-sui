# Move.toml 清单文件详解

`Move.toml` 是每个 Move 包的清单文件（Manifest），位于包的根目录下。它定义了包的基本信息、依赖关系和地址别名等配置。可以说，`Move.toml` 之于 Move 包，就像 `package.json` 之于 Node.js 项目、或清单文件之于其他语言的包管理器。

> **全书约定**：正文默认可复制片段使用 `rev = "framework/mainnet"`；下文出现 `framework/testnet` 时多用于**对照**（如 `[dev-dependencies]`）或与测试网环境匹配——详见[第六章 §6.11 · Sui Framework 依赖](../06_move_intermediate/11-move-2024.md)中的表格说明。

## 完整示例

先看一个典型的 `Move.toml` 文件全貌，后续逐段讲解：

```toml
[package]
name = "my_project"
version = "0.0.0"
edition = "2024"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
my_project = "0x0"

[dev-addresses]
my_project = "0x0"

[dev-dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }
```

## [package] — 包的基本信息

```toml
[package]
name = "my_project"
version = "0.0.0"
edition = "2024"
```

| 字段 | 说明 |
|------|------|
| `name` | 包名，使用 `snake_case` 命名。同时也是默认的命名地址 |
| `version` | 版本号，遵循语义化版本（SemVer）格式 |
| `edition` | Move 语言版本。推荐使用 `"2024"` 以获得最新的语言特性（如枚举、方法语法等） |

`edition` 字段决定了编译器可用的语言特性。`2024` 版本相较于旧版引入了枚举类型（enum）、方法语法（method syntax）、位置域（positional fields）等重要特性。

## [dependencies] — 依赖管理

Move 包通过 `[dependencies]` 段声明对其他包的依赖。

### Git 依赖

最常见的依赖方式，从 Git 仓库拉取：

```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
```

| 参数 | 说明 |
|------|------|
| `git` | Git 仓库的 URL |
| `subdir` | 仓库中包所在的子目录 |
| `rev` | Git 引用，可以是分支名、标签名或 commit hash |

也可以使用多行格式使其更易读：

```toml
[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
rev = "framework/mainnet"
```

### 本地依赖

在开发或调试时，可以引用本地路径的包：

```toml
[dependencies]
MyLibrary = { local = "../my_library" }
```

### 自动依赖（Sui CLI v1.45+）

从 Sui CLI v1.45 版本开始，系统包（如 `Sui`、`MoveStdlib`）会自动根据当前网络环境解析，无需手动指定。你可以简化为：

```toml
[dependencies]
```

留空即可，编译器会自动添加必要的系统框架依赖。

### 解决版本冲突

当多个依赖引用了同一个包的不同版本时，可以使用 `override = true` 来强制指定版本：

```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet", override = true }
```

`override = true` 会让当前包中声明的这个版本覆盖所有传递依赖中的同名包版本。

## [addresses] — 命名地址

```toml
[addresses]
my_project = "0x0"
std = "0x1"
sui = "0x2"
```

命名地址为链上地址提供了人类可读的别名。在代码中可以直接使用这些名称：

```move
module my_project::hello;

// my_project 在本地编译时指向 "0x0"
// 发布后会被替换为实际的链上地址
```

其中 `"0x0"` 是一个特殊的占位地址，表示"尚未发布"。在执行 `sui client publish` 时，编译器会自动将其替换为实际分配的链上地址。

常见的保留地址：

| 名称 | 地址 | 说明 |
|------|------|------|
| `std` | `0x1` | Move 标准库 |
| `sui` | `0x2` | Sui 框架 |

## [dev-addresses] — 开发/测试环境地址

```toml
[dev-addresses]
my_project = "0x0"
```

`[dev-addresses]` 中的配置仅在 `test` 和 `dev` 模式下生效，会覆盖 `[addresses]` 中的同名地址。这对于测试场景中需要使用不同地址的情况非常有用。

## [dev-dependencies] — 开发/测试依赖

```toml
[dev-dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }
```

与 `[dev-addresses]` 类似，`[dev-dependencies]` 中声明的依赖仅在 `test` 和 `dev` 模式下使用，会覆盖 `[dependencies]` 中的同名依赖。典型用途是在测试时使用 testnet 版本的框架。

## 实战：一个 DeFi 项目的 Move.toml

```toml
[package]
name = "defi_swap"
version = "1.0.0"
edition = "2024"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
MoveStdlib = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/move-stdlib", rev = "framework/mainnet" }

[addresses]
defi_swap = "0x0"

[dev-dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet", override = true }

[dev-addresses]
defi_swap = "0x0"
```

## 小结

`Move.toml` 是 Move 包的核心配置文件，由五个主要段落组成：`[package]` 声明包的基本信息，`[dependencies]` 管理外部依赖，`[addresses]` 定义命名地址别名，`[dev-dependencies]` 和 `[dev-addresses]` 则为测试环境提供覆盖配置。熟练掌握 `Move.toml` 的各项配置，有助于高效管理项目结构和依赖关系。
