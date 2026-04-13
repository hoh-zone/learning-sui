# Sui Framework 概览

Sui Framework 是每个 Sui Move 项目的默认依赖，它构建在 Move 标准库（Standard Library）之上，为开发者提供了丰富的链上编程原语。理解 Sui Framework 的模块结构和核心接口，是高效编写 Sui 智能合约的基础。本章将系统梳理 Sui Framework 的架构、核心模块和常用工具模块。

## 框架依赖关系

Sui Framework 本身依赖于 Move 标准库（`std`），因此当你在 `Move.toml` 中声明 Sui Framework 依赖时，标准库会自动引入，无需单独声明。

```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
```

> 默认 `rev` 约定见[第二章 · Move 2024](../02_getting_started/04-move-2024.md)中的「Sui Framework 依赖：`rev` 与网络」；在 testnet 开发时可改用 `framework/testnet`。

Sui Framework 导出了两个命名地址：

| 地址别名 | 实际地址 | 说明 |
|---------|---------|------|
| `std`   | `0x1`   | Move 标准库地址 |
| `sui`   | `0x2`   | Sui Framework 地址 |

这意味着你可以在代码中直接使用 `sui::` 和 `std::` 前缀来引用对应模块，而无需在 `Move.toml` 中手动定义这两个地址。

## 隐式导入

Sui Framework 中有三个模块会被**自动隐式导入**，你无需编写 `use` 语句即可直接使用它们的类型和函数：

- **`sui::object`** — 提供 `UID`、`ID` 等对象相关类型和 `object::new()`、`object::id()` 等函数
- **`sui::tx_context`** — 提供 `TxContext` 类型和 `ctx.sender()`、`ctx.epoch()` 等方法
- **`sui::transfer`** — 提供 `transfer::transfer()`、`transfer::share_object()` 等对象转移函数

```move
module examples::framework_usage;

// 以下模块被隐式导入，无需 `use` 语句：
// - sui::object (UID, ID)
// - sui::tx_context (TxContext)
// - sui::transfer

// 其他框架模块则需要显式导入
use sui::event;
use sui::clock::Clock;

public struct MyObject has key {
    id: UID,   // UID 来自 sui::object（隐式导入）
}

public struct MyEvent has copy, drop {
    created: bool,
}

public fun create(ctx: &mut TxContext) {
    let obj = MyObject { id: object::new(ctx) };
    event::emit(MyEvent { created: true });
    transfer::transfer(obj, ctx.sender());
}
```

上述代码中，`UID`、`object::new`、`transfer::transfer`、`ctx.sender()` 均来自隐式导入的模块，而 `event` 和 `Clock` 则需要显式声明 `use` 语句。

## 核心模块

核心模块提供了 Sui 对象模型和交易系统的基础能力，是几乎每个合约都会用到的模块。

| 模块 | 说明 |
|------|------|
| `sui::object` | 对象标识：`UID` 和 `ID` 类型，`new()`、`delete()`、`id()` 等 |
| `sui::transfer` | 对象所有权转移：`transfer`、`public_transfer`、`share_object`、`freeze_object` |
| `sui::tx_context` | 交易上下文：获取发送者地址、epoch、时间戳等 |
| `sui::address` | 地址工具：地址长度常量、与 `u256`/`vector<u8>` 之间的转换 |
| `sui::clock` | 链上时钟：提供毫秒级时间戳，共享对象位于 `0x6` |
| `sui::dynamic_field` | 动态字段：为对象附加异构键值对数据 |
| `sui::dynamic_object_field` | 动态对象字段：类似动态字段，但值必须是 Sui 对象 |
| `sui::event` | 事件系统：`emit()` 函数向链下发送通知 |
| `sui::package` | 包管理：`Publisher` 类型、包升级策略 |
| `sui::display` | 显示标准：为对象类型定义链下展示模板 |

### sui::object

`sui::object` 是 Sui 对象系统的基石。每个 Sui 对象都必须包含一个 `UID` 类型的 `id` 字段，`UID` 在内部封装了全局唯一的 `ID`。

```move
module examples::object_demo;

public struct Artifact has key {
    id: UID,
    power: u64,
}

public fun create_artifact(power: u64, ctx: &mut TxContext): Artifact {
    Artifact {
        id: object::new(ctx),
        power,
    }
}

public fun artifact_id(artifact: &Artifact): ID {
    object::id(artifact)
}

public fun destroy_artifact(artifact: Artifact) {
    let Artifact { id, power: _ } = artifact;
    id.delete();
}
```

### sui::transfer

`sui::transfer` 控制对象的所有权和访问方式。它提供了四种核心操作：

- `transfer::transfer(obj, recipient)` — 将对象转移给指定地址（需要在定义模块中调用）
- `transfer::public_transfer(obj, recipient)` — 公开转移（对象需要 `store` 能力）
- `transfer::share_object(obj)` — 将对象设为共享，所有人可访问
- `transfer::freeze_object(obj)` — 冻结对象，变为不可变

```move
module examples::transfer_demo;

public struct Gift has key, store {
    id: UID,
    message: vector<u8>,
}

public fun send_gift(message: vector<u8>, recipient: address, ctx: &mut TxContext) {
    let gift = Gift { id: object::new(ctx), message };
    // 因为 Gift 有 store，可以使用 public_transfer
    transfer::public_transfer(gift, recipient);
}

public struct SharedBoard has key {
    id: UID,
    posts: vector<vector<u8>>,
}

public fun create_shared_board(ctx: &mut TxContext) {
    let board = SharedBoard {
        id: object::new(ctx),
        posts: vector::empty(),
    };
    transfer::share_object(board);
}
```

## 集合模块

Sui Framework 提供了多种集合类型，适用于不同的数据存储需求。

| 模块 | 类型 | 存储方式 | 适用场景 |
|------|------|---------|---------|
| `sui::vec_set` | `VecSet<K>` | 对象内部 | 小规模去重集合 |
| `sui::vec_map` | `VecMap<K, V>` | 对象内部 | 小规模键值映射 |
| `sui::table` | `Table<K, V>` | 动态字段 | 大规模同构键值存储 |
| `sui::bag` | `Bag` | 动态字段 | 异构键值存储 |
| `sui::object_table` | `ObjectTable<K, V>` | 动态对象字段 | 存储值为对象的表 |
| `sui::object_bag` | `ObjectBag` | 动态对象字段 | 存储值为对象的异构包 |
| `sui::linked_table` | `LinkedTable<K, V>` | 动态字段 | 支持顺序遍历的表 |

`VecSet` 和 `VecMap` 基于 `vector` 实现，数据存储在对象内部，适合小数据集（通常几十到几百个元素）。`Table`、`Bag` 等基于动态字段实现，每个条目独立存储，适合大规模数据且不受单个对象大小限制。

```move
module examples::collection_overview;

use sui::table::{Self, Table};
use sui::vec_map::{Self, VecMap};

public struct UserRegistry has key {
    id: UID,
    // Table: 适合大量用户数据，每条记录独立存储
    profiles: Table<address, vector<u8>>,
    // VecMap: 适合少量配置项，存储在对象内部
    settings: VecMap<vector<u8>, vector<u8>>,
}

public fun create_registry(ctx: &mut TxContext) {
    let registry = UserRegistry {
        id: object::new(ctx),
        profiles: table::new(ctx),
        settings: vec_map::empty(),
    };
    transfer::share_object(registry);
}

public fun register(registry: &mut UserRegistry, profile: vector<u8>, ctx: &TxContext) {
    registry.profiles.add(ctx.sender(), profile);
}
```

## 工具模块

Sui Framework 还提供了若干通用工具模块，覆盖序列化、类型检查、十六进制编码等常见需求。

| 模块 | 说明 |
|------|------|
| `sui::bcs` | BCS（Binary Canonical Serialization）编解码 |
| `sui::borrow` | 安全借用：保证取出的对象必须归还 |
| `sui::hex` | 十六进制字符串编解码 |
| `sui::types` | 类型工具：`is_one_time_witness()` 判断 OTW |

### sui::bcs

BCS 是 Move 生态的标准序列化格式。`sui::bcs` 模块允许你在合约内对数据进行序列化和反序列化，这在跨模块通信、链下数据验证等场景中非常有用。

```move
module examples::bcs_demo;

use sui::bcs;

public struct Config has copy, drop {
    version: u64,
    active: bool,
}

public fun serialize_config(config: &Config): vector<u8> {
    bcs::to_bytes(config)
}

public fun deserialize_u64(data: vector<u8>): u64 {
    let mut bcs_data = bcs::new(data);
    bcs::peel_u64(&mut bcs_data)
}
```

### sui::types

`sui::types` 模块最常用的功能是 `is_one_time_witness<T>()`，用于在 `init` 函数中验证传入的类型是否为合法的一次性见证（OTW）。

```move
module examples::types_demo;

use sui::types;
use sui::package;

public struct TYPES_DEMO has drop {}

fun init(otw: TYPES_DEMO, ctx: &mut TxContext) {
    // 验证 OTW 合法性
    assert!(types::is_one_time_witness(&otw), 0);

    let publisher = package::claim(otw, ctx);
    transfer::public_transfer(publisher, ctx.sender());
}
```

## 使用建议

1. **优先使用隐式导入的模块**：`object`、`transfer`、`tx_context` 不需要 `use` 语句，保持代码简洁。
2. **选择合适的集合类型**：小数据集用 `VecSet`/`VecMap`，大数据集用 `Table`/`Bag`。
3. **理解地址常量**：`@sui`（`0x2`）和 `@std`（`0x1`）是框架预定义的。
4. **查阅源码**：Sui Framework 完全开源，遇到不确定的 API，直接阅读源码是最可靠的方式。

## 小结

Sui Framework 是 Sui Move 开发的核心基础设施，它在 Move 标准库之上构建了完整的链上编程能力。框架分为三大类模块：**核心模块**（对象、转移、上下文、事件等）负责对象生命周期管理；**集合模块**（Table、Bag、VecMap 等）提供多种数据结构选择；**工具模块**（BCS、hex、types 等）覆盖序列化和类型检查等通用需求。其中 `sui::object`、`sui::transfer` 和 `sui::tx_context` 三个模块会被隐式导入，是最基础也是最常用的模块。掌握 Sui Framework 的模块体系，能让你在编写合约时快速找到合适的工具，提升开发效率。
