# PAS 概述与方案对比

## 如何引入 PAS 库

### 依赖配置

在发行方包的 `Move.toml` 中声明对 `pas` 和（若需注册 Command）`ptb` 的依赖：

```toml
[package]
name = "your_coin"
edition = "2024"

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

---

## Coin、受监管 Coin、闭环 Token 与 PAS 详解

下面从「存储与转移模型」「谁做校验」「能表达什么规则」「典型用途」四方面，把 **标准 Coin**、**DenyList 受监管 Coin**、**闭环 Token**、**PAS** 说清，并说明**为什么要 PAS**。

### 1. 标准 Coin（普通代币）

| 项目 | 说明 |
|------|------|
| **创建方式** | `coin_registry::new_currency_with_otw` + `finalize`，得到 `TreasuryCap<T>`、`MetadataCap<T>` |
| **存储形态** | **Coin\<T\>** 或 **Balance\<T\>** 在用户地址下，和任意 Sui 对象一样可自由持有、转移 |
| **转移方式** | 任意人可 `coin::transfer` 或 `balance::send_funds`，无需发行方或第三方参与 |
| **谁做校验** | 无。链上不对「谁可以转、转给谁、转多少」做额外校验 |
| **能表达什么规则** | 无链上合规规则，仅依赖应用层或链下约束 |
| **Clawback / 收回** | 不支持。发行方无法从用户地址收回已转出的代币 |
| **典型用途** | 通用支付、DeFi、无合规要求的同质化代币 |

**小结**：Coin 是「完全开放」的同质化资产，适合不需要合规或转移限制的场景。

---

### 2. DenyList 受监管 Coin（黑名单代币）

| 项目 | 说明 |
|------|------|
| **创建方式** | 在 Coin 创建流程上多加一步 **`coin_registry::make_regulated`**，得到 **`DenyCapV2<T>`**；代币仍为链上标准 Coin |
| **存储形态** | 仍是 **Coin\<T\>** 在用户地址，和普通 Coin 一致 |
| **转移方式** | 仍是标准 `coin::transfer`，但**链上在转移时检查 DenyList**：若发送方或接收方在黑名单中，转移被拒绝 |
| **谁做校验** | **DenyList 系统对象** + **DenyCapV2** 维护的黑名单；校验逻辑固定为「地址是否在名单中」 |
| **能表达什么规则** | **仅黑名单**：禁止某些地址收/发；可选**全局暂停**（暂停该代币所有转移） |
| **Clawback / 收回** | 不支持。只能「禁止转移」，不能把已持有的代币从地址中收回 |
| **典型用途** | 制裁名单、简单合规黑名单、需要「一键暂停」的稳定币 |

**小结**：受监管 Coin 在「标准 Coin + 黑名单 + 可选全局暂停」范围内做合规，**不能**做按笔的 KYC、白名单、限额、自定义逻辑。

---

### 3. 闭环 Token（Closed-Loop Token）

| 项目 | 说明 |
|------|------|
| **创建方式** | `coin_registry::new_currency_with_otw` + `finalize` 得到货币元数据，再用 **`token::new_policy`** 创建 **TokenPolicy\<T\>**，并为各**动作**（transfer、spend、to_coin 等）绑定 **Rule** |
| **存储形态** | **Token\<T\>**（无 `store`），不能随意转手；只能通过 **ActionRequest** 发起操作，满足 Policy 的 Rule 并 **confirm** 后才完成 |
| **转移方式** | `token::transfer` 生成 **ActionRequest**；用户（或应用）调用各 Rule 的 **prove** 往 request 上「盖章」，再 **token::confirm_request** 完成转移 |
| **谁做校验** | **TokenPolicy** 上挂的 **Rule**（如 CrownCouncilRule）；每个 Rule 在 **prove** 里实现自己的逻辑（成员集合、时间锁等） |
| **能表达什么规则** | 按**动作**（transfer / spend / to_coin）配置不同 Rule；可做白名单、成员校验、时间锁等，但规则是「满足 Rule 即放行」，**不能**由发行方在链上做「每笔审批」或读链下 KYC |
| **Clawback / 收回** | 一般不提供；若要收回应由发行方通过自有 Cap 或 Rule 设计实现 |
| **典型用途** | 游戏内货币、忠诚度积分、仅限应用内使用的代币、需要「满足规则才可转」的同质化 Token |

**小结**：闭环 Token 是「同质化但非自由流通」的 Token，规则由 **Rule + prove** 表达，适合应用内闭环；**不是**「每笔都经发行方或链下 KYC 审批」的模型。

---

### 4. PAS（许可资产标准）

| 项目 | 说明 |
|------|------|
| **创建方式** | 依赖 **PAS 包**（Namespace、Templates 等）；发行方用 **coin_registry** 等创建货币后，用 **policy::new_for_currency** 在 PAS 里注册 **Policy\<Balance\<C\>\>**，并可选配置 **Clawback** |
| **存储形态** | 余额只能在 **Chest** 中（每地址或每对象一个派生 Chest）；**没有**「裸 Coin 在钱包」的形态，所有转入必须先进入 Chest |
| **转移方式** | **chest::send_balance** 生成 **Request\<SendFunds\>**（热土豆）；同一 PTB 内必须调用**发行方包**里的解析函数（如 **approve_transfer**），做任意校验后 **request.approve(...)**，再 **send_funds::resolve_balance** 才完成 Chest→Chest 转账 |
| **谁做校验** | **发行方自己的 Move 模块**（解析函数）；可读链上状态（KYC 表、白名单）、也可依赖链下输入（通过参数或预言机），**每笔**都可做不同逻辑 |
| **能表达什么规则** | **任意链上/链下逻辑**：KYC、白名单、黑名单、单笔限额、冷却期、监管审批等；还可区分 **send_funds / unlock_funds / clawback_funds** 配置不同审批 |
| **Clawback / 收回** | **支持**。Policy 注册时可选 **clawback_allowed**；发行方发起 **clawback_balance** 请求并满足 Policy 审批后 **resolve**，即可从某 Chest 收回余额 |
| **解锁到链上** | **UnlockFunds** 请求：经 Policy 审批后可将余额从 PAS 体系解锁为链上通用 Balance/Coin，用于赎回或退出 |
| **典型用途** | 合规稳定币、证券型代币、需 KYC/AML 的资产、需要监管收回或解锁控制的场景 |

**小结**：PAS 是「每笔转移都可被发行方自定义逻辑约束」的同质化资产框架，且支持 Clawback 与可控解锁。

---

## 为什么要 PAS：三种方案覆盖不了的场景

- **Coin**：不限制谁转、转给谁、转多少，无法做合规或每笔审批。
- **Deny Coin**：只能「禁止名单内地址」，不能做「仅允许 KYC 用户」「单笔限额」「每笔经发行方逻辑放行」。
- **闭环 Token**：规则是「满足 Rule 即放行」，规则在链上固定（如成员集、时间锁），**不能**做「每笔由发行方或链下 KYC 审批」；且一般无 Clawback、无「解锁到链上」的标准路径。

**PAS 要解决的问题**恰恰是：

1. **每笔转移都可执行自定义合规逻辑**（KYC、限额、白名单、黑名单、监管审批等），且逻辑在**发行方自己的 Move 模块**里，可演进、可升级。
2. **需要 Clawback**：监管或司法要求时，发行方能从指定 Chest 收回资产。
3. **需要可控「解锁」**：在合规允许时，将资产从 PAS 体系解锁为链上通用余额（如赎回为稳定币或法币通道）。
4. **钱包/SDK 友好**：通过 **Templates + Command**，链下可以按「审批类型」自动拼出解析 PTB，而不必手写每家的解析逻辑。

因此：**当你要做「同质化 + 每笔可审批 + 可选 Clawback/解锁」的合规资产时，应选 PAS**；若只需黑名单或应用内闭环，用 Deny Coin 或闭环 Token 更简单。

---

## 用途对比一览

| 需求 | Coin | Deny Coin | 闭环 Token | PAS |
|------|------|-----------|------------|-----|
| 自由转账、无合规 | ✅ 默认 | ✅ 未列名单即可 | ❌ 须过 Rule | ❌ 须过解析 |
| 禁止某些地址收/发 | ❌ | ✅ 黑名单 | 可用 Rule 模拟 | ✅ 解析里可做 |
| 全局暂停 | ❌ | ✅ | 需自建 | 可用 versioning 阻断 |
| 仅允许某类用户（如 KYC）每笔校验 | ❌ | ❌ | ❌ Rule 无法表达「链下 KYC」 | ✅ 解析里读 KYC/白名单 |
| 单笔限额、冷却期等自定义规则 | ❌ | ❌ | 仅 Rule 能表达的有限形式 | ✅ 任意逻辑 |
| 发行方收回资产（Clawback） | ❌ | ❌ | 一般不提供 | ✅ Policy 可选 |
| 合规「解锁」到链上余额 | ❌ | ❌ | 有 to_coin 等但非标准解锁 | ✅ UnlockFunds |
| 钱包/SDK 自动拼解析交易 | — | — | — | ✅ Templates + Command |
| 适用典型场景 | 通用支付、DeFi | 制裁/黑名单合规 | 游戏积分、应用内代币 | 证券型代币、合规稳定币、KYC 资产 |

## 小结

- **Coin**：自由转移、无合规；**Deny Coin**：黑名单 + 可选全局暂停，无每笔逻辑、无 Clawback；**闭环 Token**：Rule + ActionRequest，应用内闭环，无每笔发行方审批、一般无 Clawback；**PAS**：Chest + Request + 发行方解析，每笔可自定义合规、可选 Clawback 与 Unlock。
- PAS 面向**许可型同质化资产**，通过 **Chest + Request + Policy 解析** 实现「每笔转移都可被发行方规则约束」；**为什么要 PAS**：当需要每笔 KYC/限额/白名单、Clawback 或合规解锁时，Coin / Deny Coin / 闭环 Token 无法满足，选 PAS。
- 选型时结合「用途对比一览」表：按需求看哪一列打勾，即可在四种方案中做出取舍。
