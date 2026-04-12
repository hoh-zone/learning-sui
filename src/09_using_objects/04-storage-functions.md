# 存储函数详解

Sui Move 通过 `sui::transfer` 模块提供了一组存储函数，用于决定对象在链上的**归属方式**——是转移给某个地址、冻结为不可变对象，还是共享给所有人。这些函数是 Sui 对象生命周期管理的核心工具，每个 Sui 开发者都必须熟练掌握。

## sui::transfer 模块概览

`sui::transfer` 模块是 Sui 框架的核心模块之一，它在每个 Sui Move 模块中被**隐式导入**，无需手动 `use`。该模块提供了六个主要的存储函数，分为内部版本和公开版本两组。

### 六个核心函数

| 内部函数 | 公开函数 | 作用 |
|---------|---------|------|
| `transfer::transfer` | `transfer::public_transfer` | 转移给指定地址 |
| `transfer::freeze_object` | `transfer::public_freeze_object` | 冻结为不可变对象 |
| `transfer::share_object` | `transfer::public_share_object` | 共享为共享对象 |

## 内部函数 vs 公开函数

这是 Sui 对象权限模型的核心区分：

### 内部函数（Internal Functions）

- 要求类型拥有 `key` 能力。
- **只能在定义该类型的模块内部调用**——这由 Sui 验证器在字节码层面强制执行。
- 适用于需要模块控制转移逻辑的场景。

### 公开函数（Public Functions）

- 要求类型同时拥有 `key` 和 `store` 能力。
- **可以在任何模块中调用**——不受定义模块的限制。
- 适用于需要自由流通的资产。

```move
module examples::storage_demo;

use std::string::String;

public struct AdminCap has key { id: UID }

public struct Gift has key, store {
    id: UID,
    message: String,
}

public struct Config has key {
    id: UID,
    message: String,
}
```

## transfer 与 public_transfer：转移给地址

`transfer` 将对象的所有权转移给指定的地址。转移后，只有该地址的持有者才能在交易中使用这个对象。

### 函数签名

```move
public fun transfer<T: key>(obj: T, recipient: address);
public fun public_transfer<T: key + store>(obj: T, recipient: address);
```

注意这两个函数都是按**值**接收对象（`obj: T`，不是引用），这意味着调用后原来的变量将不再可用——所有权被转移了。

### 使用示例

```move
fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };
    // AdminCap 只有 key，使用内部 transfer
    transfer::transfer(admin_cap, ctx.sender());
}

/// 内部转移（key only）
public fun transfer_admin(cap: AdminCap, to: address) {
    transfer::transfer(cap, to);
}

/// 公开转移（key + store）
public fun send_gift(gift: Gift, to: address) {
    transfer::public_transfer(gift, to);
}
```

### 转移的语义

调用 `transfer` 后：

1. 对象从当前上下文中移除（Move 语义，按值传递）。
2. 对象被标记为 `recipient` 地址拥有。
3. 后续只有 `recipient` 发起的交易才能使用该对象。
4. 对象成为**拥有对象（Owned Object）**。

## freeze_object 与 public_freeze_object：冻结为不可变

冻结操作将对象变为**不可变对象（Immutable Object）**。冻结后，对象永远不能被修改或删除，但任何人都可以通过不可变引用（`&T`）读取它。

### 函数签名

```move
public fun freeze_object<T: key>(obj: T);
public fun public_freeze_object<T: key + store>(obj: T);
```

### 使用示例

```move
/// 创建并冻结配置——使用内部版本
public fun create_config(
    _: &AdminCap,
    message: String,
    ctx: &mut TxContext,
) {
    let config = Config { id: object::new(ctx), message };
    transfer::freeze_object(config);
}

/// 冻结礼物——使用公开版本（Gift 有 store）
public fun freeze_gift(gift: Gift) {
    transfer::public_freeze_object(gift);
}
```

### 冻结的特性

- **不可逆**：一旦冻结，永远无法解冻。
- **全局可读**：任何交易都可以通过 `&T`（不可变引用）读取冻结对象。
- **无需所有权**：读取冻结对象不需要持有它的所有权。
- **不消耗 gas**：读取冻结对象不计入交易的对象输入限制。
- **适用场景**：全局配置、元数据、不变的合约参数。

```move
/// 任何人都可以读取冻结的 Config
public fun read_config(config: &Config): String {
    config.message
}
```

## share_object 与 public_share_object：共享给所有人

共享操作将对象变为**共享对象（Shared Object）**。共享对象没有特定的所有者，任何交易都可以通过可变引用（`&mut T`）或不可变引用（`&T`）访问它。

### 函数签名

```move
public fun share_object<T: key>(obj: T);
public fun public_share_object<T: key + store>(obj: T);
```

### 使用示例

```move
/// 创建并共享配置
public fun create_shared_config(
    message: String,
    ctx: &mut TxContext,
) {
    let config = Config { id: object::new(ctx), message };
    transfer::share_object(config);
}
```

### 共享对象的特性

- **不可逆**：一旦共享，无法取消共享或转回拥有对象。
- **全局可写**：任何交易都可以获取共享对象的可变引用进行修改。
- **共识排序**：涉及共享对象的交易需要经过共识排序，性能低于纯拥有对象交易。
- **适用场景**：全局状态（如 DEX 的流动性池）、注册表、计数器等。

```move
/// 修改共享的 Config
public fun update_shared_config(config: &mut Config, new_message: String) {
    config.message = new_message;
}
```

## 三种对象状态对比

| 特性 | 拥有对象 | 共享对象 | 不可变对象 |
|------|---------|---------|-----------|
| 所有者 | 特定地址 | 无（所有人） | 无 |
| 可修改 | 是（所有者） | 是（任何人） | 否 |
| 可删除 | 是 | 是 | 否 |
| 可转移 | 是 | 否 | 否 |
| 访问方式 | 按值/`&`/`&mut` | `&`/`&mut` | 仅 `&` |
| 共识需求 | 不需要 | 需要 | 不需要 |
| 性能 | 高 | 较低 | 高 |

## 拥有对象转冻结对象

一个常见的模式是先创建拥有对象，经过配置后再冻结它：

```move
public fun setup_and_freeze(
    message: String,
    ctx: &mut TxContext,
) {
    let mut config = Config {
        id: object::new(ctx),
        message,
    };

    // 在冻结前可以修改
    config.message = b"Final config".to_string();

    // 冻结后不可再修改
    transfer::freeze_object(config);
}
```

## 共享对象的删除

共享对象可以被删除，但需要按值传入（这要求交易指定该共享对象作为输入）：

```move
/// 删除共享的 Config
public fun delete_config(config: Config) {
    let Config { id, message: _ } = config;
    id.delete();
}
```

虽然在技术上可行，但删除共享对象需要谨慎——如果其他交易正在并发访问该共享对象，可能导致交易失败。

## Move 语义回顾

理解存储函数需要牢记 Move 的**所有权语义**：

### 按值传递（By Value）

```move
public fun consume(obj: Gift) {
    // obj 被移入函数，调用者不再拥有它
    transfer::public_transfer(obj, @0x1);
}
```

所有存储函数都按值接收对象，这保证了：
- 调用者失去对对象的所有权。
- 对象不可能被"双花"——同一个对象只能被转移一次。

### 按不可变引用（By Immutable Reference）

```move
public fun read_gift(gift: &Gift): String {
    gift.message
}
```

只能读取，不能修改或转移。

### 按可变引用（By Mutable Reference）

```move
public fun update_gift(gift: &mut Gift, new_message: String) {
    gift.message = new_message;
}
```

可以修改对象的字段，但不能转移或删除对象。

## 完整示例：多功能存储管理

```move
module examples::storage_manager;

use std::string::String;

public struct ManagerCap has key {
    id: UID,
}

public struct Document has key, store {
    id: UID,
    title: String,
    content: String,
    version: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        ManagerCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

/// 创建文档并转移给指定用户
public fun create_and_send(
    _: &ManagerCap,
    title: String,
    content: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let doc = Document {
        id: object::new(ctx),
        title,
        content,
        version: 1,
    };
    transfer::public_transfer(doc, recipient);
}

/// 创建文档并共享（所有人可编辑）
public fun create_and_share(
    title: String,
    content: String,
    ctx: &mut TxContext,
) {
    let doc = Document {
        id: object::new(ctx),
        title,
        content,
        version: 1,
    };
    transfer::public_share_object(doc);
}

/// 创建文档并冻结（只读模板）
public fun create_template(
    title: String,
    content: String,
    ctx: &mut TxContext,
) {
    let doc = Document {
        id: object::new(ctx),
        title,
        content,
        version: 1,
    };
    transfer::public_freeze_object(doc);
}

/// 编辑共享文档
public fun edit_document(
    doc: &mut Document,
    new_content: String,
) {
    doc.content = new_content;
    doc.version = doc.version + 1;
}

/// 删除文档
public fun delete_document(doc: Document) {
    let Document { id, title: _, content: _, version: _ } = doc;
    id.delete();
}
```

## 小结

- `sui::transfer` 模块提供六个核心存储函数，分为内部版本和公开版本。
- 内部版本（`transfer`/`freeze_object`/`share_object`）只能在定义类型的模块中使用，类型需要 `key`。
- 公开版本（`public_transfer`/`public_freeze_object`/`public_share_object`）可在任何模块使用，类型需要 `key + store`。
- 对象有三种链上状态：拥有（Owned）、共享（Shared）、不可变（Immutable），状态转换是单向的。
- 所有存储函数按值接收对象，遵循 Move 的所有权语义，确保对象不会被"双花"。
- 共享对象涉及共识排序，性能低于拥有对象——在设计时应尽量减少共享对象的使用。
