# 第十四章 · 代币经济

本章从 **`Balance` / `Coin` / `TreasuryCap`** 出发，按 **注册表与元数据 → 铸造策略 → Owner Coin 操作 → 共享 `Currency` 与地址资金流 → 合规 DenyList → 闭环 `Token` 与 `TokenPolicy` → Accumulator 协议 → 综合经济模型 → 金库模式与运维** 的顺序组织，便于对照官方 `sui-framework` 模块阅读。

## 本章内容

| 节 | 文件 | 主题 |
|----|------|------|
| 14.1 | [本章导论](01-overview.md) | Balance / Coin / Token、开放环路与闭环、路线图 |
| 14.2 | [注册与 OTW](02-registry-otw.md) | `coin_registry::new_currency_with_otw`、`finalize` |
| 14.3 | [Coin 元数据](03-coin-metadata.md) | `MetadataCap`、decimals、展示字段 |
| 14.4 | [TreasuryCap](04-treasury.md) | 铸/销、固定供应、burn-only |
| 14.5 | [Owner Coin](05-owner-coin.md) | `split` / `join`、`pay`、与 `Balance` 互转 |
| 14.6 | [共享 Currency](06-shared-currency.md) | `CoinRegistry`、类型级登记与查询 |
| 14.7 | [地址资金流](07-funds-accumulator.md) | `send_funds`、`redeem_funds`、`Withdrawal` |
| 14.8 | [受监管与 DenyList](08-regulated-denylist.md) | `make_regulated`、`DenyCapV2`、黑名单 |
| 14.9 | [Token 入门](09-token-intro.md) | 闭环 `Token` vs `Coin`、动作请求 |
| 14.10 | [TokenPolicy](10-token-policy.md) | 共享策略、`allow`、Rule、`confirm_request` |
| 14.11 | [Accumulator 协议](11-accumulator-protocol.md) | `AccumulatorRoot`、`settled_funds_value` |
| 14.12 | [游戏与双币](12-game-economy.md) | 主币 + 积分、兑换与金库 |
| 14.13 | [嵌入式 Balance](13-balance-vault-patterns.md) | 奖池、与 `send_funds` 区分 |
| 14.14 | [运维与说明](14-operations-and-notes.md) | 权限、epoch、CoinLock 说明 |

## 学习目标

读完本章后，你将能够：

- 用 **`coin_registry` + OTW** 创建可注册的 **`Coin`** 类型并完成 **元数据与 Treasury** 初始化  
- 区分 **Owner `Coin`**、**共享 `Currency` 元数据**、**地址级 accumulator 资金**  
- 在需要合规时接入 **`DenyList` / `DenyCapV2`**  
- 为强约束场景选择 **`Token` + `TokenPolicy`**，并理解 **`ActionRequest`** 流程  
- 在应用层用 **嵌入式 `Balance`** 实现金库与池子  

## 实战

见 [本章实战练习](hands-on.md)；示例包见 `src/14_tokens/code/silver_coin/`。
