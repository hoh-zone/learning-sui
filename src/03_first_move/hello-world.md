# Hello, World!

> **与侧边栏目录对应**：3.1 Hello World — 编写、编译与测试

每位开发者学习新语言的第一步，几乎都是编写一个 "Hello, World!" 程序。在 Move 中，我们将创建一个完整的 Move 包，编写模块和测试，并通过 Sui CLI 完成构建与测试。本节将带你体验从零开始创建 Move 项目的完整流程。

## 创建 Move 包

使用 `sui move new` 命令创建一个新的 Move 项目：

```bash
sui move new hello_world
```

该命令会生成以下目录结构：

```
hello_world/
├── Move.toml
├── sources/
│   └── hello_world.move
└── tests/
    └── hello_world_tests.move
```

各文件和目录的作用：

| 文件/目录 | 说明 |
|-----------|------|
| `Move.toml` | 包的清单文件，定义包名、依赖和地址等 |
| `sources/` | 存放 Move 源代码 |
| `tests/` | 存放测试代码 |

## 理解 Move.toml

打开生成的 `Move.toml` 文件：

```toml
[package]
name = "hello_world"
edition = "2024"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
hello_world = "0x0"
```

> **`rev` 说明**：与[第二章 · Move 2024](../02_getting_started/move-2024.md)一致，默认使用 `framework/mainnet`。若你仅用 **testnet/devnet** 且希望与 CLI 模板习惯一致，可改为 `framework/testnet`，并与当前 `sui client` 环境匹配。

各字段含义：

### `[package]`

- **name**：包名称，在依赖引用时使用
- **edition**：Move 语言版本。建议设为 `"2024"` 以使用最新语法

### `[dependencies]`

声明项目依赖。默认依赖 Sui Framework，它提供了核心类型和函数（如 `UID`、`TxContext`、`transfer` 等）。

### `[addresses]`

定义地址别名。`hello_world = "0x0"` 表示本包在本地开发时使用 `0x0` 作为地址占位符，发布到链上后会被替换为实际的包地址。

## 编写模块

打开 `sources/hello_world.move`，将内容替换为：

```move
module hello_world::hello_world;

use std::string::String;

/// 返回 "Hello, World!" 字符串
public fun hello_world(): String {
    b"Hello, World!".to_string()
}
```

让我们逐行解析：

### 模块声明

```move
module hello_world::hello_world;
```

- `hello_world`（第一个）：对应 `Move.toml` 中 `[addresses]` 下定义的地址别名
- `hello_world`（第二个）：模块名称
- 以分号结尾：这是 Move 2024 的文件级模块声明语法

### 导入

```move
use std::string::String;
```

从标准库导入 `String` 类型。`std` 是 Sui 框架隐式包含的 Move 标准库。

### 函数定义

```move
public fun hello_world(): String {
    b"Hello, World!".to_string()
}
```

- `public`：该函数可以被其他模块调用
- `fun`：函数声明关键字
- `hello_world()`：函数名和参数（此处无参数）
- `: String`：返回类型
- `b"Hello, World!"`：字节串字面量
- `.to_string()`：Move 2024 的内置方法，将字节串转换为 `String`

> **注意**：Move 函数中最后一个表达式会自动作为返回值，无需 `return` 关键字。

## 编写测试

打开 `tests/hello_world_tests.move`，将内容替换为：

```move
#[test_only]
module hello_world::hello_world_tests;

use hello_world::hello_world;

#[test]
fun hello_world() {
    assert_eq!(hello_world::hello_world(), b"Hello, World!".to_string());
}
```

### 测试模块属性

```move
#[test_only]
module hello_world::hello_world_tests;
```

`#[test_only]` 标注表示这个模块仅在测试时编译，不会包含在发布的包中。

### 测试函数

```move
#[test]
fun hello_world() {
    assert_eq!(hello_world::hello_world(), b"Hello, World!".to_string());
}
```

- `#[test]`：标记该函数为测试函数
- `assert!`：断言宏，条件为 `false` 时测试失败
- 测试函数不需要 `public` 修饰符

## 构建项目

在项目根目录下运行：

```bash
cd hello_world
sui move build
```

成功构建的输出：

```
UPDATING GIT DEPENDENCY https://github.com/MystenLabs/sui.git
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING hello_world
```

如果代码有错误，编译器会给出详细的错误信息和位置提示：

```
error[E01002]: unexpected token
   ┌─ sources/hello_world.move:5:1
   │
 5 │ public fun hello_world() String {
   │                          ^^^^^^
   │                          Expected ':'
```

> **提示**：第一次构建会下载 Sui Framework 依赖，可能需要一些时间。后续构建会使用缓存，速度会快很多。

## 运行测试

```bash
sui move test
```

成功输出：

```
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING hello_world
Running Move unit tests
[ PASS    ] hello_world::hello_world_tests::test_hello_world
Test result: OK. Total tests: 1; passed: 1; failed: 0
```

### 运行特定测试

如果项目中有多个测试，可以通过名称过滤：

```bash
# 只运行名称包含 "hello" 的测试
sui move test hello
```

### 查看详细输出

```bash
# 显示测试过程中的调试信息
sui move test --verbose
```

### 测试覆盖率

```bash
sui move test --coverage

# 查看覆盖率报告
sui move coverage summary
```

## 项目结构最佳实践

随着项目增长，建议采用以下结构：

```
my_project/
├── Move.toml
├── sources/
│   ├── module_a.move
│   ├── module_b.move
│   └── utils.move
└── tests/
    ├── module_a_tests.move
    └── module_b_tests.move
```

约定：

- 每个 `.move` 文件包含一个模块
- 文件名与模块名一致
- 测试文件名以 `_tests` 后缀命名
- 将相关功能组织在同一个包中

## 小结

本节我们完成了第一个 Move 程序的完整开发流程：使用 `sui move new` 创建项目，理解 `Move.toml` 配置文件，编写模块和测试代码，最后通过 `sui move build` 构建和 `sui move test` 测试。虽然 "Hello, World!" 很简单，但它涵盖了 Move 开发的核心工作流。下一节我们将编写一个更有实际意义的合约，并将其部署到 Sui 网络上。

若你希望先了解**全书章节如何递进、哪些章可以跳读**，可穿插阅读[导读 — 本书结构与阅读方式](../introduction.md)。
