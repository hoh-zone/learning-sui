# 升级策略

升级策略决定了包被允许进行何种程度的修改。合理选择和管理升级策略是平衡**灵活性**与**安全性**的关键——策略越宽松，开发者越灵活；策略越严格，用户越安心。

## 四种内置策略

Sui 提供四种内置升级策略，由 `UpgradeCap` 的 `policy` 字段控制。按权限从高到低排列：

```
compatible  →  additive  →  dependency-only  →  immutable
 (最灵活)                                        (最安全)
     ←────── 只能往这个方向收紧，不可回退 ──────→
```

### 1. compatible（兼容升级）— 默认策略

发布包时默认使用此策略，提供最大灵活性：

| 允许 | 不允许 |
|------|--------|
| 添加新模块 | 删除已有模块 |
| 添加新函数（包括 `public`） | 删除 `public` 函数 |
| 添加新结构体 | 修改已有结构体字段/abilities |
| 修改任何函数的实现 | 修改 `public` 函数签名 |
| 修改/删除 `private`、`entry`、`public(package)` 函数 | |

```move
// ✅ compatible 策略下允许的修改

// 修改私有函数实现
fun internal_logic(): u64 {
    42 // 可以改为任何值
}

// 修改 public(package) 函数（签名和实现都可以改）
public(package) fun helper(x: u64): u64 {
    x * 2 // 自由修改
}

// 添加新的 public 函数
public fun new_feature(): bool { true }

// 修改 public 函数的实现（但签名不变）
public fun existing_fn(x: u64): u64 {
    x + 1 // 实现可以改
    // 但参数 (x: u64) 和返回类型 u64 不能改
}
```

**适用场景：** 开发和测试阶段、Beta 版本、需要快速迭代的项目

### 2. additive（仅添加升级）

只允许**添加**新内容，不允许修改已有代码（包括私有函数）：

| 允许 | 不允许 |
|------|--------|
| 添加新模块 | 修改已有函数体（即使是 private） |
| 添加新函数 | 删除任何函数 |
| 添加新结构体 | 修改结构体 |

```move
// ✅ additive 策略下允许的修改

// 添加全新的模块
module my_package::analytics;

// 添加新函数
public fun get_statistics(): u64 { 0 }

// ❌ 以下都不允许：
// 修改已有函数体（即使是 private）
// fun existing_helper(): u64 { 100 }  // 原来是 42，不能改
```

**适用场景：** 稳定版本，只需要添加新功能而不修改已有逻辑

### 3. dependency-only（仅依赖升级）

只允许修改 `Move.toml` 中的依赖版本，不允许修改任何 `.move` 文件：

```toml
# ✅ 允许：更新依赖版本
[dependencies]
Sui = { git = "...", rev = "framework/testnet" }  # 可以改 rev

# ❌ 不允许：修改任何 .move 源文件
```

**适用场景：** 框架升级（跟随 Sui Framework 更新），代码已完全冻结

### 4. immutable（不可变）

永久冻结，再也无法进行任何升级。**此操作不可逆！**

```move
// 通过销毁 UpgradeCap 实现
public fun make_immutable(cap: UpgradeCap) {
    // UpgradeCap 被永久销毁
    // 此后任何升级尝试都会失败
}
```

**适用场景：** 成熟协议（如 DEX 核心合约）、需要给用户"永不修改"承诺的场景

## 收紧策略的操作

策略只能**收紧**（向更严格的方向），永远不能放松：

```move
use sui::package;

// 当前是 compatible，收紧为 additive
package::only_additive_upgrades(&mut upgrade_cap);

// 当前是 additive，收紧为 dependency-only
package::only_dep_upgrades(&mut upgrade_cap);

// 永久冻结（不可逆！请三思！）
package::make_immutable(upgrade_cap); // 注意：这里是 move，不是引用
```

**你不能这样做：**

```
immutable → dependency-only   ❌ 不可能
dependency-only → additive    ❌ 不可能
additive → compatible         ❌ 不可能
```

## 策略选择指南

### 按项目阶段选择

| 阶段 | 推荐策略 | 理由 |
|------|---------|------|
| 开发/测试 | `compatible` | 需要快速迭代，修复 bug |
| Beta / 审计中 | `compatible` | 审计可能发现需要修改的问题 |
| 正式发布 v1 | `compatible` → `additive` | 初期保留修复能力，稳定后收紧 |
| 成熟稳定 | `additive` → `dependency-only` | 只跟随框架升级 |
| 最终冻结 | `immutable` | 给用户最大信任 |

### 渐进式收紧策略

最佳实践是**渐进式收紧**——随着项目成熟逐步限制升级能力：

```
发布 v1 ──→ 修复 bug ──→ v1 稳定
(compatible)              │
                          ↓
              收紧为 additive
              只添加新功能
                          │
                          ↓
              v2 功能完整
              收紧为 dependency-only
                          │
                          ↓
              协议成熟
              make_immutable（永久冻结）
```

### 不同类型项目的建议

| 项目类型 | 建议策略 | 说明 |
|---------|---------|------|
| 个人项目 / 学习 | `compatible` | 保持最大灵活性 |
| DeFi 协议 | `compatible` → `additive` | 安全审计后收紧 |
| NFT 合约 | `additive` → `immutable` | 保证 NFT 规则不变 |
| 基础设施（Oracle） | `compatible` | 需要持续维护 |
| 标准库 / 公共合约 | `immutable` | 给依赖方最大信任 |

## 自定义升级策略

内置策略可能不满足所有需求。你可以通过**封装 UpgradeCap**来实施额外的升级规则。

### 时间锁升级

要求升级提议后必须等待一段冷却期，给社区时间审查：

```move
module my_protocol::timelock_upgrade;

use sui::package::UpgradeCap;
use sui::clock::Clock;

const ETimelockNotExpired: u64 = 0;
const ENoProposal: u64 = 1;

/// 24 小时冷却期
const TIMELOCK_DURATION_MS: u64 = 86_400_000;

/// 将 UpgradeCap 封装在时间锁中
public struct TimelockUpgrade has key {
    id: UID,
    cap: UpgradeCap,
    proposed_at: Option<u64>,  // 提议时间戳
}

/// 发布时调用：创建时间锁封装
public fun wrap_upgrade_cap(
    cap: UpgradeCap,
    ctx: &mut TxContext,
) {
    transfer::share_object(TimelockUpgrade {
        id: object::new(ctx),
        cap,
        proposed_at: option::none(),
    });
}

/// 第一步：提议升级（开始计时）
/// 社区可以在冷却期内审查升级内容
public fun propose_upgrade(
    self: &mut TimelockUpgrade,
    clock: &Clock,
) {
    self.proposed_at = option::some(clock.timestamp_ms());
}

/// 第二步：取消提议（如果社区有异议）
public fun cancel_proposal(self: &mut TimelockUpgrade) {
    self.proposed_at = option::none();
}

/// 第三步：执行升级（需等待冷却期结束）
public fun authorize_upgrade(
    self: &mut TimelockUpgrade,
    clock: &Clock,
): &mut UpgradeCap {
    assert!(self.proposed_at.is_some(), ENoProposal);
    let proposed_time = *self.proposed_at.borrow();
    assert!(
        clock.timestamp_ms() >= proposed_time + TIMELOCK_DURATION_MS,
        ETimelockNotExpired,
    );
    self.proposed_at = option::none();
    &mut self.cap
}
```

使用流程：

```
Day 0: propose_upgrade()         ← 提议升级
Day 0-1: 社区审查代码             ← 24 小时冷却期
Day 1: authorize_upgrade()        ← 冷却期结束，执行升级
       sui client upgrade ...
```

### 多签升级

要求多个管理员同意才能执行升级：

```move
module my_protocol::multisig_upgrade;

use sui::package::UpgradeCap;

const ENotApprover: u64 = 0;
const EAlreadyApproved: u64 = 1;
const ENotEnoughApprovals: u64 = 2;

/// 需要 3/5 管理员同意
const REQUIRED_APPROVALS: u64 = 3;

public struct MultisigUpgrade has key {
    id: UID,
    cap: UpgradeCap,
    approvers: vector<address>,  // 5 个授权管理员
    approvals: vector<address>,  // 已批准的管理员
}

/// 创建多签升级管理器
public fun create(
    cap: UpgradeCap,
    approvers: vector<address>,
    ctx: &mut TxContext,
) {
    transfer::share_object(MultisigUpgrade {
        id: object::new(ctx),
        cap,
        approvers,
        approvals: vector[],
    });
}

/// 管理员批准升级
public fun approve(
    self: &mut MultisigUpgrade,
    ctx: &TxContext,
) {
    let sender = ctx.sender();
    assert!(self.approvers.contains(&sender), ENotApprover);
    assert!(!self.approvals.contains(&sender), EAlreadyApproved);
    self.approvals.push_back(sender);
}

/// 批准数达到阈值后执行升级
public fun authorize_upgrade(
    self: &mut MultisigUpgrade,
): &mut UpgradeCap {
    assert!(
        self.approvals.length() >= REQUIRED_APPROVALS,
        ENotEnoughApprovals,
    );
    self.approvals = vector[];
    &mut self.cap
}
```

使用流程：

```
管理员 A: approve()   → approvals: [A]
管理员 B: approve()   → approvals: [A, B]
管理员 C: approve()   → approvals: [A, B, C]  ← 达到阈值
任何人:   authorize_upgrade()  → 执行升级
```

### DAO 投票升级

更复杂的场景可以结合代币投票：

```move
module my_protocol::dao_upgrade;

use sui::package::UpgradeCap;
use sui::coin::Coin;
use sui::balance::{Self, Balance};
use sui::clock::Clock;

const EVotingNotEnded: u64 = 0;
const EVoteNotPassed: u64 = 1;

/// 投票持续 7 天
const VOTING_DURATION_MS: u64 = 604_800_000;
/// 需要 > 50% 赞成票
const APPROVAL_THRESHOLD_BPS: u64 = 5000;

public struct DAOUpgrade<phantom T> has key {
    id: UID,
    cap: UpgradeCap,
    vote_start: u64,
    votes_for: Balance<T>,
    votes_against: Balance<T>,
}

/// 发起升级投票
public fun start_vote<T>(
    cap: UpgradeCap,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer::share_object(DAOUpgrade<T> {
        id: object::new(ctx),
        cap,
        vote_start: clock.timestamp_ms(),
        votes_for: balance::zero(),
        votes_against: balance::zero(),
    });
}

/// 投赞成票（质押代币作为投票权重）
public fun vote_for<T>(
    self: &mut DAOUpgrade<T>,
    coin: Coin<T>,
) {
    self.votes_for.join(coin.into_balance());
}

/// 投反对票
public fun vote_against<T>(
    self: &mut DAOUpgrade<T>,
    coin: Coin<T>,
) {
    self.votes_against.join(coin.into_balance());
}

/// 投票结束后执行升级
public fun finalize<T>(
    self: &mut DAOUpgrade<T>,
    clock: &Clock,
): &mut UpgradeCap {
    assert!(
        clock.timestamp_ms() >= self.vote_start + VOTING_DURATION_MS,
        EVotingNotEnded,
    );
    let total = self.votes_for.value() + self.votes_against.value();
    let for_bps = (self.votes_for.value() * 10000) / total;
    assert!(for_bps > APPROVAL_THRESHOLD_BPS, EVoteNotPassed);
    &mut self.cap
}
```

## 实战：管理 UpgradeCap

### 发布时保存 UpgradeCap

```bash
# 发布包
sui client publish --gas-budget 100000000

# 从输出中找到 UpgradeCap 的 ObjectID
# 类型：0x2::package::UpgradeCap
```

### 查看当前策略

```bash
sui client object <UPGRADE_CAP_ID> --json
```

输出中的 `policy` 字段：
- `0` = compatible
- `128` = additive
- `192` = dependency-only
- `255` = immutable

### 收紧策略

```bash
# 收紧为 additive
sui client call \
  --package 0x2 \
  --module package \
  --function only_additive_upgrades \
  --args <UPGRADE_CAP_ID> \
  --gas-budget 10000000

# 永久冻结
sui client call \
  --package 0x2 \
  --module package \
  --function make_immutable \
  --args <UPGRADE_CAP_ID> \
  --gas-budget 10000000
```

### 转移 UpgradeCap 给多签地址

```bash
sui client transfer \
  --object-id <UPGRADE_CAP_ID> \
  --to <MULTISIG_ADDRESS> \
  --gas-budget 10000000
```

## 小结

- Sui 提供四种内置升级策略：compatible → additive → dependency-only → immutable
- 策略只能变得更严格，**不可回退**
- `compatible` 是默认策略，适合开发迭代阶段
- `immutable` 是终极安全选择，但**不可逆**
- 最佳实践是**渐进式收紧**——随项目成熟逐步限制升级能力
- 通过封装 `UpgradeCap` 可以实现自定义策略：时间锁、多签、DAO 投票
- `UpgradeCap` 具有 `store` 能力，可以转移给多签地址或由智能合约管理
