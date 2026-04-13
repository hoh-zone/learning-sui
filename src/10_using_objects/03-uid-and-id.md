# UID 与 ID

`UID` 和 `ID` 是 Sui 对象系统的基石类型。每个链上对象都通过一个全局唯一的 `UID` 来标识，而 `ID` 则是 `UID` 的轻量级引用形式，用于在不持有对象的情况下指向它。深入理解这两个类型的定义、生成机制和生命周期，是构建可靠 Sui 应用的前提。

## UID 的定义

`UID` 定义在 `sui::object` 模块中，是一个包装了 `ID` 的结构体：

```move
// sui::object 模块中的定义（简化）
public struct UID has store {
    id: ID,
}
```

而 `ID` 又是一个包装了 `address` 的结构体：

```move
public struct ID has copy, drop, store {
    bytes: address,
}
```

因此，层级关系为：

```
UID (has store)
 └── ID (has copy, drop, store)
      └── address (has copy, drop, store)
```

注意 `UID` 的能力：

- **有 `store`**：可以作为对象的字段（`key` 结构体要求所有字段有 `store`）。
- **没有 `copy`**：对象标识不可复制，确保唯一性。
- **没有 `drop`**：对象标识不可隐式丢弃，必须显式删除。

## UID 的生成机制

### object::new(ctx)

`UID` 通过 `object::new(ctx)` 创建，其中 `ctx` 是 `&mut TxContext`——交易上下文的可变引用：

```move
let uid: UID = object::new(ctx);
```

底层实现流程：

1. 从 `TxContext` 中获取**交易哈希**（`tx_hash`）。
2. 获取并递增 `TxContext` 中的**对象计数器**（`ids_created`）。
3. 将 `tx_hash` 和计数器值通过哈希函数派生出一个唯一的 `address`。
4. 用这个 `address` 构造 `ID`，再包装为 `UID`。

这个机制保证了：

- **同一笔交易内**：即使创建多个对象，每个 `UID` 都不同（计数器递增）。
- **不同交易之间**：交易哈希不同，派生的地址自然不同。
- **不可预测性**：外部无法提前计算出将要生成的 `UID`。

### 必须在同一函数中使用

`UID` 一旦创建，由于没有 `drop` 能力，必须在当前执行路径中被使用（嵌入到对象中）或被删除。编译器会确保不存在被遗忘的 `UID`。

## UID 的生命周期

一个 `UID` 从创建到销毁的完整生命周期：

```move
module examples::uid_demo;

public struct Character has key {
    id: UID,
    name: vector<u8>,
}

/// 创建并销毁一个角色——演示 UID 完整生命周期
public fun create_and_destroy(ctx: &mut TxContext) {
    // 1. 创建 UID
    let char = Character {
        id: object::new(ctx),
        name: b"Hero",
    };

    // 2. 解构对象，取出 UID
    let Character { id, name: _ } = char;

    // 3. 显式删除 UID
    id.delete();
}
```

### 三个阶段

| 阶段 | 操作 | 说明 |
|------|------|------|
| 创建 | `object::new(ctx)` | 生成全局唯一的 UID |
| 使用 | 作为对象的 `id` 字段 | 对象通过 UID 在链上寻址 |
| 删除 | `id.delete()` | 释放 UID，对象从链上消失 |

### 删除的重要性

`UID` 的删除不仅仅是内存释放——它意味着这个对象标识从 Sui 的全局对象表中移除。被删除的 `UID` 对应的对象将不再可查询或访问。

## ID 类型详解

`ID` 是 `UID` 的内部表示，但它拥有 `copy`、`drop` 和 `store`，使得它可以被自由复制和传递：

```move
/// 演示 ID 和地址的转换
public fun id_operations(ctx: &mut TxContext) {
    let uid: UID = object::new(ctx);

    // UID -> ID（复制内部 ID）
    let id: ID = uid.to_inner();

    // UID -> address
    let addr_from_uid: address = uid.to_address();

    // ID -> address
    let addr_from_id: address = id.to_address();

    assert!(addr_from_uid == addr_from_id, 0);

    uid.delete();
}
```

### ID 的常用方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `object::id<T>` | `&T -> ID` | 从对象引用获取 ID |
| `object::id_address<T>` | `&T -> address` | 从对象引用获取地址 |
| `uid.to_inner()` | `&UID -> ID` | 从 UID 引用获取 ID 副本 |
| `uid.to_address()` | `&UID -> address` | 从 UID 引用获取地址 |
| `id.to_address()` | `&ID -> address` | 从 ID 获取底层地址 |
| `object::id_to_address` | `&ID -> address` | 同上的模块函数形式 |
| `object::id_from_address` | `address -> ID` | 从地址构造 ID |

### ID 的典型用途

`ID` 常用于在不持有对象的情况下引用它：

```move
public struct Listing has key {
    id: UID,
    item_id: ID,        // 引用另一个对象
    seller: address,
    price: u64,
}

public struct TransferRecord has key {
    id: UID,
    object_id: ID,      // 记录哪个对象被转移了
    from: address,
    to: address,
}
```

## fresh_object_address

有时候你需要一个全局唯一的地址，但不需要创建完整的 `UID`（例如用作订单 ID、随机种子等）：

```move
/// 生成唯一的订单 ID，不创建对象
public fun unique_order_id(ctx: &mut TxContext): address {
    tx_context::fresh_object_address(ctx)
}
```

`fresh_object_address` 使用与 `object::new` 相同的派生机制，但只返回 `address`，不创建 `UID`。这意味着它也会递增 `TxContext` 中的计数器。

## UID 派生：derived_object 模块

Sui 还提供了基于已有 UID 的**确定性派生**机制，通过 `sui::derived_object` 模块实现：

```move
/// 从父对象的 UID 派生一个新的地址
public fun derive_id(uid: &UID, derivation_key: u64): address {
    // 基于 uid 的地址和 derivation_key 进行哈希派生
    sui::derived_object::derive_id(uid.to_address(), derivation_key)
}
```

派生 ID 的特点：

- **确定性**：同一个父 UID + 同一个 key，总是得到相同的派生地址。
- **用途**：创建与父对象逻辑关联的子对象，使得子对象的 ID 可预测。

## 删除证明（Proof of Deletion）

由于 `UID` 不能被 `drop`，必须通过 `id.delete()` 显式删除，这一特性可以被利用来实现**删除证明**模式：

```move
module examples::deletion_proof;

public struct Asset has key {
    id: UID,
    value: u64,
}

public struct DeletionReceipt has key {
    id: UID,
    deleted_asset_id: ID,
    deleted_value: u64,
}

/// 销毁资产并发放删除凭证
public fun destroy_with_receipt(
    asset: Asset,
    ctx: &mut TxContext,
): DeletionReceipt {
    let asset_id = object::id(&asset);
    let Asset { id, value } = asset;
    id.delete();

    DeletionReceipt {
        id: object::new(ctx),
        deleted_asset_id: asset_id,
        deleted_value: value,
    }
}
```

这个模式在以下场景非常有用：

- **跨模块销毁协议**：模块 A 需要验证模块 B 的对象已被销毁。
- **销毁即铸造**：销毁旧版本资产后，凭凭证铸造新版本。
- **退款流程**：销毁代金券后凭删除凭证领取退款。

## 完整示例：对象注册表

```move
module examples::registry;

use sui::table::{Self, Table};

public struct Registry has key {
    id: UID,
    items: Table<ID, address>,
    count: u64,
}

public struct Item has key, store {
    id: UID,
    data: vector<u8>,
}

public fun create_registry(ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        items: table::new(ctx),
        count: 0,
    };
    transfer::share_object(registry);
}

public fun register_item(
    registry: &mut Registry,
    data: vector<u8>,
    ctx: &mut TxContext,
) {
    let item = Item {
        id: object::new(ctx),
        data,
    };

    let item_id = object::id(&item);
    registry.items.add(item_id, ctx.sender());
    registry.count = registry.count + 1;

    transfer::public_transfer(item, ctx.sender());
}

public fun is_registered(registry: &Registry, item: &Item): bool {
    let item_id = object::id(item);
    registry.items.contains(item_id)
}
```

## 小结

- `UID` 是 Sui 对象的全局唯一标识符，由 `object::new(ctx)` 生成，底层通过交易哈希和计数器派生。
- `UID` 拥有 `store` 但没有 `copy` 和 `drop`，确保了对象标识的唯一性和不可丢弃性。
- `ID` 是 `UID` 的轻量级引用形式，拥有 `copy`、`drop`、`store`，适合用于记录和引用对象。
- `UID` 的生命周期包括创建、使用和删除三个阶段，每个 `UID` 最终必须被显式删除。
- `fresh_object_address` 可以生成唯一地址而不创建 `UID`，适用于需要唯一标识但不需要对象的场景。
- `UID` 的不可丢弃特性可以被利用来实现"删除证明"模式，为跨模块协作提供可验证的销毁凭证。
