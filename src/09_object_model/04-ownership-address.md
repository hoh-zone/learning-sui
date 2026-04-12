# 地址所有的对象

地址所有（Address-owned）是 Sui 中最常见的所有权类型。当一个对象被转移给某个地址后，只有该地址的持有者才能在交易中使用它。这种模型直观地对应了现实世界中"个人拥有物品"的概念——你的钱包里的代币、你的 NFT 收藏、你的管理员权限凭证，都是地址所有的对象。

本章将深入探讨地址所有对象的创建、转移、使用模式，以及常见的设计模式。

## 创建与转移

创建一个地址所有的对象分为两步：构造对象，然后将其转移给某个地址。

### 使用 `transfer::transfer`

`transfer::transfer` 是模块内部使用的转移函数。它可以转移**任何具有 `key` 能力**的对象，即使该对象没有 `store` 能力：

```move
module examples::basic_transfer;

public struct Secret has key {
    id: UID,
    content: vector<u8>,
}

public fun create_and_send(
    content: vector<u8>,
    recipient: address,
    ctx: &mut TxContext,
) {
    let secret = Secret {
        id: object::new(ctx),
        content,
    };
    transfer::transfer(secret, recipient);
}
```

注意 `Secret` 只有 `key` 能力而没有 `store`。这意味着只有定义 `Secret` 的模块才能转移它——外部模块无法调用 `transfer::transfer` 来转移 `Secret`。

### 使用 `transfer::public_transfer`

如果对象同时具有 `key` 和 `store` 能力，可以使用 `transfer::public_transfer`。这个函数可以在**任何模块**中调用：

```move
module examples::public_transfer_demo;

public struct Collectible has key, store {
    id: UID,
    name: vector<u8>,
}

public fun create(name: vector<u8>, ctx: &mut TxContext): Collectible {
    Collectible {
        id: object::new(ctx),
        name,
    }
}

/// 任何拥有 Collectible 的人都可以转移它
public fun send(item: Collectible, to: address) {
    transfer::public_transfer(item, to);
}
```

`store` 能力的存在与否决定了对象的**可转移性控制**：

| | `key` only | `key + store` |
|---|---|---|
| 模块内转移 | `transfer::transfer` | `transfer::transfer` 或 `transfer::public_transfer` |
| 模块外转移 | 不可以 | `transfer::public_transfer` |

## 只有所有者可以使用

地址所有对象最重要的特性是：**只有所有者才能在交易中将其作为输入**。

当你提交一个交易时，Sui 运行时会检查：

1. 交易中引用的每个地址所有对象，其所有者是否匹配交易发送者
2. 对象的版本是否与链上最新版本一致

如果检查失败，交易会被直接拒绝，不会执行。

这种机制提供了强大的安全保障：即使你的合约代码有 bug，其他人也无法使用你的对象。

## 转移的语义：按值传递

在 Move 中，转移对象意味着**按值传递**。调用 `transfer::transfer(obj, addr)` 后，`obj` 被**消耗（consumed）**，调用者完全失去对它的控制：

```move
module examples::transfer_semantics;

public struct Token has key, store {
    id: UID,
    value: u64,
}

public fun transfer_demo(token: Token, recipient: address) {
    transfer::public_transfer(token, recipient);
    // 此处 token 已经被消耗，以下代码会导致编译错误：
    // let v = token.value;  // 错误！token 已经不存在
}
```

这确保了所有权转移的**原子性**——不会出现一个对象同时属于两个人的情况。

## 常见设计模式

### 能力模式（Capability Pattern）

能力模式是 Sui 开发中最重要的设计模式之一。它使用一个特殊的对象作为"权限凭证"，持有该对象的人拥有特定的操作权限。

```move
module examples::address_owned;

public struct AdminCap has key {
    id: UID,
}

public struct UserProfile has key, store {
    id: UID,
    name: vector<u8>,
    points: u64,
}

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::transfer(admin_cap, ctx.sender());
}

public fun create_profile(
    _: &AdminCap,
    name: vector<u8>,
    recipient: address,
    ctx: &mut TxContext,
) {
    let profile = UserProfile {
        id: object::new(ctx),
        name,
        points: 0,
    };
    transfer::public_transfer(profile, recipient);
}

public fun transfer_profile(profile: UserProfile, to: address) {
    transfer::public_transfer(profile, to);
}
```

#### 能力模式解析

1. **`AdminCap`**：一个只有 `key` 能力的结构体，作为管理员权限凭证。
2. **`init` 函数**：模块发布时自动执行，将 `AdminCap` 转移给发布者。
3. **`create_profile` 的第一个参数 `_: &AdminCap`**：虽然不使用其值（用 `_` 忽略），但要求调用者必须拥有 `AdminCap` 对象。由于 `AdminCap` 是地址所有的，只有管理员才能调用此函数。
4. **`AdminCap` 没有 `store`**：这意味着它不能被模块外部转移，增强了安全性。

### 转移到自身模式

有时函数需要创建对象并将其转移给交易发送者：

```move
module examples::self_transfer;

public struct Ticket has key {
    id: UID,
    event: vector<u8>,
    seat: u64,
}

/// 用户为自己购买门票
public fun buy_ticket(
    event: vector<u8>,
    seat: u64,
    ctx: &mut TxContext,
) {
    let ticket = Ticket {
        id: object::new(ctx),
        event,
        seat,
    };
    transfer::transfer(ticket, ctx.sender());
}
```

`ctx.sender()` 返回当前交易的发送者地址，将对象转移给它等于"给自己创建了一个新对象"。

### 多凭证模式

对于需要更精细权限控制的场景，可以使用多个不同的能力对象：

```move
module examples::multi_cap;

/// 可以创建内容
public struct CreatorCap has key { id: UID }

/// 可以删除内容
public struct ModeratorCap has key { id: UID }

public struct Post has key, store {
    id: UID,
    content: vector<u8>,
    author: address,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        CreatorCap { id: object::new(ctx) },
        ctx.sender(),
    );
    transfer::transfer(
        ModeratorCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

/// 只有 Creator 可以发布内容
public fun publish(
    _: &CreatorCap,
    content: vector<u8>,
    ctx: &mut TxContext,
) {
    let post = Post {
        id: object::new(ctx),
        content,
        author: ctx.sender(),
    };
    transfer::public_transfer(post, ctx.sender());
}

/// 只有 Moderator 可以删除内容
public fun remove(_: &ModeratorCap, post: Post) {
    let Post { id, content: _, author: _ } = post;
    id.delete();
}

/// Creator 和 Moderator 可以分别授权给不同的人
public fun delegate_creator(cap: CreatorCap, to: address) {
    transfer::transfer(cap, to);
}

public fun delegate_moderator(cap: ModeratorCap, to: address) {
    transfer::transfer(cap, to);
}
```

这种模式将不同的权限分离到不同的能力对象中，可以将它们授权给不同的地址，实现精细的权限管理。

## 地址所有对象的优势

### 交互成本

地址所有对象由单方独占使用，**不涉及多方对同一拥有对象的写争用**；与共享可变状态相比，通常更容易并行、交互更简单（见 [§8.4](09-owned-shared-and-ordering.md)）。**不**使用「快速路径」旧称，也不承诺固定毫秒延迟。

### 安全性

即使合约代码存在漏洞，攻击者也无法使用你地址下的对象。所有权检查是在运行时层面进行的，不依赖于合约逻辑。

### 简单性

地址所有权的语义非常直观——谁拥有对象，谁就能使用它。这降低了开发和理解的复杂度。

## 注意事项

### 不能在交易外查询"我拥有哪些对象"

Move 智能合约内部没有 API 可以列出某个地址拥有的所有对象。这种查询需要通过 Sui SDK 或索引服务在链外完成。

### 丢失私钥意味着丢失资产

地址所有对象只能由对应私钥的持有者使用。如果私钥丢失，对应地址下的所有对象将永久无法访问。

### 一次只能在一个交易中使用

一个地址所有对象在同一时刻只能被一个交易使用。如果你提交了两个使用同一对象的交易，只有一个会成功（基于版本检查）。

## 小结

地址所有对象是 Sui 中最基础也最常用的所有权类型。核心要点回顾：

- **独占控制**：只有所有者可以在交易中使用该对象。
- **按值转移**：转移操作消耗原对象，保证所有权的原子性转移。
- **能力模式**：通过持有特定的能力对象来控制操作权限，是 Sui 开发中的核心设计模式。
- **`key` vs `key + store`**：决定了对象是否可以在模块外部被转移。
- **争用面小**：无多方同时改写同一拥有对象的典型模式，适合个人资产主路径。

地址所有对象适用于所有"个人资产"场景。在需要多方共同访问数据时，应考虑使用共享对象或不可变对象。
