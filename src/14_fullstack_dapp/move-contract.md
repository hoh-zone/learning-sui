# Move 合约开发

本节详细讲解如何设计和实现 DApp 的 Move 智能合约。我们以 Hero NFT 游戏为实战案例，涵盖数据模型设计、核心逻辑实现、错误处理和单元测试。

## 数据模型设计

### 核心结构体

一个 Hero NFT 游戏需要三个核心类型：

```move
module hero::hero;

use std::string::String;

const EAlreadyEquipedWeapon: u64 = 1;
const ENotEquipedWeapon: u64 = 2;

/// 英雄 NFT：拥有名字、耐力值和可选武器
public struct Hero has key, store {
    id: UID,
    name: String,
    stamina: u64,
    weapon: Option<Weapon>,
}

/// 武器 NFT：拥有名字和攻击力
public struct Weapon has key, store {
    id: UID,
    name: String,
    attack: u64,
}

/// 共享注册表：追踪所有已铸造英雄的 ID 和总数
public struct HeroRegistry has key {
    id: UID,
    ids: vector<ID>,
    counter: u64,
}
```

### 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| Hero 的 abilities | `key, store` | 允许自由转让和存储 |
| Weapon 作为 Option | `Option<Weapon>` | 英雄可以没有武器 |
| Registry 作为共享对象 | `share_object` | 所有用户都能读取英雄列表 |

## 初始化函数

```move
/// init 在包发布时自动调用一次
fun init(ctx: &mut TxContext) {
    transfer::share_object(HeroRegistry {
        id: object::new(ctx),
        ids: vector[],
        counter: 0,
    });
}
```

`init` 函数的特点：
- 只在包首次发布时执行一次
- 升级时不会重新执行
- 通常用于创建全局共享对象和分发管理员权限

## 核心逻辑实现

### 铸造英雄

```move
/// 创建英雄并注册到全局注册表
public fun new_hero(
    name: String,
    stamina: u64,
    registry: &mut HeroRegistry,
    ctx: &mut TxContext,
) {
    let hero = Hero {
        id: object::new(ctx),
        name,
        stamina,
        weapon: option::none(),
    };
    // 注册英雄 ID
    registry.ids.push_back(object::id(&hero));
    registry.counter = registry.counter + 1;
    // 转让给调用者
    transfer::transfer(hero, ctx.sender());
}
```

### 铸造武器

```move
/// 创建武器并转让给调用者
public fun new_weapon(name: String, attack: u64, ctx: &mut TxContext) {
    let weapon = Weapon {
        id: object::new(ctx),
        name,
        attack,
    };
    transfer::transfer(weapon, ctx.sender());
}
```

### 装备与卸下武器

```move
/// 为英雄装备武器。如果已有武器则中止
public fun equip_weapon(hero: &mut Hero, weapon: Weapon) {
    assert!(hero.weapon.is_none(), EAlreadyEquipedWeapon);
    hero.weapon.fill(weapon);
}

/// 卸下英雄的武器。如果没有武器则中止
public fun unequip_weapon(hero: &mut Hero): Weapon {
    assert!(hero.weapon.is_some(), ENotEquipedWeapon);
    hero.weapon.extract()
}
```

### 访问器函数

为前端查询提供只读访问（getter 以字段命名，无 `get_` 前缀）：

```move
public fun name(hero: &Hero): String { hero.name }
public fun stamina(hero: &Hero): u64 { hero.stamina }
public fun weapon(hero: &Hero): &Option<Weapon> { &hero.weapon }
public fun name(weapon: &Weapon): String { weapon.name }
public fun attack(weapon: &Weapon): u64 { weapon.attack }
public fun counter(registry: &HeroRegistry): u64 { registry.counter }
public fun ids(registry: &HeroRegistry): vector<ID> { registry.ids }
```

## PTB 友好的设计

为了支持可编程交易块（PTB），函数设计应遵循可组合原则：

```move
// 好的设计：返回对象，让调用者决定如何处理
public fun mint(ctx: &mut TxContext): Hero { /* ... */ }

// 不推荐：在函数内部 transfer，不够灵活
public fun mint_and_transfer(ctx: &mut TxContext) {
    transfer::transfer(mint(ctx), ctx.sender());
}
```

PTB 中的组合调用示例——在一笔交易中完成铸造英雄、铸造武器、装备武器：

```typescript
const tx = new Transaction();

// 铸造英雄
tx.moveCall({
  target: `${packageId}::hero::new_hero`,
  arguments: [
    tx.pure.string("Warrior"),
    tx.pure.u64(100),
    tx.object(registryId),
  ],
});

// 铸造武器
tx.moveCall({
  target: `${packageId}::hero::new_weapon`,
  arguments: [
    tx.pure.string("Excalibur"),
    tx.pure.u64(50),
  ],
});

// 装备武器（需要从前面的 moveCall 获取结果）
tx.moveCall({
  target: `${packageId}::hero::equip_weapon`,
  arguments: [tx.object(heroId), tx.object(weaponId)],
});
```

## 单元测试

### 测试框架

```move
#[test_only]
public(package) fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test]
fun new_hero() {
    use std::unit_test::assert_eq;
    use sui::test_utils::destroy;

    let mut ctx = tx_context::dummy();
    let mut registry = HeroRegistry {
        id: object::new(&mut ctx),
        ids: vector[],
        counter: 0,
    };

    new_hero(b"Test Hero".to_string(), 100, &mut registry, &mut ctx);
    assert_eq!(registry.counter(), 1);
    assert_eq!(registry.ids().length(), 1);

    destroy(registry);
}

#[test]
fun equip_unequip_weapon() {
    use std::unit_test::assert_eq;
    use sui::test_utils::destroy;

    let mut ctx = tx_context::dummy();
    let mut hero = Hero {
        id: object::new(&mut ctx),
        name: b"Warrior".to_string(),
        stamina: 100,
        weapon: option::none(),
    };
    let weapon = Weapon {
        id: object::new(&mut ctx),
        name: b"Sword".to_string(),
        attack: 50,
    };

    equip_weapon(&mut hero, weapon);
    assert!(hero.weapon().is_some());

    let weapon = unequip_weapon(&mut hero);
    assert!(hero.weapon().is_none());

    destroy(hero);
    destroy(weapon);
}

#[test, expected_failure(abort_code = EAlreadyEquipedWeapon)]
fun double_equip_fails() {
    let mut ctx = tx_context::dummy();
    let mut hero = Hero {
        id: object::new(&mut ctx),
        name: b"Warrior".to_string(),
        stamina: 100,
        weapon: option::none(),
    };
    let w1 = Weapon { id: object::new(&mut ctx), name: b"S1".to_string(), attack: 10 };
    let w2 = Weapon { id: object::new(&mut ctx), name: b"S2".to_string(), attack: 20 };

    equip_weapon(&mut hero, w1);
    equip_weapon(&mut hero, w2); // 应当中止
}
```

### 运行测试

```bash
cd move/hero
sui move test
```

测试输出示例：

```
Running Move unit tests
[ PASS    ] hero::hero::new_hero
[ PASS    ] hero::hero::equip_unequip_weapon
[ PASS    ] hero::hero::double_equip_fails
Test result: OK. Total tests: 3; passed: 3; failed: 0
```

## 发布合约

```bash
# 发布到 testnet
sui client publish --gas-budget 100000000

# 从输出中记录：
# - Package ID
# - HeroRegistry 对象 ID
```

## 小结

Move 合约开发的核心要点：

- 使用 `key + store` abilities 创建可转让的 NFT
- 利用共享对象（如 HeroRegistry）管理全局状态
- 通过 `Option` 类型实现可选字段
- 设计可组合的公共函数以支持 PTB
- 用 `assert!` + 错误常量进行输入验证
- 编写充分的单元测试，包括正常路径和失败路径
