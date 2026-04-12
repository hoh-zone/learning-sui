# 共享 Currency：CoinRegistry 与链上可查性

## 导读

**「Share」在本节**指 **`Currency<T>`** 作为 **全局注册表** 的一部分被 **`share`**（具体初始化在 **`coin_registry::finalize`** 内完成），**不是**指把用户的 **`Coin<T>`** 变成共享对象。任何人可按类型 **`T`** 在 **`CoinRegistry`** 中解析 **元数据、供应状态标记**（regulated 等），钱包与浏览器依赖这一点。

- **前置**：[§14.2](02-registry-otw.md)、[§14.3](03-coin-metadata.md)  
- **后续**：[§14.7](07-funds-accumulator.md)  

---

## CoinRegistry 单例

链上存在 **`CoinRegistry`** 共享对象，登记每种 **`Currency<T>`** 的：

- 展示字段（名、符号、精度、图标）  
- 供应策略状态（是否已固定、是否 regulated 等，以类型为准）

**部署者**在 `init` 里 **`finalize`** 时，把 **`Currency<T>`** 挂入注册表——之后**全链可读**。

## 与 Owner Coin 的对比

| 概念 | 是否共享 | 持有者 |
|------|----------|--------|
| **`Currency<T>`**（元数据/类型登记） | 是，逻辑上由注册表索引 | 网络公共知识 |
| **`Coin<T>`**（一笔余额） | 否，**拥有型对象** | 某 `address` |

## 查询路径（概念）

应用与索引器通常：

1. 已知 **`T`** 的 **类型布局**（包地址 + 模块 + 结构名）；  
2. 调 RPC / GraphQL 读 **`CoinRegistry`** 与 **`Currency<T>`**；  
3. 再结合 **`Coin` 对象** 的 **`owner`** 字段展示余额。

具体查询字段名随 **Sui 版本** 更新，请以官方 JSON-RPC / GraphQL 文档为准。

## 小结

**共享**的是 **类型级元数据与注册状态**；**私有**的是 **各地址下的 Coin 对象**。下一节讲 **地址级余额与 `send_funds`**，衔接 **Accumulator** 语境。
