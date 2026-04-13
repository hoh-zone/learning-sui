# 共享对象

共享对象（Shared Object）是 Sui 中唯一一种允许**任何人**以可变方式访问的所有权类型。与地址所有对象的独占控制不同，共享对象没有特定的所有者——任何地址都可以在交易中读取或修改它。这使得共享对象成为构建去中心化市场、流动性池、投票系统等多方交互应用的核心构建块。

本章将深入探讨共享对象的创建、使用、性能影响，以及设计共享对象时需要注意的陷阱。

## 创建共享对象

与不可变对象类似，共享对象也有两种创建方式。

### `transfer::share_object`

在定义对象类型的模块内部使用，对象只需具有 `key` 能力：

```move
module examples::share_demo;

public struct Registry has key {
    id: UID,
    entries: vector<vector<u8>>,
}

public fun create(ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        entries: vector::empty(),
    };
    transfer::share_object(registry);
}
```

### `transfer::public_share_object`

可以在任何模块中调用，但要求对象同时具有 `key` 和 `store` 能力：

```move
module examples::public_share_demo;

public struct Pool has key, store {
    id: UID,
    balance: u64,
}

public fun create_pool(ctx: &mut TxContext): Pool {
    Pool {
        id: object::new(ctx),
        balance: 0,
    }
}

public fun share_pool(pool: Pool) {
    transfer::public_share_object(pool);
}
```

## 共享对象的核心特性

### 任何人可访问

共享对象可以被任何地址在交易中引用。在交易中，你可以通过以下方式使用共享对象：

- **`&T`**（不可变引用）：读取数据
- **`&mut T`**（可变引用）：读取和修改数据
- **`T`**（按值）：只在销毁对象时使用

### 共识排序

由于多个交易可能同时尝试修改同一个共享对象，Sui 需要通过**共识机制**对这些交易进行排序。这意味着涉及共享对象的交易延迟高于地址所有对象的交易。

### 不可逆转

一旦对象被共享，就**永远不能**：

- 转移给某个地址（变为地址所有）
- 冻结（变为不可变）
- 只能通过销毁来"移除"

## 完整示例：共享计数器

以下是一个经典的共享计数器示例：

```move
module examples::shared_counter;

const ENotCreator: u64 = 0;

public struct Counter has key {
    id: UID,
    value: u64,
    owner: address,
}

public fun create_and_share(ctx: &mut TxContext) {
    let counter = Counter {
        id: object::new(ctx),
        value: 0,
        owner: ctx.sender(),
    };
    transfer::share_object(counter);
}

/// Anyone can increment the counter
public fun increment(counter: &mut Counter) {
    counter.value = counter.value + 1;
}

/// Anyone can read the value
public fun value(counter: &Counter): u64 {
    counter.value
}

/// Only the creator can destroy the shared counter
public fun destroy(counter: Counter, ctx: &TxContext) {
    assert!(counter.owner == ctx.sender(), ENotCreator);
    let Counter { id, value: _, owner: _ } = counter;
    id.delete();
}
```

### 示例解析

1. **创建即共享**：`create_and_share` 在同一个函数中创建并共享计数器。注意我们保存了创建者的地址（`owner`），以便后续进行权限检查。
2. **任何人可递增**：`increment` 接受 `&mut Counter`，任何地址都可以调用它来增加计数值。
3. **任何人可读取**：`value` 接受 `&Counter`，纯读取操作。
4. **权限控制销毁**：虽然共享对象可以被任何人访问，但我们在 `destroy` 中通过 `assert!` 检查只有创建者可以销毁它。

## 共享对象的删除

共享对象是可以被删除的，这是一个常见的误解需要澄清。删除共享对象需要：

1. 以**按值（`T`）** 方式接收共享对象
2. 解构对象，删除其 `UID`

```move
module examples::shared_deletion;

const ENotCreator: u64 = 0;

public struct SharedBox has key {
    id: UID,
    content: vector<u8>,
    creator: address,
}

public fun create(content: vector<u8>, ctx: &mut TxContext) {
    let box_obj = SharedBox {
        id: object::new(ctx),
        content,
        creator: ctx.sender(),
    };
    transfer::share_object(box_obj);
}

/// 销毁共享对象 - 注意参数类型是 SharedBox（按值），不是 &mut SharedBox
public fun destroy(box_obj: SharedBox, ctx: &TxContext) {
    assert!(box_obj.creator == ctx.sender(), ENotCreator);
    let SharedBox { id, content: _, creator: _ } = box_obj;
    id.delete();
}
```

当在交易中使用共享对象并按值传递时，Sui 会检查该对象确实是共享的，并纳入**共享状态的一致性/排序**流程（实现随版本演进）。

## 性能影响与优化策略

### 排序与延迟

涉及共享对象的交易需要验证者网络对**访问同一共享对象**的请求形成一致顺序；与仅操作单方拥有对象、或只读不可变数据的交易相比，**通常更重、延迟更高**——具体数字随版本与负载变化，以实测与官方文档为准。本书**不**再对比「快速路径 vs 共识路径」的固定毫秒表。

### 热点问题

如果一个共享对象被大量交易同时访问和修改，它会成为**热点（hotspot）**，限制系统吞吐量。常见热点场景：

- 全局计数器
- 单一的流动性池
- 集中式的订单簿

### 优化策略

#### 策略一：最小化共享对象的使用

尽可能将数据存储在地址所有对象中，只在必要时使用共享对象：

```move
module examples::minimize_shared;

/// 不好的设计：所有用户数据存在一个共享对象中
public struct BadUserStore has key {
    id: UID,
    users: vector<address>,
    balances: vector<u64>,
}

/// 好的设计：每个用户有自己的对象（地址所有）
public struct UserAccount has key {
    id: UID,
    balance: u64,
}

/// 只在需要多方交互时使用共享对象
public struct Marketplace has key {
    id: UID,
    listings: vector<Listing>,
}

public struct Listing has store {
    seller: address,
    price: u64,
    item_id: address,
}
```

#### 策略二：分片

将一个大的共享对象拆分为多个：

```move
module examples::sharding;

/// 不好的设计：单一全局计数器
public struct GlobalCounter has key {
    id: UID,
    count: u64,
}

/// 好的设计：分区计数器
public struct ShardedCounter has key {
    id: UID,
    shard_id: u8,
    count: u64,
}

/// 创建多个分片
public fun create_shards(ctx: &mut TxContext) {
    let mut i: u8 = 0;
    while (i < 10) {
        let shard = ShardedCounter {
            id: object::new(ctx),
            shard_id: i,
            count: 0,
        };
        transfer::share_object(shard);
        i = i + 1;
    };
}

/// 用户根据某种规则选择一个分片来递增
public fun increment_shard(shard: &mut ShardedCounter) {
    shard.count = shard.count + 1;
}
```

#### 策略三：读写分离

对于读多写少的场景，考虑使用不可变对象存储只读数据，共享对象只负责写操作：

```move
module examples::read_write_split;

use std::string::String;

/// 不可变对象：存储产品目录（只读）
public struct ProductCatalog has key {
    id: UID,
    products: vector<String>,
}

/// 共享对象：存储订单（需要读写）
public struct OrderBook has key {
    id: UID,
    orders: vector<Order>,
}

public struct Order has store, drop {
    buyer: address,
    product_index: u64,
    quantity: u64,
}
```

## 共享对象的安全考虑

### 权限控制

共享对象可以被任何人访问，因此**必须在函数逻辑中实现权限控制**：

```move
module examples::shared_security;

const ENotAdmin: u64 = 0;
const EInsufficientBalance: u64 = 1;

public struct Treasury has key {
    id: UID,
    balance: u64,
    admin: address,
}

public fun create(ctx: &mut TxContext) {
    let treasury = Treasury {
        id: object::new(ctx),
        balance: 0,
        admin: ctx.sender(),
    };
    transfer::share_object(treasury);
}

/// 任何人可以存款
public fun deposit(treasury: &mut Treasury, amount: u64) {
    treasury.balance = treasury.balance + amount;
}

/// 只有管理员可以取款
public fun withdraw(
    treasury: &mut Treasury,
    amount: u64,
    ctx: &TxContext,
): u64 {
    assert!(treasury.admin == ctx.sender(), ENotAdmin);
    assert!(treasury.balance >= amount, EInsufficientBalance);
    treasury.balance = treasury.balance - amount;
    amount
}
```

### 重入安全

与以太坊不同，Sui 的交易模型天然防止重入攻击。每个交易是原子性的，在一个交易内对共享对象的修改不会被其他交易"中途"观察到。

### 前置交易（Front-running）

由于共享对象的交易需要共识排序，理论上存在前置交易（front-running）的风险——矿工/验证者可以在看到你的交易后抢先提交自己的交易。在设计金融协议时需要考虑这一点。

## 共享对象 vs 其他所有权类型

| 特性 | Address-owned | Shared | Immutable |
|------|-------------|--------|-----------|
| 访问权限 | 仅所有者 | 任何人 | 任何人（只读） |
| 修改 | 所有者可修改 | 任何人可修改 | 不可修改 |
| 删除 | 所有者可删除 | 可删除（需权限检查） | 不可删除 |
| 转移 | 可转移 | 不可转移 | 不可转移 |
| 多方写争用 | 无（独占） | 有 | 无（只读） |
| 并发性 | 低（独占） | 需要排序 | 高（无限并行） |

## 小结

共享对象是 Sui 中实现多方交互的关键机制，但也带来了性能和安全方面的挑战：

- **创建方式**：通过 `share_object`（模块内部）或 `public_share_object`（需要 `store` 能力）。
- **任何人可访问**：共享对象可以被任何地址在交易中使用，支持读写操作。
- **排序成本**：涉及共享可变对象的交易需要全局协调，通常比纯拥有对象场景更重。
- **不可逆转**：共享状态是不可逆的，但共享对象可以被销毁。
- **权限控制**：必须在合约逻辑中自行实现，因为任何人都能调用函数。
- **性能优化**：最小化共享对象的使用、分片、读写分离是常见的优化策略。

在设计 Sui 应用时，应该审慎使用共享对象——只在确实需要多方交互时才使用，其余数据尽量存储在地址所有或不可变对象中。
