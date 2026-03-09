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

**`coin::create_currency` 已废弃**。应使用 **`coin_registry::new_currency_with_otw`** 与 **`coin_registry::finalize`**：元数据会写入链上 `CoinRegistry` 的 `Currency<T>`，并返回 **`MetadataCap<T>`** 用于后续更新。

```move
use std::string;
use sui::coin_registry;

fun init(otw: MY_TOKEN, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<MY_TOKEN>(
        otw,
        9,                                  // 精度
        string::utf8(b"MYT"),               // 符号
        string::utf8(b"My Token"),          // 名称
        string::utf8(b"A demo token on Sui"), // 描述
        string::utf8(b"https://example.com/icon.png"), // 图标 URL
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

## 读取元数据

使用新 API 时，元数据存储在 `CoinRegistry` 的 **`Currency<T>`** 中。需要通过 `CoinRegistry` 按类型 `T` 取到对应 `Currency` 后，用 **`coin_registry::decimals` / `name` / `symbol` / `description` / `icon_url`** 读取：

```move
use sui::coin_registry;

public fun display_info<T>(registry: &CoinRegistry, currency: &Currency<T>) {
    let decimals = coin_registry::decimals(currency);
    let name = coin_registry::name(currency);
    let symbol = coin_registry::symbol(currency);
    let description = coin_registry::description(currency);
    let icon_url = coin_registry::icon_url(currency);
}
```

（旧版 **`CoinMetadata<T>`** 仍可用于已用 `create_currency` 创建的老代币，通过 `get_decimals()`、`get_name()` 等读取。）

## 更新元数据

使用新 API 时，持有 **`MetadataCap<T>`** 的人可通过 **`coin_registry::set_*`** 更新链上 `Currency<T>` 的元数据：

```move
use sui::coin_registry;

public fun update_description<T>(
    currency: &mut Currency<T>,
    metadata_cap: &MetadataCap<T>,
    new_description: std::string::String,
) {
    coin_registry::set_description(currency, metadata_cap, new_description);
}

public fun update_name<T>(
    currency: &mut Currency<T>,
    metadata_cap: &MetadataCap<T>,
    new_name: std::string::String,
) {
    coin_registry::set_name(currency, metadata_cap, new_name);
}

public fun update_icon_url<T>(
    currency: &mut Currency<T>,
    metadata_cap: &MetadataCap<T>,
    new_url: std::string::String,
) {
    coin_registry::set_icon_url(currency, metadata_cap, new_url);
}
```

> `Currency` 由 `CoinRegistry` 管理；若调用 **`coin_registry::delete_metadata_cap`** 删除 `MetadataCap`，则之后无法再更新该代币元数据。

## 元数据的处理策略（新 API）

使用 **coin_registry** 时，元数据在链上 `Currency<T>` 中，由 `CoinRegistry` 管理：

- **MetadataCap** 转移给发行方，持有者可调用 `coin_registry::set_name` 等更新元数据。
- 若不再需要更新，可调用 **`coin_registry::delete_metadata_cap`** 永久删除 `MetadataCap`，此后该代币元数据不可再改。

（旧 API 下可将 `CoinMetadata` 冻结或转移，新 API 下不再单独冻结元数据对象。）

## 测试元数据

使用 **coin_registry** 时，测试中可用 **`coin_registry::create_coin_data_registry_for_testing`** 创建测试用 Registry，用 **`finalize_for_testing`** 得到 `(Currency, MetadataCap)`，再通过 **`coin_registry::decimals(currency)`** 等读取：

```move
#[test]
fun metadata_fields() {
    use std::string;
    use std::unit_test::assert_eq;
    use std::unit_test::destroy;
    use sui::coin_registry;

    let mut ctx = tx_context::dummy();
    let (initializer, _treasury_cap) = coin_registry::new_currency_with_otw<MY_TOKEN>(
        MY_TOKEN(), 6,
        string::utf8(b"MYT"),
        string::utf8(b"My Token"),
        string::utf8(b"A demo token"),
        string::utf8(b""),
        &mut ctx,
    );
    let (currency, metadata_cap) = coin_registry::finalize_for_testing(initializer, &mut ctx);

    assert_eq!(coin_registry::decimals(&currency), 6);
    assert_eq!(coin_registry::symbol(&currency), string::utf8(b"MYT"));
    assert_eq!(coin_registry::name(&currency), string::utf8(b"My Token"));
    assert_eq!(coin_registry::description(&currency), string::utf8(b"A demo token"));
    assert_eq!(coin_registry::icon_url(&currency), string::utf8(b""));
}
```

## 小结

- 新代币应使用 **`coin_registry::new_currency_with_otw` + `finalize`** 创建；元数据存储在链上 **`Currency<T>`** 中，由 `CoinRegistry` 管理
- **`MetadataCap<T>`** 用于更新元数据（`set_name`、`set_description`、`set_icon_url`）；删除后不可再更新
- 精度（decimals）决定代币的最小可分割单位，最常见值为 9 和 6
- 旧版 **`coin::create_currency`** 与 **`CoinMetadata<T>`** 已废弃，仅适用于历史代币
