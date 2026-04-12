# 不可变对象

不可变对象（Immutable Object）是 Sui 中一种特殊的所有权状态。当对象被冻结（frozen）后，它将**永久不可修改**——没有任何人可以更改、删除或转移它，但任何人都可以读取它的数据。不可变对象就像刻在石碑上的铭文，一旦刻下便永恒不变，供所有人查阅。

本章将深入探讨不可变对象的创建方式、使用约束、性能特征，以及在实际开发中的最佳实践。

## 创建不可变对象

将对象变为不可变状态有两种方式，取决于调用的上下文和对象的能力。

### `transfer::freeze_object`

`freeze_object` 只能在**定义该对象类型的模块内部**调用。对象只需具有 `key` 能力：

```move
module examples::freeze_demo;

public struct Rule has key {
    id: UID,
    description: vector<u8>,
}

public fun create_and_freeze(
    description: vector<u8>,
    ctx: &mut TxContext,
) {
    let rule = Rule {
        id: object::new(ctx),
        description,
    };
    transfer::freeze_object(rule);
}
```

### `transfer::public_freeze_object`

`public_freeze_object` 可以在**任何模块**中调用，但要求对象同时具有 `key` 和 `store` 能力：

```move
module examples::public_freeze_demo;

public struct Announcement has key, store {
    id: UID,
    message: vector<u8>,
}

public fun create(message: vector<u8>, ctx: &mut TxContext): Announcement {
    Announcement {
        id: object::new(ctx),
        message,
    }
}

/// 因为 Announcement 有 store，任何模块都可以调用此函数冻结它
public fun make_permanent(announcement: Announcement) {
    transfer::public_freeze_object(announcement);
}
```

### `freeze_object` vs `public_freeze_object` 对比

| 特性 | `freeze_object` | `public_freeze_object` |
|------|----------------|----------------------|
| 要求的能力 | `key` | `key + store` |
| 调用位置 | 仅定义模块内 | 任何模块 |
| 控制力 | 模块完全控制冻结逻辑 | 外部也可以冻结 |

## 不可变对象的约束

一旦对象被冻结，以下操作都**永久不可执行**：

### 不可修改

不可变对象只能以不可变引用（`&T`）的形式在交易中使用。任何试图获取可变引用（`&mut T`）或按值（`T`）使用的操作都会被拒绝。

```move
module examples::immutable_access;

public struct Config has key {
    id: UID,
    value: u64,
}

/// 这个函数可以接受不可变对象
public fun value(config: &Config): u64 {
    config.value
}

/// 这个函数不能接受不可变对象（需要 &mut）
public fun update(config: &mut Config, new_value: u64) {
    config.value = new_value;
}
```

如果 `Config` 对象已被冻结，只有 `value` 函数可以使用它，`update` 函数将无法在交易中引用这个对象。

### 不可删除

不可变对象不能被解构和销毁。即使模块提供了销毁函数，也无法在交易中按值获取冻结的对象。

### 不可转移

不可变对象没有"所有者"——它属于所有人。因此不存在转移所有权的概念。

## 完整示例：游戏配置

以下是一个使用不可变对象存储游戏配置的完整示例：

```move
module examples::immutable_config;

use std::string::String;

public struct GameConfig has key {
    id: UID,
    max_players: u64,
    game_name: String,
    version: u64,
}

public struct AdminCap has key { id: UID }

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

public fun create_and_freeze(
    _: &AdminCap,
    max_players: u64,
    game_name: String,
    version: u64,
    ctx: &mut TxContext,
) {
    let config = GameConfig {
        id: object::new(ctx),
        max_players,
        game_name,
        version,
    };
    transfer::freeze_object(config);
}

/// Anyone can read config via immutable reference
public fun max_players(config: &GameConfig): u64 {
    config.max_players
}

public fun game_name(config: &GameConfig): &String {
    &config.game_name
}
```

### 示例解析

1. **`AdminCap` 控制创建权**：只有管理员可以创建游戏配置，这通过能力模式保证。
2. **创建即冻结**：`create_and_freeze` 在同一个函数中创建并冻结配置。这是一个常见模式——配置对象从来不会处于可修改状态。
3. **只提供读取函数**：`max_players` 和 `game_name` 都接受 `&GameConfig`（不可变引用），这是使用不可变对象的唯一方式。
4. **没有更新函数**：既然对象是不可变的，提供更新函数没有意义。如果需要"更新配置"，应该创建一个新的配置对象（带有新版本号）并冻结它。

## 从地址所有到冻结的转换

对象可以先作为地址所有对象存在，然后在某个时刻被冻结。这在某些场景中很有用——例如，先让管理员对配置进行调整，确认无误后再冻结：

```move
module examples::owned_to_frozen;

use std::string::String;

public struct Document has key {
    id: UID,
    title: String,
    content: String,
    finalized: bool,
}

public struct EditorCap has key { id: UID }

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        EditorCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

/// 创建一个可编辑的文档（地址所有）
public fun create_draft(
    _: &EditorCap,
    title: String,
    content: String,
    ctx: &mut TxContext,
) {
    let doc = Document {
        id: object::new(ctx),
        title,
        content,
        finalized: false,
    };
    transfer::transfer(doc, ctx.sender());
}

/// 编辑文档内容（地址所有状态下）
public fun edit(doc: &mut Document, new_content: String) {
    assert!(!doc.finalized, 0);
    doc.content = new_content;
}

/// 定稿并冻结文档（从地址所有 → 不可变）
public fun finalize(doc: Document) {
    let Document { id, title: _, content: _, finalized: _ } = doc;
    // 注意：这里需要重新创建一个标记为 finalized 的文档
    // 因为我们不能修改后再冻结同一个对象
    id.delete();
}

/// 更好的做法：直接冻结整个对象
public fun publish(mut doc: Document) {
    doc.finalized = true;
    transfer::freeze_object(doc);
}
```

### 转换注意事项

- 冻结操作需要对象的**值**（按值传递），而非引用
- 这意味着调用者必须是对象的所有者
- 冻结后，对象永远无法回到地址所有或共享状态

## 不可变对象的性能优势

不可变对象在 Sui 的执行模型中享有与地址所有对象相同的**快速路径**优势：

### 为什么不需要共识？

共识排序的目的是解决"多个交易同时修改同一对象"的冲突。不可变对象**永远不会被修改**，因此不存在这种冲突，自然不需要共识排序。

### 多交易并行使用

不可变对象可以被**无限数量的交易同时使用**，因为每个交易都只是读取它，不存在竞争条件。这使得不可变对象成为高吞吐量场景下的理想选择。

### 与共享对象的性能对比

| 特性 | 不可变对象 | 共享对象 |
|------|----------|---------|
| 执行路径 | 快速路径 | 共识路径 |
| 并发访问 | 无限制 | 需要排序 |
| 延迟 | 极低 | 较高 |
| 适用场景 | 只读数据 | 需要修改的共享数据 |

## 实际应用场景

### 全局常量

将应用的常量配置存储为不可变对象，所有用户都可以读取：

```move
module examples::constants;

public struct AppConstants has key {
    id: UID,
    fee_rate_bps: u64,     // 手续费率（基点）
    min_deposit: u64,       // 最小存款额
    max_withdrawal: u64,    // 最大取款额
}

fun init(ctx: &mut TxContext) {
    let constants = AppConstants {
        id: object::new(ctx),
        fee_rate_bps: 30,      // 0.3%
        min_deposit: 1000,
        max_withdrawal: 1_000_000,
    };
    transfer::freeze_object(constants);
}

public fun fee_rate(c: &AppConstants): u64 { c.fee_rate_bps }
public fun min_deposit(c: &AppConstants): u64 { c.min_deposit }
public fun max_withdrawal(c: &AppConstants): u64 { c.max_withdrawal }
```

### 合约元数据

存储合约的版本信息、描述等元数据：

```move
module examples::metadata;

use std::string::String;

public struct PackageInfo has key {
    id: UID,
    name: String,
    version: String,
    author: address,
    description: String,
}

fun init(ctx: &mut TxContext) {
    let info = PackageInfo {
        id: object::new(ctx),
        name: b"MyDApp".to_string(),
        version: b"1.0.0".to_string(),
        author: ctx.sender(),
        description: b"A decentralized application on Sui".to_string(),
    };
    transfer::freeze_object(info);
}
```

## 版本化配置的更新策略

既然不可变对象不能修改，那如何"更新"配置？常见策略是**创建新版本**：

```move
module examples::versioned_config;

use std::string::String;

public struct Config has key {
    id: UID,
    version: u64,
    data: String,
}

public struct AdminCap has key { id: UID }

/// 创建新版本的配置并冻结
public fun publish_config(
    _: &AdminCap,
    version: u64,
    data: String,
    ctx: &mut TxContext,
) {
    let config = Config {
        id: object::new(ctx),
        version,
        data,
    };
    transfer::freeze_object(config);
}
```

客户端应用通过版本号来选择使用最新的配置对象。旧版本的配置依然存在于链上，可以作为历史记录查阅。

## 小结

不可变对象为 Sui 开发者提供了一种高效的只读数据共享机制。核心要点如下：

- **创建方式**：通过 `freeze_object`（模块内部）或 `public_freeze_object`（需要 `store` 能力）冻结。
- **永久约束**：冻结后不可修改、不可删除、不可转移，操作不可逆。
- **访问方式**：只能以不可变引用（`&T`）使用，任何人都可以读取。
- **性能优势**：走快速路径执行，可以被无限数量的交易并行使用。
- **适用场景**：全局配置、合约元数据、常量数据、参考数据集等只读场景。
- **更新策略**：通过创建新版本的不可变对象来实现"更新"。

在需要全局共享且永不更改的数据时，不可变对象是最佳选择——它兼具安全性和高性能。
