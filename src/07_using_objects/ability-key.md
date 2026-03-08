# key 能力

在 Sui Move 中，`key` 能力是定义**对象（Object）**的核心标志。一个结构体只有拥有 `key` 能力，才能作为独立的链上对象存在，拥有全局唯一的标识符，并参与 Sui 的所有权和存储模型。理解 `key` 能力是掌握 Sui 对象系统的第一步。

## key 的历史演变

在早期的 Move 语言（Diem/Aptos 版本）中，`key` 能力表示一个类型可以作为**全局存储的顶层资源（Resource）**存在。拥有 `key` 的结构体可以通过 `move_to`、`move_from` 等操作存储到账户地址下。

Sui Move 对 `key` 的语义进行了重新定义：

- **不再有全局存储操作**：Sui 移除了 `move_to`、`move_from`、`borrow_global` 等全局存储原语。
- **key = 对象**：在 Sui 中，`key` 能力的唯一作用是将一个结构体声明为**对象**。
- **对象模型取代资源模型**：Sui 使用基于对象的存储模型，每个对象通过唯一的 `UID` 在链上独立存在。

这一转变使得 Sui 能够实现并行交易执行——每个对象独立寻址，不依赖账户级别的全局存储。

## 对象定义规则

### 第一字段必须是 `id: UID`

这是 Sui Move 的硬性规则：任何拥有 `key` 能力的结构体，**第一个字段必须是 `id: UID`**。这由 Sui 字节码验证器（Sui Verifier）在编译和发布时强制检查。

```move
module examples::key_demo;

use std::string::String;

/// 一个拥有 `key` 能力的结构体就是一个 Object
/// 第一个字段必须是 `id: UID`
public struct User has key {
    id: UID,
    name: String,
    age: u8,
}

/// 创建一个新的 User 对象
public fun new(name: String, age: u8, ctx: &mut TxContext): User {
    User {
        id: object::new(ctx),
        name,
        age,
    }
}

/// 创建并转移给发送者
public fun create_and_send(name: String, age: u8, ctx: &mut TxContext) {
    let user = new(name, age, ctx);
    transfer::transfer(user, ctx.sender());
}
```

`UID` 是对象的全局唯一标识符。它由 `object::new(ctx)` 生成，其底层是从交易哈希和计数器派生的地址值，保证全局唯一且不可预测。

### 违反规则的示例

以下代码**无法通过编译**：

```move
// 错误！第一个字段不是 `id: UID`
public struct BadObject has key {
    name: String,  // 第一个字段必须是 id: UID
    id: UID,
}
```

```move
// 错误！缺少 id 字段
public struct AlsoBad has key {
    value: u64,
}
```

Sui 验证器会拒绝这些定义，确保所有对象都有统一的标识方式。

## key 与 store 的字段约束

拥有 `key` 能力的结构体，其**所有字段**的类型都必须拥有 `store` 能力。这是 Move 类型系统的约束——一个结构体的能力不能"超过"其字段类型的能力。

```move
/// String 拥有 store，u8 拥有 store，UID 拥有 store
/// 所以 Profile 可以拥有 key
public struct Profile has key {
    id: UID,          // UID has store
    name: String,     // String has store
    score: u64,       // u64 has store
}
```

如果某个字段的类型没有 `store`，编译器会报错：

```move
public struct NoStore { value: u64 }

// 错误！NoStore 没有 store 能力
public struct Invalid has key {
    id: UID,
    data: NoStore,  // 编译失败
}
```

### 原生类型的 store 能力

以下原生类型天然拥有 `store`（以及 `copy` 和 `drop`）：

| 类型 | 能力 |
|------|------|
| `bool` | `copy`, `drop`, `store` |
| `u8`, `u16`, `u32`, `u64`, `u128`, `u256` | `copy`, `drop`, `store` |
| `address` | `copy`, `drop`, `store` |
| `vector<T>` | 继承 `T` 的能力 |

## key 与 copy/drop 的关系

这是理解 Sui 对象模型的关键点：**拥有 `key` 能力的结构体通常不能同时拥有 `copy` 或 `drop`**。

原因在于 `UID` 类型：

- `UID` **没有** `copy` 能力——对象标识不能被复制，否则两个对象会共享同一个 ID。
- `UID` **没有** `drop` 能力——对象标识不能被隐式丢弃，必须显式调用 `id.delete()` 删除。

由于结构体的能力受限于其字段类型的能力，包含 `UID` 的结构体自然无法拥有 `copy` 或 `drop`：

```move
// 错误！UID 没有 copy 和 drop，所以 CopyObj 不能拥有它们
public struct CopyObj has key, copy, drop {
    id: UID,
    value: u64,
}
```

这个设计是刻意为之的：

- **不能 copy**：确保每个对象在链上是唯一的，不会出现"分身"。
- **不能 drop**：确保对象不会被意外丢弃，必须被显式转移（transfer）、共享（share）、冻结（freeze）或销毁（delete）。

### 对象的去向

由于对象不能被 `drop`，在函数结束时，对象必须有一个明确的归宿：

```move
public fun must_handle_object(ctx: &mut TxContext) {
    let user = User {
        id: object::new(ctx),
        name: std::string::utf8(b"Alice"),
        age: 25,
    };

    // 必须处理 user，以下四种方式之一：
    // 1. 转移给某人
    transfer::transfer(user, ctx.sender());

    // 2. 共享为共享对象
    // transfer::share_object(user);

    // 3. 冻结为不可变对象
    // transfer::freeze_object(user);

    // 4. 解构并删除 UID
    // let User { id, name: _, age: _ } = user;
    // id.delete();
}
```

## 拥有 key 能力的类型总结

在 Sui 生态中，几乎所有链上实体都是拥有 `key` 的对象：

| 用途 | 示例 |
|------|------|
| NFT | `public struct NFT has key, store { id: UID, ... }` |
| 代币金库 | `public struct TreasuryCap has key, store { id: UID, ... }` |
| 权限凭证 | `public struct AdminCap has key { id: UID }` |
| 配置对象 | `public struct Config has key { id: UID, ... }` |
| 共享状态 | `public struct Registry has key { id: UID, ... }` |

注意：有些对象只有 `key` 而没有 `store`，这是为了限制转移权限（详见后续章节）。

## 完整示例：游戏角色对象

```move
module examples::game_character;

use std::string::String;

public struct Weapon has store {
    name: String,
    damage: u64,
}

public struct Character has key {
    id: UID,
    name: String,
    level: u8,
    hp: u64,
    weapon: Weapon,
}

public fun create_character(
    name: String,
    ctx: &mut TxContext,
) {
    let starter_weapon = Weapon {
        name: std::string::utf8(b"Wooden Sword"),
        damage: 10,
    };

    let character = Character {
        id: object::new(ctx),
        name,
        level: 1,
        hp: 100,
        weapon: starter_weapon,
    };

    transfer::transfer(character, ctx.sender());
}

public fun upgrade_weapon(
    character: &mut Character,
    new_weapon_name: String,
    new_damage: u64,
) {
    character.weapon = Weapon {
        name: new_weapon_name,
        damage: new_damage,
    };
}

public fun destroy_character(character: Character) {
    let Character {
        id,
        name: _,
        level: _,
        hp: _,
        weapon: _,
    } = character;
    id.delete();
}
```

在这个例子中：

- `Weapon` 拥有 `store`——它可以作为对象的字段存在，但本身不是对象。
- `Character` 拥有 `key`——它是链上对象，拥有唯一的 `id`。
- `Character` 的所有字段（`UID`、`String`、`u8`、`u64`、`Weapon`）都拥有 `store`。
- `Character` 没有 `copy` 或 `drop`，因此必须在 `destroy_character` 中显式解构并删除 `UID`。

## 小结

- `key` 能力是 Sui 对象的定义标志，任何拥有 `key` 的结构体都是链上对象。
- 对象的第一个字段**必须**是 `id: UID`，这是 Sui 验证器的硬性要求。
- 对象的所有字段类型都必须拥有 `store` 能力。
- 由于 `UID` 没有 `copy` 和 `drop`，对象通常也不能拥有这两个能力，这保证了对象的唯一性和不可丢弃性。
- 对象在使用完毕后必须被转移、共享、冻结或显式销毁——没有第五种选择。
