# 核心抽象：Namespace、Chest、Policy

## 模块与入口一览

| 模块 | 主要类型 / 函数 | 说明 |
|------|-----------------|------|
| `pas::namespace` | `Namespace`, `setup`, `block_version`, `unblock_version`, `chest_address`, `policy_address` | 单例、派生地址、版本阻断 |
| `pas::chest` | `Chest`, `Auth`, `create_and_share`, `send_balance`, `unlock_balance`, `clawback_balance`, `deposit_balance`, `new_auth` | 创建 Chest、发起请求、存款、鉴权 |
| `pas::policy` | `Policy<T>`, `PolicyCap<T>`, `new_for_currency`, `share`, `set_required_approval`, `required_approvals` | 创建策略、配置审批、查询 |
| `pas::templates` | `Templates`, `setup`, `set_template_command`, `unset_template_command` | Command 注册，供 SDK 解析 |
| `pas::request` | `Request<K>`, `approve`, `data`, `approvals` | 热土豆、收集审批 |
| `pas::send_funds` / `unlock_funds` / `clawback_funds` | `SendFunds<T>`, `resolve_balance` / `resolve` | 请求数据与 resolve 入口 |
| `pas::keys` | `send_funds_action()`, `unlock_funds_action()`, `clawback_funds_action()`, `is_valid_action` | 动作名字符串（`"send_funds"` 等） |

---

## Namespace

**Namespace** 是 PAS 中的全局单例共享对象，负责：

- 为每个**地址**（或对象）派生唯一的 **Chest** 地址；
- 为每种**代币类型**派生唯一的 **Policy\<Balance\<C\>\>** 地址；
- 存储 **Templates**（各审批类型对应的 PTB Command）；
- 管理 **Versioning**（block_version / unblock_version），用于紧急阻断或升级兼容。

发布 PAS 包时，`init` 会创建并 `share_object` 一个 Namespace。之后通过 `namespace::setup(namespace, &upgrade_cap)` 绑定 UpgradeCap，即可用该 Cap 调用 `block_version` / `unblock_version`。

派生规则依赖 **derived_object**：Chest 由 `keys::chest_key(owner)` 派生，Policy 由 `keys::policy_key<Balance<C>>()` 派生，因此**同一地址在同一 Namespace 下只有一个 Chest**，**同一代币类型只有一个 Policy**，便于钱包与索引器按地址/类型推算 ID。

### Namespace 接口速查

| 函数 | 签名 | 说明 |
|------|------|------|
| `setup` | `entry fun setup(namespace: &mut Namespace, cap: &UpgradeCap)` | 绑定 UpgradeCap，之后才能 block/unblock 版本、claim 派生对象 |
| `block_version` | `public fun block_version(namespace: &mut Namespace, cap: &UpgradeCap, version: u64)` | 阻断指定包版本 |
| `unblock_version` | `public fun unblock_version(namespace: &mut Namespace, cap: &UpgradeCap, version: u64)` | 解除版本阻断 |
| `chest_exists` | `public fun chest_exists(namespace: &Namespace, owner: address): bool` | 某地址是否已有 Chest |
| `chest_address` | `public fun chest_address(namespace: &Namespace, owner: address): address` | 派生 Chest 地址（用于查询或 deposit） |
| `policy_exists` | `public fun policy_exists<T>(namespace: &Namespace): bool` | 是否存在 Policy\<T\> |
| `policy_address` | `public fun policy_address<T>(namespace: &Namespace): address` | 派生 Policy\<T\> 的地址 |

## Chest

**Chest** 是存放某一种或多种 PAS 代币余额的容器，与「所有者」一一对应：

- **所有者**：可以是 `address`（用户钱包）或对象（用于账户抽象/协议托管）。
- **每个所有者在一个 Namespace 下只有一个 Chest**（由 `derived_object::claim(namespace, chest_key(owner))` 保证）。
- Chest 创建后通常 **share_object**，便于任何人向该 Chest 存款或查询余额；只有所有者（或授权证明 **Auth**）才能发起转出、解锁或被动被 clawback。

余额只能：

- 从 Chest A **转到** Chest B（通过 **SendFunds** 请求）；
- 从 Chest **解锁**到链上普通余额（通过 **UnlockFunds** 请求，若 Policy 支持）；
- 被发行方 **Clawback**（通过 **ClawbackFunds** 请求，若 Policy 在注册时允许）。

Chest 内部使用 `balance::Balance<C>` 等存储，与 Sui 标准余额兼容，RPC/钱包可按「Chest 的派生地址」查询余额。

### Chest 接口速查

| 函数 | 签名 | 说明 |
|------|------|------|
| `create` | `public fun create(namespace: &mut Namespace, owner: address): Chest` | 为 owner 创建 Chest（需随后 share） |
| `create_and_share` | `public fun create_and_share(namespace: &mut Namespace, owner: address)` | 创建并共享，一步完成 |
| `share` | `public fun share(chest: Chest)` | 将 Chest 设为共享对象 |
| `send_balance` | `public fun send_balance<C>(from: &mut Chest, auth: &Auth, to: &Chest, amount: u64, _ctx: &mut TxContext): Request<SendFunds<Balance<C>>>` | 从 from 转 amount 到 to Chest，返回待解析的 Request |
| `unsafe_send_balance` | `public fun unsafe_send_balance<C>(from: &mut Chest, auth: &Auth, recipient_address: address, amount: u64, _ctx: &mut TxContext): Request<SendFunds<Balance<C>>>` | 按**地址**转账（可转给尚未建 Chest 的地址），易用错，慎用 |
| `unlock_balance` | `public fun unlock_balance<C>(chest: &mut Chest, auth: &Auth, amount: u64, _ctx: &mut TxContext): Request<UnlockFunds<Balance<C>>>` | 发起解锁请求 |
| `clawback_balance` | `public fun clawback_balance<C>(from: &mut Chest, amount: u64, _ctx: &mut TxContext): Request<ClawbackFunds<Balance<C>>>` | 发行方发起收回请求（无 Auth） |
| `deposit_balance` | `public fun deposit_balance<C>(chest: &Chest, balance: Balance<C>)` | 无许可向 Chest 存入余额 |
| `owner` | `public fun owner(chest: &Chest): address` | 返回 Chest 所有者地址 |
| `new_auth` | `public fun new_auth(ctx: &TxContext): Auth` | 用交易发送方生成 Auth |
| `new_auth_as_object` | `public fun new_auth_as_object(uid: &mut UID): Auth` | 用对象 UID 生成 Auth（对象拥有 Chest 时） |
| `sync_versioning` | `public fun sync_versioning(chest: &mut Chest, namespace: &Namespace)` | 与 Namespace 同步版本信息 |

## Policy 与 PolicyCap

**Policy\<T\>** 与某种可转移类型 `T`（实践中多为 `Balance<C>`）绑定，表示「该类型在 PAS 下的转移规则」：

- **required_approvals**：`VecMap<String, VecSet<TypeName>>`，键为动作名（如 `"send_funds"`、`"unlock_funds"`、`"clawback_funds"`），值为需要收集的**审批类型**（TypeName）集合；只有收集齐这些审批后，对应 Request 才能被 resolve。
- **clawback_allowed**：注册时确定，是否允许对该类型的 Chest 发起 clawback。
- **versioning**：与 Namespace 同步，用于阻断旧版本。

**PolicyCap\<T\>** 与 Policy 一一对应，持有者可：

- 调用 `policy::set_required_approval` / `remove_action_approval` 配置各动作所需的审批类型；
- 与 **Templates** 配合，为每种审批类型设置 PTB **Command**，供 SDK 解析转账时使用。

创建方式（以代币类型 `Balance<C>` 为例）：`policy::new_for_currency(namespace, &mut treasury_cap, clawback_allowed)`，得到 `(Policy<Balance<C>>, PolicyCap<Balance<C>>)`；然后 `policy::share(policy)`，PolicyCap 由发行方保管。

### Policy 接口速查

| 函数 | 签名 | 说明 |
|------|------|------|
| `new_for_currency` | `public fun new_for_currency<C>(namespace: &mut Namespace, _cap: &mut TreasuryCap<C>, clawback_allowed: bool): (Policy<Balance<C>>, PolicyCap<Balance<C>>)` | 为货币 C 创建 Policy 与 PolicyCap |
| `share` | `public fun share<T>(policy: Policy<T>)` | 共享 Policy，供 resolve 等使用 |
| `set_required_approval` | `public fun set_required_approval<T, A: drop>(policy: &mut Policy<T>, cap: &PolicyCap<T>, action: String)` | 设置某动作（如 `"send_funds"`）需要审批类型 A |
| `remove_action_approval` | `public fun remove_action_approval<T>(policy: &mut Policy<T>, _: &PolicyCap<T>, action: String)` | 移除某动作的审批要求（导致该动作无法 resolve） |
| `required_approvals` | `public fun required_approvals<T>(policy: &Policy<T>, action_type: String): VecSet<TypeName>` | 查询某动作所需的审批类型集合 |
| `sync_versioning` | `public fun sync_versioning<T>(policy: &mut Policy<T>, namespace: &Namespace)` | 与 Namespace 同步版本 |

合法 `action` 字符串由 `pas::keys` 定义：`send_funds_action()`、`unlock_funds_action()`、`clawback_funds_action()`（即 `"send_funds"`、`"unlock_funds"`、`"clawback_funds"`）。

## 小结

- **Namespace**：单例，负责派生 Chest/Policy/Templates 及版本控制。
- **Chest**：每地址（或对象）一个，存 PAS 余额；仅能通过 SendFunds / UnlockFunds / Clawback 变动。
- **Policy + PolicyCap**：按代币类型规定各动作所需审批类型，Cap 持有者配置审批与 Templates。
