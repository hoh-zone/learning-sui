# store 能力

`store` 能力在 Sui Move 中扮演着双重角色：它既控制一个类型**能否被嵌套存储**在其他对象中，又决定了对象的**转移权限**是开放的还是受限的。理解 `store` 能力对于设计合理的对象访问控制至关重要。

## store 的基本定义

`store` 能力表示一个类型可以出现在拥有 `key` 的结构体内部作为字段。换句话说，`store` 是"可被存储"的许可证。

```move
module examples::store_demo;

use std::string::String;

/// 拥有 `store` —— 可以作为其他对象的字段
public struct Metadata has store {
    bio: String,
    website: String,
}

/// 拥有 `key` + `store` —— 既是对象，又可公开转移
public struct TradableItem has key, store {
    id: UID,
    name: String,
    metadata: Metadata,
}
```

`Metadata` 本身不是对象（没有 `key`），但它拥有 `store`，所以可以作为 `TradableItem` 的字段嵌套存储。

## store 与 key 的关系

这是一条经常被忽视但至关重要的规则：

> **拥有 `key` 能力的结构体，其所有字段的类型都必须拥有 `store` 能力。**

这意味着如果你定义了一个对象，那么这个对象内部的每个字段类型都必须明确声明 `store`：

```move
/// 拥有 store 的辅助类型
public struct Stats has store {
    strength: u64,
    agility: u64,
}

/// 合法：所有字段类型都有 store
public struct Hero has key {
    id: UID,       // UID has store
    name: String,  // String has store
    stats: Stats,  // Stats has store（我们刚声明的）
    level: u64,    // u64 has store
}
```

```move
/// 没有声明任何能力
public struct RawData {
    bytes: vector<u8>,
}

/// 非法！RawData 没有 store
public struct BadObj has key {
    id: UID,
    data: RawData,  // 编译错误
}
```

### 隐含关系链

这形成了一个自底向上的能力依赖链：

```
key 结构体
  └── 所有字段必须有 store
        └── 这些字段的字段也必须有 store
              └── ... 递归到叶子类型
```

## store 与 copy/drop 的关系

`store` 与 `copy`、`drop` 是完全**独立**的能力，它们之间没有隐含的依赖关系：

| 组合 | 合法？ | 含义 |
|------|--------|------|
| `store` | 是 | 可嵌套存储，不可复制，不可丢弃 |
| `store, copy` | 是 | 可嵌套存储，可复制 |
| `store, drop` | 是 | 可嵌套存储，可丢弃 |
| `store, copy, drop` | 是 | 可嵌套存储，可复制，可丢弃 |
| `copy, drop`（无 store） | 是 | 纯内存类型，不可存储在对象中 |

```move
/// 可存储、可复制、可丢弃的轻量数据
public struct Point has store, copy, drop {
    x: u64,
    y: u64,
}

/// 只能存储，不可复制不可丢弃——适合表示唯一性资源
public struct UniqueGem has store {
    rarity: u8,
    color: vector<u8>,
}
```

## store 作为"公开"修饰符

在 Sui 中，`store` 能力的另一个关键作用是**解锁公开存储操作**。这是 Sui 特有的语义，在其他 Move 平台上不存在。

### 核心规则

`sui::transfer` 模块提供了两组存储函数：

| 内部函数（key 即可） | 公开函数（需要 key + store） |
|----------------------|----------------------------|
| `transfer::transfer` | `transfer::public_transfer` |
| `transfer::freeze_object` | `transfer::public_freeze_object` |
| `transfer::share_object` | `transfer::public_share_object` |

- **内部函数**：只能在**定义该类型的模块内部**调用。
- **公开函数**：可以在**任何模块**中调用，但要求类型同时拥有 `key` 和 `store`。

```move
/// 只有 `key` —— 转移受限，只有定义模块能控制
public struct SoulboundBadge has key {
    id: UID,
    title: String,
}

/// `key` + `store` —— 任何人都可以公开转移
public struct TradableItem has key, store {
    id: UID,
    name: String,
    metadata: Metadata,
}
```

### 模块控制的转移

对于只有 `key` 的 `SoulboundBadge`，只有定义它的模块才能调用 `transfer::transfer`：

```move
/// 模块控制：只有本模块能决定 badge 的去向
public fun issue_badge(
    title: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let badge = SoulboundBadge { id: object::new(ctx), title };
    transfer::transfer(badge, recipient);
}
```

其他模块尝试转移 `SoulboundBadge` 会被 Sui 验证器拒绝：

```move
// 在另一个模块中——编译失败！
// SoulboundBadge 只有 key，不能在外部模块使用 transfer
public fun try_steal(badge: SoulboundBadge, thief: address) {
    transfer::transfer(badge, thief);        // 错误
    transfer::public_transfer(badge, thief); // 也是错误，因为没有 store
}
```

### 公开转移

对于拥有 `key + store` 的 `TradableItem`，任何模块都可以转移它：

```move
/// 任何模块都可以调用——因为 TradableItem 有 store
public fun trade(item: TradableItem, to: address) {
    transfer::public_transfer(item, to);
}
```

## 拥有 store 的标准类型

Sui 标准库和 Move 标准库中的大多数类型都拥有 `store`：

| 类型 | 能力 |
|------|------|
| `bool`, `u8` ~ `u256`, `address` | `copy`, `drop`, `store` |
| `vector<T>` | 继承 `T` 的能力 |
| `String` (`std::string`) | `copy`, `drop`, `store` |
| `Option<T>` | 继承 `T` 的能力 |
| `UID` | `store` |
| `ID` | `copy`, `drop`, `store` |
| `Coin<T>` | `key`, `store` |
| `Balance<T>` | `store` |
| `Table<K, V>` | `store` |
| `Bag` | `store` |

## 有无 store 的设计考量

选择是否给对象添加 `store` 能力是一个重要的设计决策：

### 添加 store（key + store）

- 用户可以自由转移、交易对象
- 适合 NFT、代币、游戏道具等需要流通的资产
- 可以被包装（wrapped）在其他对象中
- 放弃了模块对转移的独占控制

### 不添加 store（仅 key）

- 只有定义模块能控制对象的转移
- 适合权限凭证（Capability）、灵魂绑定代币（SBT）、系统配置
- 模块可以实现自定义转移逻辑（如收费转移、条件转移）
- 无法被其他模块的对象包含

## 完整示例：游戏资产系统

```move
module examples::game_assets;

use std::string::String;

/// 可交易的游戏道具（key + store）
public struct Sword has key, store {
    id: UID,
    name: String,
    attack: u64,
}

/// 不可交易的玩家等级证明（仅 key）
public struct PlayerRank has key {
    id: UID,
    rank: u64,
    player: address,
}

/// 可嵌套的附魔效果（仅 store）
public struct Enchantment has store, copy, drop {
    element: String,
    power: u64,
}

/// 带附魔的高级武器
public struct EnchantedSword has key, store {
    id: UID,
    base: Sword,
    enchantment: Enchantment,
}

/// 铸造武器——任何人随后可自由转移
public fun forge_sword(
    name: String,
    attack: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let sword = Sword { id: object::new(ctx), name, attack };
    transfer::public_transfer(sword, recipient);
}

/// 授予等级——只有本模块能转移
public fun grant_rank(
    player: address,
    rank: u64,
    ctx: &mut TxContext,
) {
    let player_rank = PlayerRank {
        id: object::new(ctx),
        rank,
        player,
    };
    transfer::transfer(player_rank, player);
}

/// 附魔武器
public fun enchant_sword(
    sword: Sword,
    element: String,
    power: u64,
    ctx: &mut TxContext,
): EnchantedSword {
    let enchantment = Enchantment { element, power };
    EnchantedSword {
        id: object::new(ctx),
        base: sword,
        enchantment,
    }
}

/// 拆解附魔武器，取回基础武器
public fun disenchant(enchanted: EnchantedSword): Sword {
    let EnchantedSword { id, base, enchantment: _ } = enchanted;
    id.delete();
    base
}
```

## 小结

- `store` 能力表示一个类型可以作为对象的字段存储，是嵌套存储的许可证。
- 拥有 `key` 的对象，其所有字段类型都必须拥有 `store`。
- `store` 与 `copy`、`drop` 是完全独立的，可以自由组合。
- 在 Sui 中，`store` 还充当"公开"修饰符——`key + store` 的对象可以被任何模块使用 `public_transfer`、`public_freeze_object`、`public_share_object` 操作。
- 只有 `key` 的对象，其存储操作被限制在定义模块内部，适合实现灵魂绑定、权限控制等场景。
- 是否添加 `store` 是灵活性与控制权之间的权衡——这是 Sui 对象设计中最重要的决策之一。
