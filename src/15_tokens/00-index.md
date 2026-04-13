# 第十五章 · 代币经济

本章系统讲解 Sui 上与 **同质化代币** 相关的完整工具链：从 **`coin_registry` 与 OTW** 创建可登记币种，到 **`TreasuryCap` 与总供应**、**`Coin` 与 `Balance` 的分工**、**全局 `CoinRegistry` 与合规 DenyList**、再到 **闭环 `Token` 与 `TokenPolicy`**，以及 **协议层地址资金（accumulator）** 与 **应用层金库模式**。

**与第十二章 §12.11 的分工**：§12.11 讲 **`Balance` / `Coin` / `TreasuryCap` 的 API 与金库模式**；**本章不再重复** 长段 **`new_currency_with_otw` 全例**（已集中在 §15.2 与 `silver_coin`）。两章应 **先后通读**，避免只读其一。

阅读本章后，你应能**在概念上画出一幅「类型—供应—载体—策略」的图**，并能对照 `sui-framework` 模块名定位实现；**具体函数签名与错误码**请以部署目标所依赖的 Framework 版本为准。

## 本章结构

| 节 | 链接 | 核心内容 |
|----|------|----------|
| 14.1 | [本章导论](01-overview.md) | 四层模型、开放/闭环、术语边界 |
| 14.2 | [注册与 OTW](02-registry-otw.md) | `new_currency_with_otw`、`finalize`、`CurrencyInitializer` |
| 14.3 | [元数据与 MetadataCap](03-coin-metadata.md) | `Currency` 字段、`coin_registry` 只读 API、更新与受监管展示 |
| 14.4 | [TreasuryCap 与供应策略](04-treasury.md) | `mint`/`burn`、固定供应、`burn-only` |
| 14.5 | [Owner Coin 操作](05-owner-coin.md) | `split`/`join`、`pay`、与 `Balance` 互转 |
| 14.6 | [CoinRegistry 与 Currency](06-shared-currency.md) | 类型级登记、与「钱包余额」的区分 |
| 14.7 | [地址资金与 send_funds](07-funds-accumulator.md) | 与 `Coin` 转账的差异、`Withdrawal` |
| 14.8 | [受监管与 DenyList](08-regulated-denylist.md) | `make_regulated`、`DenyCapV2`、epoch |
| 14.9 | [Token 与闭环入门](09-token-intro.md) | `Token` vs `Coin`、`ActionRequest` |
| 14.10 | [TokenPolicy 与规则](10-token-policy.md) | `share_policy`、`allow`、Rule、`confirm_request` |
| 14.11 | [Accumulator 与 settled 读数](11-accumulator-protocol.md) | `AccumulatorRoot`、`settled_funds_value` |
| 14.12 | [经济模型综合](12-game-economy.md) | 双币、积分、池子 |
| 14.13 | [嵌入式 Balance 模式](13-balance-vault-patterns.md) | 金库、与 `send_funds` 的取舍 |
| 14.14 | [上线运维与版本](14-operations-and-notes.md) | 权限、升级、常见误解 |

## 学习目标

- 说明 **OTW** 在发币流程中的作用，以及 **`finalize`** 前后链上状态的变化。  
- 解释 **`TreasuryCap`、`Supply`、`Coin`、`Balance`** 在铸币、转账、销毁时的数量关系。  
- 区分 **对象级 `Coin` 余额** 与 **协议层地址资金**，避免产品展示与风控口径混乱。  
- 在需要时选择 **`make_regulated`** 与 **DenyList** 运维流程。  
- 理解 **`Token` + `TokenPolicy`** 的「请求—确认」语义，并与 **`Coin`** 的组合性对比。  

## 实战与代码

- 正文示例与 **`src/15_tokens/code/silver_coin/`** 包对应（`coin_registry::new_currency_with_otw` + `finalize`）。  
- 练习见 [hands-on.md](hands-on.md)。
