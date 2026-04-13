# 第十八章实战 · `guarded.move` 威胁建模（参考答案）

| 攻击面 | 说明 | 缓解思路 |
|--------|------|----------|
| 任意构造 `Vault` / `AdminCap` | 若存在 `public fun new_vault` 且未校验，攻击者可伪造金库 | 仅 `init` 或受 `AdminCap` 保护的构造函数创建；敏感结构体避免无约束 `public` 构造 |
| `read_balance` 仅依赖 `&AdminCap` | 若 Cap 可转让，任何持有人可读；未校验 `TxContext::sender` 是否与业务角色一致 | 按需在函数内 `assert!(tx_context::sender(ctx) == expected_admin)`；或不可转让 Cap + 链下流程 |

读者可在此基础上补充「重入」「整数溢出」等项。
