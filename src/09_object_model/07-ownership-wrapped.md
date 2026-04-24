# 包装对象

包装对象（Wrapped Object）是 Sui 对象模型中一种强大的组合机制——一个对象可以被另一个对象"包装"在内部，成为其字段的一部分。被包装的对象从全局对象存储中"消失"，不再能被直接访问，只有通过父对象才能触及它们。这种机制非常适合建模层级关系，比如游戏角色与装备、容器与内容物等。

本章将详细介绍包装对象的工作原理、使用方式、以及在实际开发中的常见模式。

## 什么是包装

在 Sui 中，当一个对象（子对象）被存储为另一个对象（父对象）的字段时，就发生了**包装（wrapping）**。被包装的子对象：

- 从 Sui 的全局对象存储中**移除**
- 不再能被直接通过 ID 查询或访问
- 只能通过父对象间接访问
- 其 UID 仍然存在，但不在顶层索引中

### 包装的前提条件

子对象必须具有 `store` 能力，才能被嵌入到其他对象中。这是因为 `store` 能力的定义就是"可以作为其他对象的字段存储"。

```move
module examples::wrapping_basics;

/// 子对象：具有 key + store，可以独立存在，也可以被包装
public struct Gem has key, store {
    id: UID,
    value: u64,
}

/// 父对象：将 Gem 包装在内部
public struct Chest has key {
    id: UID,
    gem: Gem,   // Gem 被包装在 Chest 中
}

public fun create_chest_with_gem(
    gem_value: u64,
    ctx: &mut TxContext,
): Chest {
    let gem = Gem {
        id: object::new(ctx),
        value: gem_value,
    };
    Chest {
        id: object::new(ctx),
        gem,
    }
}
```

当 `Chest` 被创建并放到链上时，`Gem` 作为 `Chest` 的字段一起存储。此时 `Gem` 不能被独立查询——你必须通过 `Chest` 来访问它。

## 使用 Option 实现可选包装

更常见的模式是使用 `Option<T>` 来表示一个对象**可能持有**也可能不持有某个子对象。这在游戏场景中尤为常用：

```move
module examples::wrapped_objects;

use std::string::String;

public struct Sword has key, store {
    id: UID,
    damage: u64,
    name: String,
}

public struct Shield has key, store {
    id: UID,
    defense: u64,
}

public struct Hero has key {
    id: UID,
    name: String,
    hp: u64,
    sword: Option<Sword>,
    shield: Option<Shield>,
}

public fun create_hero(
    name: String,
    ctx: &mut TxContext,
): Hero {
    Hero {
        id: object::new(ctx),
        name,
        hp: 100,
        sword: option::none(),
        shield: option::none(),
    }
}

public fun equip_sword(hero: &mut Hero, sword: Sword) {
    hero.sword.fill(sword);
}

public fun unequip_sword(hero: &mut Hero): Sword {
    hero.sword.extract()
}

public fun create_sword(
    damage: u64,
    name: String,
    ctx: &mut TxContext,
): Sword {
    Sword { id: object::new(ctx), damage, name }
}
```

### 装备与卸下流程

1. **创建英雄**：调用 `create_hero`，此时 `sword` 和 `shield` 都是 `option::none()`。
2. **创建武器**：调用 `create_sword` 创建一把 `Sword` 对象（地址所有）。
3. **装备武器**：调用 `equip_sword`，将 `Sword` 按值传入并存储到 `Hero` 内部。此时 `Sword` 从全局对象存储中消失，被包装在 `Hero` 中。
4. **卸下武器**：调用 `unequip_sword`，从 `Hero` 中提取 `Sword`。提取后的 `Sword` 重新成为独立对象，需要被转移给某个地址。

## 包装与解包装的完整生命周期

```move
module examples::wrap_lifecycle;

use std::string::String;

public struct Accessory has key, store {
    id: UID,
    name: String,
    bonus: u64,
}

public struct Character has key {
    id: UID,
    name: String,
    accessories: vector<Accessory>,
}

/// 创建一个角色
public fun create_character(name: String, ctx: &mut TxContext): Character {
    Character {
        id: object::new(ctx),
        name,
        accessories: vector[],
    }
}

/// 创建一个饰品
public fun create_accessory(
    name: String,
    bonus: u64,
    ctx: &mut TxContext,
): Accessory {
    Accessory { id: object::new(ctx), name, bonus }
}

/// 包装：将饰品添加到角色身上
public fun add_accessory(character: &mut Character, acc: Accessory) {
    character.accessories.push_back(acc);
}

/// 解包装：从角色身上移除饰品（按索引）
public fun remove_accessory(
    character: &mut Character,
    index: u64,
): Accessory {
    character.accessories.remove(index)
}

/// 读取角色的饰品数量
public fun accessory_count(character: &Character): u64 {
    character.accessories.length()
}

/// 销毁角色和所有饰品
public fun destroy_character(character: Character) {
    let Character { id, name: _, mut accessories } = character;
    while (!accessories.is_empty()) {
        let acc = accessories.pop_back();
        let Accessory { id: acc_id, name: _, bonus: _ } = acc;
        acc_id.delete();
    };
    accessories.destroy_empty();
    id.delete();
}
```

### 销毁包含被包装对象的父对象

当销毁一个包含被包装对象的父对象时，你**必须同时处理所有被包装的子对象**。由于子对象不具有 `drop` 能力（数字资产不应该有），你需要：

1. 解构父对象，取出所有子对象
2. 对每个子对象，要么转移给某个地址，要么也解构并销毁它

上面的 `destroy_character` 函数展示了逐一销毁所有饰品的过程。

## 包装 vs `transfer::transfer/public_transfer` to object

Sui 提供了两种方式让一个对象"拥有"另一个对象：

### 方式一：直接包装（Wrapping）

将子对象存储为父对象的字段。子对象从全局存储中消失。

**优点**：
- 访问子对象只需要访问父对象
- 数据局部性好
- 概念简单直观

**缺点**：
- 子对象不能被直接查询
- 修改子对象必须通过父对象
- 需要 `store` 能力

### 方式二：对象转移到对象

使用 `transfer::transfer/public_transfer` 将子对象转移给父对象的 UID 地址。子对象仍然存在于全局存储中，但其所有者是另一个对象。

**优点**：
- 子对象仍然可以被查询（通过 ID）
- 可以独立地读取子对象的版本和状态

**缺点**：
- 需要额外的机制来访问子对象（如 `Receiving`）
- 概念上更复杂

在大多数场景中，直接包装是更简单和常用的选择。

## 进阶模式：背包系统

下面是一个更复杂的背包系统示例，展示了包装对象在游戏开发中的实际应用：

```move
module examples::backpack;

use std::string::String;

const EBackpackFull: u64 = 0;
const EItemNotFound: u64 = 1;

public struct Item has key, store {
    id: UID,
    name: String,
    weight: u64,
}

public struct Backpack has key {
    id: UID,
    max_capacity: u64,
    items: vector<Item>,
}

public fun create_backpack(
    max_capacity: u64,
    ctx: &mut TxContext,
): Backpack {
    Backpack {
        id: object::new(ctx),
        max_capacity,
        items: vector[],
    }
}

public fun create_item(
    name: String,
    weight: u64,
    ctx: &mut TxContext,
): Item {
    Item { id: object::new(ctx), name, weight }
}

/// 将物品放入背包（包装）
public fun put_item(backpack: &mut Backpack, item: Item) {
    assert!(
        backpack.items.length() < backpack.max_capacity,
        EBackpackFull,
    );
    backpack.items.push_back(item);
}

/// 从背包取出物品（解包装）
public fun take_item(backpack: &mut Backpack, index: u64): Item {
    assert!(index < backpack.items.length(), EItemNotFound);
    backpack.items.remove(index)
}

/// 查看背包中的物品数量
public fun item_count(backpack: &Backpack): u64 {
    backpack.items.length()
}

/// 计算背包中所有物品的总重量
public fun total_weight(backpack: &Backpack): u64 {
    let mut total = 0u64;
    let mut i = 0u64;
    let len = backpack.items.length();
    while (i < len) {
        total = total + backpack.items[i].weight;
        i = i + 1;
    };
    total
}

/// 丢弃背包中的物品（销毁）
public fun discard_item(backpack: &mut Backpack, index: u64) {
    let item = backpack.items.remove(index);
    let Item { id, name: _, weight: _ } = item;
    id.delete();
}
```

这个背包系统展示了：

- **容量限制**：`max_capacity` 限制了背包能持有的物品数量
- **包装（put_item）**：物品被放入背包后，从全局存储中消失
- **解包装（take_item）**：物品从背包中取出后，重新成为独立对象
- **销毁（discard_item）**：在背包内直接销毁物品

## 注意事项

### 包装的对象不可被直接查询

这是最重要的注意事项。一旦对象被包装，它就不在全局对象索引中了。如果你的应用需要通过对象 ID 直接查询某个对象，那么包装可能不是正确的选择。

### 嵌套包装

对象可以多层嵌套包装：A 包含 B，B 包含 C。这在概念上没问题，但会增加销毁操作的复杂度——你需要逐层解构。

### 大量包装影响交易大小

父对象包含的被包装对象越多，交易读写这个父对象时需要处理的数据量越大。这可能会影响交易的 gas 费用和执行效率。

### store 能力的安全考量

给对象添加 `store` 能力意味着它可以被包装到任何其他对象中，也可以被 `public_transfer` 转移。在设计时需要考虑是否真的需要这种灵活性。

## 小结

包装对象为 Sui 开发者提供了一种强大的对象组合机制，核心要点如下：

- **包装本质**：将子对象存储为父对象的字段，子对象从全局存储中消失。
- **`store` 能力**：子对象必须具有 `store` 能力才能被包装。
- **`Option<T>`**：使用 Option 类型实现可选包装，适合装备/卸下场景。
- **解包装**：从父对象中取出子对象后，它重新成为独立对象。
- **销毁规则**：销毁父对象时必须同时处理所有被包装的子对象。
- **适用场景**：游戏角色与装备、容器与内容物、组合资产等层级关系。

包装对象是构建复杂链上数据结构的重要工具。在需要建模"拥有"关系时，包装比简单地存储 ID 引用更安全、更直观。但要注意包装对象的不可查询性和对交易大小的影响。
