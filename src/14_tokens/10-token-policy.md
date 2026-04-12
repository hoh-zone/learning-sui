# TokenPolicy：动作表、Rule 与确认函数

## 本节要回答的问题

- **`TokenPolicy` 为什么要 `share_object`**？  
- **`allow` 与「挂载 Rule」** 的差别是什么？  
- **`confirm_request` 与 `confirm_request_mut`** 分别在什么动作上必须使用？

**前置**：[§14.9](09-token-intro.md)。  
**后续**：[§14.12](12-game-economy.md)。

---

## 创建与发布策略

```move
use sui::coin::TreasuryCap;
use sui::token::{Self, TokenPolicy, TokenPolicyCap};

public fun setup<T>(
    treasury: &TreasuryCap<T>,
    ctx: &mut TxContext,
): TokenPolicyCap<T> {
    let (policy, cap) = token::new_policy(treasury, ctx);
    token::share_policy(policy);
    cap
}
```

**`new_policy` 要求传入 `&TreasuryCap`**：用 **铸币权的唯一性** 证明 **你有权为该类型定义策略**。  
**`share_policy`** 发出事件并 **共享 `TokenPolicy`**，使任意用户在执行 **`confirm_*`** 时可传入 **`&TokenPolicy`**。

---

## 动作表：`rules` 里存什么

**`TokenPolicy`** 内含 **`VecMap<String, VecSet<TypeName>>`**：**动作名 → 一组 Rule 类型**（以 **`TypeName`** 标识模块里的 **Rule** 实现）。

- **`allow(action)`**：对该动作 **关闭 Rule 校验**（测试网或完全开放积分常用）；**主网生产** 往往改为 **显式 Rule**。  
- **`add_rule_for_action`**：为某动作 **增加** 必须满足的 **Rule 类型**；**`confirm_request`** 时会检查 **`ActionRequest.approvals`** 是否覆盖策略要求。

**精髓**：**策略 = 白名单动作集合 × 每动作一组可接受的 Rule「签章」类型**。

---

## `ActionRequest` 与 `add_approval`

自定义 **Rule 模块** 在验证业务条件后，对 **`ActionRequest`** 调用 **`add_approval`**（API 以 `token.move` 为准），填入 **`approvals`**。**`confirm_request`** 再比对 **`TokenPolicy.rules`** 是否全部满足。

---

## 两种确认函数

| 函数 | 适用 |
|------|------|
| **`confirm_request`** | **`spent_balance` 为空** 的请求（如 **`transfer`**、部分 **`to_coin` / `from_coin`** 路径）。 |
| **`confirm_request_mut`** | 含 **`spent_balance`** 的 **`spend`** 等，需要 **写入 `TokenPolicy.spent_balance`**。 |

误用会导致 **`EUseImmutableConfirm`** 等错误（见 **`token.move`**）。

---

## 常见误区

1. **只 `transfer` 不 `confirm`**：若你的 **`public` 入口** 把两步拆开，可能留下 **策略未认可** 的中间状态；生产应 **单函数封装** 或 **强制同一 PTB**。  
2. **以为 `allow` 适合主网默认**：等价于 **关闭 Rule 闸**，需治理明确授权。  
3. **自定义动作名与 `rules` 不同步**：**`new_request`** 构造的请求名必须在 **`TokenPolicy`** 里 **事先注册** 对应规则。

---

## 小结

**`TokenPolicy` 是闭环经济的「宪法」**；**`TokenPolicyCap` 是修宪钥匙**。配置完成后，务必审计 **`to_coin` / `from_coin`** 与 **`spend` / `flush`** 全路径。下一节：**Accumulator 与 `settled_funds_value`**。
