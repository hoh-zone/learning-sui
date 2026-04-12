# Treasury Cap 管理

`TreasuryCap` 是 Sui Coin 标准中的核心权限对象，控制着代币的铸造和销毁。如何管理 `TreasuryCap` 直接决定了代币的供应模型——是无限供应、固定供应还是可控供应。本节将深入探讨不同的 TreasuryCap 管理策略。

## TreasuryCap 的角色

```move
public struct TreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: Supply<T>,
}
```

`TreasuryCap` 持有者拥有以下权限：

- **铸造**：通过 `coin::mint` 创建新代币
- **销毁**：通过 `coin::burn` 销毁代币
- **查询总供应量**：通过 `total_supply()` 获取当前总供应量
- **更新元数据**：持有 `MetadataCap` 时可通过 `coin_registry::set_name` 等更新链上 `Currency` 元数据

## 无限供应模型

最简单的模型——`TreasuryCap` 持有者可以随时铸造新代币：

```move
module game::gold;

use std::string;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry;

public struct GOLD() has drop;

fun init(otw: GOLD, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<GOLD>(
        otw, 9,
        string::utf8(b"GOLD"),
        string::utf8(b"Gold"),
        string::utf8(b"Game currency"),
        string::utf8(b""),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}

public fun mint(
    treasury_cap: &mut TreasuryCap<GOLD>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient);
}

public fun burn(
    treasury_cap: &mut TreasuryCap<GOLD>,
    coin: coin::Coin<GOLD>,
) {
    coin::burn(treasury_cap, coin);
}
```

## 固定供应模型

在 `init` 中铸造全部供应量，然后锁定 `TreasuryCap` 使其无法再铸造：

```move
module fixed_supply::silver;

use std::string;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry;
use sui::dynamic_object_field as dof;

public struct SILVER() has drop;

public struct Freezer has key {
    id: UID,
}

public struct TreasuryCapKey() has copy, drop, store;

const TOTAL_SUPPLY: u64 = 10_000_000_000_000_000_000;

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (initializer, mut treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        otw, 9,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Fixed supply token"),
        string::utf8(b""),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(metadata_cap, ctx.sender());

    // 铸造全部供应量
    let coin = coin::mint(&mut treasury_cap, TOTAL_SUPPLY, ctx);
    transfer::public_transfer(coin, ctx.sender());

    // 将 TreasuryCap 锁入 Freezer 的动态对象字段
    let mut freezer = Freezer { id: object::new(ctx) };
    dof::add(&mut freezer.id, TreasuryCapKey(), treasury_cap);

    // 冻结 Freezer，使 TreasuryCap 永远无法取出
    transfer::freeze_object(freezer);
}
```

### 锁定策略解析

1. **铸造全部供应量**并转移给发布者
2. **将 TreasuryCap 放入 Freezer**的动态对象字段中
3. **冻结 Freezer**——一旦冻结，其中的 TreasuryCap 无法取出，也就无法再铸造

这样代币的总供应量就被永久固定了。TreasuryCap 仍然存在（可被索引器查询），但无法使用。

## 可控供应模型

通过智能合约逻辑控制铸造，而非直接暴露 `TreasuryCap`：

```move
module game::reward_token;

use std::string;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry;

public struct REWARD_TOKEN() has drop;

public struct MintCap has key {
    id: UID,
    max_per_mint: u64,
    total_minted: u64,
    max_supply: u64,
}

const EExceedsMaxPerMint: u64 = 1;
const EExceedsMaxSupply: u64 = 2;

fun init(otw: REWARD_TOKEN, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<REWARD_TOKEN>(
        otw, 9,
        string::utf8(b"RWD"),
        string::utf8(b"Reward Token"),
        string::utf8(b"Reward"),
        string::utf8(b""),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);

    // TreasuryCap 共享，通过 MintCap 控制访问
    transfer::public_share_object(treasury_cap);
    transfer::public_transfer(metadata_cap, ctx.sender());

    transfer::transfer(MintCap {
        id: object::new(ctx),
        max_per_mint: 1_000_000_000,
        total_minted: 0,
        max_supply: 100_000_000_000_000_000,
    }, ctx.sender());
}

public fun controlled_mint(
    treasury_cap: &mut TreasuryCap<REWARD_TOKEN>,
    mint_cap: &mut MintCap,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(amount <= mint_cap.max_per_mint, EExceedsMaxPerMint);
    assert!(
        mint_cap.total_minted + amount <= mint_cap.max_supply,
        EExceedsMaxSupply,
    );

    let coin = coin::mint(treasury_cap, amount, ctx);
    mint_cap.total_minted = mint_cap.total_minted + amount;
    transfer::public_transfer(coin, recipient);
}
```

## 销毁 TreasuryCap

另一种确保固定供应的方式——直接销毁 TreasuryCap（如果框架支持）或将其转移到无人能访问的地址：

```move
// 将 TreasuryCap 转移给 0x0 地址（事实上销毁）
transfer::public_transfer(treasury_cap, @0x0);
```

## 测试固定供应

```move
#[test_only]
use sui::coin::Coin;
use sui::dynamic_object_field as dof;
use sui::test_scenario;

#[test]
fun fixed_supply_init() {
    let publisher = @0x11111;
    let mut scenario = test_scenario::begin(publisher);

    init(SILVER(), scenario.ctx());
    scenario.next_tx(publisher);
    {
        // 验证 Freezer 被冻结且包含 TreasuryCap
        let freezer = scenario.take_immutable<Freezer>();
        assert!(dof::exists_(&freezer.id, TreasuryCapKey()));

        let cap: &TreasuryCap<SILVER> = dof::borrow(&freezer.id, TreasuryCapKey());
        assert_eq!(cap.total_supply(), TOTAL_SUPPLY);

        // 验证全部供应量转移给了发布者
        let coin = scenario.take_from_sender<Coin<SILVER>>();
        assert_eq!(coin.value(), TOTAL_SUPPLY);

        scenario.return_to_sender(coin);
        test_scenario::return_immutable(freezer);
    };
    scenario.end();
}
```

## 小结

- `TreasuryCap` 是代币铸造和销毁的核心权限对象
- **无限供应**：持有者随时可铸造，适合游戏货币等场景
- **固定供应**：在 `init` 中铸造全部供应量，然后锁定 TreasuryCap（放入冻结对象的 DOF）
- **可控供应**：通过额外的 `MintCap` 逻辑控制铸造量和频率
- TreasuryCap 的管理方式直接决定了代币的经济模型
