# NFT 基础概念

在 Sui 上，NFT（Non-Fungible Token，非同质化代币）不需要特殊的标准或框架——每个 Sui 对象天然就是唯一的。Sui 的对象模型为 NFT 提供了天然的表达能力：每个对象都有唯一的 ID、明确的所有权，并且可以附加丰富的数据。本节将介绍 NFT 的基础概念及其在 Sui 上的实现方式。

## Sui 对象即 NFT

在其他区块链上，NFT 需要遵循特定标准（如 ERC-721）。但在 Sui 上，任何具有 `key` ability 的对象都天然具备 NFT 的核心特性：

- **唯一性**：每个对象有全局唯一的 `UID`
- **所有权**：对象属于特定地址或另一个对象
- **不可替代**：每个对象是独立的实体

```move
module game::hero;

/// Hero 就是一个 NFT——每个实例都是唯一的
public struct Hero has key, store {
    id: UID,
    health: u64,
    stamina: u64,
}

public fun mint_hero(ctx: &mut TxContext): Hero {
    Hero {
        id: object::new(ctx),
        health: 100,
        stamina: 10,
    }
}
```

## Display 标准

`sui::display` 模块允许为对象定义链下展示模板，告诉钱包、浏览器和市场如何展示你的 NFT：

```move
module game::hero;

use sui::display;
use sui::package;

public struct Hero has key, store {
    id: UID,
    name: String,
    image_url: String,
    description: String,
    power: u64,
}

public struct HERO() has drop;

fun init(otw: HERO, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut display = display::new<Hero>(&publisher, ctx);

    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"image_url".to_string(), b"{image_url}".to_string());
    display.add(b"description".to_string(), b"{description}".to_string());
    display.add(
        b"project_url".to_string(),
        b"https://mygame.com".to_string(),
    );

    display.update_version();

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
}
```

### Display 模板语法

Display 使用 `{field_name}` 语法引用对象字段：

| 键 | 值示例 | 说明 |
| --- | --- | --- |
| `name` | `{name}` | NFT 名称 |
| `image_url` | `{image_url}` | 图片 URL |
| `description` | `{description}` | 描述 |
| `project_url` | 固定 URL | 项目主页 |
| `creator` | `MyGame Team` | 创作者信息 |

### Display 的工作原理

1. 用 `package::claim` 获取 `Publisher` 对象证明包的发布者身份
2. 用 `display::new<T>` 创建 Display 对象
3. 用 `display.add()` 添加模板字段
4. 调用 `display.update_version()` 发出更新事件
5. 链下索引器读取事件并缓存模板

## 对象所有权与 NFT

Sui 的所有权模型天然契合 NFT 的需求：

### 地址拥有

NFT 属于某个钱包地址，只有该地址可以操作：

```move
// 铸造并转移给玩家
let hero = mint_hero(ctx);
transfer::public_transfer(hero, player_address);
```

### 对象拥有

NFT 可以属于另一个对象（嵌套组合）：

```move
use sui::dynamic_object_field as dof;

/// 武器 NFT
public struct Sword has key, store {
    id: UID,
    name: String,
    damage: u64,
}

/// 英雄装备武器
public fun equip_sword(hero: &mut Hero, sword: Sword) {
    dof::add(&mut hero.id, b"sword".to_string(), sword);
}

/// 英雄卸下武器
public fun unequip_sword(hero: &mut Hero): Sword {
    dof::remove(&mut hero.id, b"sword".to_string())
}
```

### 不可变对象

将 NFT 冻结为不可变——永远无法修改或转移：

```move
// 创建永久性证书
let cert = Certificate { id: object::new(ctx), /* ... */ };
transfer::freeze_object(cert);
```

## NFT 的 Ability 选择

| Ability 组合 | 含义 | 适用场景 |
| --- | --- | --- |
| `key, store` | 可自由转移、可存入其他对象 | 可交易的 NFT |
| `key` | 只能通过自定义函数转移 | 灵魂绑定 NFT |
| `key, store, copy` | 可复制 | 通常不用于 NFT |

## 集合（Collection）模式

虽然 Sui 没有强制的集合概念，但可以通过共享对象实现：

```move
public struct Collection has key {
    id: UID,
    name: String,
    description: String,
    total_minted: u64,
    max_supply: u64,
}

const EMaxSupplyReached: u64 = 1;

public fun mint_from_collection(
    collection: &mut Collection,
    ctx: &mut TxContext,
): Hero {
    assert!(collection.total_minted < collection.max_supply, EMaxSupplyReached);
    collection.total_minted = collection.total_minted + 1;

    Hero {
        id: object::new(ctx),
        name: b"Hero #".to_string(), // 可拼接编号
        image_url: b"https://mygame.com/hero.png".to_string(),
        description: b"A brave hero".to_string(),
        power: 10,
    }
}
```

## 小结

- 在 Sui 上每个对象天然就是 NFT——具有唯一 ID 和明确所有权
- `Display` 标准定义 NFT 的链下展示方式（名称、图片、描述等）
- 所有权模型支持地址拥有、对象嵌套、不可变等多种模式
- 通过 ability 选择控制 NFT 的可转移性（`store` 允许自由转移）
- 集合（Collection）模式可通过共享对象实现供应量限制
