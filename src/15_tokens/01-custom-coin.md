# 创建自定义 Coin

Sui 的 **coin_registry** 与 **coin** 模块提供了标准化的同质化代币创建机制。通过 **`coin_registry::new_currency_with_otw`** 与 **`finalize`**，你可以在模块初始化时创建代币并将元数据注册到链上（旧 API **`coin::create_currency`** 已废弃）。本节介绍如何从零开始创建一个自定义 Coin。

## Coin 标准概述

Sui 上的 Coin 标准基于以下核心概念：

- **One-Time Witness (OTW)**：一次性见证者，确保代币类型只能被创建一次
- **TreasuryCap**：铸造权凭证，持有者可以铸造和销毁代币
- **Currency / MetadataCap**：元数据由链上 **CoinRegistry** 的 **Currency<T>** 管理，**MetadataCap<T>** 用于更新元数据

## 定义代币类型

首先定义一个一次性见证者结构体。它必须与模块名同名（大写），且只有 `drop` ability：

```move
module silver::silver;

use std::string;
use sui::coin::{Self, TreasuryCap, Coin};
use sui::coin_registry;

/// One-Time Witness，必须与模块名同名
public struct SILVER() has drop;
```

## 创建代币

在 `init` 函数中使用 **`coin_registry::new_currency_with_otw`** 与 **`finalize`** 创建代币：

```move
const DECIMALS: u8 = 9;

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        otw,
        DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Silver, commonly used by heroes"),
        string::utf8(b"https://example.com/silver.png"),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

### 参数说明

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `otw` | `SILVER` | 一次性见证者，证明这是首次创建 |
| `decimals` | `u8` | 精度，9 表示最小单位为 10^-9 |
| `symbol` | `String` | 代币符号，如 `string::utf8(b"SILVER")` |
| `name` | `String` | 代币名称 |
| `description` | `String` | 代币描述 |
| `icon_url` | `String` | 图标 URL，无图标可传 `string::utf8(b"")` |
| `ctx` | `&mut TxContext` | 交易上下文 |

### 返回值

- **new_currency_with_otw** 返回 `(CurrencyInitializer<T>, TreasuryCap<T>)`
- **finalize(initializer, ctx)** 消耗 initializer 并返回 **MetadataCap<T>**；元数据写入链上 **Currency<T>**

## 铸造代币

使用 `TreasuryCap` 铸造新代币：

```move
public fun mint_silver(
    treasury_cap: &mut TreasuryCap<SILVER>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient);
}
```

## 销毁代币

使用 `TreasuryCap` 销毁代币：

```move
public fun burn_silver(
    treasury_cap: &mut TreasuryCap<SILVER>,
    coin: Coin<SILVER>,
) {
    coin::burn(treasury_cap, coin);
}
```

## 查询总供应量

```move
public fun total_supply(treasury_cap: &TreasuryCap<SILVER>): u64 {
    treasury_cap.total_supply()
}
```

## 测试

测试中可使用 **`coin_registry::finalize_for_testing`** 得到 `(Currency, MetadataCap)`，或直接使用 **finalize** 得到 `MetadataCap` 并断言 `treasury_cap.total_supply()` 等：

```move
#[test_only]
use std::string;
use sui::coin::Coin;
use sui::coin_registry;

#[test]
fun create_currency() {
    let mut ctx = tx_context::dummy();
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        SILVER(), DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Silver, commonly used by heroes"),
        string::utf8(b"https://example.com/silver.png"),
        &mut ctx,
    );
    let (currency, _metadata_cap) = coin_registry::finalize_for_testing(initializer, &mut ctx);

    assert_eq!(treasury_cap.total_supply(), 0);
    assert_eq!(coin_registry::decimals(&currency), DECIMALS);
    assert_eq!(coin_registry::name(&currency), string::utf8(b"Silver"));
    assert_eq!(coin_registry::symbol(&currency), string::utf8(b"SILVER"));
}

#[test]
fun mint_and_burn() {
    let amount = 10_000_000_000;
    let mut ctx = tx_context::dummy();
    let (initializer, mut treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        SILVER(), DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Silver, commonly used by heroes"),
        string::utf8(b""),
        &mut ctx,
    );
    let _ = coin_registry::finalize_for_testing(initializer, &mut ctx);

    let coin = coin::mint(&mut treasury_cap, amount, &mut ctx);
    assert_eq!(coin::value(&coin), amount);
    assert_eq!(treasury_cap.total_supply(), amount);

    coin::burn(&mut treasury_cap, coin);
    assert_eq!(treasury_cap.total_supply(), 0);
}
```

## 小结

- Coin 标准通过 **`coin_registry::new_currency_with_otw` + `finalize`** 创建（**`coin::create_currency`** 已废弃），需要 One-Time Witness 确保唯一性
- **TreasuryCap** 是铸造权凭证，持有者可铸造和销毁代币
- 元数据由链上 **Currency<T>** 管理，**MetadataCap<T>** 用于更新；链下/索引器可通过 CoinRegistry 查询
- `init` 函数是创建代币的标准位置，在模块发布时自动执行
- 代币精度（decimals）决定了最小单位，9 是最常用的精度值
