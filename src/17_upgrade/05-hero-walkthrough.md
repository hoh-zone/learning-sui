# 实战：Hero 游戏完整升级

本节通过一个完整的 Hero 游戏案例，演示从 V1 发布、使用，到 V2 修改、升级、迁移和验证的全流程。你将亲手完成一次真实的包升级。

## 第一步：创建项目

```bash
sui move new hero_game
cd hero_game
```

## 第二步：编写 V1 代码

**sources/hero.move** — 英雄 NFT 定义：

```move
module hero_game::hero;

use sui::package;

public struct HERO has drop {}

public struct Hero has key, store {
    id: UID,
    lvl: u64,
    xp: u64,
    xp_to_next_lvl: u64,
}

fun init(otw: HERO, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
}

public fun mint_hero(ctx: &mut TxContext) {
    let hero = Hero {
        id: object::new(ctx),
        lvl: 1,
        xp: 0,
        xp_to_next_lvl: 100,
    };
    transfer::transfer(hero, ctx.sender());
}

// === Package 内部访问器 ===

public(package) fun lvl(self: &Hero): u64 { self.lvl }
public(package) fun xp(self: &Hero): u64 { self.xp }
public(package) fun xp_to_next_lvl(self: &Hero): u64 { self.xp_to_next_lvl }

// === Package 内部修改器 ===

public(package) fun add_xp(self: &mut Hero, amount: u64) {
    self.xp = self.xp + amount;
}

public(package) fun set_lvl(self: &mut Hero, value: u64) {
    self.lvl = value;
}

public(package) fun set_xp(self: &mut Hero, value: u64) {
    self.xp = value;
}

public(package) fun set_xp_to_next_lvl(self: &mut Hero, value: u64) {
    self.xp_to_next_lvl = value;
}
```

访问器和修改器使用 `public(package)` 而非 `public`，保留升级时修改签名的灵活性。

**sources/training_ground.move** — 训练场（版本控制 + 业务逻辑）：

```move
module hero_game::training_ground;

use hero_game::hero::Hero;

const VERSION: u64 = 1;
const XP_PER_TRAINING: u64 = 50;

const EInvalidPackageVersion: u64 = 0;
const ENotEnoughXp: u64 = 1;

public struct TrainingGround has key {
    id: UID,
    version: u64,
    xp_per_level: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(TrainingGround {
        id: object::new(ctx),
        version: VERSION,
        xp_per_level: 100,
    })
}

public fun check_is_valid(self: &TrainingGround) {
    assert!(self.version == VERSION, EInvalidPackageVersion);
}

public fun train(self: &TrainingGround, hero: &mut Hero) {
    self.check_is_valid();
    hero.add_xp(XP_PER_TRAINING);
}

public fun level_up(self: &TrainingGround, hero: &mut Hero) {
    self.check_is_valid();
    let current_xp = hero.xp();
    let req_xp = hero.xp_to_next_lvl();
    let current_lvl = hero.lvl();
    assert!(current_xp >= req_xp, ENotEnoughXp);

    hero.set_xp(current_xp - req_xp);
    let new_lvl = current_lvl + 1;
    hero.set_lvl(new_lvl);
    hero.set_xp_to_next_lvl(new_lvl * self.xp_per_level);
}
```

## 第三步：发布 V1

```bash
sui client publish
```

记录输出中的：
- **Package ID**（例如 `0xV1_PACKAGE`）
- **UpgradeCap ID**（例如 `0xUPGRADE_CAP`）
- **TrainingGround ID**（共享对象，例如 `0xTRAINING_GROUND`）

## 第四步：V1 使用体验

```bash
# 铸造英雄
sui client call \
  --package 0xV1_PACKAGE \
  --module hero \
  --function mint_hero \
# 记录 Hero ID（例如 0xHERO）

# 训练英雄（+50 XP）
sui client call \
  --package 0xV1_PACKAGE \
  --module training_ground \
  --function train \
  --args 0xTRAINING_GROUND 0xHERO \

# 再训练一次（累计 100 XP）
sui client call \
  --package 0xV1_PACKAGE \
  --module training_ground \
  --function train \
  --args 0xTRAINING_GROUND 0xHERO \

# 升级英雄（100 XP → Level 2）
sui client call \
  --package 0xV1_PACKAGE \
  --module training_ground \
  --function level_up \
  --args 0xTRAINING_GROUND 0xHERO \
```

## 第五步：修改为 V2

假设要重新平衡：每次训练 XP 从 50 降为 30，并增加升级所需 XP。V2 改动：

1. `VERSION` 从 1 改为 2
2. 废弃旧 `train`，新增 `train_v2`（30 XP）
3. 添加 `migrate` 更新共享对象版本和参数

修改 **sources/training_ground.move**：

```move
module hero_game::training_ground;

use hero_game::hero::Hero;

const VERSION: u64 = 2;

const EInvalidPackageVersion: u64 = 0;
const ENotEnoughXp: u64 = 1;
const EUseTrainV2Instead: u64 = 2;

public struct TrainingGround has key {
    id: UID,
    version: u64,
    xp_per_level: u64,
}

public fun check_is_valid(self: &TrainingGround) {
    assert!(self.version == VERSION, EInvalidPackageVersion);
}

/// 迁移共享对象到 V2
public fun migrate(self: &mut TrainingGround) {
    assert!(self.version < VERSION, EInvalidPackageVersion);
    self.version = VERSION;
    self.xp_per_level = 150;
}

/// [已废弃] 旧训练函数 — 调用将中止
public fun train(_self: &TrainingGround, _hero: &mut Hero) {
    abort EUseTrainV2Instead
}

/// V2 训练：每次 30 XP
public fun train_v2(self: &TrainingGround, hero: &mut Hero) {
    self.check_is_valid();
    hero.add_xp(30);
}

public fun level_up(self: &TrainingGround, hero: &mut Hero) {
    self.check_is_valid();
    let current_xp = hero.xp();
    let req_xp = hero.xp_to_next_lvl();
    let current_lvl = hero.lvl();
    assert!(current_xp >= req_xp, ENotEnoughXp);

    hero.set_xp(current_xp - req_xp);
    let new_lvl = current_lvl + 1;
    hero.set_lvl(new_lvl);
    hero.set_xp_to_next_lvl(new_lvl * self.xp_per_level);
}
```

## 第六步：发布 V2 升级

```bash
sui move build
sui client upgrade --upgrade-capability 0xUPGRADE_CAP
```

记录新的 **Package ID**（例如 `0xV2_PACKAGE`）。

## 第七步：迁移窗口

升级发布后、调用 `migrate` 之前，存在一个**迁移窗口**：

```
发布 V2 后，migrate 前的状态：
┌──────────────────┬───────────────────┐
│ V1 包 (VERSION=1)│ V2 包 (VERSION=2) │
│ 对象 version=1   │ 对象 version=1    │
│ 1 == 1 ✅ 可调用 │ 2 != 1 ❌ 会中止  │
└──────────────────┴───────────────────┘

调用 migrate 后：
┌──────────────────┬───────────────────┐
│ V1 包 (VERSION=1)│ V2 包 (VERSION=2) │
│ 对象 version=2   │ 对象 version=2    │
│ 1 != 2 ❌ 会中止 │ 2 == 2 ✅ 可调用  │
└──────────────────┴───────────────────┘
```

发布与激活解耦，便于先验证再切换。

## 第八步：执行迁移

```bash
sui client call \
  --package 0xV2_PACKAGE \
  --module training_ground \
  --function migrate \
  --args 0xTRAINING_GROUND \
```

## 第九步：验证升级效果

```bash
# 验证 1：旧 train 已废弃
sui client call \
  --package 0xV2_PACKAGE \
  --module training_ground \
  --function train \
  --args 0xTRAINING_GROUND 0xHERO \
# 预期：MoveAbort EUseTrainV2Instead

# 验证 2：train_v2 正常
sui client call \
  --package 0xV2_PACKAGE \
  --module training_ground \
  --function train_v2 \
  --args 0xTRAINING_GROUND 0xHERO \
# 预期：成功，+30 XP

# 验证 3：旧包被拒绝
sui client call \
  --package 0xV1_PACKAGE \
  --module training_ground \
  --function train \
  --args 0xTRAINING_GROUND 0xHERO \
# 预期：MoveAbort EInvalidPackageVersion
```

## 小结

- 完整流程：创建项目 → 写 V1 → 发布 → 使用 → 改 V2 → 升级 → 迁移 → 验证
- 版本化共享对象（`version` 字段 + `check_is_valid()`）实现发布与激活解耦
- `public` 函数不能删除，可改为 `abort` 实现废弃
- 迁移窗口内旧包仍可用，调用 `migrate` 后仅新包可用
- 建议在 devnet/testnet 上完整跑通一遍后再上主网
