# 数据迁移与向前兼容

升级时最大的挑战之一是如何修改已有对象的数据结构。因为结构体字段在发布后**不能增减**，我们必须使用**动态字段**或**扩展容器**来实现数据迁移和向前兼容。本节介绍三种常用模式，并给出完整升级检查清单。

## 为什么不能直接改结构体

兼容性规则要求：**已有 `public` 结构体的字段不能增删改**。因此：

```move
// ❌ 错误：升级时添加新字段会破坏兼容性
public struct User has key, store {
    id: UID,
    name: String,
    level: u64,     // 不能添加
}
```

正确做法是：**保持结构体签名不变**，用动态字段或嵌套结构（如 Bag）来扩展数据。

## 模式 A：Bag 扩展

使用 `Bag` 作为万能扩展容器，在升级时往 Bag 里添加新键值对：

```move
module my_protocol::extensible_state;

use sui::bag::{Self, Bag};

public struct AppState has key {
    id: UID,
    version: u64,
    core_data: u64,
    extensions: Bag,  // 万能扩展容器
}

fun init(ctx: &mut TxContext) {
    let mut extensions = bag::new(ctx);
    extensions.add(b"fee_rate", 100u64);
    extensions.add(b"max_supply", 10000u64);

    transfer::share_object(AppState {
        id: object::new(ctx),
        version: 1,
        core_data: 0,
        extensions,
    });
}

// V1 的读取
public fun fee_rate(state: &AppState): u64 {
    *state.extensions.borrow(b"fee_rate")
}

// V2 迁移：添加新字段
public fun migrate_to_v2(state: &mut AppState) {
    state.extensions.add(b"is_paused", false);
    state.extensions.add(b"admin_fee_bps", 30u64);
    state.version = 2;
}

// V3 迁移：修改已有字段、添加新字段
public fun migrate_to_v3(state: &mut AppState) {
    let fee_rate: &mut u64 = state.extensions.borrow_mut(b"fee_rate");
    *fee_rate = 50;
    state.extensions.add(b"treasury_address", @0x123);
    state.version = 3;
}
```

## 模式 B：动态字段 Anchor

使用动态字段挂载整个配置结构体，升级时用 `remove` + `add` 替换为新版本结构体：

```move
module my_protocol::anchor;

use sui::dynamic_field as df;

/// 锚对象（结构永远不变）
public struct Anchor has key {
    id: UID,
    version: u16,
}

/// V1 配置
public struct ConfigV1 has store, drop {
    max_items: u64,
    fee_rate: u64,
}

fun init(ctx: &mut TxContext) {
    let mut anchor = Anchor {
        id: object::new(ctx),
        version: 1,
    };
    df::add(&mut anchor.id, 0u8, ConfigV1 {
        max_items: 100,
        fee_rate: 50,
    });
    transfer::share_object(anchor);
}

/// V1 读取配置
public fun get_max_items(anchor: &Anchor): u64 {
    let config: &ConfigV1 = df::borrow(&anchor.id, 0u8);
    config.max_items
}
```

V2 升级时，定义新的配置结构并迁移：

```move
/// V2 配置（添加了 paused 和 admin 字段）
public struct ConfigV2 has store, drop {
    max_items: u64,
    fee_rate: u64,
    paused: bool,
    admin: address,
}

/// 从 V1 迁移到 V2
public fun migrate_v1_to_v2(anchor: &mut Anchor, admin: address) {
    let old: ConfigV1 = df::remove(&mut anchor.id, 0u8);
    df::add(&mut anchor.id, 0u8, ConfigV2 {
        max_items: old.max_items,
        fee_rate: old.fee_rate,
        paused: false,
        admin,
    });
    anchor.version = 2;
}

public fun get_config_v2(anchor: &Anchor): &ConfigV2 {
    df::borrow(&anchor.id, 0u8)
}
```

## 模式 C：单对象动态字段扩展

不需要替换整个配置、只需给已有对象“加字段”时，可以直接用 `dynamic_field` 在对象上挂新数据：

```move
module hero_game::upgrade_requirements;

use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;
use std::string::String;

public struct DummyObject has key, store {
    id: UID,
    name: String,
}

// ✅ 使用动态字段添加“新字段”
public fun add_level_to_object(obj: &mut DummyObject, level: u64) {
    df::add(&mut obj.id, b"level", level);
}

public fun get_level(obj: &DummyObject): u64 {
    *df::borrow(&obj.id, b"level")
}

// ✅ 使用动态对象字段挂载新对象
public struct Equipment has key, store {
    id: UID,
    power: u64,
}

public fun equip(obj: &mut DummyObject, equipment: Equipment) {
    dof::add(&mut obj.id, b"equipment", equipment);
}
```

## 模式 D：用户对象迁移

升级后，旧版本创建的用户对象（如 HeroV1）仍然存在。若新版本引入了新结构体（如 HeroV2），需要提供**显式迁移函数**，让用户把旧对象换成新对象：

```move
/// 旧版英雄（V1 创建的）
public struct HeroV1 has key, store {
    id: UID,
    name: vector<u8>,
    xp: u64,
}

/// 新版英雄（V2 新增了 level 字段）
/// 注意：这是新增的结构体，不是修改旧结构体
public struct HeroV2 has key, store {
    id: UID,
    name: vector<u8>,
    xp: u64,
    level: u64,
}

/// 用户调用此函数将旧英雄迁移到新版本
public fun migrate_hero(
    old_hero: HeroV1,
    ctx: &mut TxContext,
): HeroV2 {
    let HeroV1 { id, name, xp } = old_hero;
    id.delete(); // 销毁旧 UID

    HeroV2 {
        id: object::new(ctx),
        name,
        xp,
        level: xp / 100,
    }
}
```

**注意：** 用户对象迁移后**对象 ID 会改变**。若有其他合约或链下系统引用旧 ID，需要同步更新。

## 完整升级检查清单

每次升级前，建议对照以下清单：

```
□ 代码修改
  □ 更新 VERSION / CURRENT_VERSION 常量
  □ 确认没有删除 public 函数
  □ 确认没有修改 public 函数签名
  □ 确认没有修改已有结构体
  □ 新增字段用动态字段实现
  □ 废弃的函数改为 abort

□ 迁移函数
  □ 编写 migrate() 函数
  □ migrate() 有适当的权限控制（AdminCap / Publisher）
  □ migrate() 处理数据结构变化
  □ 测试 migrate() 在单元测试中通过

□ 兼容性测试
  □ sui move build 无错误
  □ 单元测试全部通过
  □ 在 devnet/testnet 上测试完整流程

□ 发布流程
  □ 暂停协议（如果使用暂停机制）
  □ sui client upgrade --upgrade-capability <CAP_ID>
  □ 记录新 Package ID
  □ 调用 migrate() 更新共享对象版本
  □ 迁移各个共享对象（如果使用对象级版本化）
  □ 恢复协议
  □ 验证旧包函数不可调用
  □ 验证新包函数正常工作
```

## 小结

- 结构体字段不可增减，必须通过**动态字段**或 **Bag** 扩展
- **Bag 扩展**：适合键值型扩展，多版本逐步加字段
- **动态字段 Anchor**：适合整块配置替换（ConfigV1 → ConfigV2）
- **单对象动态字段**：给已有对象挂新字段或新对象（如 level、equipment）
- **用户对象迁移**：旧类型 → 新类型需显式迁移函数，注意对象 ID 会变
- 每次升级前对照检查清单，确保兼容性与迁移流程正确
