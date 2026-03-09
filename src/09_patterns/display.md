# Object Display

Object Display 是 Sui 提供的一套标准化机制，用于定义对象在链下客户端（钱包、浏览器、市场）中的**展示方式**。通过 `Display<T>` 对象，开发者可以为类型设置模板化的展示字段，而无需在每个对象实例中存储元数据。

本章将介绍 Display 的设计背景、创建方式、模板语法以及最佳实践。

## 设计背景

### 为什么不在对象中存储元数据？

传统方案可能会在每个 NFT 对象中存储 `name`、`description`、`image_url` 等展示字段：

```move
/// ❌ 不推荐：每个对象都存储完整的元数据
public struct BadNFT has key, store {
    id: UID,
    name: String,
    description: String,    // 每个对象都存一份
    image_url: String,      // 每个对象都存一份
    project_url: String,    // 每个对象都存一份
    creator: String,        // 每个对象都存一份
    // ...业务字段
    power: u64,
}
```

这种方式存在几个问题：

1. **存储冗余**：大量重复数据（如 `project_url` 对同类对象都一样）
2. **Gas 浪费**：创建和存储更多数据意味着更高的 Gas 费
3. **更新困难**：如果要修改展示方式，需要逐个更新所有对象
4. **耦合严重**：业务逻辑与展示逻辑混在一起

### Display 的解决方案

`Display<T>` 将展示逻辑与对象数据分离：

- 对象只存储**业务数据**
- 展示规则定义在单独的 `Display<T>` 对象中
- 客户端在展示时，将 Display 模板与对象字段结合，动态生成展示内容

```move
/// ✅ 推荐：对象只存储业务数据
public struct GoodNFT has key, store {
    id: UID,
    name: String,
    power: u64,
    image_id: String,
}

// Display<GoodNFT> 定义展示规则：
// name: "{name}"
// description: "An NFT with {power} power"
// image_url: "https://example.com/nfts/{image_id}.png"
```

## Display\<T\> 对象

`Display<T>` 是一个与类型 `T` 关联的对象，包含一组键值对，定义了展示模板：

```move
// sui::display 模块中的定义（简化）
public struct Display<phantom T: key> has key, store {
    id: UID,
    fields: VecMap<String, String>,
    version: u16,
}
```

关键点：

- `phantom T`：与特定类型关联，`Display<Hero>` 和 `Display<Weapon>` 是不同类型
- `fields`：键值对映射，key 是字段名，value 是模板字符串
- `version`：版本号，每次更新后递增，客户端据此刷新缓存

## 创建 Display

创建 `Display<T>` 需要该类型所属模块的 `Publisher` 对象：

```move
module examples::game_hero;

use sui::package;
use sui::display;
use std::string::String;

public struct GAME_HERO has drop {}

public struct Hero has key, store {
    id: UID,
    name: String,
    class: String,
    level: u64,
    image_id: String,
}

fun init(otw: GAME_HERO, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let keys = vector[
        std::string::utf8(b"name"),
        std::string::utf8(b"description"),
        std::string::utf8(b"image_url"),
        std::string::utf8(b"project_url"),
    ];

    let values = vector[
        std::string::utf8(b"{name} - Level {level}"),
        std::string::utf8(b"A {class} hero in the game"),
        std::string::utf8(b"https://game.example.com/heroes/{image_id}"),
        std::string::utf8(b"https://game.example.com"),
    ];

    let mut disp = display::new_with_fields<Hero>(
        &publisher,
        keys,
        values,
        ctx,
    );
    display::update_version(&mut disp);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());
}
```

也可以分步创建和添加字段：

```move
fun init_step_by_step(otw: GAME_HERO, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    // 先创建空的 Display
    let mut disp = display::new<Hero>(&publisher, ctx);

    // 逐个添加字段
    display::add(&mut disp, std::string::utf8(b"name"), std::string::utf8(b"{name}"));
    display::add(&mut disp, std::string::utf8(b"description"), std::string::utf8(b"A {class} hero"));
    display::add(&mut disp, std::string::utf8(b"image_url"), std::string::utf8(b"https://game.example.com/heroes/{image_id}"));

    // 更新版本号以通知客户端
    display::update_version(&mut disp);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());
}
```

## 模板语法

Display 使用花括号 `{}` 作为模板占位符，在客户端渲染时替换为对象的实际字段值。

### 基本字段引用

```
{field_name}
```

直接引用对象的字段名：

| 模板 | 对象字段 | 渲染结果 |
|------|---------|---------|
| `"{name}"` | `name: "Warrior"` | `"Warrior"` |
| `"Level {level}"` | `level: 5` | `"Level 5"` |
| `"{name} - Lv.{level}"` | `name: "Warrior"`, `level: 5` | `"Warrior - Lv.5"` |

### URL 模板

最常见的用法是构建动态 URL：

```
"https://example.com/images/{image_id}.png"
```

如果对象的 `image_id` 字段值为 `"abc123"`，渲染结果为：

```
"https://example.com/images/abc123.png"
```

### 静态值

不包含 `{}` 的值会原样展示：

```
"https://game.example.com"  // 所有对象共享同一个项目 URL
```

## 标准字段

Sui 生态约定了一组标准展示字段，客户端会优先识别这些字段：

| 字段 | 用途 | 示例值 |
|------|------|--------|
| `name` | 对象名称 | `"{name}"` |
| `description` | 对象描述 | `"A {class} hero"` |
| `image_url` | 展示图片 URL | `"https://example.com/{image_id}.png"` |
| `link` | 对象详情页链接 | `"https://example.com/items/{id}"` |
| `project_url` | 项目主页 | `"https://example.com"` |
| `creator` | 创建者信息 | `"Game Studio"` |
| `thumbnail_url` | 缩略图 URL | `"https://example.com/thumbs/{image_id}.png"` |

## 更新 Display

持有 `Display<T>` 对象的用户可以随时更新展示规则：

```move
module examples::update_display;

use sui::display;
use std::string::String;

public struct Item has key, store {
    id: UID,
    name: String,
    version: u64,
}

/// 更新 Display 的字段
public fun update_item_display(
    disp: &mut display::Display<Item>,
) {
    // 修改已有字段
    display::edit(
        disp,
        std::string::utf8(b"description"),
        std::string::utf8(b"Updated: Item v{version} - {name}"),
    );

    // 添加新字段
    display::add(
        disp,
        std::string::utf8(b"thumbnail_url"),
        std::string::utf8(b"https://new-cdn.example.com/thumbs/{name}.png"),
    );

    // 必须更新版本号，客户端才会刷新
    display::update_version(disp);
}

/// 移除字段
public fun remove_field(
    disp: &mut display::Display<Item>,
) {
    display::remove(disp, std::string::utf8(b"thumbnail_url"));
    display::update_version(disp);
}
```

### 版本号的重要性

每次修改 Display 后，必须调用 `display::update_version` 来递增版本号。客户端通过监听版本变化来决定是否刷新缓存。如果忘记更新版本号，修改可能不会立即生效。

## 创建者特权

Display 的一个重要特性是**创建者特权**——持有 Display 对象的人可以随时全局更新所有同类型对象的展示方式，而无需逐个修改对象本身。

这带来了巨大的灵活性：

- **迁移 CDN**：更换图片服务器时，只需更新 Display 中的 URL 模板
- **修复错误**：发现描述有误，一次修改即可全部生效
- **版本迭代**：随着项目发展，逐步丰富展示内容

```move
module examples::cdn_migration;

use sui::display;
use std::string::String;

public struct NFT has key, store {
    id: UID,
    name: String,
    image_hash: String,
}

/// 迁移到新的 CDN
public fun migrate_cdn(
    disp: &mut display::Display<NFT>,
) {
    // 从旧 CDN 迁移到新 CDN
    display::edit(
        disp,
        std::string::utf8(b"image_url"),
        std::string::utf8(b"https://new-cdn.example.com/nfts/{image_hash}.png"),
    );
    display::update_version(disp);
}
```

## 完整示例：游戏装备系统

```move
module examples::equipment;

use sui::package;
use sui::display;
use std::string::String;

public struct EQUIPMENT has drop {}

public struct Weapon has key, store {
    id: UID,
    name: String,
    weapon_type: String,
    damage: u64,
    rarity: String,
    skin_id: String,
}

public struct Armor has key, store {
    id: UID,
    name: String,
    armor_type: String,
    defense: u64,
    rarity: String,
    skin_id: String,
}

fun init(otw: EQUIPMENT, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    // 为 Weapon 创建 Display
    let mut weapon_display = display::new_with_fields<Weapon>(
        &publisher,
        vector[
            std::string::utf8(b"name"),
            std::string::utf8(b"description"),
            std::string::utf8(b"image_url"),
            std::string::utf8(b"project_url"),
            std::string::utf8(b"creator"),
        ],
        vector[
            std::string::utf8(b"{name} ({rarity})"),
            std::string::utf8(b"A {weapon_type} dealing {damage} damage"),
            std::string::utf8(b"https://game.example.com/weapons/{skin_id}.png"),
            std::string::utf8(b"https://game.example.com"),
            std::string::utf8(b"Game Studio"),
        ],
        ctx,
    );
    display::update_version(&mut weapon_display);

    // 为 Armor 创建 Display
    let mut armor_display = display::new_with_fields<Armor>(
        &publisher,
        vector[
            std::string::utf8(b"name"),
            std::string::utf8(b"description"),
            std::string::utf8(b"image_url"),
            std::string::utf8(b"project_url"),
            std::string::utf8(b"creator"),
        ],
        vector[
            std::string::utf8(b"{name} ({rarity})"),
            std::string::utf8(b"A {armor_type} providing {defense} defense"),
            std::string::utf8(b"https://game.example.com/armors/{skin_id}.png"),
            std::string::utf8(b"https://game.example.com"),
            std::string::utf8(b"Game Studio"),
        ],
        ctx,
    );
    display::update_version(&mut armor_display);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(weapon_display, ctx.sender());
    transfer::public_transfer(armor_display, ctx.sender());
}
```

## Display 与 CoinMetadata

值得注意的是，`Coin<T>` 类型不使用 Display 标准来展示元数据。代币的元数据（名称、符号、图标等）由 **coin_registry** 管理，存储在链上 **`Currency<T>`** 中（通过 **`coin_registry::new_currency_with_otw` + `finalize`** 创建，而非已废弃的 `coin::create_currency`）。这是因为代币的元数据需求与普通对象不同，需要标准化的字段格式。

## 小结

Object Display 是 Sui 的链下展示标准，它将展示逻辑从对象数据中分离出来，通过模板机制实现了高效、灵活的展示配置。创建 Display 需要 Publisher 权限，确保只有类型的定义者才能设置展示规则。模板语法使用 `{field_name}` 引用对象字段，支持动态 URL 生成和字符串拼接。Display 的创建者特权允许全局更新展示规则，无需修改单个对象，极大地方便了项目的运营和迭代。
