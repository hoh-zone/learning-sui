# 版本控制与 Clawback

## 相关接口速查

| 模块 | 函数 / 说明 |
|------|-------------|
| `pas::namespace` | `block_version(namespace, cap, version)`, `unblock_version(namespace, cap, version)`：需先 `setup` 绑定 UpgradeCap |
| `pas::versioning` | `assert_is_valid_version(versioning)`：在 Chest/Policy 操作中由 PAS 内部调用，使用 `breaking_version!()` 宏得到的包版本；若该版本被 block 则断言失败 |
| `pas::chest` / `policy` | `sync_versioning(chest/policy, namespace)`：任何人可调，将对象版本信息与 Namespace 同步，以继续在 block 后使用新版本 |

## Versioning

PAS 的 **Versioning** 与 Namespace 绑定，用于在紧急情况下**阻断**特定包版本，使旧版本无法再参与 Chest/Policy 操作（例如 resolve、send_balance）。Namespace 持有 UpgradeCap 后，管理员可调用：

- `namespace::block_version(namespace, cap, version)`：阻断该版本；
- `namespace::unblock_version(namespace, cap, version)`：解除阻断。

Policy 和 Chest 在关键路径上会调用 `versioning.assert_is_valid_version()`，若当前包版本已被 block，则断言失败，从而强制用户或协议升级到新版本后再与 PAS 交互。这为安全修复或破坏性升级提供了「紧急制动」能力。

## Clawback

**Clawback** 指发行方（或授权方）从某 Chest 中**收回**一定数量代币，通常用于监管要求（如法院令、制裁合规）。PAS 中：

- 只有在**注册 Policy** 时传入 `clawback_allowed = true` 的代币类型才允许 clawback。
- 发行方调用 `chest::clawback_balance(from_chest, amount, ctx)` 生成 `Request<ClawbackFunds<Balance<C>>>`。
- 在同一 PTB 中，发行方提供 Policy 为 `clawback_funds` 动作要求的审批（例如监管 Cap 或内部 witness），然后调用 `clawback_funds::resolve_balance(...)`，将余额转入发行方指定的目标（如 Treasury 或专用 Chest）。

Clawback 一旦在注册时启用，无法通过升级关闭（由 Policy 的 `clawback_allowed` 在创建时确定），因此发行方需要在设计时明确是否接受该能力。

## 小结

- **Versioning**：通过 block_version 禁止旧版本参与 PAS，用于紧急修复或升级。
- **Clawback**：可选功能，仅在 Policy 注册时开启；由发行方发起请求并满足审批后 resolve，将指定 Chest 中的余额收回。
