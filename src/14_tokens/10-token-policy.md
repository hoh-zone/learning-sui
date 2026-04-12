# TokenPolicy：动作、规则与确认

## 导读

**`TokenPolicy<T>`** 是 **`key`** 对象，创建后需 **`token::share_policy`** **共享**到链上；**`TokenPolicyCap<T>`** 用于 **管理员** 配置 **允许的动作名** 与 **每种动作要满足的 Rule 类型集合**。用户执行 **`transfer` / `spend` / `to_coin` / `from_coin`** 时得到 **`ActionRequest<T>`**，只有 **`confirm_request`** 或 **`confirm_request_mut`**（用于带 `spent_balance` 的 `spend`）成功，交易才符合协议设计。

- **前置**：[§14.9](09-token-intro.md)  
- **后续**：[§14.12 · 综合经济](12-game-economy.md)  

---

## 创建与共享策略

```move
use sui::token::{Self, TokenPolicy, TokenPolicyCap};
use sui::coin::TreasuryCap;

public fun setup_policy<T>(
    treasury: &TreasuryCap<T>,
    ctx: &mut TxContext,
): TokenPolicyCap<T> {
    let (policy, cap) = token::new_policy(treasury, ctx);
    token::share_policy(policy);
    cap
}
```

## 内置动作名（常量）

与 Framework 一致（见 `token.move`）：

- **`transfer`** — 已把 `Token` 转给 `recipient`，需策略认可。  
- **`spend`** — 销毁 `Token`，余额进入 policy 的 **spent** 池。  
- **`to_coin` / `from_coin`** — 与 `Coin` 互转。

自定义动作可用 **`token::new_request`** 构造扩展流程（需在同一模块内与 policy 的 `rules` 对齐）。

## 允许动作：allow

管理员可对某动作调用 **`allow`**，使该动作 **无需 Rule 盖章**即可确认（适合测试或完全开放的测试网积分）。生产环境通常 **关闭 allow**，改为挂载具体 **Rule**（例如仅某 `Package` 模块可盖章）。

## Rule 与 `add_approval`

每个 **Rule** 是一个 **模块定义的类型**，在 **`confirm_request`** 路径里检查 **`ActionRequest.approvals`** 是否包含策略要求的 **`TypeName` 集合**。典型扩展方式：

1. 实现自定义 **`Rule`** 模块，暴露 **`prove`** 或类似函数，在 **`ActionRequest`** 上 **`add_approval`**（API 以 `token.move` 为准）。  
2. **`TokenPolicyCap`** 持有者在 **`add_rule_for_action`** 中注册 **动作名 → 允许的 Rule 类型集合**。

## `confirm_request` vs `confirm_request_mut`

- **`confirm_request`**：用于 **没有** `spent_balance` 的请求（如 `transfer`、`to_coin`、`from_coin` 的确认路径）。  
- **`confirm_request_mut`**：用于 **`spend`** 等会把余额写入 **`TokenPolicy.spent_balance`** 的动作。

## 小结

设计闭环经济时，先列出 **允许的业务动作**，再为每个动作选择 **开放（allow）** 或 **Rule 组合**；与开放 **`Coin`** 的互转务必单独审计 **to_coin / from_coin** 路径。下一节回到 **协议层 Accumulator** 与 **`settled_funds_value`**。
