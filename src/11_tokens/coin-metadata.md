# Coin 元数据

每个 Coin 类型都有对应的 `CoinMetadata` 对象，存储代币的名称、符号、精度、描述和图标等信息。元数据通常在代币创建时设置，然后冻结为不可变对象供全链查询。本节将深入介绍 Coin 元数据的各个方面。

## CoinMetadata 结构

`CoinMetadata` 是一个 Sui 对象，包含以下字段：

```move
public struct CoinMetadata<phantom T> has key, store {
    id: UID,
    decimals: u8,
    name: string::String,
    symbol: ascii::String,
    description: string::String,
    icon_url: Option<Url>,
}
```

### 字段说明

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `decimals` | `u8` | 精度，决定最小可分割单位 |
| `name` | `String` | 代币全名，如 "Silver" |
| `symbol` | `ascii::String` | 代币符号（ASCII），如 "SILVER" |
| `description` | `String` | 代币描述文本 |
| `icon_url` | `Option<Url>` | 代币图标的 URL |

## 精度（Decimals）

精度决定了代币的最小可分割单位。最常见的精度值：

- **9**：最常用，1 个代币 = 10^9 个最小单位（类似 SUI 的精度）
- **6**：类似 USDC/USDT
- **0**：不可分割的代币（如积分、票据）

```move
// 精度为 9 时：
// 1 SILVER = 1_000_000_000 (10^9) 最小单位
// 0.5 SILVER = 500_000_000

// 精度为 6 时：
// 1 USDC = 1_000_000 (10^6) 最小单位

// 精度为 0 时：
// 1 POINT = 1（不可分割）
```

## 创建元数据

元数据由 `coin::create_currency` 自动创建并返回：

```move
fun init(otw: MY_TOKEN, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency<MY_TOKEN>(
        otw,
        9,                          // 精度
        b"MYT",                     // 符号
        b"My Token",                // 名称
        b"A demo token on Sui",     // 描述
        option::some(url::new_unsafe_from_bytes(
            b"https://example.com/icon.png"
        )),
        ctx,
    );

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_freeze_object(metadata);
}
```

## 读取元数据

`CoinMetadata` 提供了读取各字段的方法：

```move
use sui::coin::CoinMetadata;

public fun display_info<T>(metadata: &CoinMetadata<T>) {
    let decimals = metadata.get_decimals();
    let name = metadata.get_name();
    let symbol = metadata.get_symbol();
    let description = metadata.get_description();
    let icon_url = metadata.get_icon_url();
}
```

## 更新元数据

在冻结之前，持有 `TreasuryCap` 的人可以更新元数据：

```move
use sui::coin;

public fun update_description<T>(
    treasury_cap: &TreasuryCap<T>,
    metadata: &mut CoinMetadata<T>,
    new_description: string::String,
) {
    coin::update_description(treasury_cap, metadata, new_description);
}

public fun update_name<T>(
    treasury_cap: &TreasuryCap<T>,
    metadata: &mut CoinMetadata<T>,
    new_name: string::String,
) {
    coin::update_name(treasury_cap, metadata, new_name);
}

public fun update_symbol<T>(
    treasury_cap: &TreasuryCap<T>,
    metadata: &mut CoinMetadata<T>,
    new_symbol: ascii::String,
) {
    coin::update_symbol(treasury_cap, metadata, new_symbol);
}

public fun update_icon_url<T>(
    treasury_cap: &TreasuryCap<T>,
    metadata: &mut CoinMetadata<T>,
    new_url: ascii::String,
) {
    coin::update_icon_url(treasury_cap, metadata, new_url);
}
```

> 一旦 `CoinMetadata` 被 `freeze_object` 冻结，就无法再更新。因此在冻结前务必确认所有信息正确。

## 元数据的处理策略

### 方案一：冻结（推荐）

将元数据冻结为不可变对象，任何人都可以引用但无人可修改：

```move
transfer::public_freeze_object(metadata);
```

### 方案二：保持可变

不冻结元数据，保留由 `TreasuryCap` 持有者更新的能力：

```move
transfer::public_transfer(metadata, ctx.sender());
```

### 方案三：共享

将元数据设为共享对象（不太常见）：

```move
transfer::public_share_object(metadata);
```

## 测试元数据

```move
#[test]
fun metadata_fields() {
    use std::unit_test::assert_eq;
    use sui::test_utils::destroy;

    let mut ctx = tx_context::dummy();
    let (treasury_cap, metadata) = coin::create_currency<MY_TOKEN>(
        MY_TOKEN(),
        6,
        b"MYT",
        b"My Token",
        b"A demo token",
        option::none(),
        &mut ctx,
    );

    assert_eq!(metadata.get_decimals(), 6);
    assert_eq!(metadata.get_symbol(), b"MYT".to_ascii_string());
    assert_eq!(metadata.get_name(), b"My Token".to_string());
    assert_eq!(metadata.get_description(), b"A demo token".to_string());
    assert!(metadata.get_icon_url().is_none());

    destroy(treasury_cap);
    destroy(metadata);
}
```

## 小结

- `CoinMetadata` 存储代币的名称、符号、精度、描述和图标 URL
- 精度（decimals）决定代币的最小可分割单位，最常见值为 9 和 6
- 元数据由 `create_currency` 自动创建，通常冻结为不可变对象
- 持有 `TreasuryCap` 可在冻结前更新元数据字段
- 冻结后的元数据不可修改，确保代币信息的永久一致性
