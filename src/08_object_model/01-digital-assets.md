# 数字资产的语言

Move 语言从设计之初就将**数字资产**作为一等公民（first-class citizen）来对待。与传统的智能合约语言不同，Move 通过其类型系统在语言层面保障资产的安全性，让开发者可以像操作普通数据类型一样自然地表达数字资产的创建、转移和销毁。本章将探讨 Move 为何是表达数字资产的理想语言，以及它如何从根本上解决了区块链资产管理中的常见问题。

## 传统区块链语言的资产表达困境

在理解 Move 的优势之前，我们需要先了解传统方案的不足。

### ERC-20 与 ERC-721 的本质问题

以太坊的 ERC-20（同质化代币）和 ERC-721（非同质化代币）标准本质上只是**记账模型**——它们使用 `mapping(address => uint256)` 这样的映射表来记录谁拥有多少代币。这带来了几个根本性问题：

- **资产不是独立实体**：代币余额只是合约内部状态中的一个数字，它没有独立的身份和生命周期。
- **安全性依赖开发者自律**：重入攻击、整数溢出、授权漏洞等问题反复出现，因为语言本身不提供资产安全的保障。
- **标准碎片化**：ERC-20、ERC-721、ERC-1155……每种资产类型需要独立的标准和实现，增加了复杂性。

### Move 的解决方案

Move 采用了完全不同的思路：**资产即类型**。一个数字资产就是一个 Move 结构体（struct），其安全属性由类型系统在编译期强制保证。不需要任何外部标准或约定，语言本身就知道如何正确处理资产。

## 数字资产的三大本质属性

任何真正的数字资产都应具备三个关键属性。Move 通过其独特的能力（ability）系统来强制保障这些属性。

### 所有权（Ownership）

每个数字资产必须有明确的所有者。在 Move on Sui 中，每个对象都有一个确定的所有者——可以是一个地址、另一个对象，或者被共享/冻结。

所有权不是通过查询合约内部映射表来确定的，而是**由运行时直接追踪**的。这意味着：

- 只有所有者可以在交易中使用该对象
- 所有权的转移是原子性的
- 无需担心授权和代理的复杂逻辑

### 不可复制（Non-copyable）

现实世界中，你不能复制一幅画或一枚金币。数字资产也应如此。Move 中，除非显式声明 `copy` 能力，结构体默认是**不可复制**的。这意味着：

- 数字资产不会被意外或恶意地"复制"
- 资产的总量始终是可控的
- "双重支付"在类型系统层面就被杜绝了

### 不可丢弃（Non-discardable）

你不能让一枚有价值的代币凭空消失。在 Move 中，除非显式声明 `drop` 能力，结构体在作用域结束时**必须被显式处理**——要么转移给他人，要么通过解构（destructure）来销毁。编译器会强制检查这一点：

- 忘记处理资产会导致编译错误
- 资产不会因为编程疏忽而丢失
- 每个资产的完整生命周期都是可追踪的

## Move 的类型系统如何保障资源安全

Move 的**线性类型系统**（linear type system）是其安全保障的核心。它的四种能力（abilities）精确控制了类型的行为：

| 能力 | 含义 | 对资产的影响 |
|------|------|-------------|
| `key` | 可以作为对象存储 | 使结构体成为链上对象 |
| `store` | 可以嵌入其他对象 | 允许资产被包装和组合 |
| `copy` | 可以被复制 | 资产通常**不应**具有此能力 |
| `drop` | 可以被隐式丢弃 | 资产通常**不应**具有此能力 |

一个典型的数字资产只需要 `key` 能力（可能加上 `store`），而刻意**不赋予** `copy` 和 `drop`。这样，Move 编译器就会自动保证该资产不能被复制或丢弃。

## 代码示例：一个简单的数字资产

下面的示例展示了如何在 Sui 上定义一个数字资产——一幅画作（Painting）。注意它只有 `key` 能力，没有 `copy` 和 `drop`：

```move
module examples::digital_asset;

/// A simple digital asset - a Painting
public struct Painting has key {
    id: UID,
    artist: address,
    title: vector<u8>,
    year: u64,
}

/// Create a new painting - ownership is granted to the creator
public fun create(
    title: vector<u8>,
    year: u64,
    ctx: &mut TxContext,
): Painting {
    Painting {
        id: object::new(ctx),
        artist: ctx.sender(),
        title,
        year,
    }
}

/// Transfer a painting to a new owner
/// After this call, the original owner loses all control
public fun give_to(painting: Painting, recipient: address) {
    transfer::transfer(painting, recipient);
}
```

### 代码要点分析

1. **`has key`**：`Painting` 具有 `key` 能力，这使它成为一个 Sui 对象，可以被独立拥有和追踪。
2. **`id: UID`**：每个 Sui 对象的第一个字段必须是 `id: UID`，这是其全局唯一标识符。
3. **没有 `copy`**：你无法复制一幅画，`let copy = painting;` 这样的代码会编译失败。
4. **没有 `drop`**：你不能忽略一幅画，函数结束时如果 `Painting` 没有被转移或解构，编译器会报错。
5. **`give_to` 接收值而非引用**：`painting: Painting` 是按值传递的。调用此函数后，调用者**完全失去**对这幅画的控制权——这就是真正的所有权转移。

## 与传统方案的对比

让我们用一个表格来对比 Move 和传统 ERC 标准在资产管理上的差异：

| 特性 | ERC-20/ERC-721 | Move |
|------|---------------|------|
| 资产表达 | 映射表中的数字 | 独立的结构体实例 |
| 所有权保障 | 开发者自行实现 | 运行时自动追踪 |
| 防止复制 | 依赖业务逻辑 | 类型系统编译期保证 |
| 防止丢失 | 无保障 | 编译器强制检查 |
| 可组合性 | 需要额外标准 | 结构体自然组合 |
| 安全审计 | 需要大量人工审查 | 编译器自动验证关键属性 |

## 更复杂的资产示例

在实际开发中，数字资产通常更复杂。以下示例展示了一个带有稀有度和属性的游戏道具：

```move
module examples::game_item;

use std::string::String;

/// 稀有度枚举
public struct Rarity has store, copy, drop {
    level: u8, // 1=普通, 2=稀有, 3=史诗, 4=传说
}

/// 游戏道具 - 不可复制、不可丢弃的数字资产
public struct GameItem has key, store {
    id: UID,
    name: String,
    rarity: Rarity,
    power: u64,
    creator: address,
}

/// 铸造一个新的游戏道具
public fun mint(
    name: String,
    rarity_level: u8,
    power: u64,
    ctx: &mut TxContext,
): GameItem {
    assert!(rarity_level >= 1 && rarity_level <= 4, 0);
    GameItem {
        id: object::new(ctx),
        name,
        rarity: Rarity { level: rarity_level },
        power,
        creator: ctx.sender(),
    }
}

/// 销毁道具（回收），只有创建者可以销毁
public fun burn(item: GameItem, ctx: &TxContext) {
    assert!(item.creator == ctx.sender(), 1);
    let GameItem { id, name: _, rarity: _, power: _, creator: _ } = item;
    id.delete();
}

/// 读取道具的属性
public fun power(item: &GameItem): u64 {
    item.power
}

public fun rarity_level(item: &GameItem): u8 {
    item.rarity.level
}
```

在这个例子中：

- `Rarity` 是一个值类型（有 `store`、`copy`、`drop`），它不是对象，可以自由复制和丢弃。
- `GameItem` 是一个数字资产（有 `key`、`store`），它是不可复制、不可丢弃的对象。
- `burn` 函数是销毁资产的唯一途径——必须显式解构每个字段，并删除 `UID`。

这种设计确保了即使在复杂的游戏经济中，每个道具的生命周期都是完整可追踪的。

## 小结

Move 语言从本质上重新定义了区块链上数字资产的表达方式。通过将资产建模为具有线性类型约束的结构体，Move 在编译期就能保证三大核心属性：

- **所有权明确**：每个资产都有唯一的所有者，所有权转移是原子性的。
- **不可复制**：类型系统阻止了任何非法的资产复制。
- **不可丢弃**：编译器确保每个资产都被正确处理，不会因编程失误而丢失。

这些保障不需要开发者额外编写任何安全检查代码——它们是语言内建的。这就是 Move 被称为"数字资产的语言"的原因。在接下来的章节中，我们将深入探讨 Sui 的对象模型，了解这些资产在链上是如何被组织和管理的。
