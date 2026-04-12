# 本章导论：从 Balance 到代币地图

## 导读

本章在 [第十一章 §11.11 · Balance 与 Coin](../11_programmability/11-balance-and-coin.md) 的基础上，把 **`Balance<T>`、`Coin<T>`、`Supply<T>`、`TreasuryCap<T>`** 放进**发币与运营**的完整故事里。建议先确保理解：**`Coin` 是带 `UID` 的可转移包装**，**`Balance` 是嵌入对象的纯数值**，**`TreasuryCap` 持有 `Supply` 才能铸/销**。

- **后续**：[§14.2](02-registry-otw.md) 起按「注册 → 元数据 → 金库 → 持有物操作 → 资金流 → 合规 → 闭环 Token → 协议层 Accumulator → 综合实战」阅读。  

---

## 三条「钱」的形态

| 形态 | 类型（典型） | 能否单独当对象转移 | 说明 |
|------|----------------|----------------------|------|
| 裸余额 | `Balance<T>` | 否（`store`，须包在对象或 `Coin` 里） | 轻量，适合 `Coin` 内部或自定义结构体字段 |
| 硬币对象 | `Coin<T>` | **能**（`key + store`） | **Owner Coin**：用户钱包里常见的一枚枚 `Coin` |
| 总供应 | `Supply<T>`（经 `TreasuryCap`） | `TreasuryCap` 为对象 | 铸造/销毁改 `Supply` |

**Open-loop（开放环路）** 指 **`Coin<T>`** 标准路径：有 `store`，可 `public_transfer`，与 DeFi、钱包兼容性好。

**Closed-loop（闭环）** 指 **`Token<T>`**（`sui::token`）：**无 `store`**，转移/消费需 **`TokenPolicy`** 确认——适合积分、游戏币、强合规场景。见 [§14.9](09-token-intro.md)、[§14.10](10-token-policy.md)。

---

## 「共享」与「自有」在注册层面的含义

- **自有（Owner）**：用户地址持有的 **`Coin<T>`** 对象；你可 **`split` / `join`** 调整额度（见 [§14.5](05-owner-coin.md)）。  
- **共享（Shared）**：**`CoinRegistry`** 链上单例里注册的 **`Currency<T>`** 元数据对象——**人人可查**，不是某个人兜里的钱，而是**类型级登记簿**。见 [§14.2](02-registry-otw.md)、[§14.6](06-shared-currency.md)。

勿把「共享 Coin」误解成「大家分同一枚 `Coin`」——共享的是**注册信息与元数据**，**余额仍在各地址下的 `Coin`/`Balance` 里**。

---

## 本章路线图（与模块对应）

| 主题 | Framework 模块（节选） | 本书节 |
|------|------------------------|--------|
| 注册与 OTW | `coin_registry` | [§14.2](02-registry-otw.md) |
| 元数据 | `Currency` / `MetadataCap` | [§14.3](03-coin-metadata.md) |
| 铸造与供应 | `coin::mint` / `burn`，`TreasuryCap` | [§14.4](04-treasury.md) |
| 持币操作 | `coin::split` / `join`，`pay` | [§14.5](05-owner-coin.md) |
| 注册表查询 | `CoinRegistry` 共享对象 | [§14.6](06-shared-currency.md) |
| 地址级资金流 | `send_funds` / `redeem_funds` | [§14.7](07-funds-accumulator.md) |
| 合规 | `DenyList`，`DenyCapV2` | [§14.8](08-regulated-denylist.md) |
| 闭环 | `token::Token`，`TokenPolicy` | [§14.9](09-token-intro.md)、[§14.10](10-token-policy.md) |
| 协议 Accumulator | `accumulator` / `funds_accumulator` | [§14.11](11-accumulator-protocol.md) |
| 综合 | 双币、积分 | [§14.12](12-game-economy.md) |
| 嵌入式 Balance | 金库、池 | [§14.13](13-balance-vault-patterns.md) |
| 运维与说明 | 权限、epoch、CoinLock | [§14.14](14-operations-and-notes.md) |

> API 以当前 Sui Framework 源码为准；本书示例侧重**概念与模式**，升级迁移时请以官方 Release 说明为准。

---

## 小结

先建立 **Balance / Coin / TreasuryCap / Token** 的分工，再进入注册与元数据；**Owner Coin** 操作与 **共享 Currency 元数据** 是不同层次的问题。下一节从 **OTW + `coin_registry`** 开始创建类型。
