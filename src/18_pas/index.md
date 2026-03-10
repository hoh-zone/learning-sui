# 第二十一章 · 许可资产标准（PAS）

本章介绍 Mysten Labs 的 **Permissioned Assets Standard（PAS）**——一套在 Sui 上发行与管理**许可型余额**的框架，适用于需要 KYC/AML、转移限制与监管控制的现实资产代币化场景。内容基于 [MystenLabs/pas](https://github.com/MystenLabs/pas) 及 [KYC-compliant coin 示例 PR #25](https://github.com/MystenLabs/pas/pull/25)。

## 本章内容

| 节 | 主题 | 你将学到 |
|---|------|---------|
| 21.1 | PAS 概述与方案对比 | 设计目标、Chest/Policy 模型、与 DenyList/闭环 Token/TransferPolicy 的对比 |
| 21.2 | 核心抽象 | Namespace、Chest、Policy、PolicyCap |
| 21.3 | 请求与解析 | SendFunds / UnlockFunds / Clawback、Request、required_approvals、resolve |
| 21.4 | Templates 与 Command | 发行方如何配置 PTB 模板、SDK 如何解析转账 |
| 21.5 | 版本控制与 Clawback | Versioning、可选 Clawback、紧急阻断 |
| 21.6 | 实战一：简单合规代币 | 限额、禁止某地址、自定义 TransferApproval |
| 21.7 | 实战二：KYC 合规代币 | KYC 校验、发行方签发 stamp、仅 KYC 通过可收发 |

## 学习目标

读完本章后，你将能够：

- **引入并使用 PAS 库**：配置依赖、use 语句，并在各节中查阅 Namespace / Chest / Policy / Request / Templates 的接口速查表
- 理解 PAS 的 Chest 架构与「请求-解析」流程，会使用 **request.data()**、**send_funds::sender/recipient/funds**、**resolve_balance** / **resolve** 等接口
- 将 PAS 与 DenyList 受监管代币、闭环 Token、Kiosk TransferPolicy 做选型对比
- 使用 PAS 实现简单合规规则与 KYC 合规代币思路，并会配置 **set_template_command** 与 **ptb::move_call** / **ext_input**
