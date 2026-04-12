# 注册与 OTW：创建币种类型

## 导读

本节对应 **`sui::coin_registry`**：用 **OTW（一次性见证）** 保证 **`Currency<T>`** 只注册一次，并把 **`TreasuryCap<T>`**、**`MetadataCap<T>`** 交给部署者。与 [§11.3 · init](../11_programmability/03-module-initializer.md)、[第十二章 · OTW](../12_patterns/03-one-time-witness.md) 强相关。

- **前置**：[§14.1 · 本章导论](01-overview.md)  
- **后续**：[§14.3 · 元数据](03-coin-metadata.md)  

---

## 为什么必须 OTW

每种代币类型 `T` 在链上只能有一条 **canonical 元数据 + 一条供应曲线入口**（`TreasuryCap`）。OTW 类型 **`MYCOIN` has drop** 与模块同名、仅发布时可得实例，与 `coin_registry::new_currency_with_otw` 绑定，防止重复「创世」。

## 最小创建流程

```move
module example::silver;

use std::string;
use sui::coin_registry;

public struct SILVER() has drop;

const DECIMALS: u8 = 9;

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        otw,
        DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Hero currency"),
        string::utf8(b"https://example.com/silver.png"),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

- **`new_currency_with_otw`**：创建 **`CurrencyInitializer<T>`** + **`TreasuryCap<T>`**。  
- **`finalize`**：把 **`Currency<T>`** 登记进 **`CoinRegistry`**（共享注册表），并产出 **`MetadataCap<T>`**。

## 受监管分支（预告）

若需要 **DenyList**，在 `finalize` 前对 `initializer` 调用 **`coin_registry::make_regulated`**，得到 **`DenyCapV2<T>`**——详见 [§14.8](08-regulated-denylist.md)。

## 铸造入口（衔接下一节）

拿到 **`TreasuryCap`** 后即可 **`coin::mint`**，铸出的 **`Coin<T>`** 即用户的 **Owner Coin**（见 [§14.5](05-owner-coin.md)）。

```move
use sui::coin::{Self, Coin, TreasuryCap};

public fun mint(
    cap: &mut TreasuryCap<SILVER>,
    amount: u64,
    to: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(cap, amount, ctx);
    transfer::public_transfer(c, to);
}
```

## 小结

**`coin_registry`** 把 **OTW → Currency 登记 + TreasuryCap** 串成标准发币路径；**`finalize`** 后元数据由共享 **`Currency<T>`** 承载。下一节专门讲 **元数据字段与 `MetadataCap`**。
