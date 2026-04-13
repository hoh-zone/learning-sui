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

[addresses]
hello_world = "0x0"
```

> **依赖**：Sui 1.45 起 Framework 为**隐式依赖**，`Move.toml` 中无需再写 `Sui = { git = ... }`。若你使用较旧工具链，可按[第六章 §6.11](../06_move_intermediate/11-move-2024.md)补全 `[dependencies]`。

> **`rev` 说明**：与[第六章 §6.11 · Move 2024 Edition](../06_move_intermediate/11-move-2024.md)中的约定一致，默认使用 `framework/mainnet`。若你仅用 **testnet/devnet** 且希望与 CLI 模板习惯一致，可改为 `framework/testnet`，并与当前 `sui client` 环境匹配。

各字段含义：

### `[package]`

- **name**：包名称，在依赖引用时使用
- **edition**：Move 语言版本。建议设为 `"2024"` 以使用最新语法

### `[dependencies]`

新版本工具链下 Sui Framework 为隐式依赖；若显式声明，则与[清单文件](../04_concepts/02-manifest.md)一致，指向 Mysten 仓库的 `framework/mainnet` 等分支。Framework 提供 `object::UID`、`TxContext`、`transfer` 等。

### `[addresses]`

定义地址别名。`hello_world = "0x0"` 表示本包在本地开发时使用 `0x0` 作为地址占位符，发布到链上后会被替换为实际的包地址。

## 编写模块

打开 `sources/hello_world.move`，将内容替换为：

```move
/// 与本书 3.1「Hello World」对应：创建一个可上链的 `Hello` 对象并转移给交易发送者。
module hello_world::hello_world;

use std::string::String;

/// 链上可拥有的问候对象；发布后调用 `mint_hello` 可在钱包或区块浏览器里看到。
public struct Hello has key, store {
    id: object::UID,
    greeting: String,
}

public fun greeting(hello: &Hello): &String {
    &hello.greeting
}

/// 构造 `Hello`（供测试或其它模块组合使用）。
public fun new_hello(ctx: &mut TxContext): Hello {
    Hello {
        id: object::new(ctx),
        greeting: b"Hello, World!".to_string(),
    }
}

/// 铸造 `Hello` 并转移给当前交易发送者（链上会产生新对象 ID）。
entry fun mint_hello(ctx: &mut TxContext) {
    let hello = new_hello(ctx);
    transfer::public_transfer(hello, ctx.sender());
}
```

### 模块声明与导入

```move
module hello_world::hello_world;

use std::string::String;
```

- `hello_world`（地址别名）与 `hello_world`（模块名）与 `Move.toml` 中 `[addresses]` 对应；分号结尾为 Move 2024 **文件级模块**语法。
- 仅显式导入 `String`；`object`、`transfer`、`TxContext` 等由 Sui 预导入，可直接写 `object::new`、`TxContext` 等。

### 对象类型 `Hello`

```move
public struct Hello has key, store {
    id: object::UID,
    greeting: String,
}
```

- **`has key`**：表示这是 **Sui 对象**，首字段必须是 `id: UID`。
- **`has store`**：对象可被转移，也可作为字段嵌入其它类型（后续章节会深入）。
- **`greeting`**：本例在链上可读的一段 UTF-8 文本，便于在浏览器里看出「这是 Hello 示例」。

### 构造函数与 `entry`

```move
public fun new_hello(ctx: &mut TxContext): Hello { /* ... */ }

entry fun mint_hello(ctx: &mut TxContext) {
    let hello = new_hello(ctx);
    transfer::public_transfer(hello, ctx.sender());
}
```

- **`new_hello`**：用 `object::new(ctx)` 分配唯一 `id`，在内存 / 测试中也可单独调用。
- **`entry fun mint_hello`**：**入口函数**，可从钱包或 CLI 作为**一笔交易的唯一调用**直接执行（无需被其它 Move 模块再包装）。内部把新建的 `Hello` **`public_transfer` 给 `ctx.sender()`**，即**当前交易的发送地址**，因此发布后你用自己的地址调用，就会在**自己的名下**出现一个新的 `Hello` 对象。
- 这样不再只是「返回一个字符串」的纯函数，而是**在链上创建可查询的对象**，与真实 DApp 的「铸造 NFT / 道具」是同一类模式的最小版。

> **注意**：Move 函数中最后一个表达式会自动作为返回值；无返回值的函数体以分号或控制流结束。

## 编写测试

打开 `tests/hello_world_tests.move`，将内容替换为：

```move
#[test_only]
module hello_world::hello_world_tests;

use hello_world::hello_world::{Self, Hello};
use std::unit_test::destroy;

#[test]
fun test_greeting() {
    let ctx = &mut tx_context::dummy();
    let hello: Hello = hello_world::new_hello(ctx);
    assert!(hello_world::greeting(&hello) == b"Hello, World!".to_string());
    destroy(hello);
}
```

### 测试模块属性

```move
#[test_only]
module hello_world::hello_world_tests;
```

`#[test_only]` 标注表示这个模块仅在测试时编译，不会包含在发布的包中。

### 测试函数

- `#[test]`：标记该函数为测试函数。
- 使用 **`tx_context::dummy()`** 模拟交易上下文，调用 **`new_hello`** 得到带 `key` 的对象；测试结束用 **`std::unit_test::destroy`** 回收对象（仅测试环境可用）。
- 测试函数不需要 `public` 修饰符。

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
[ PASS    ] hello_world::hello_world_tests::test_greeting
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

## 链上铸一枚 Hello（可选）

本地 `sui move test` 通过后，若已按[钱包与测试币](../02_getting_started/03-wallet-and-faucet.md)配置好 `sui client`，可将本包**发布**到 devnet/testnet，再**调用入口函数** `mint_hello`，这样浏览器与 CLI 里都会出现**真实对象 ID**（而非仅控制台打印字符串）：

```bash
# 在 hello_world 包根目录，发布（详见 §3.2）
sui client publish

# 将输出中的 Package ID 设为环境变量后，一笔交易只调 mint_hello：
sui client ptb --move-call $PACKAGE_ID::hello_world::mint_hello
```

成功后在交易回执的 **Created Objects** 中可看到类型为 `...::hello_world::Hello` 的新对象；用 `sui client object <对象ID>` 可查看其中的 `greeting` 字段。**PTB 与更多调用方式**见 §3.3。

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

本节我们完成了第一个 Move 程序的完整开发流程：使用 `sui move new` 创建项目，理解 `Move.toml`，编写带 **`Hello` 对象**与 **`entry fun mint_hello`** 的模块（**转移给自己**对应 `ctx.sender()`），编写测试，再通过 `sui move build` / `sui move test` 验证。这样你既练习了**纯函数式**的单元测试路径，又具备了**链上可查询输出**（对象 ID 与字段）的最小闭环；下一节将以另一示例深入**发布交易**的细节，§3.3 则系统讲解 PTB 调用。

若你希望先了解**全书章节如何递进、哪些章可以跳读**，可穿插阅读[导读 — 本书结构与阅读方式](../01-introduction.md)。
