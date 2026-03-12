# 所有权模型概述

所有权（Ownership）是 Sui 对象模型中最核心的概念之一。每个存在于 Sui 链上的对象都必须有一个明确的所有权状态，而这个状态直接决定了谁可以访问该对象、如何访问，以及对象在交易中的执行路径。Sui 提供了四种所有权类型，每种类型适用于不同的应用场景，理解它们是构建高效 Sui 应用的基础。

## 四种所有权类型概览

Sui 中的每个对象都处于以下四种所有权状态之一：

| 所有权类型 | 中文名称 | 访问控制 | 执行路径 |
|-----------|---------|---------|---------|
| Address-owned | 地址所有 | 仅所有者 | 快速路径 |
| Shared | 共享状态 | 任何人 | 共识路径 |
| Immutable | 不可变 | 任何人（只读） | 快速路径 |
| Object-owned | 对象所有 | 父对象的所有者 | 继承父对象 |
| Party | Party 对象 | Party 内配置的权限 | 共识路径 |

此外，**Party 对象**结合了「单一所有者」与「共识版本化」：通过 `party_transfer` / `public_party_transfer` 创建，适合多笔交易排队、与共享对象配合等场景，详见 [8.3.5 Party 对象](ownership-party.md)。

接下来我们逐一介绍每种所有权类型。

## 地址所有（Account Owner / Address-owned）

地址所有是最常见也最直观的所有权类型。一个地址所有的对象**只能由其所有者**在交易中使用。

### 核心特征

- 对象属于一个特定的 Sui 地址
- 只有该地址的持有者可以在交易中引用此对象
- 这是真正意义上的"个人所有权"——与现实世界中拥有一件物品非常类似
- 通过 `transfer::transfer` 或 `transfer::public_transfer` 转移所有权

### 适用场景

- 个人钱包中的代币
- 用户的 NFT 收藏
- 管理权限凭证（如 `AdminCap`）
- 任何应该由个人独占的资产

### 性能优势

由于地址所有的对象只能被其所有者使用，涉及此类对象的交易**不需要经过共识排序**，可以通过快速路径（fast path）直接执行。这使得此类交易的延迟极低。

## 共享状态（Shared State）

共享对象可以被**任何人**在交易中访问和修改。这使得它成为实现多方交互的关键机制。

### 核心特征

- 没有特定的所有者
- 任何地址都可以在交易中以可变引用（`&mut T`）或不可变引用（`&T`）访问
- 通过 `transfer::share_object` 或 `transfer::public_share_object` 创建
- 一旦共享，**不可逆转**——不能再转移或冻结

### 适用场景

想象一个 NFT 市场：

- 卖家将 NFT 挂单到一个共享的市场对象中
- 买家从市场对象中购买 NFT
- 多个用户需要同时读写同一个对象

其他场景包括：去中心化交易所的流动性池、投票合约、排行榜等。

### 性能考量

由于共享对象可能被多个交易同时访问，Sui 需要通过**共识机制**对涉及共享对象的交易进行排序。这意味着共享对象交易的延迟相对较高。因此，在设计应用时应尽量减少对共享对象的使用。

## 不可变状态（Immutable State）

不可变对象被永久冻结，**任何人**都可以读取但**没有人**可以修改、删除或转移它。

### 核心特征

- 通过 `transfer::freeze_object` 或 `transfer::public_freeze_object` 创建
- 冻结操作是不可逆的
- 只能以不可变引用（`&T`）在交易中使用
- 任何地址都可以读取

### 适用场景

- 全局配置参数
- 合约元数据
- 共享的常量数据（如游戏规则）
- 参考数据集

### 性能优势

不可变对象像地址所有的对象一样，走**快速路径**执行。因为它们不会被修改，所以不需要共识排序。

## 对象所有（Object Owner）

对象可以由另一个对象所拥有，形成对象之间的层级关系。

### 核心特征

- 一个对象被另一个对象"持有"
- 被持有的对象通过 `transfer::transfer_to_object` 或直接嵌入父对象的字段中（包装，wrapping）
- 访问被持有的对象需要先访问父对象

### 适用场景

想象一个 RPG 游戏：

- 一个角色（Hero）对象拥有装备（Sword、Shield）
- 装备被包装在角色对象内部
- 要使用装备，必须先通过角色对象访问

```move
module examples::ownership_demo;

public struct Item has key, store {
    id: UID,
    name: vector<u8>,
}

/// Single owner: transfer to a specific address
public fun send_to_owner(item: Item, recipient: address) {
    transfer::transfer(item, recipient);
}

/// Shared: anyone can access
public fun make_shared(item: Item) {
    transfer::share_object(item);
}

/// Immutable: permanently read-only
public fun make_immutable(item: Item) {
    transfer::freeze_object(item);
}
```

### 代码解析

上述代码展示了一个 `Item` 对象在三种所有权状态之间的转换：

1. **`send_to_owner`**：将 Item 转移给指定地址，该地址成为唯一所有者。
2. **`make_shared`**：将 Item 变为共享对象，任何人都可以访问。
3. **`make_immutable`**：将 Item 永久冻结，任何人可读但无人可改。

注意：`Item` 同时具有 `key` 和 `store` 能力。`store` 能力使得它可以使用 `transfer::transfer`（模块内部调用）以及 `transfer::public_transfer`（任何模块都可以调用）。

## 所有权与数据可见性

一个常见的误解是：**所有权控制了数据的可见性**。实际上并非如此。

在 Sui 中，所有链上数据都是**公开可读**的。所有权控制的是**谁可以在交易中使用这个对象作为输入**，而不是谁可以看到这个对象的数据。

| | 可以查看数据 | 可以在交易中使用 |
|---|---|---|
| Address-owned | 任何人 | 仅所有者 |
| Shared | 任何人 | 任何人 |
| Immutable | 任何人 | 任何人（只读） |
| Object-owned | 任何人 | 父对象的使用者 |

这意味着：**不要将敏感信息直接存储在对象中**。如果需要保密数据，应该使用加密方案。

## 所有权转换规则

对象的所有权状态之间存在严格的转换规则：

```
Address-owned ──→ Shared（不可逆）
Address-owned ──→ Immutable（不可逆）
Address-owned ──→ Object-owned
Address-owned ──→ Party（party_transfer / public_party_transfer）
Address-owned ──→ 另一个 Address（转移）

Object-owned  ──→ Address-owned（解包后转移）

Party         ──→ Address-owned / Immutable / Object-owned；──×→ Shared（不可转为共享）
Shared        ──→ ×（不可转换，只能销毁）
Immutable     ──→ ×（不可转换，不可销毁）
```

关键规则：
- 共享和不可变状态都是**不可逆的**
- **Party 对象**一旦创建，不能再变为共享；可转回地址所有、变为不可变或放入动态字段
- 共享对象可以被销毁（如果模块提供了销毁函数）
- 不可变对象**不能**被销毁

## 如何选择所有权类型

在设计应用时，选择正确的所有权类型至关重要。以下是一些指导原则：

### 使用 Address-owned 当：

- 对象属于某个特定用户
- 需要最高的交易性能（快速路径）
- 对象不需要被多方同时修改

### 使用 Shared 当：

- 多方需要读写同一个对象
- 构建市场、流动性池等多方交互场景
- 愿意接受共识带来的额外延迟

### 使用 Immutable 当：

- 数据一旦设置就永不更改
- 需要全局可读的配置或参考数据
- 希望享受快速路径的性能优势

### 使用 Object-owned 当：

- 需要建模对象之间的层级关系
- 一个对象在逻辑上"属于"另一个对象
- 游戏角色与装备、容器与内容等场景

### 使用 Party 当：

- 需要共识版本化，但对象仍由单方（或有限成员）控制
- 同一对象上希望多笔交易并行排队（pipeline）
- 与共享对象或其它 Party 对象一起使用，且不想把对象设为完全共享  
详见 [8.3.5 Party 对象](ownership-party.md)。

## 小结

Sui 的四种所有权类型为开发者提供了灵活而强大的状态管理模型：

- **地址所有**：个人独占，快速路径执行，最常用的所有权类型。
- **共享状态**：多方可访问，需要共识排序，适用于多方交互场景。
- **不可变状态**：永久冻结，全局可读，适用于配置和参考数据。
- **对象所有**：对象间的层级关系，实现复杂的数据组合模式。
- **Party 对象**：单一 Party 所有 + 共识版本化，支持多笔交易排队，详见 8.3.5。

所有权**不控制数据可见性**——所有链上数据都是公开的。所有权控制的是谁可以在交易中使用对象。选择正确的所有权类型，是平衡安全性、性能和功能需求的关键决策。

在接下来的章节中，我们将分别深入每种所有权类型的细节和最佳实践。
