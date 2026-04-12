# 综合示例：游戏经济与双币

## 导读

单游戏常同时需要：**链上可交易的主代币（开放环路 `Coin`）**、**不可出游戏圈的积分（闭环 `Token`）**、以及 **金库对象内嵌的 `Balance`**（奖励池、公会仓库）。本节用 **模式组合** 说明设计要点，避免绑定某一版本的业务合约细节。

- **前置**：[§14.5](05-owner-coin.md)、[§14.9–§14.10](09-token-intro.md)  

---

## 模式一：主币 + 积分

| 资产 | 类型 | 说明 |
|------|------|------|
| **GOLD** | `Coin<GOLD>` | 玩家间交易、上 DEX；`TreasuryCap` 由多签控制铸销 |
| **PTS** | `Token<PTS>` + `TokenPolicy` | 任务奖励；**仅允许** `spend` 在商城模块消费；禁止随意 `to_coin` |

**衔接方式**：活动期可开放 **`from_coin`** 把少量 **GOLD** 换成 **PTS**（需 Rule 限制额度与地址）；退市时 **`to_coin`** 出口需单独审计。

## 模式二：双 Coin 与兑换池

**`Coin<SILVER>`**（书内示例包）与 **`Coin<GOLD>`** 通过 **共享对象 AMM 池** 兑换：池子内部用 **`Balance<SILVER>`** / **`Balance<GOLD>`** 记账（见 [§14.13](13-balance-vault-patterns.md)）。  
注意：**`send_funds`** 与 **AMM 余额** 是不同层次——AMM 通常 **不** 用地址 accumulator，而用 **自定义共享对象** 内的 **`Balance`**。

## 模式三：公会金库与权限

**`GuildVault`** 内含 **`Balance<GOLD>`**，仅 **`GuildCap`** 可 **`coin::take` / `put`**。与 **Owner Coin** 区分：**玩家钱包** 持 **`Coin`**，**公会** 持 **共享对象里的 Balance**。

## 设计检查清单

1. **供应**：无限铸、固定上限、burn-only 是否已在 **`Currency` / Treasury** 层落实？  
2. **合规**：是否需要 **`make_regulated`** 与 **DenyList**？  
3. **闭环**：积分是否必须用 **`Token`**，**TokenPolicy** 是否已 **`share_policy`**？  
4. **资金流**：是否误把 **AMM 余额** 与 **`send_funds` 聚合**混在同一产品口径？

## 小结

**没有单一标准答案**；用 **Coin / Token / 嵌入式 Balance** 三套工具组合出经济模型。实战编译与发布见 [本章 hands-on](hands-on.md)。
