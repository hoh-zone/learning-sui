# 第十二章 · 高级可编程性

本章系统讲解 **`sui::` Framework**（以及与之配合的 **`std::`** 能力）在合约中的实际用法：从**每笔交易自带的上下文**，到**发布时的一次性初始化**、**链下可观测的事件**，再到 **Epoch / 时钟 / 随机数**，然后是 **对象内集合与动态字段上的大规模集合**，最后落到 **Coin / BCS / 密码学**。**全章的模块地图与三层包关系**已集中在 **[§12.1 · Sui Framework 概览](01-sui-framework.md)**，建议先通读 §12.1，再按下面路线读各节。

---

## 建议阅读路线

| 阶段 | 节 | 主题 | 说明 |
|------|-----|------|------|
| **A. 交易与启动** | [§12.2](02-transaction-context.md) | `TxContext` | 隐式模块 `tx_context`；`sender` / `epoch` / `object::new` 的前提 |
| | [§12.3](03-module-initializer.md) | `init` | 发布时一次；可与 OTW、`package::claim` 配合 |
| **B. 可观测性** | [§12.4](04-events.md) | `event::emit` | `copy + drop`、内部类型约束；链下索引依赖 |
| **C. 时间与随机** | [§12.5](05-epoch-and-time.md) | Epoch 与 `Clock` | 粗粒度 epoch vs 毫秒级 `Clock@0x6` |
| | [§12.14](14-randomness.md) | `Random@0x8` | 与 §12.5 同属「系统共享对象」语境 |
| **D. 存储：小与大** | [§12.6](06-collections.md) | `VecMap` / `VecSet` | 数据在**对象内部**，适合小规模 |
| | [§12.7](07-dynamic-fields.md) | 动态字段 | `UID` 上异构扩展，是 §12.8 / §12.10 的底层 |
| | [§12.8](08-dynamic-object-fields.md) | 动态对象字段 | 值为**子对象**，可索引 |
| | [§12.9](09-derived-object.md) | `derived_object` | 确定性地址与注册表模式 |
| | [§12.10](10-dynamic-collections.md) | `Table` / `Bag` / … | 基于动态（对象）字段的集合；与 §12.6 对照 |
| **E. 资产与数据编码** | [§12.11](11-balance-and-coin.md) | `Balance` / `Coin` | 代币底层；与[第十五章 · 代币](../15_tokens/00-index.md)衔接 |
| | [§12.12](12-bcs.md) | `sui::bcs` | 字节与结构体；与 `std::bcs` 分工见节内 |
| | [§12.13](13-cryptography-and-hashing.md) | 哈希与签名 | `crypto/*` 原语 |
| **回顾** | [§12.1](01-sui-framework.md) | 框架总览 | `move-stdlib` / `sui-framework` / `sui-system`、集合选型表 |

---

## 本章内容（与 §12.1 对照）

| 节 | 主题 | 在框架中的位置（摘要） |
|---|------|------------------------|
| 11.1 | [Sui Framework 概览](01-sui-framework.md) | `packages` 三层、`std`/`sui`/`sui_system`、集合与模块总表 |
| 11.2 | [交易上下文](02-transaction-context.md) | 隐式 **`sui::tx_context`** |
| 11.3 | [模块初始化器](03-module-initializer.md) | `init`、**`sui::package`** 与 OTW |
| 11.4 | [事件](04-events.md) | **`sui::event`** |
| 11.5 | [Epoch 与时间](05-epoch-and-time.md) | **`sui::clock`** 与 `TxContext` 中的 epoch |
| 11.6 | [集合类型（Vec）](06-collections.md) | **`sui::vec_map` / `vec_set`** |
| 11.7 | [动态字段](07-dynamic-fields.md) | **`sui::dynamic_field`** |
| 11.8 | [动态对象字段](08-dynamic-object-fields.md) | **`sui::dynamic_object_field`** |
| 11.9 | [派生对象](09-derived-object.md) | **`sui::derived_object`** |
| 11.10 | [动态集合](10-dynamic-collections.md) | **`table` / `bag` / `object_*` / `linked_table` / `table_vec`** 等 |
| 11.11 | [Balance 与 Coin](11-balance-and-coin.md) | **`balance` / `coin` / `sui::SUI`** |
| 11.12 | [BCS 序列化](12-bcs.md) | **`sui::bcs`**（与 `std::bcs` 配合） |
| 11.13 | [密码学与哈希](13-cryptography-and-hashing.md) | **`crypto/*`、哈希、签名** |
| 11.14 | [链上随机数](14-randomness.md) | **`sui::random`** |

---

## 与其它章的衔接

- **对象与存储 API**：[第九章 · 对象模型](../09_object_model/00-index.md)、[第十章 · 使用对象](../10_using_objects/00-index.md)  
- **内部约束与 `emit`**：[第十章 §10.5](../10_using_objects/05-internal-constraint.md)  
- **设计模式（OTW、Capability）**：[第十三章](../13_patterns/00-index.md)  
- **代币与 NFT 实战**：[第十五](../15_tokens/00-index.md)、[第十六](../16_nft_kiosk/00-index.md)  

---

## 学习目标

读完本章后，你将能够：

- 正确使用 **`TxContext`**，并理解 **`init` 与 OTW** 在发布流程中的角色  
- 发出符合验证器要求的 **事件**，并理解其与链下索引的关系  
- 区分 **Epoch / `Clock` / `Random`** 的语义与适用场景  
- 在 **`VecMap`/`VecSet`** 与 **`Table`/`Bag`/…** 之间做**存储选型**（并与 §12.1 对照表一致）  
- 使用 **动态字段与动态对象字段** 扩展对象；在合适场景使用 **派生对象**  
- 操作 **`Balance`/`Coin`**，并了解 **BCS** 与 **密码学模块** 的常见用法  

---

## 本章实战练习

动手任务见 **[hands-on.md](hands-on.md)**；示例代码见 **[code/README.md](code/README.md)**。
