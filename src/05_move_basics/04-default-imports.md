# 默认导入的包与预置名称

上一节学习了**显式** `use`。在 Sui Move 中，编译器还会注入一层 **Prelude（预导入）**：部分模块与类型**无需写 `use` 即可使用**。若再手动 `use` 同名模块，会触发 **`duplicate alias`** 类警告。本节说明预导入里有什么、哪些仍须手写 `use`，并区分「编译期预导入」与「链上固定地址上的包 / 对象」。

## 为什么需要 Prelude

合约里几乎总会用到 `object::new`、`transfer::public_transfer`、`TxContext` 等。若每个文件都重复：

```move
use sui::object;
use sui::transfer;
use sui::tx_context::TxContext;
```

既冗长又易与编译器内建别名冲突。因此 Sui 工具链为 **Move 2024 Edition** 提供了预导入集合（具体列表以当前 `sui move build` 为准，随版本可能微调）。

## 常见预导入模块与类型

下表为**日常编写中最常遇到的**、往往可直接写 `object::`、`transfer::`、`tx_context::` 的原因（不必再为模块名单独 `use`）：

| 预置可用（示例） | 典型用途 |
|------------------|----------|
| `sui::object` | `object::new`、`UID`、`ID` |
| `sui::transfer` | `transfer::public_transfer`、其它转移 API |
| `sui::tx_context` | `TxContext`、`ctx.sender()` 等 |
| `std::vector` | `vector[]`、向量字面量与相关运算 |
| `std::option` | `Option`、`some`、`none` |

> **提示**：若你显式写了 `use sui::object;` 而编译器提示 **Unnecessary alias / duplicate alias**，说明该项**已在 Prelude 中**，可删去多余的 `use` 以消除警告。

## 仍须显式 `use` 的常见项

下列在多数模块中**不会**预导入，需按上一节方式自行 `use`：

- **`std::string::String`**、**`std::ascii::String`** 等字符串类型  
- **`sui::coin`**、**`sui::sui::SUI`**、**`sui::balance`** 等与代币相关的模块  
- **`sui::event`**、**`sui::clock::Clock`**、**`sui::table::Table`** 等按业务再引入  

编写时以 **`sui move build`** 报错为准：若提示 **未解析的名称**，补一条 `use` 即可。

## 「链上的包地址」≠ Prelude

- **Prelude** 是**编译器在源码里**帮你展开的命名空间，解决的是「少写 `use`」。
- 链上 **`0x1`、`0x2`** 等是**已发布包**的地址（Move 标准库、Sui Framework 等），与「是否预导入」是不同层面的事；详见[第四章 · 地址](../04_concepts/03-address.md)与[附录 B · 保留地址](../appendix/02-reserved-addresses.md)。

## 系统对象（共享对象）简表

部分能力需要在函数参数中传入**系统共享对象**的引用，例如：

| 对象 | 典型地址（各环境一致） | 说明 |
|------|------------------------|------|
| **Clock** | `0x6` | 链上时间，见[第十二章 · Epoch 与时间](../12_programmability/05-epoch-and-time.md) |
| **Random** | `0x8` | 随机数，见[第十二章 · 链上随机数](../12_programmability/14-randomness.md) |

调用这些函数时，通常通过 **`sui::clock::Clock`** 等类型与 **`entry`** / **`public`** 函数参数由运行时注入，**不是** Prelude 替你导入「整个对象」，而是**类型定义**仍来自 `sui::clock` 等模块——多数情况需要 **`use sui::clock::Clock`**。

## 与 `Move.toml` 隐式依赖的关系

Sui CLI **1.45+** 对 Framework 的**隐式 `[dependencies]`** 与 Prelude 是互补关系：前者让 **`sui::...` / `std::...` 包能链接到链上对应字节码**；后者让你在**源码里**少写 `use`。Edition 与依赖写法见[第六章 §6.11 · Move 2024 Edition](../06_move_intermediate/11-move-2024.md)。

## 小结

- **Prelude**：编译器预导入的一批模块（如 `object`、`transfer`、`tx_context`，以及常用的 `vector` / `option` 等），可直接使用其路径或类型。  
- **重复 `use`**：易触发 **duplicate alias** 警告，删除多余导入即可。  
- **多数业务模块**（`string`、`coin`、`event` 等）仍需**显式 `use`**。  
- **0x1 / 0x2 / 系统共享对象 ID** 描述的是**链上部署与运行时对象**，与 Prelude 概念不同；系统对象详见后文章节与附录 B。
