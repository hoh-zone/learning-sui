# Accumulator：协议层聚合与 `settled_funds_value`

## 与 §15.7 的关系

[§15.7](07-funds-accumulator.md) 从**用户与产品口径**说明 **`public_transfer` 与 `send_funds` 的两套余额视图**。**本节不重复该辨析**，只补充 **实现层**（**`AccumulatorRoot`**、**u128**、**`settled` 快照**、**`Withdrawal`**），供读源码或做索引/风控时对照。

## 本节要回答的问题

- **`balance::send_funds` 写入的聚合** 存在哪里、为何需要 **u128**？  
- **`AccumulatorRoot`** 与 **`funds_accumulator::redeem`** 如何配合？  
- **`settled_funds_value`** 的 **「settled」** 指什么时刻的快照？

**前置**：[§15.7](07-funds-accumulator.md)。  
**后续**：[§15.13](13-balance-vault-patterns.md)。

---

## 数据流（实现备忘）

与 §15.7 一致的链路如下（详见 `coin.move` / `balance.move`）：

```text
Coin → into_balance → Balance → balance::send_funds(addr) → 地址聚合
Withdrawal<Balance<T>> → balance::redeem_funds → Balance → into_coin → Coin
```

---

## 为何需要 `AccumulatorRoot`

**`sui::accumulator`** 模块维护 **根对象 `AccumulatorRoot`**，在内部以 **动态字段** 等方式挂载 **按地址、按类型的聚合值**。  
对 **`Balance<T>`** 的累加可能超过 **`u64` 单次操作语义** 的朴素假设，因此聚合单元使用 **u128** 等更宽类型防止 **累加溢出**（见模块内 **`U128`** 与注释）。

**公开只读接口** 例如 **`balance::settled_funds_value<T>(root, address)`**：读取 **当前共识 commit 边界上** 已结算的聚合值（注释说明读取的是 **commit 开始时刻** 的快照语义）。  
**用途**：索引器、风控、链上定价模块；**必须与产品说明「settled 含义」一致**。

---

## `Withdrawal` 的设计意图

**`Withdrawal<T: store>`** 携带 **`owner`** 与 **`limit`**（**u256**），在 **赎回** 时由 **`funds_accumulator::redeem`** 与内部 **`Permit`** 协作，把价值从聚合中划出。  
**`split` / `join`** 用于 **拆分额度** 与 **合并多笔**，便于 **PTB 组合**。

---

## 与 Owner `Coin` 的边界（再强调）

| 视图 | 含义 |
|------|------|
| **地址下 `Coin` 对象列表** | **对象模型** 下的持有 |
| **`settled_funds_value` 等** | **协议层地址资金** 视图 |

**同一地址可以同时存在两种口径**；**禁止**在不经说明的情况下相加或混展示。

---

## 常见误区

1. **把 Accumulator 当成「用户余额表」唯一真相**：业务若只用 **`Coin`**，则 **无** 聚合项；**若混用**，需 **产品定义**。  
2. **忽略 `settled` 时刻**：用于风控时若需要 **实时**，要另设链下或合约内缓存策略。  
3. **在 AMM 池里错误调用 `send_funds`**：池子应使用 **自定义 `Balance`**（§15.13）。

---

## 小结

**Accumulator 提供「地址维度的、可结算的聚合读数」**；**`Coin` 提供「可转移的对象证据」**。下一节：**游戏/双币** 综合；再下一节：**嵌入式 `Balance` 金库**。
