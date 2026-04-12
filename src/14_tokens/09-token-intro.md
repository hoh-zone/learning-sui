# Closed-Loop：Token 与 Coin 对照

## 导读

**`sui::token::Token<T>`** 实现 **闭环代币**：与 **`Coin<T>`** 共用同一 **`TreasuryCap<T>`** 与供应，但 **`Token` 只有 `key`，没有 `store`**——**不能**像 `Coin` 那样任意 `public_transfer` 到任意模块组合；**转账、销毁、与 Coin 互转** 都要产生 **`ActionRequest`**，并由 **`TokenPolicy<T>`** 校验 **规则（Rules）** 是否满足。

Framework 中的对应关系（摘自 `token.move` 文件头注释）：

| 模块 | 主类型 | 能力 | 典型能力对象 |
|------|--------|------|----------------|
| `sui::balance` | `Balance<T>` | `store` | `Supply`（经 Treasury） |
| `sui::coin` | `Coin<T>` | `key + store` | `TreasuryCap<T>` |
| `sui::token` | `Token<T>` | **`key` 仅** | `TreasuryCap<T>` + **`TokenPolicy<T>`** |

- **前置**：[§14.4 · TreasuryCap](04-treasury.md)  
- **后续**：[§14.10 · TokenPolicy 与规则](10-token-policy.md)  

---

## 何时用 Coin，何时用 Token

| 需求 | 更合适的模型 |
|------|----------------|
| 上 DEX、通用钱包转账、组合进任意 PTB | **`Coin<T>`**（开放环路） |
| 游戏积分、许可制转账、必须经模块审批的销毁/兑换 | **`Token<T>`** + **`TokenPolicy`** |

## 最小概念：保护型转账

`token::transfer` 会先把 **`Token`** 转给接收方，再构造 **`ActionRequest`**（`"transfer"` 动作）。**必须**在后续步骤里用 **`TokenPolicy`** 调用 **`confirm_request`**（并视情况为 **`ActionRequest`** 集齐 **Rule** 所需的 **`approvals`**），交易在链上才构成完整的「策略认可的转账」。具体配置见 [§14.10](10-token-policy.md)。

## 与 Coin 的互转（需策略允许）

- **`to_coin`**：`Token` → `Coin`，并产生 **`"to_coin"`** 的 `ActionRequest`。  
- **`from_coin`**：`Coin` → `Token`，并产生 **`"from_coin"`** 的 `ActionRequest`。

二者都用于 **桥接开放环路 / 闭环**，例如在 **合规出口** 才把 Token 换成 Coin。

## spend 与 Treasury 的衔接

**`spend`** 会销毁 **`Token`** 对象，把 **`Balance<T>`** 放入 request；确认后余额进入 **`TokenPolicy.spent_balance`**，需 **`TreasuryCap` 持有者** 通过 **`flush`**（见 Framework）把供应层面销账。适合 **游戏内消耗、购票销毁** 等。

## 小结

**Token = 带策略的余额载体**；**TokenPolicy = 共享的规则表**。下一节专门讲 **如何配置 `allow`、自定义动作与 Rule**。
