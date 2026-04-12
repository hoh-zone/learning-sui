# 动态集合

## 导读

本节对应 [§11.1](01-sui-framework.md) **集合选型表**中基于**动态（对象）字段**的类型：`Table`、`Bag`、`ObjectTable`、`ObjectBag`、`LinkedTable`、`TableVec` 等。数据**不**再挤在宿主对象的 `vector` 里，而是按条目分散存储，适合**大规模**与复杂键值语义。请与 [§11.6](06-collections.md) 的 `VecMap`/`VecSet` 对照阅读。

- **前置**：[§11.7](07-dynamic-fields.md)、[§11.8](08-dynamic-object-fields.md)、[§11.1](01-sui-framework.md)  
- **后续**：[第十四章 · 代币](../14_tokens/00-index.md)（大量 Coin 与用户索引时常用 `Table` 系）  

---

Sui 框架在动态字段之上构建了一系列开箱即用的集合类型，包括 `Table`、`Bag`、`ObjectTable`、`ObjectBag` 和 `LinkedTable`。这些集合封装了底层动态字段的操作细节，提供了类似传统编程语言中 Map、Dictionary 等数据结构的使用体验。合理选择集合类型是编写高效 Move 合约的关键技能。

## Table — 同构键值映射

`Table<K, V>` 是一个**同构**的键值映射集合，所有键必须是同一类型 `K`，所有值必须是同一类型 `V`。它基于普通动态字段实现，内部会自动追踪元素数量。

### 核心 API

```move
use sui::table::{Self, Table};

// 创建
table::new<K, V>(ctx: &mut TxContext): Table<K, V>

// 增删改查
table::add<K, V>(table: &mut Table<K, V>, k: K, v: V)
table::remove<K, V>(table: &mut Table<K, V>, k: K): V
table::borrow<K, V>(table: &Table<K, V>, k: K): &V
table::borrow_mut<K, V>(table: &mut Table<K, V>, k: K): &mut V

// 查询
table::contains<K, V>(table: &Table<K, V>, k: K): bool
table::length<K, V>(table: &Table<K, V>): u64
table::is_empty<K, V>(table: &Table<K, V>): bool

// 销毁（仅当为空时）
table::destroy_empty<K, V>(table: Table<K, V>)
```

### 索引语法支持

`Table` 支持方括号索引语法，使代码更加简洁：

```move
// 以下两种写法等价
let val = table::borrow(&my_table, key);
let val = &my_table[key];

// 可变借用同样支持
let val_mut = table::borrow_mut(&mut my_table, key);
let val_mut = &mut my_table[key];
```

### 类型约束

- 键 `K`：`copy + drop + store`
- 值 `V`：`store`

## Bag — 异构键值映射

`Bag` 是一个**异构**的键值映射集合，不同的键值对可以拥有不同的类型。这使得 `Bag` 极其灵活，适合存储结构多样的数据。

### 核心 API

```move
use sui::bag::{Self, Bag};

// 创建
bag::new(ctx: &mut TxContext): Bag

// 增删改查（K/V 类型每次可以不同）
bag::add<K: copy + drop + store, V: store>(bag: &mut Bag, k: K, v: V)
bag::remove<K: copy + drop + store, V: store>(bag: &mut Bag, k: K): V
bag::borrow<K: copy + drop + store, V: store>(bag: &Bag, k: K): &V
bag::borrow_mut<K: copy + drop + store, V: store>(bag: &mut Bag, k: K): &mut V

// 查询
bag::contains<K: copy + drop + store>(bag: &Bag, k: K): bool
bag::length(bag: &Bag): u64
bag::is_empty(bag: &Bag): bool
```

### 异构存储示例

`Bag` 允许在同一个集合中存储不同类型的值：

```move
bag::add(&mut my_bag, b"name", b"Alice");       // vector<u8>
bag::add(&mut my_bag, b"score", 100u64);         // u64
bag::add(&mut my_bag, b"active", true);          // bool
```

但读取时必须指定正确的类型，否则会在运行时报错：

```move
let name: &vector<u8> = bag::borrow(&my_bag, b"name");
let score: &u64 = bag::borrow(&my_bag, b"score");
```

## ObjectTable — 对象级同构映射

`ObjectTable<K, V>` 与 `Table` 类似，但基于**动态对象字段**实现。其核心区别在于：

- 值 `V` 必须具有 `key + store` 能力（必须是对象）
- 存储的对象保持独立身份，可被链下索引器发现
- 每次访问需要加载两个底层对象，成本更高

API 与 `Table` 完全一致，只是类型约束更严格：

```move
use sui::object_table::{Self, ObjectTable};

// 值必须是对象（key + store）
object_table::add<K, V: key + store>(table: &mut ObjectTable<K, V>, k: K, v: V)
```

## ObjectBag — 对象级异构映射

`ObjectBag` 与 `Bag` 的关系类似 `ObjectTable` 与 `Table` 的关系：

- 基于动态对象字段实现
- 值必须具有 `key + store` 能力
- 保留子对象的链下可发现性
- 成本更高

```move
use sui::object_bag::{Self, ObjectBag};
```

## LinkedTable — 有序链表映射

`LinkedTable<K, V>` 是一个维护插入顺序的键值映射，内部通过双向链表实现。它是唯一支持有序遍历的集合类型。

### 核心 API

```move
use sui::linked_table::{Self, LinkedTable};

// 创建
linked_table::new<K, V>(ctx: &mut TxContext): LinkedTable<K, V>

// 头尾操作
linked_table::push_front<K, V>(table: &mut LinkedTable<K, V>, k: K, v: V)
linked_table::push_back<K, V>(table: &mut LinkedTable<K, V>, k: K, v: V)
linked_table::pop_front<K, V>(table: &mut LinkedTable<K, V>): (K, V)
linked_table::pop_back<K, V>(table: &mut LinkedTable<K, V>): (K, V)

// 头尾查询
linked_table::front<K, V>(table: &LinkedTable<K, V>): &Option<K>
linked_table::back<K, V>(table: &LinkedTable<K, V>): &Option<K>

// 前后节点导航
linked_table::prev<K, V>(table: &LinkedTable<K, V>, k: K): &Option<K>
linked_table::next<K, V>(table: &LinkedTable<K, V>, k: K): &Option<K>

// 标准操作
linked_table::remove<K, V>(table: &mut LinkedTable<K, V>, k: K): V
linked_table::borrow<K, V>(table: &LinkedTable<K, V>, k: K): &V
linked_table::borrow_mut<K, V>(table: &mut LinkedTable<K, V>, k: K): &mut V
linked_table::contains<K, V>(table: &LinkedTable<K, V>, k: K): bool
linked_table::length<K, V>(table: &LinkedTable<K, V>): u64
linked_table::is_empty<K, V>(table: &LinkedTable<K, V>): bool
```

### LinkedTable 遍历示例

```move
public fun sum_all_values(table: &LinkedTable<u64, u64>): u64 {
    let mut sum = 0u64;
    let mut current = *linked_table::front(table);
    while (option::is_some(&current)) {
        let key = *option::borrow(&current);
        sum = sum + *linked_table::borrow(table, key);
        current = *linked_table::next(table, key);
    };
    sum
}
```

## 完整代码示例

### 用户注册系统（Table）

```move
module examples::collections;

use sui::table::{Self, Table};
use sui::bag::{Self, Bag};

public struct UserRegistry has key {
    id: UID,
    users: Table<address, vector<u8>>,
    count: u64,
}

public struct GameInventory has key {
    id: UID,
    items: Bag,
}

public fun create_registry(ctx: &mut TxContext): UserRegistry {
    UserRegistry {
        id: object::new(ctx),
        users: table::new(ctx),
        count: 0,
    }
}

public fun register(registry: &mut UserRegistry, name: vector<u8>, ctx: &TxContext) {
    let sender = ctx.sender();
    table::add(&mut registry.users, sender, name);
    registry.count = registry.count + 1;
}

public fun name(registry: &UserRegistry, addr: address): &vector<u8> {
    &registry.users[addr]
}

public fun create_inventory(ctx: &mut TxContext): GameInventory {
    GameInventory {
        id: object::new(ctx),
        items: bag::new(ctx),
    }
}

public fun add_item<V: store>(inventory: &mut GameInventory, key: vector<u8>, item: V) {
    bag::add(&mut inventory.items, key, item);
}

public fun item<V: store>(inventory: &GameInventory, key: vector<u8>): &V {
    bag::borrow(&inventory.items, key)
}
```

### 排行榜系统（LinkedTable）

```move
module examples::leaderboard;

use sui::linked_table::{Self, LinkedTable};

public struct Leaderboard has key {
    id: UID,
    scores: LinkedTable<address, u64>,
}

public fun create(ctx: &mut TxContext) {
    let board = Leaderboard {
        id: object::new(ctx),
        scores: linked_table::new(ctx),
    };
    transfer::share_object(board);
}

public fun submit_score(board: &mut Leaderboard, score: u64, ctx: &TxContext) {
    let player = ctx.sender();
    if (linked_table::contains(&board.scores, player)) {
        let current = linked_table::borrow_mut(&mut board.scores, player);
        if (score > *current) {
            *current = score;
        };
    } else {
        linked_table::push_back(&mut board.scores, player, score);
    };
}

public fun get_top_player(board: &Leaderboard): (address, u64) {
    let mut best_addr = @0x0;
    let mut best_score = 0u64;
    let mut current = *linked_table::front(&board.scores);
    while (option::is_some(&current)) {
        let addr = *option::borrow(&current);
        let score = *linked_table::borrow(&board.scores, addr);
        if (score > best_score) {
            best_score = score;
            best_addr = addr;
        };
        current = *linked_table::next(&board.scores, addr);
    };
    (best_addr, best_score)
}
```

## 集合类型选择指南

选择合适的集合类型是设计 Move 合约的重要决策。以下是选择建议：

| 需求 | 推荐类型 |
|------|---------|
| 固定类型的键值对，不需要链下发现值 | `Table` |
| 固定类型的键值对，值需要链下可发现 | `ObjectTable` |
| 不同类型的键值对（灵活结构） | `Bag` |
| 不同类型的对象，需要链下可发现 | `ObjectBag` |
| 需要维护插入顺序或遍历 | `LinkedTable` |

### 关键决策因素

1. **类型一致性**：如果所有键值对类型相同，使用 `Table`/`ObjectTable`；否则使用 `Bag`/`ObjectBag`
2. **链下可发现性**：如果值需要通过 ID 被链下查询，使用 `Object-` 前缀的变体
3. **有序性**：如果需要遍历或维护顺序，使用 `LinkedTable`
4. **Gas 成本**：`Object-` 变体每次访问的成本更高（加载两个对象），在不需要可发现性时避免使用

### 注意事项

- 所有集合类型都具有 `key + store` 能力，可以作为对象字段或独立对象使用
- 集合拥有 `drop` 能力的前提是内部为空——非空集合不能被丢弃
- `destroy_empty` 仅在集合为空时可以调用，否则会报错
- 非空集合在模块升级或对象删除时需要先清空

## 小结

Sui 提供的五种集合类型覆盖了链上数据存储的常见需求：

- **Table**：同构、高效、适合已知类型的映射场景
- **Bag**：异构、灵活、适合结构不固定的存储场景
- **ObjectTable / ObjectBag**：基于动态对象字段，保留子对象的链下可发现性，代价是更高的 Gas 消耗
- **LinkedTable**：唯一支持有序遍历的集合，适合排行榜、队列等需要顺序的场景

所有集合都支持 `add`、`remove`、`borrow`、`borrow_mut`、`contains`、`length`、`is_empty` 等标准操作，且 `Table` 和 `Bag` 支持方括号索引语法。根据实际需求在类型安全性、灵活性、可发现性和性能之间做出权衡，选择最合适的集合类型。

与 [§11.1](01-sui-framework.md) 的**集合选型总表**、[§11.6](06-collections.md) 的 **VecMap/VecSet** 对照阅读，可形成「小到对象内、大到动态字段」的完整选型链。
