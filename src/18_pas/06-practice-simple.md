# 实战一：简单合规代币（限额与禁止地址）

本实战基于 PAS 仓库中的 [demo_usd](https://github.com/MystenLabs/pas/blob/main/packages/testing/demo_usd/sources/demo_usd.move)，实现一个「简单合规」的 PAS 代币：单笔转账金额上限、禁止自转、以及（在 V2 中）禁止向某地址转账。

## 依赖与入口

- **依赖**：`pas`、`ptb`、`sui`（含 `coin_registry`、`balance`、`clock` 等）。
- **init**：用 `coin_registry::new_currency_with_otw` 注册货币，并 `share_object(Faucet { cap, metadata, policy_cap: none() })`。
- **entry setup**：入参 `namespace: &mut Namespace`、`templates: &mut Templates`、`faucet: &mut Faucet`；内部创建 Policy、注册 Command、`policy.share()`。

## 目标

- 使用 PAS 的 Chest + Policy + Request 模型；
- 在 **approve_transfer** 中实现：金额 &lt; 10K、sender ≠ recipient、V2 中 recipient ≠ 0x2；
- 通过 **setup** 注册 Policy 与 Templates Command，便于 SDK 解析。

## 核心代码要点

### 1. 代币与 Faucet

- 用 **coin_registry** 注册 `DEMO_USD` 货币（精度 6、名称/描述等），得到 `TreasuryCap` 与 `MetadataCap`。
- **Faucet** 持有 `cap`、`metadata` 和可选的 `policy_cap`；`faucet_mint_balance` 用于测试时铸造余额。

### 2. 审批类型

- **TransferApproval**：V1 解析用；
- **TransferApprovalV2**：V2 解析用（演示升级后切换审批逻辑）；
- **UnlockApproval**：若需解锁到链上，可在此模块实现 `approve_unlock` 并注册。

### 3. approve_transfer（V1）与接口使用

解析函数签名需与 Command 中注册的 `move_call` 一致（参数顺序、类型）：

```move
public fun approve_transfer<T>(request: &mut Request<SendFunds<Balance<T>>>, _clock: &Clock) {
    let data = request.data();
    assert!(send_funds::funds(data).value() < 10_000 * 1_000_000, EInvalidAmount);
    assert!(send_funds::sender(data) != send_funds::recipient(data), ECannotSelfTransfer);
    request.approve(TransferApproval());
}
```

- **request.data()** 得到 `&SendFunds<Balance<T>>`，用 **send_funds::sender/recipient/funds** 取字段；**funds().value()** 为金额（6 位精度下 10K = 10_000 * 1_000_000）。
- 禁止 sender == recipient。
- 通过则 **request.approve(TransferApproval())**，与 Policy 的 `required_approvals["send_funds"]` 一致后，同一 PTB 中可调用 **send_funds::resolve_balance(request, policy)** 完成转账。

### 4. approve_transfer_v2（V2）

- 仅校验 `request.data().recipient() != @0x2`（禁止向 0x2 转账）；
- `request.approve(TransferApprovalV2())`。
- 通过 **use_v2** 将 Policy 的 send_funds 改为需要 TransferApprovalV2，并更新 Templates 中对应 Command，实现「升级后规则变更」。

### 5. setup

- `policy::new_for_currency(namespace, &mut faucet.cap, true)`：创建 Policy 与 PolicyCap，`clawback_allowed = true`。
- `policy.set_required_approval<_, TransferApproval>(&cap, "send_funds")`：send_funds 需要 TransferApproval。
- 构造 `ptb::move_call(..., "approve_transfer", [request, clock], type_args)`，用 **templates.set_template_command(permit<TransferApproval>(), cmd)** 注册，便于 SDK 根据 Request 类型自动构造解析 PTB。

## 流程小结

1. 用户发起 `chest::send_balance(from_chest, auth, to, amount, ctx)`，得到 `Request<SendFunds<Balance<DEMO_USD>>>`。
2. 同一 PTB 中调用 `demo_usd::approve_transfer(request, clock)`，通过则 `request.approve(TransferApproval())`。
3. 调用 `send_funds::resolve_balance(request, policy)`，完成 Chest → Chest 转账。
4. 若升级到 V2，管理员调用 **use_v2** 后，解析改为 `approve_transfer_v2`，规则变为「仅禁止转给 0x2」。

此实战展示了：**限额、自转校验、禁止某地址** 均可放在发行方自己的 `approve_*` 里，与 PAS 的 Request/Policy 无缝配合。
