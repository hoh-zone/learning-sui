# PAS 概述与方案对比

## 如何引入 PAS 库

### 依赖配置

在发行方包的 `Move.toml` 中声明对 `pas` 和（若需注册 Command）`ptb` 的依赖：

```toml
[package]
name = "your_coin"
edition = "2024.beta"

[dependencies]
pas = { local = "../pas" }   # 或 git = "https://github.com/MystenLabs/pas" }
ptb = { local = "../ptb" }   # 仅当需要 set_template_command 时
sui = { git = "https://github.com/MystenLabs/sui", rev = "..." }
```

### 常用 use 语句

发行方模块中通常需要：

```move
use pas::namespace::Namespace;
use pas::policy::{Self, Policy, PolicyCap};
use pas::chest::{Self, Chest, Auth};
use pas::request::Request;
use pas::send_funds::{Self, SendFunds};
use pas::unlock_funds::{Self, UnlockFunds};
use pas::clawback_funds::{Self, ClawbackFunds};
use pas::templates::Templates;
use ptb::ptb;  // 用于 move_call、ext_input、object_by_id 等
```

解析函数里会用到 `request.data()`、`request.approve(...)`，以及 `send_funds::sender/recipient/funds` 等访问器。

## 什么是 PAS

**Permissioned Assets Standard（PAS）** 是 Sui 上用于发行和管理**许可型资产**的框架，面向需要合规约束、转移限制和监管控制的**同质化代币**场景（如证券型代币、稳定币、合规稳定币等）。资产只能存放在 **Chest** 中，转账通过 **Request（SendFunds / UnlockFunds / Clawback）** 发起，并由发行方定义的**解析逻辑**（含 KYC、白名单、限额等）批准后才会完成。

参考：[MystenLabs/pas](https://github.com/MystenLabs/pas)、[PR #25 KYC-compliant coin example](https://github.com/MystenLabs/pas/pull/25)。

## 设计目标

- **许可转移**：所有转账必须经过 Chest，并由与 Policy 绑定的自定义规则批准。
- **Chest 架构**：代币只能存在于 Chest 中，每个地址（或对象）对应一个派生 Chest，便于发现与 RPC 查询。
- **灵活策略**：每种代币类型对应一个 Policy，可配置不同动作（send_funds、unlock_funds、clawback_funds）所需的审批类型。
- **可选 Clawback**：在注册时选择是否允许监管收回（clawback），满足合规需求。

## 核心概念一览

| 概念 | 说明 |
|------|------|
| **Namespace** | 全局单例，用于派生 Chest、Policy、Templates 的地址，并管理版本阻断。 |
| **Chest** | 每个地址（或对象）一个，由 Namespace 派生；余额只能从 Chest 到 Chest 或通过 Unlock 流出。 |
| **Policy\<T\>** | 与代币类型 T 绑定，规定各动作（send_funds 等）需要哪些「审批类型」才能 resolve。 |
| **Request** | 转账/解锁/收回时产生的「热土豆」，须在 PTB 中调用发行方包里的 resolve 逻辑并凑齐所需审批后 resolve。 |
| **Templates** | 存储每种审批类型对应的 PTB Command，供 SDK 自动构造解析交易。 |

## 与既有方案的详细对比

下表对比 PAS 与本书前面介绍的几种「受限/合规」方案，便于按场景选型。

| 维度 | **PAS（许可资产标准）** | **DenyList 受监管代币**（13.4） | **闭环 Token（Closed-Loop）**（13.5） | **Kiosk TransferPolicy**（14.4） |
|------|-------------------------|----------------------------------|----------------------------------------|-----------------------------------|
| **适用资产** | 同质化、许可型（如合规稳定币、证券型代币） | 同质化 Coin，链上原生 | 同质化 Token（sui::token） | NFT / 可交易对象 |
| **存储形态** | 余额在 **Chest**（每地址一个派生对象） | 普通 **Coin\<T\>** 在钱包地址 | **Token\<T\>**，转移受 Policy 约束 | 对象在 Kiosk 或钱包 |
| **限制方式** | 每笔转账生成 **Request**，须发行方包内 **resolve**（任意逻辑：KYC、白名单、限额等） | **黑名单**：被列地址不能收/发该 Coin；可选全局暂停 | **TokenPolicy**：按动作（transfer/spend 等）配置 Rule，须 prove 后 confirm | **TransferPolicy**：按 Rule 收版税、锁定 Kiosk 等，满足后 confirm_request |
| **谁做校验** | **发行方自己的 Move 模块**（approve_transfer 等），可读链上/链下 KYC 等 | 链上 **DenyList** 系统对象，DenyCap 持有者维护名单 | 链上 **TokenPolicy**，Rule 的 prove 在合约内 | 链上 **TransferPolicy**，Rule 的 add_receipt 在合约内 |
| **发现与索引** | Chest/Policy 地址**可推导**，无需事件即可查余额 | 普通对象，按类型与 owner 查询 | 普通对象，按类型与 owner 查询 | 需 Policy 与 Kiosk 对象 ID |
| **Clawback** | **支持**（Policy 注册时可选，由发行方发起 clawback 请求并 resolve） | 不支持（仅禁止转移） | 一般不支持 | 不适用 |
| **解锁到链上通用余额** | 通过 **UnlockFunds** 请求，由 Policy 决定是否允许「流出 PAS 体系」 | 无「解锁」概念，仅黑名单解除 | 无「解锁」概念 | 不涉及 |
| **典型场景** | 合规稳定币、证券型代币、需 KYC/AML 的资产 | 制裁名单、简单黑名单合规 | 游戏积分、忠诚度、仅限应用内使用 | NFT 版税、NFT 锁定在 Kiosk |

### 选型建议

- **只需黑/白名单、无需每笔自定义逻辑**：DenyList 受监管代币即可。
- **同质化 + 每笔转账都要做 KYC/限额/白名单等自定义检查**：用 **PAS**，在 resolve 里实现你的规则。
- **同质化 + 仅限在自家应用内 transfer/spend**：闭环 **Token + TokenPolicy** 更轻。
- **NFT 版税、Kiosk 内交易与锁定**：用 **Kiosk + TransferPolicy**。

## 小结

- PAS 面向**许可型同质化资产**，通过 **Chest + Request + Policy 解析** 实现「每笔转移都可被发行方规则约束」。
- 与 DenyList、闭环 Token、TransferPolicy 的区别在于：**谁做校验、存储形态、是否支持 Clawback/Unlock**；PAS 最灵活但实现成本也最高，适合强合规与 KYC 场景。
