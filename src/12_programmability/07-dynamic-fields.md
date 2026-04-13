# 动态字段

## 导读

本节对应 [§12.1](01-sui-framework.md) 中的 **`sui::dynamic_field`**：在 **`UID`** 上按运行时键挂载额外数据，**突破编译期固定字段**。它是 [§12.8](08-dynamic-object-fields.md)、[§12.10](10-dynamic-collections.md) 的**底层机制**——`Table`/`Bag` 等都在此之上封装。

- **前置**：[§12.1](01-sui-framework.md)、[第九章 · UID](../09_using_objects/03-uid-and-id.md)  
- **后续**：[§12.8](08-dynamic-object-fields.md)、[§12.10](10-dynamic-collections.md)  

---

动态字段（Dynamic Fields）是 Sui Move 中最强大的存储机制之一。它允许你在运行时为对象添加、修改和删除任意键值对数据，突破了结构体字段在编译时固定的限制。动态字段没有数量上限，可以存储异构数据类型，是构建灵活、可扩展合约的核心工具。

## 基本概念

### 什么是动态字段

普通的结构体字段在编译时确定，一旦定义就不能增减。动态字段则不同——它们在运行时通过名称（key）附加到对象的 `UID` 上，存储在独立的内部 `Field` 对象中。

从概念上说，动态字段就像是一个无限大小的键值存储，挂载在某个 Sui 对象上。

### 工作原理

当你调用 `dynamic_field::add(uid, name, value)` 时：

1. Sui 运行时创建一个内部 `Field<Name, Value>` 对象
2. 该 `Field` 对象以 `name` 为键，与目标对象的 `UID` 关联
3. `value` 被存储在这个 `Field` 对象中
4. 这个 `Field` 对象不会出现在对象的序列化表示中，但可以通过 `UID` 和 `name` 访问

### 类型约束

| 约束 | 名称（Name） | 值（Value） |
|------|-------------|------------|
| 必须能力 | `copy + drop + store` | `store` |
| 说明 | 用于查找和比较 | 需要持久化存储 |

## 核心 API

动态字段的操作由 `sui::dynamic_field` 模块提供：

| 函数 | 签名 | 说明 |
|------|------|------|
| `add` | `fun add<Name, Value>(uid: &mut UID, name: Name, value: Value)` | 添加字段，名称重复则 abort |
| `remove` | `fun remove<Name, Value>(uid: &mut UID, name: Name): Value` | 移除并返回字段值 |
| `borrow` | `fun borrow<Name, Value>(uid: &UID, name: Name): &Value` | 借用字段值（不可变） |
| `borrow_mut` | `fun borrow_mut<Name, Value>(uid: &mut UID, name: Name): &mut Value` | 借用字段值（可变） |
| `exists_` | `fun exists_<Name>(uid: &UID, name: Name): bool` | 检查字段是否存在 |
| `exists_with_type` | `fun exists_with_type<Name, Value>(uid: &UID, name: Name): bool` | 检查指定类型的字段是否存在 |

## 基础用法

### 添加和读取动态字段

```move
module examples::dynamic_fields_demo;

use sui::dynamic_field as df;
use std::string::String;

public struct Character has key {
    id: UID,
    name: String,
}

public struct Hat has store {
    color: String,
}

public struct Sword has store {
    damage: u64,
}

public fun create_character(name: String, ctx: &mut TxContext): Character {
    Character { id: object::new(ctx), name }
}

/// 使用动态字段添加异构装备
public fun equip_hat(character: &mut Character, hat: Hat) {
    df::add(&mut character.id, b"hat", hat);
}

public fun equip_sword(character: &mut Character, sword: Sword) {
    df::add(&mut character.id, b"sword", sword);
}

/// 借用动态字段
public fun hat_color(character: &Character): &String {
    let hat: &Hat = df::borrow(&character.id, b"hat");
    &hat.color
}

/// 移除动态字段
public fun unequip_hat(character: &mut Character): Hat {
    df::remove(&mut character.id, b"hat")
}

/// 检查字段是否存在
public fun has_sword(character: &Character): bool {
    df::exists_(&character.id, b"sword")
}
```

### 修改动态字段值

```move
module examples::df_modify;

use sui::dynamic_field as df;

public struct GameItem has key {
    id: UID,
}

public struct Stats has store, drop {
    attack: u64,
    defense: u64,
}

public fun create_item(ctx: &mut TxContext): GameItem {
    let mut item = GameItem { id: object::new(ctx) };
    df::add(&mut item.id, b"stats", Stats { attack: 10, defense: 5 });
    item
}

public fun upgrade_attack(item: &mut GameItem, bonus: u64) {
    let stats: &mut Stats = df::borrow_mut(&mut item.id, b"stats");
    stats.attack = stats.attack + bonus;
}

public fun upgrade_defense(item: &mut GameItem, bonus: u64) {
    let stats: &mut Stats = df::borrow_mut(&mut item.id, b"stats");
    stats.defense = stats.defense + bonus;
}

public fun attack(item: &GameItem): u64 {
    let stats: &Stats = df::borrow(&item.id, b"stats");
    stats.attack
}
```

## 自定义类型作为字段名

使用原始类型（如 `vector<u8>`）作为字段名虽然简单，但存在安全风险——任何知道名称的模块都可能访问你的字段。使用**自定义类型作为字段名**可以实现模块级别的访问控制。

### 为什么需要自定义键

只有能构造键类型实例的模块才能访问对应的动态字段。如果键类型定义在你的模块中且构造函数不对外暴露，那么只有你的模块能操作这些字段。

```move
module examples::df_custom_key;

use sui::dynamic_field as df;

/// 自定义键类型——只有本模块能创建实例
public struct ConfigKey has copy, drop, store {}

public struct AdminKey has copy, drop, store { index: u64 }

public struct Registry has key {
    id: UID,
}

public fun set_config(registry: &mut Registry, value: vector<u8>) {
    if (df::exists_(&registry.id, ConfigKey {})) {
        let v: &mut vector<u8> = df::borrow_mut(&mut registry.id, ConfigKey {});
        *v = value;
    } else {
        df::add(&mut registry.id, ConfigKey {}, value);
    }
}

public fun get_config(registry: &Registry): &vector<u8> {
    df::borrow(&registry.id, ConfigKey {})
}

public fun set_admin(registry: &mut Registry, index: u64, admin: address) {
    let key = AdminKey { index };
    if (df::exists_(&registry.id, key)) {
        let v: &mut address = df::borrow_mut(&mut registry.id, key);
        *v = admin;
    } else {
        df::add(&mut registry.id, key, admin);
    }
}

public fun get_admin(registry: &Registry, index: u64): address {
    *df::borrow(&registry.id, AdminKey { index })
}
```

### 多维度访问控制

```move
module examples::df_access;

use sui::dynamic_field as df;
use std::string::String;

/// 只有本模块能创建和使用这些键
public struct MetadataKey has copy, drop, store { field: String }
public struct PermissionKey has copy, drop, store { role: vector<u8> }

public struct ProtectedObject has key {
    id: UID,
}

public fun set_metadata(obj: &mut ProtectedObject, field: String, value: String) {
    let key = MetadataKey { field };
    if (df::exists_(&obj.id, key)) {
        let v: &mut String = df::borrow_mut(&mut obj.id, key);
        *v = value;
    } else {
        df::add(&mut obj.id, key, value);
    };
}

public fun metadata(obj: &ProtectedObject, field: String): &String {
    df::borrow(&obj.id, MetadataKey { field })
}

public fun grant_permission(obj: &mut ProtectedObject, role: vector<u8>, addr: address) {
    let key = PermissionKey { role };
    if (df::exists_(&obj.id, key)) {
        let v: &mut address = df::borrow_mut(&mut obj.id, key);
        *v = addr;
    } else {
        df::add(&mut obj.id, key, addr);
    };
}
```

## 外部类型作为动态字段

动态字段的一个强大特性是可以使用**其他模块定义的类型**作为值存储。只要该类型具有 `store` 能力，就可以作为动态字段的值。

```move
module examples::df_foreign;

use sui::dynamic_field as df;
use sui::coin::Coin;
use sui::sui::SUI;

public struct Wallet has key {
    id: UID,
    owner: address,
}

public struct CoinSlotKey has copy, drop, store { index: u64 }

public fun create_wallet(ctx: &mut TxContext): Wallet {
    Wallet {
        id: object::new(ctx),
        owner: ctx.sender(),
    }
}

public fun deposit_coin(wallet: &mut Wallet, index: u64, coin: Coin<SUI>) {
    df::add(&mut wallet.id, CoinSlotKey { index }, coin);
}

public fun withdraw_coin(wallet: &mut Wallet, index: u64): Coin<SUI> {
    df::remove(&mut wallet.id, CoinSlotKey { index })
}

public fun has_coin(wallet: &Wallet, index: u64): bool {
    df::exists_with_type<CoinSlotKey, Coin<SUI>>(&wallet.id, CoinSlotKey { index })
}
```

## 动态字段 vs 动态对象字段

Sui Framework 还提供了 `sui::dynamic_object_field` 模块。两者的主要区别在于：

| 特性 | 动态字段 (`dynamic_field`) | 动态对象字段 (`dynamic_object_field`) |
|------|--------------------------|--------------------------------------|
| 值类型要求 | `store` | `key + store`（必须是 Sui 对象） |
| 存储方式 | 值嵌入在 Field 对象中 | 值作为独立对象存储，Field 只存引用 |
| 链上可见性 | 值不可通过 ID 直接查询 | 值作为独立对象，可通过 ID 查询 |
| 适用场景 | 存储普通数据 | 存储需要独立可见的子对象 |

```move
module examples::df_vs_dof;

use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;
use std::string::String;

public struct Parent has key {
    id: UID,
}

/// 普通值——用 dynamic_field
public struct Metadata has store {
    description: String,
}

/// Sui 对象——可以用 dynamic_object_field
public struct Child has key, store {
    id: UID,
    value: u64,
}

public fun attach_metadata(parent: &mut Parent, desc: String) {
    df::add(&mut parent.id, b"metadata", Metadata { description: desc });
}

public fun attach_child(parent: &mut Parent, child: Child) {
    dof::add(&mut parent.id, b"child", child);
}

public fun detach_child(parent: &mut Parent): Child {
    dof::remove(&mut parent.id, b"child")
}
```

## 孤儿动态字段

当一个拥有动态字段的对象被销毁（通过解构 + `object::delete()`）时，如果其动态字段**没有被先移除**，这些字段就会变成"孤儿"——它们仍然存在于链上存储中，但再也无法被访问或删除。

### 问题示例

```move
module examples::orphan_warning;

use sui::dynamic_field as df;

public struct Container has key {
    id: UID,
}

public fun create(ctx: &mut TxContext): Container {
    let mut c = Container { id: object::new(ctx) };
    df::add(&mut c.id, b"data", 42u64);
    c
}

/// 危险！动态字段 "data" 将变成孤儿
public fun destroy_unsafe(container: Container) {
    let Container { id } = container;
    id.delete();
    // "data" 字段永远无法访问了
}

/// 安全的做法：先移除所有动态字段
public fun destroy_safe(mut container: Container) {
    if (df::exists_(&container.id, b"data")) {
        let _: u64 = df::remove(&mut container.id, b"data");
    };
    let Container { id } = container;
    id.delete();
}
```

> **最佳实践**：在销毁拥有动态字段的对象之前，始终确保所有动态字段已被移除。如果动态字段数量不确定或过多，考虑设计时就避免需要销毁父对象的场景。

## 暴露 UID 的安全性

要让外部模块能为你的对象添加动态字段，你需要暴露对象的 `UID` 引用。这有安全隐患——任何获得 `&mut UID` 的模块都可以为该对象添加、修改或删除动态字段。

### 安全暴露策略

```move
module examples::uid_exposure;

use sui::dynamic_field as df;

public struct MyObject has key {
    id: UID,
    owner: address,
}

/// 暴露不可变 UID——允许读取动态字段，但不能修改
public fun uid(obj: &MyObject): &UID {
    &obj.id
}

/// 暴露可变 UID——允许添加/修改/删除动态字段
/// 通过要求 owner 验证来限制访问
public fun uid_mut(obj: &mut MyObject, ctx: &TxContext): &mut UID {
    assert!(obj.owner == ctx.sender(), 0);
    &mut obj.id
}
```

## 动态字段 vs 结构体字段

| 维度 | 结构体字段 | 动态字段 |
|------|-----------|---------|
| 定义时机 | 编译时固定 | 运行时动态添加 |
| 类型一致性 | 每个字段类型固定 | 不同名称可存储不同类型 |
| 数量限制 | 编译时确定 | 无上限 |
| 访问开销 | 直接访问，零额外开销 | 需要查找，有额外 Gas 开销 |
| 对象大小 | 占用对象空间 | 独立存储，不占父对象空间 |
| 可见性 | 对象序列化中可见 | 不在对象序列化中直接可见 |

### 性能考虑

- **结构体字段**读写没有额外开销，是最快的方式
- **动态字段**每次操作需要额外的存储查找，Gas 开销更高
- 对于固定已知的属性，优先使用结构体字段
- 对于数量不定或类型不一的扩展数据，使用动态字段

## 实际应用：可扩展的 NFT

```move
module examples::extensible_nft;

use sui::dynamic_field as df;
use std::string::String;

public struct NFT has key, store {
    id: UID,
    name: String,
    collection: String,
}

public struct TraitKey has copy, drop, store { name: String }

public fun create_nft(
    name: String,
    collection: String,
    ctx: &mut TxContext,
): NFT {
    NFT { id: object::new(ctx), name, collection }
}

public fun add_trait(nft: &mut NFT, trait_name: String, trait_value: String) {
    let key = TraitKey { name: trait_name };
    if (df::exists_(&nft.id, key)) {
        let v: &mut String = df::borrow_mut(&mut nft.id, key);
        *v = trait_value;
    } else {
        df::add(&mut nft.id, key, trait_value);
    };
}

public fun trait_value(nft: &NFT, trait_name: String): &String {
    df::borrow(&nft.id, TraitKey { name: trait_name })
}

public fun has_trait(nft: &NFT, trait_name: String): bool {
    df::exists_(&nft.id, TraitKey { name: trait_name })
}

public fun remove_trait(nft: &mut NFT, trait_name: String): String {
    df::remove(&mut nft.id, TraitKey { name: trait_name })
}
```

## 小结

动态字段是 Sui Move 中实现灵活数据存储的核心机制。它通过将键值对附加到对象的 `UID` 上，突破了结构体字段在编译时固定的限制，支持运行时动态添加异构数据且没有数量上限。核心操作包括 `add`、`remove`、`borrow`、`borrow_mut` 和 `exists_`。使用自定义类型作为字段名可以实现模块级访问控制，增强安全性。需要注意孤儿字段问题——销毁父对象前应移除所有动态字段。动态字段与动态对象字段（`dynamic_object_field`）的区别在于后者要求值为 Sui 对象，且值作为独立对象在链上可查询。在性能方面，动态字段比结构体字段有更高的 Gas 开销，应根据数据的固定性和规模选择合适的存储方式。
