# 什么是对象

在 Sui 区块链中，**对象（Object）** 是存储和管理链上数据的基本单元。它是 Move 数字资产概念在 Sui 平台上的具体实现——每个对象都是一个具有全局唯一标识符的独立实体，拥有明确的所有者和完整的生命周期。理解对象模型是掌握 Sui 开发的关键基础。

本章将详细介绍什么是 Sui 对象、对象的结构和属性，以及对象与普通值类型（value）之间的本质区别。

## 对象模型：数字资产的高层抽象

Sui 的对象模型为数字资产提供了一个高层次的抽象。与传统区块链将所有状态存储在一个全局状态树中不同，Sui 将链上状态组织为一个个**独立的对象**。每个对象：

- 有自己的唯一身份
- 有明确的所有者
- 可以独立地被读取、修改和转移
- 有完整的版本历史

这种模型带来了一个重要优势：由于对象是独立的，涉及不同对象的交易可以**并行执行**，大幅提升了区块链的吞吐量。

## 对象的六大属性

每个 Sui 对象都具备以下六大属性：

### 类型（Type）

每个对象都有一个确定的 Move 类型，例如 `0x2::coin::Coin<0x2::sui::SUI>`。类型定义了对象包含哪些数据字段，以及可以对它执行哪些操作。类型在对象创建后**不可更改**。

### 唯一标识符（Unique ID）

每个对象在创建时会被分配一个全局唯一的 ID（`UID`），格式为 32 字节的地址。这个 ID 在整个 Sui 网络中是唯一的，即使对象被销毁，其 ID 也不会被复用。

### 所有者（Owner）

每个对象都有一个所有者，决定了谁可以在交易中使用这个对象。所有者可以是：

- 一个地址（address-owned）
- 被共享（shared）
- 被冻结（immutable/frozen）
- 另一个对象（object-owned/wrapped）

### 数据（Data）

对象携带的实际业务数据，由其类型中定义的字段组成。例如一个代币对象的数据包含余额，一个 NFT 的数据包含名称和图片 URL。

### 版本（Version）

每当对象被交易修改时，其版本号会递增。版本号用于乐观并发控制——如果交易提交时对象的版本已经变化，该交易会被拒绝。

### 摘要（Digest）

对象内容的加密哈希，用于验证对象数据的完整性。

## 如何定义一个对象

在 Move 中定义一个 Sui 对象需要满足两个条件：

1. 结构体必须具有 **`key`** 能力
2. 结构体的**第一个字段**必须是 `id: UID`

```move
module examples::object_basics;

/// An object has `key` ability and `id: UID` as first field
public struct Profile has key {
    id: UID,
    name: vector<u8>,
    score: u64,
}

/// A value struct - NOT an object (no `key` ability)
public struct Stats has store, copy, drop {
    level: u8,
    experience: u64,
}

/// Create a new Profile object
public fun new_profile(
    name: vector<u8>,
    ctx: &mut TxContext,
): Profile {
    Profile {
        id: object::new(ctx),
        name,
        score: 0,
    }
}
```

### `key` 能力的意义

`key` 能力告诉 Sui 运行时：这个结构体的实例应该被当作一个**独立的链上对象**来管理。拥有 `key` 能力的结构体：

- 可以作为交易的输入和输出
- 会被分配全局唯一 ID
- 受到所有权系统的保护
- 会被存储在 Sui 的全局对象存储中

### `UID` 的作用

`UID`（Unique Identifier）是 Sui 对象系统的核心类型，定义在 `sui::object` 模块中。它有以下特点：

- **不可复制**（没有 `copy` 能力）：确保每个 ID 的唯一性
- **不可丢弃**（没有 `drop` 能力）：销毁对象时必须显式删除 UID
- **全局唯一**：由 `TxContext` 保证每次生成的 ID 都不同
- **必须是第一个字段**：这是 Sui 运行时的硬性要求

```move
module examples::uid_demo;

public struct MyObject has key {
    id: UID,       // 必须是第一个字段
    value: u64,
}

/// 创建对象时，通过 object::new(ctx) 生成唯一 ID
public fun create(value: u64, ctx: &mut TxContext): MyObject {
    MyObject {
        id: object::new(ctx),
        value,
    }
}

/// 销毁对象时，必须显式删除 UID
public fun destroy(obj: MyObject) {
    let MyObject { id, value: _ } = obj;
    id.delete();
}
```

## 对象 vs 值（Object vs Value）

理解对象和值的区别是 Sui 开发中非常重要的概念。

### 对象（Object）

- 具有 `key` 能力
- 第一个字段是 `id: UID`
- 存在于 Sui 的全局对象存储中
- 有独立的所有者
- 可以作为交易的输入
- 有版本号和摘要

### 值（Value）

- 没有 `key` 能力
- 没有 `id: UID` 字段
- 不能独立存在于链上
- 只能作为对象的字段存在
- 不能直接作为交易的输入
- 通常具有 `store`、`copy`、`drop` 等能力

```move
module examples::object_vs_value;

use std::string::String;

/// 这是一个对象：有 key 能力和 id: UID
public struct Notebook has key {
    id: UID,
    title: String,
    entries: vector<Entry>,
}

/// 这是一个值：没有 key 能力，不能独立存在于链上
public struct Entry has store, copy, drop {
    content: String,
    timestamp: u64,
}

/// 创建一个笔记本对象
public fun create_notebook(
    title: String,
    ctx: &mut TxContext,
): Notebook {
    Notebook {
        id: object::new(ctx),
        title,
        entries: vector[],
    }
}

/// 添加一个条目（值）到笔记本（对象）
public fun add_entry(
    notebook: &mut Notebook,
    content: String,
    timestamp: u64,
) {
    let entry = Entry { content, timestamp };
    notebook.entries.push_back(entry);
}

/// 读取条目数量
public fun entry_count(notebook: &Notebook): u64 {
    notebook.entries.length()
}
```

在这个例子中，`Notebook` 是一个对象，它可以独立存在于链上，有自己的 ID 和所有者。而 `Entry` 是一个值，它只能作为 `Notebook` 的一部分存在，不能独立拥有或转移。

## 对象的创建与生命周期

一个对象从创建到销毁的完整生命周期如下：

### 1. 创建

通过 `object::new(ctx)` 生成新的 UID，构造结构体实例。

### 2. 上链

通过 `transfer::transfer`、`transfer::share_object`、`transfer::freeze_object` 等函数将对象放到链上。

### 3. 使用

对象可以在后续交易中被读取（`&T`）或修改（`&mut T`），也可以被按值传入（`T`）以转移或销毁。

### 4. 销毁

通过解构（destructure）对象，提取所有字段，并调用 `id.delete()` 删除 UID。

```move
module examples::lifecycle;

public struct Token has key {
    id: UID,
    value: u64,
}

/// 步骤1: 创建
public fun mint(value: u64, ctx: &mut TxContext): Token {
    Token {
        id: object::new(ctx),
        value,
    }
}

/// 步骤2: 上链（转移给某人）
public fun send(token: Token, recipient: address) {
    transfer::transfer(token, recipient);
}

/// 步骤3: 使用（读取和修改）
public fun value(token: &Token): u64 {
    token.value
}

public fun add_value(token: &mut Token, amount: u64) {
    token.value = token.value + amount;
}

/// 步骤4: 销毁
public fun burn(token: Token) {
    let Token { id, value: _ } = token;
    id.delete();
}
```

## 常见错误与注意事项

### UID 不是第一个字段

```move
// 错误！UID 必须是第一个字段
public struct Bad has key {
    value: u64,
    id: UID,  // 应作为第一个字段
}
```

### 忘记删除 UID

```move
// 错误！UID 没有 drop 能力，不能被丢弃
public fun bad_destroy(obj: MyObject) {
    let MyObject { id, value: _ } = obj;
    // 编译错误：id 没有被使用，也不能被隐式丢弃
}
```

正确做法是调用 `id.delete()`。

### 给资产对象添加 copy/drop

```move
// 数字资产不可被复制或丢弃
public struct BadToken has key, copy, drop {
    id: UID,
    value: u64,
}
```

`UID` 没有 `copy` 和 `drop` 的能力，上述做法会发生编译错误。

## 小结

Sui 的对象是链上数据的基本组织单元，也是数字资产概念的具体实现。核心要点如下：

- **对象定义**：具有 `key` 能力且第一个字段为 `id: UID` 的结构体就是 Sui 对象。
- **六大属性**：每个对象都有类型、唯一 ID、所有者、数据、版本和摘要。
- **UID 是关键**：UID 保证了对象的全局唯一性，创建时生成，销毁时必须显式删除。
- **对象 vs 值**：对象可以独立存在于链上，值只能嵌入对象中。
- **完整生命周期**：创建 → 上链 → 使用 → 销毁，每个阶段都有明确的语义。

理解了对象的概念和结构后，下一章我们将深入探讨 Sui 的所有权模型——对象最重要的属性之一。
