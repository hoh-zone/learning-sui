# 铸造自定义 NFT

本节将通过一个完整的 Hero NFT 项目，手把手教你如何定义结构体、编写 mint 函数、设置 Display 元数据，以及使用动态对象字段组合 NFT。

## 定义 NFT 结构体

一个好的 NFT 结构体应包含有意义的属性：

```move
module hero::hero;

use std::string::String;
use sui::dynamic_object_field as dof;

public struct Hero has key, store {
    id: UID,
    health: u64,
    stamina: u64,
}

public fun mint_hero(ctx: &mut TxContext): Hero {
    Hero {
        id: object::new(ctx),
        health: 100,
        stamina: 10,
    }
}

public fun health(self: &Hero): u64 { self.health }
public fun stamina(self: &Hero): u64 { self.stamina }
```

## 定义附属 NFT

英雄可以装备武器——另一个独立的 NFT：

```move
module hero::blacksmith;

use std::string::String;

public struct Sword has key, store {
    id: UID,
    name: String,
    damage: u64,
    special_effects: vector<String>,
}

public fun new_sword(
    name: String,
    damage: u64,
    special_effects: vector<String>,
    ctx: &mut TxContext,
): Sword {
    Sword {
        id: object::new(ctx),
        name,
        damage,
        special_effects,
    }
}

public fun name(self: &Sword): &String { &self.name }
public fun damage(self: &Sword): u64 { self.damage }
```

## 组合 NFT（动态对象字段）

通过动态对象字段将武器装备到英雄身上：

```move
module hero::hero;

use hero::blacksmith::Sword;
use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;

const EAlreadyEquipedSword: u64 = 1;

public fun equip_sword(self: &mut Hero, sword: Sword) {
    if (df::exists_(&self.id, b"sword".to_string())) {
        abort(EAlreadyEquipedSword)
    };
    dof::add(&mut self.id, b"sword".to_string(), sword);
}

public fun sword(self: &Hero): &Sword {
    dof::borrow(&self.id, b"sword".to_string())
}
```

## 设置 Display

使用 `Publisher` 和 `Display` 定义 NFT 在前端的展示方式：

```move
module hero::hero;

use sui::display;
use sui::package;

public struct HERO() has drop;

fun init(otw: HERO, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    // 创建 Hero 的 Display
    let mut hero_display = display::new<Hero>(&publisher, ctx);
    hero_display.add(b"name".to_string(), b"Hero #{id}".to_string());
    hero_display.add(
        b"image_url".to_string(),
        b"https://mygame.com/heroes/{id}.png".to_string(),
    );
    hero_display.add(
        b"description".to_string(),
        b"A brave hero with {health} HP".to_string(),
    );
    hero_display.update_version();

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(hero_display, ctx.sender());
}
```

### Display 字段自动填充

Display 模板中的 `{field_name}` 会被对象的实际字段值替换：

```
模板: "A brave hero with {health} HP"
对象: Hero { health: 100, ... }
结果: "A brave hero with 100 HP"
```

## 完整的 Mint 函数

提供公开的 mint 入口函数，带参数验证：

```move
const ENameTooLong: u64 = 2;
const EInvalidDamage: u64 = 3;
const MAX_NAME_LENGTH: u64 = 64;

public fun mint_hero_and_transfer(
    recipient: address,
    ctx: &mut TxContext,
) {
    let hero = mint_hero(ctx);
    transfer::public_transfer(hero, recipient);
}

public fun forge_sword_and_transfer(
    name: String,
    damage: u64,
    special_effects: vector<String>,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(name.length() <= MAX_NAME_LENGTH, ENameTooLong);
    assert!(damage > 0, EInvalidDamage);

    let sword = blacksmith::new_sword(name, damage, special_effects, ctx);
    transfer::public_transfer(sword, recipient);
}
```

## 通过 PTB 铸造并装备

在客户端通过可编程交易块（PTB）一次性完成铸造和装备：

```typescript
const tx = new Transaction();

// 铸造 Hero
const hero = tx.moveCall({
  target: `${PACKAGE_ID}::hero::mint_hero`,
  arguments: [],
});

// 铸造 Sword
const sword = tx.moveCall({
  target: `${PACKAGE_ID}::blacksmith::new_sword`,
  arguments: [
    tx.pure.string("Excalibur"),
    tx.pure.u64(100),
    tx.pure(bcs.vector(bcs.string()).serialize(["Fire", "Holy"])),
  ],
});

// 装备
tx.moveCall({
  target: `${PACKAGE_ID}::hero::equip_sword`,
  arguments: [hero, sword],
});

// 转移给用户
tx.transferObjects([hero], account.address);
```

## 测试

```move
#[test_only]
public fun uid_mut_for_testing(self: &mut Hero): &mut UID {
    &mut self.id
}

#[test]
fun mint_and_equip() {
    use std::unit_test::assert_eq;
    use sui::test_utils::destroy;

    let mut ctx = tx_context::dummy();

    let mut hero = mint_hero(&mut ctx);
    assert_eq!(hero.health(), 100);
    assert_eq!(hero.stamina(), 10);

    let sword = blacksmith::new_sword(
        b"Iron Sword".to_string(),
        25,
        vector[b"None".to_string()],
        &mut ctx,
    );

    equip_sword(&mut hero, sword);

    let equipped_sword = hero.sword();
    assert_eq!(equipped_sword.damage(), 25);

    destroy(hero);
}

#[test, expected_failure(abort_code = EAlreadyEquipedSword)]
fun cannot_equip_two_swords() {
    let mut ctx = tx_context::dummy();
    let mut hero = mint_hero(&mut ctx);

    let sword1 = blacksmith::new_sword(
        b"Sword 1".to_string(), 10, vector[], &mut ctx,
    );
    let sword2 = blacksmith::new_sword(
        b"Sword 2".to_string(), 20, vector[], &mut ctx,
    );

    equip_sword(&mut hero, sword1);
    equip_sword(&mut hero, sword2); // 应该失败
}
```

## 小结

- NFT 结构体需要 `key` ability（如需自由交易还需 `store`）
- 通过动态对象字段可实现 NFT 的组合和嵌套（如英雄装备武器）
- `Display` 标准定义前端展示模板，支持字段自动填充
- `Publisher` 对象证明包的发布者身份，是创建 Display 的前提
- PTB 可以在一次交易中完成铸造、装备和转移等多步操作
