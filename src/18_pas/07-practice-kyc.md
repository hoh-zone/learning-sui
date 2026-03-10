# 实战二：KYC 合规代币（仅 KYC 通过可收发）

本实战对应 [MystenLabs/pas PR #25](https://github.com/MystenLabs/pas/pull/25) 的 **KYC-compliant coin** 思路：只有通过 KYC 的地址才能接收或发送该 PAS 代币，发行方通过签发 **KYC Stamp**（或类似证明）来授权。

## 设计思路

- **KYC 状态**：链上维护「已通过 KYC 的地址」集合，或由发行方为每个用户签发一个 **KYC Stamp** 对象（如 NFT 或 one-time proof）。
- **发送/接收规则**：在 **approve_transfer**（或等价解析函数）中检查：
  - **发送方**：必须持有有效 KYC 证明（或其地址在 KYC 名单中）；
  - **接收方**：必须已通过 KYC（或将在同一 PTB 中创建 Chest 并满足「首次接收前已 KYC」的策略）。
- **发行方**：拥有 KYC 签发权（例如 KYCCap），可调用 `issue_kyc_stamp(user)` 将 Stamp 转给用户；用户后续转账时在 PTB 中传入该 Stamp，解析函数验证后 `request.approve(KYCApproval())`。

## 实现要点（概念代码）

### 1. KYC 证明类型

```move
// 发行方签发的 KYC 证明，用户持有才能参与转账
public struct KYCStamp has key, store {
    id: UID,
    user: address,
    issued_at: u64,
}
```

或使用 **Table** / **Bag** 维护 `address -> bool` 的 KYC 名单，由发行方 Cap 更新。

### 2. 审批类型

- 定义 **KYCApproval**（或 KYCTransferApproval），在 Policy 中设置 `set_required_approval<_, KYCApproval>(&cap, "send_funds")`。

### 3. approve_transfer 中的 KYC 校验与接口

在解析函数中使用 PAS 接口读取请求数据并做校验：

```move
public fun approve_kyc_transfer<C>(
    request: &mut Request<SendFunds<Balance<C>>>,
    kyc_registry: &KYCRegistry,
) {
    let data = request.data();
    assert!(kyc_registry.is_kyc(send_funds::sender(data)), ESenderNotKYC);
    assert!(kyc_registry.is_kyc(send_funds::recipient(data)), ERecipientNotKYC);
    request.approve(KYCApproval());
}
```

- **request.data()** 配合 **send_funds::sender(data)**、**send_funds::recipient(data)** 获取发送方与接收方地址；
- 校验 sender/recipient 已在链上 KYC 表或持有有效 KYCStamp；
- 通过则 **request.approve(KYCApproval())**；Policy 中需 `set_required_approval<_, KYCApproval>(&cap, "send_funds")`，Templates 中为该类型注册对应 Command。

### 4. Templates

- 为 KYCApproval 设置 Command：例如 `move_call(..., "approve_kyc_transfer", [request, kyc_stamp_or_registry], type_args)`，SDK 解析时知道需要用户提供 KYC 证明对象或由发行方服务端提供证明。

### 5. 发行方流程

- **KYC 通过**：发行方调用 `issue_kyc_stamp(user)` 将 KYCStamp 转给 user，或将 user 加入链上 KYC 表；
- **撤销 KYC**：收回 Stamp 或从表中移除，后续该用户的转账在解析时将无法通过校验。

## 与简单合规代币的对比

| 项目 | 实战一（简单合规） | 实战二（KYC 合规） |
|------|-------------------|---------------------|
| 校验依据 | 金额、sender/recipient 地址 | 发送方/接收方是否持有 KYC 证明或位于 KYC 名单 |
| 审批类型 | TransferApproval / TransferApprovalV2 | KYCApproval（需 KYCStamp 或 KYC 表） |
| 发行方能力 | 仅配置 Policy/Templates、升级解析逻辑 | 签发/撤销 KYC、控制谁可参与转账 |
| 典型场景 | 限额、黑名单 | 证券型代币、合规稳定币、机构客户 |

## 小结

- KYC 合规代币在 PAS 中的实现方式：**在 resolve 前的 approve 函数里校验「发送方 + 接收方」的 KYC 状态**，通过则 approve 对应类型，由 PAS 完成 resolve。
- 参考 [PR #25](https://github.com/MystenLabs/pas/pull/25) 的 KYC-compliant coin 示例可获得完整 Move 与 setup 细节；本章给出的是通用思路与与实战一的对比，便于你在自己的包中实现类似逻辑。
