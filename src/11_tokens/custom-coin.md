# 创建自定义 Coin

Sui 的 `coin` 模块提供了标准化的同质化代币（Fungible Token）创建机制。通过 `coin::create_currency` 函数，你可以在模块初始化时创建具有自定义元数据的代币。本节将详细介绍如何从零开始创建一个自定义 Coin。

## Coin 标准概述

Sui 上的 Coin 标准基于以下核心概念：

- **One-Time Witness (OTW)**：一次性见证者，确保代币类型只能被创建一次
- **TreasuryCap**：铸造权凭证，持有者可以铸造和销毁代币
- **CoinMetadata**：代币元数据对象，存储名称、符号、精度等信息

## 定义代币类型

首先定义一个一次性见证者结构体。它必须与模块名同名（大写），且只有 `drop` ability：

```move
module silver::silver;

use sui::coin::{TreasuryCap, CoinMetadata};
use sui::url;

/// One-Time Witness，必须与模块名同名
public struct SILVER() has drop;
```

## 创建代币

在 `init` 函数中使用 `coin::create_currency` 创建代币：

```move
const DECIMALS: u8 = 9;
const NAME: vector<u8> = b"Silver";
const SYMBOL: vector<u8> = b"SILVER";
const DESCRIPTION: vector<u8> = b"Silver, commonly used by heroes";
const ICON_URL: vector<u8> = b"https://example.com/silver.png";

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency<SILVER>(
        otw,
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(ICON_URL)),
        ctx,
    );

    // TreasuryCap 转移给发布者
    transfer::public_transfer(treasury_cap, ctx.sender());
    // CoinMetadata 冻结为不可变对象
    transfer::public_freeze_object(metadata);
}
```

### 参数说明

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `otw` | `SILVER` | 一次性见证者，证明这是首次创建 |
| `DECIMALS` | `u8` | 精度，9 表示最小单位为 10^-9 |
| `SYMBOL` | `vector<u8>` | 代币符号，如 "SILVER" |
| `NAME` | `vector<u8>` | 代币名称，如 "Silver" |
| `DESCRIPTION` | `vector<u8>` | 代币描述 |
| `icon_url` | `Option<Url>` | 代币图标 URL |
| `ctx` | `&mut TxContext` | 交易上下文 |

### 返回值

`create_currency` 返回一个元组 `(TreasuryCap<T>, CoinMetadata<T>)`：

- **TreasuryCap<T>**：铸造权凭证，持有此对象的人可以铸造和销毁 `T` 类型的代币
- **CoinMetadata<T>**：代币元数据，通常冻结为不可变对象供链上查询

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

```move
#[test_only]
use sui::coin::Coin;
use sui::test_utils::destroy;

#[test]
fun create_currency() {
    let mut ctx = tx_context::dummy();
    let (treasury_cap, metadata) = coin::create_currency<SILVER>(
        SILVER(),
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(ICON_URL)),
        &mut ctx,
    );

    assert_eq!(treasury_cap.total_supply(), 0);
    assert_eq!(metadata.get_decimals(), DECIMALS);
    assert_eq!(metadata.get_name(), NAME.to_string());
    assert_eq!(metadata.get_symbol(), SYMBOL.to_ascii_string());

    destroy(treasury_cap);
    destroy(metadata);
}

#[test]
fun mint_and_burn() {
    let amount = 10_000_000_000;
    let mut ctx = tx_context::dummy();
    let (mut treasury_cap, metadata) = coin::create_currency<SILVER>(
        SILVER(),
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(ICON_URL)),
        &mut ctx,
    );

    // 铸造
    let coin = coin::mint(&mut treasury_cap, amount, &mut ctx);
    assert_eq!(coin.value(), amount);
    assert_eq!(treasury_cap.total_supply(), amount);

    // 销毁
    coin::burn(&mut treasury_cap, coin);
    assert_eq!(treasury_cap.total_supply(), 0);

    destroy(treasury_cap);
    destroy(metadata);
}
```

## 小结

- Coin 标准通过 `coin::create_currency` 创建，需要 One-Time Witness 确保唯一性
- `TreasuryCap` 是铸造权凭证，持有者可铸造和销毁代币
- `CoinMetadata` 通常冻结为不可变对象，供所有人查询代币信息
- `init` 函数是创建代币的标准位置，在模块发布时自动执行
- 代币精度（decimals）决定了最小单位，9 是最常用的精度值
