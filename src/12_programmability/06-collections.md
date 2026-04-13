# 集合类型

## 导读

本节对应 [§12.1](01-sui-framework.md) **集合选型表**中的 **`VecMap` / `VecSet`**：数据存放在**宿主对象内部**，实现简单、适合**小规模**；与 [§12.10](10-dynamic-collections.md) 的 `Table` / `Bag` 等（**动态字段**后端、可扩展）形成对照。

- **前置**：[§12.1](01-sui-framework.md)（选型表）、[第六章 · Vector](../06_move_intermediate/02-vector.md)（底层仍是 `vector` 语义）  
- **后续**：[§12.10](10-dynamic-collections.md)（数据变大时迁移思路）  

---

Sui Framework 提供了一组轻量级的集合数据结构——`VecSet` 和 `VecMap`，它们基于 `vector` 实现，适合在对象内部存储小规模数据。与基于动态字段的 `Table`/`Bag` 不同，这些集合将所有数据存储在对象内部，具有更简单的使用模型和更低的 Gas 开销（在数据量较小时）。本章将详细介绍它们的 API、使用场景和限制。

## VecSet：去重集合

### 概述

`VecSet<K>` 是一个基于 `vector` 的集合类型，保证元素唯一性。它的行为类似于其他语言中的 `HashSet`，但底层使用有序数组实现。

`VecSet` 位于 `sui::vec_set` 模块中，元素类型 `K` 必须具有 `copy` 和 `drop` 能力。

### 核心 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `empty()` | `fun empty<K>(): VecSet<K>` | 创建空集合 |
| `singleton()` | `fun singleton<K>(key: K): VecSet<K>` | 创建只含一个元素的集合 |
| `insert()` | `fun insert<K>(set: &mut VecSet<K>, key: K)` | 插入元素，已存在则 abort |
| `remove()` | `fun remove<K>(set: &mut VecSet<K>, key: &K)` | 移除元素，不存在则 abort |
| `contains()` | `fun contains<K>(set: &VecSet<K>, key: &K): bool` | 检查元素是否存在 |
| `size()` | `fun size<K>(set: &VecSet<K>): u64` | 返回元素数量 |
| `is_empty()` | `fun is_empty<K>(set: &VecSet<K>): bool` | 是否为空 |
| `into_keys()` | `fun into_keys<K>(set: VecSet<K>): vector<K>` | 解构为 vector |

### 使用示例

```move
module examples::collections_demo;

use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use std::string::String;

public struct Whitelist has key {
    id: UID,
    addresses: VecSet<address>,
}

public struct Scores has key {
    id: UID,
    player_scores: VecMap<address, u64>,
}

public fun create_whitelist(ctx: &mut TxContext): Whitelist {
    Whitelist {
        id: object::new(ctx),
        addresses: vec_set::empty(),
    }
}

public fun add_to_whitelist(wl: &mut Whitelist, addr: address) {
    vec_set::insert(&mut wl.addresses, addr);
}

public fun is_whitelisted(wl: &Whitelist, addr: &address): bool {
    vec_set::contains(&wl.addresses, addr)
}

public fun create_scores(ctx: &mut TxContext): Scores {
    Scores {
        id: object::new(ctx),
        player_scores: vec_map::empty(),
    }
}

public fun set_score(scores: &mut Scores, player: address, score: u64) {
    if (vec_map::contains(&scores.player_scores, &player)) {
        let s = vec_map::get_mut(&mut scores.player_scores, &player);
        *s = score;
    } else {
        vec_map::insert(&mut scores.player_scores, player, score);
    };
}
```

### 白名单完整示例

```move
module examples::whitelist;

use sui::vec_set::{Self, VecSet};
use sui::event;

public struct WhitelistUpdated has copy, drop {
    added: bool,
    addr: address,
    new_size: u64,
}

public struct AdminCap has key {
    id: UID,
}

public struct MintWhitelist has key {
    id: UID,
    allowed: VecSet<address>,
    max_size: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    transfer::share_object(MintWhitelist {
        id: object::new(ctx),
        allowed: vec_set::empty(),
        max_size: 1000,
    });
}

public fun add_address(_: &AdminCap, wl: &mut MintWhitelist, addr: address) {
    assert!(vec_set::size(&wl.allowed) < wl.max_size, 0);
    assert!(!vec_set::contains(&wl.allowed, &addr), 1);
    vec_set::insert(&mut wl.allowed, addr);

    event::emit(WhitelistUpdated {
        added: true,
        addr,
        new_size: vec_set::size(&wl.allowed),
    });
}

public fun remove_address(_: &AdminCap, wl: &mut MintWhitelist, addr: address) {
    assert!(vec_set::contains(&wl.allowed, &addr), 0);
    vec_set::remove(&mut wl.allowed, &addr);

    event::emit(WhitelistUpdated {
        added: false,
        addr,
        new_size: vec_set::size(&wl.allowed),
    });
}

public fun can_mint(wl: &MintWhitelist, addr: &address): bool {
    vec_set::contains(&wl.allowed, addr)
}
```

## VecMap：键值映射

### 概述

`VecMap<K, V>` 是一个基于 `vector` 的键值对映射，保证键的唯一性。键类型 `K` 必须具有 `copy` 能力，以便进行查找和比较。

`VecMap` 位于 `sui::vec_map` 模块中。

### 核心 API

| 方法 | 说明 |
|------|------|
| `empty()` | 创建空映射 |
| `insert(map, key, value)` | 插入键值对，键已存在则 abort |
| `remove(map, key)` | 移除键值对，返回 `(key, value)` |
| `contains(map, key)` | 检查键是否存在 |
| `get(map, key)` | 获取值的不可变引用 |
| `get_mut(map, key)` | 获取值的可变引用 |
| `size(map)` | 返回键值对数量 |
| `is_empty(map)` | 是否为空 |
| `keys(map)` | 获取所有键的引用 |
| `into_keys_values(map)` | 解构为两个 vector |
| `get_idx(map, key)` | 获取键的索引位置 |
| `get_entry_by_idx(map, idx)` | 通过索引获取键值对引用 |
| `remove_entry_by_idx(map, idx)` | 通过索引移除键值对 |

### 配置管理示例

```move
module examples::config_map;

use sui::vec_map::{Self, VecMap};
use std::string::{Self, String};

const ENotAdmin: u64 = 0;

public struct AppConfig has key {
    id: UID,
    settings: VecMap<String, String>,
    admin: address,
}

public fun create_config(ctx: &mut TxContext) {
    let mut settings = vec_map::empty<String, String>();

    vec_map::insert(
        &mut settings,
        string::utf8(b"app_name"),
        string::utf8(b"MyDApp"),
    );
    vec_map::insert(
        &mut settings,
        string::utf8(b"version"),
        string::utf8(b"1.0.0"),
    );
    vec_map::insert(
        &mut settings,
        string::utf8(b"max_users"),
        string::utf8(b"10000"),
    );

    let config = AppConfig {
        id: object::new(ctx),
        settings,
        admin: ctx.sender(),
    };
    transfer::share_object(config);
}

public fun update_setting(
    config: &mut AppConfig,
    key: String,
    value: String,
    ctx: &TxContext,
) {
    assert!(config.admin == ctx.sender(), ENotAdmin);

    if (vec_map::contains(&config.settings, &key)) {
        let v = vec_map::get_mut(&mut config.settings, &key);
        *v = value;
    } else {
        vec_map::insert(&mut config.settings, key, value);
    };
}

public fun setting(config: &AppConfig, key: &String): &String {
    vec_map::get(&config.settings, key)
}

public fun remove_setting(config: &mut AppConfig, key: &String, ctx: &TxContext) {
    assert!(config.admin == ctx.sender(), ENotAdmin);
    vec_map::remove(&mut config.settings, key);
}

public fun setting_count(config: &AppConfig): u64 {
    vec_map::size(&config.settings)
}
```

### 积分排行榜示例

```move
module examples::leaderboard;

use sui::vec_map::{Self, VecMap};

public struct Leaderboard has key {
    id: UID,
    scores: VecMap<address, u64>,
}

public fun create(ctx: &mut TxContext) {
    transfer::share_object(Leaderboard {
        id: object::new(ctx),
        scores: vec_map::empty(),
    });
}

public fun add_score(board: &mut Leaderboard, player: address, points: u64) {
    if (vec_map::contains(&board.scores, &player)) {
        let current = vec_map::get_mut(&mut board.scores, &player);
        *current = *current + points;
    } else {
        vec_map::insert(&mut board.scores, player, points);
    };
}

public fun score(board: &Leaderboard, player: &address): u64 {
    if (vec_map::contains(&board.scores, player)) {
        *vec_map::get(&board.scores, player)
    } else {
        0
    }
}

public fun player_count(board: &Leaderboard): u64 {
    vec_map::size(&board.scores)
}

public fun reset_player(board: &mut Leaderboard, player: &address) {
    if (vec_map::contains(& board.scores, player)) {
        vec_map::remove(&mut board.scores, player);
    };
}
```

## 限制与注意事项

### 对象大小限制

`VecSet` 和 `VecMap` 将所有数据存储在对象内部。Sui 对单个对象的大小有上限（目前约 256 KB）。当集合数据量增长到接近此限制时，交易可能会失败。

### O(n) 操作复杂度

由于底层基于 `vector`，大部分查找和删除操作的时间复杂度为 **O(n)**：

- `contains()` — 线性扫描查找
- `remove()` — 线性扫描 + 移位
- `insert()` — 线性扫描检查唯一性

对于频繁操作的大数据集，这会导致 Gas 消耗显著增加。

### 何时使用 VecSet/VecMap vs 动态集合

| 场景 | 推荐 | 原因 |
|------|------|------|
| 元素数量 < 100 | `VecSet`/`VecMap` | 简单直接，Gas 低 |
| 元素数量 100-1000 | 视情况而定 | 测试 Gas 消耗后决定 |
| 元素数量 > 1000 | `Table`/`Bag` | 避免对象大小限制和高 Gas |
| 需要存储对象值 | `ObjectTable`/`ObjectBag` | 对象需要独立存储 |
| 需要顺序遍历 | `LinkedTable` | 支持链式遍历 |
| 数据异构（不同类型） | `Bag`/`ObjectBag` | 支持不同类型的值 |

### 不可比较

`VecSet` 和 `VecMap` 本身**不支持相等性比较**（没有 `==` 操作）。如果你需要比较两个集合，需要将它们解构为 `vector` 后自行实现比较逻辑。

## 组合使用模式

在实际项目中，`VecSet` 和 `VecMap` 经常组合使用，或与其他数据结构配合：

```move
module examples::access_control;

use sui::vec_set::{Self, VecSet};
use sui::vec_map::{Self, VecMap};

public struct AccessControl has key {
    id: UID,
    admins: VecSet<address>,
    role_permissions: VecMap<vector<u8>, VecSet<vector<u8>>>,
}

public fun create(creator: address, ctx: &mut TxContext) {
    let mut admins = vec_set::empty<address>();
    vec_set::insert(&mut admins, creator);

    transfer::share_object(AccessControl {
        id: object::new(ctx),
        admins,
        role_permissions: vec_map::empty(),
    });
}

const ENotAdmin: u64 = 0;

public fun add_admin(ac: &mut AccessControl, new_admin: address, ctx: &TxContext) {
    assert!(vec_set::contains(&ac.admins, &ctx.sender()), ENotAdmin);
    vec_set::insert(&mut ac.admins, new_admin);
}

public fun add_role_permission(
    ac: &mut AccessControl,
    role: vector<u8>,
    permission: vector<u8>,
    ctx: &TxContext,
) {
    assert!(vec_set::contains(&ac.admins, &ctx.sender()), ENotAdmin);

    if (vec_map::contains(&ac.role_permissions, &role)) {
        let perms = vec_map::get_mut(&mut ac.role_permissions, &role);
        if (!vec_set::contains(perms, &permission)) {
            vec_set::insert(perms, permission);
        };
    } else {
        let mut perms = vec_set::empty<vector<u8>>();
        vec_set::insert(&mut perms, permission);
        vec_map::insert(&mut ac.role_permissions, role, perms);
    };
}

public fun has_permission(
    ac: &AccessControl,
    role: &vector<u8>,
    permission: &vector<u8>,
): bool {
    if (!vec_map::contains(&ac.role_permissions, role)) {
        return false
    };
    let perms = vec_map::get(&ac.role_permissions, role);
    vec_set::contains(perms, permission)
}
```

## 小结

`VecSet` 和 `VecMap` 是 Sui Framework 提供的轻量级集合类型，基于 `vector` 实现，数据存储在对象内部。`VecSet` 提供去重集合语义，`VecMap` 提供键值映射语义，两者都保证键/元素的唯一性。它们适合存储小规模数据（通常几十到几百个元素），操作简单且 Gas 开销较低。但由于底层使用线性扫描，操作复杂度为 O(n)，且受对象大小限制（约 256 KB），不适合大规模数据存储。当数据量增长到数百以上时，应考虑使用 `Table`、`Bag` 等基于动态字段的集合类型。

回到 [§12.1](01-sui-framework.md) 的集合对比表，把「**对象内**」与「**动态字段**」两行对照记忆，选型会更快。
