# 请求与解析：SendFunds、UnlockFunds、Clawback

## 请求与解析相关接口速查

| 模块 | 函数 / 类型 | 说明 |
|------|-------------|------|
| `pas::request` | `Request<K>`, `approve<K, U>(request, _approval: U)`, `data<K>(request): &K`, `approvals<K>(request): VecSet<TypeName>` | 热土豆：approve 收集审批，data 取请求体，resolve 时校验 approvals |
| `pas::send_funds` | `SendFunds<T>`, `sender/recipient/sender_chest_id/recipient_chest_id/funds`, `resolve_balance<C>(request, policy)` | 发送请求数据与 resolve：将 balance 转入 recipient_chest_id |
| `pas::unlock_funds` | `UnlockFunds<T>`, `owner/chest_id/funds`, `resolve(request, policy): T`, `resolve_unrestricted_balance<C>(request, namespace): Balance<C>` | 解锁：有 Policy 时用 resolve；无 Policy 时用 resolve_unrestricted_balance |
| `pas::clawback_funds` | `ClawbackFunds<T>`, `owner/chest_id/funds`, `resolve(request, policy): T` | 收回：仅当 Policy 允许 clawback 时可 resolve，返回被收回的 T |

## Request 是什么

在 PAS 中，任何「从 Chest 转出」或「被收回」的操作都会先产生一个 **Request\<K\>**，其中 `K` 是请求数据类型（如 `SendFunds<Balance<C>>`、`UnlockFunds<Balance<C>>`、`ClawbackFunds<Balance<C>>`）。Request 是一个**热土豆**：必须在同一笔交易（PTB）内被 **resolve**，否则交易失败。

- **approvals**：本请求已收集的审批类型集合（TypeName）。
- **data**：请求数据（发送方、接收方、金额、Chest ID 等）。

只有当前请求的 `approvals` 与 Policy 中该动作的 **required_approvals** 完全一致时，才能调用对应请求模块的 **resolve** 消费 Request 并完成余额移动。`request::resolve` 为包内函数，对外暴露的是 `send_funds::resolve_balance`、`unlock_funds::resolve`、`clawback_funds::resolve` 等。

### request 模块接口

- **approve\<K, U: drop\>(request: &mut Request\<K\>, _approval: U)**：向 request 加入审批类型 U（用 `type_name::with_defining_ids<U>()` 记录）。
- **data\<K\>(request: &Request\<K\>): &K**：获取请求体，用于解析函数内读取 sender、recipient、amount 等做业务校验。
- **approvals\<K\>(request: &Request\<K\>): VecSet\<TypeName\>**：当前已收集的审批类型集合（一般由 resolve 内部使用）。

## 三种请求类型

### SendFunds

**发送余额到另一个 Chest**。用户（或协议）调用 `chest::send_balance(from, auth, to, amount, ctx)`：

- 从 `from` Chest 扣减 `amount`，生成 `Request<SendFunds<Balance<C>>>`，其中包含 sender、recipient、sender_chest_id、recipient_chest_id、funds。
- 在 PTB 中需要调用**发行方包**中的「解析函数」，该函数内部对 Request 做业务校验（KYC、白名单、限额等），然后调用 `request.approve(SomeApproval())` 凑齐 Policy 要求的审批类型，最后由 PAS 模块完成 `send_funds::resolve_balance(request, policy)`，将 balance 转入 recipient_chest_id。

**SendFunds 数据访问器**（在解析函数中常用）：

- `send_funds::sender(request.data())` / `send_funds::recipient(request.data())`：发送方、接收方**地址**（非 chest id）。
- `send_funds::sender_chest_id` / `send_funds::recipient_chest_id`：Chest 的 ID。
- `send_funds::funds(request.data())`：`&Balance<C>`，可 `.value()` 取金额。

### UnlockFunds

**将余额从 PAS 体系解锁到链上**（例如变成普通 Coin 或转给非 Chest 地址）。调用 `chest::unlock_balance(chest, auth, amount, ctx)` 会生成 `Request<UnlockFunds<Balance<C>>>`。解析逻辑同样在发行方包中实现，满足 Policy 的 `unlock_funds` 所需审批后，调用 `unlock_funds::resolve(request, policy)` 得到 `Balance<C>`，再由发行方或用户将该 balance 转成 Coin 或做后续处理。

**两种解锁方式**：

- **有 Policy 的资产**：必须用 `unlock_funds::resolve(request, policy): T`，且 Policy 中需配置 `unlock_funds` 的 required_approvals。
- **无 Policy 的资产**（如 SUI）：任何人可调用 `unlock_funds::resolve_unrestricted_balance<C>(request, namespace): Balance<C>`，将余额取回；若该类型存在 Policy 则断言失败。

### ClawbackFunds

**发行方收回某 Chest 中的余额**。仅当该代币类型的 Policy 在注册时设置了 `clawback_allowed = true` 时可用。调用 `chest::clawback_balance(from, amount, ctx)` 生成 `Request<ClawbackFunds<Balance<C>>>`，由发行方在 PTB 中提供 Policy 要求的审批（例如监管授权 witness），然后 `clawback_funds::resolve(request, policy): T` 返回被收回的余额 T（如 `Balance<C>`），发行方再将该 balance 转入自己的 Treasury 或专用 Chest。

## 解析流程简述

1. 用户/前端发起「转账」或「解锁」：构造 PTB，其中一步调用 `chest::send_balance` 或 `chest::unlock_balance`，得到未完成的 Request。
2. 同一 PTB 中，必须再调用**发行方包**中的解析函数（例如 `approve_transfer`），传入该 Request 以及所需系统对象（如 Clock、Faucet）。
3. 解析函数内做业务检查（金额上限、KYC、禁止地址等），然后 `request.approve(TransferApproval())`（或发行方定义的其它审批类型）。
4. 最后调用 PAS 的 `send_funds::resolve_balance(request, policy)`（或对应 unlock/clawback 的 resolve），Request 被消费，余额完成移动。
5. 若 Policy 要求多种审批类型，则需在 PTB 中多次调用不同的 approve，凑齐后再 resolve。

## 小结

- 所有「转出或收回」都通过 **Request** 热土豆完成；须在**同一 PTB** 内凑齐 **required_approvals** 并 **resolve**。
- **SendFunds**：Chest → Chest；**UnlockFunds**：Chest → 链上通用；**ClawbackFunds**：发行方收回，仅当 Policy 允许时可用。
