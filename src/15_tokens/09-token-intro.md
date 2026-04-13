# 闭环 Token：与 `Coin` 共用供应、不同载体

## 本节要回答的问题

- **`Token<T>`** 与 **`Coin<T>`** 在 **能力（abilities）** 上差了什么，为什么这一差带来「策略闸」？  
- **`TreasuryCap`** 如何同时服务 **`Coin` 与 `Token`**？  
- **`transfer` + `ActionRequest`** 在同一笔交易里如何 **原子完成**？

**前置**：[§15.4](04-treasury.md)。  
**后续**：[§15.10 · TokenPolicy](10-token-policy.md)。

---

## 原理：同一供应，两种载体

`sui::token` 模块头注释给出清晰对照：

| 模块 | 主类型 | 能力 |
|------|--------|------|
| `sui::balance` | `Balance<T>` | `store` |
| `sui::coin` | `Coin<T>` | `key + store` |
| `sui::token` | `Token<T>` | **`key` 仅（无 `store`）** |

**无 `store`** 意味着：**`Token` 不能像普通 `Coin` 那样作为任意 `store` 结构体的字段长期嵌入**（组合方式受限），从而 **迫使** 与 **`TokenPolicy`** 协作完成敏感操作。

**`Token<T>`** 内部仍包 **`Balance<T>`**；**`TreasuryCap<T>`** 仍可 **`mint` / `burn`**（与 `Coin` 路径共用供应账本，具体 API 见 `token.move` 中与 **`TreasuryCap`** 协作的函数）。

---

## 保护型动作如何闭环

以 **`token::transfer`** 为例（语义概要）：

1. 将 **`Token`** 对象 **转移** 给 **`recipient`**（对象所有权变更）；  
2. 构造 **`ActionRequest`**，动作名为 **`transfer`**，带 **金额、发送者、接收者** 等字段；  
3. 必须在同一交易（或你设计的可组合流程）中调用 **`TokenPolicy`** 的 **`confirm_request`**（并满足 **rules** 与 **approvals**），否则 **策略上** 不应视为「合规完成」——具体是否 **`abort`** 取决于你是否在模块里把 **`confirm`** 与 **`transfer`** 绑在同一 **`public` 函数** 中。

**精髓**：**闭环不是「不能转」**，而是 **「转 + 策略确认」绑定**；与 **`Coin`** 的 **默认可组合** 形成对比。

---

## 内置动作（与策略表对齐）

Framework 为常见业务定义动作标签（如 **`transfer`、`spend`、`to_coin`、`from_coin`**，见 `token.move` 中常量）。  

- **`spend`**：销毁 **`Token`**，将 **`Balance`** 放入 request，后续经 **`confirm_request_mut`** 把价值记入 **`TokenPolicy.spent_balance`**，再由 **`TreasuryCap` 侧 `flush`** 等路径销账（**供应层**与 **策略层** 分工见源码）。  
- **`to_coin` / `from_coin`**：与 **`Coin`** 互转，用于 **合规出口、活动期兑换** 等。

---

## 何时选 `Coin`，何时选 `Token`

| 目标 | 倾向 |
|------|------|
| DEX、通用钱包、任意 PTB 组合 | **`Coin`** |
| 积分、许可商城、必须审计的销毁路径 | **`Token` + `TokenPolicy`** |

---

## 常见误区

1. **以为 `Token` 不能转账**：对象仍可 **`transfer`**；关键是 **策略是否确认**。  
2. **把 `Token` 当 `Coin` 做 `store` 嵌套**：能力不允许时需改设计（例如用 **`Balance` + 自定义规则** 或 **`Coin`**）。  
3. **忽略 `spent_balance` 与 `Treasury` 的衔接**：**`spend`** 路径涉及 **mutable 确认** 与 **供应核销**，需读完整 **`confirm_request_mut` / `flush`** 文档。

---

## 小结

**`Token` = 策略强制参与的余额载体**；**`TokenPolicy` = 链上共享的规则表**。下一节专门讲 **如何配置策略与 Rule**。
