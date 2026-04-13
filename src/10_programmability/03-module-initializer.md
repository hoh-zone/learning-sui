# 模块初始化器 init

`init` 函数是 Sui Move 中特殊的模块初始化器，它在模块发布（publish）时被自动调用且仅调用一次。`init` 函数是设置模块初始状态、创建管理员权限对象、初始化共享资源的标准方式。理解 `init` 函数的规则和限制，对于正确设计合约的启动流程至关重要。

## 基本规则

`init` 函数有一组严格的约束条件：

| 规则 | 说明 |
|------|------|
| 函数名 | 必须命名为 `init`，不能是其他名称 |
| 可见性 | 必须是 **`private`**（不加任何可见性修饰符） |
| 返回值 | **不能有返回值** |
| 参数 | 接受 1 或 2 个参数（见下文） |
| 调用时机 | 模块**发布时**自动调用，**仅调用一次** |
| 升级时 | 包升级时**不会**再次调用 |

### 参数形式

`init` 函数支持两种参数签名：

1. **仅 TxContext**：`fun init(ctx: &mut TxContext)`
2. **OTW + TxContext**：`fun init(otw: MY_TYPE, ctx: &mut TxContext)`

TxContext 始终是最后一个参数，可以是 `&mut TxContext` 或 `&TxContext`（推荐使用 `&mut`，因为大多数情况下需要创建对象）。

## 基本用法

最常见的 `init` 用法是创建管理员权限能力对象（AdminCap）并建立模块的初始状态。

```move
module examples::shop;

use std::string::String;

public struct ShopOwnerCap has key {
    id: UID,
}

public struct Shop has key {
    id: UID,
    name: String,
    item_count: u64,
}

/// 模块发布时调用一次
fun init(ctx: &mut TxContext) {
    // 创建管理员权限对象
    let owner_cap = ShopOwnerCap { id: object::new(ctx) };
    transfer::transfer(owner_cap, ctx.sender());

    // 创建并共享商店对象
    let shop = Shop {
        id: object::new(ctx),
        name: b"My Shop".to_string(),
        item_count: 0,
    };
    transfer::share_object(shop);
}

/// 只有持有 ShopOwnerCap 的人才能添加商品
public fun add_item(_: &ShopOwnerCap, shop: &mut Shop) {
    shop.item_count = shop.item_count + 1;
}
```

在上面的例子中，`init` 做了两件事：

1. 创建了一个 `ShopOwnerCap` 对象并转移给模块发布者——这赋予了发布者管理商店的权限
2. 创建了一个 `Shop` 共享对象——这是所有用户都可以交互的公共资源

## 一次性见证 OTW 变体

当 `init` 函数的第一个参数是**一次性见证（One-Time Witness，OTW）**类型时，Sui 虚拟机会自动创建该类型的实例并传入。OTW 提供了**密码学级别的保证**，证明该代码只在模块发布时执行了一次。

### OTW 类型规则

OTW 类型必须满足以下条件：

- 以模块名命名，全部大写（如模块名为 `shop`，则 OTW 类型为 `SHOP`）
- 只有 `drop` 能力（`has drop`）
- 没有任何字段
- 不是泛型类型

```move
module examples::shop_otw;

/// OTW：以模块名大写命名，只有 drop 能力，没有字段
public struct SHOP_OTW has drop {}

fun init(otw: SHOP_OTW, ctx: &mut TxContext) {
    // otw 证明这是模块发布时的首次且唯一的调用
    // 常用于创建 Publisher、定义 Coin 类型等
    let _ = otw;
    let _ = ctx;
}
```

### OTW 的典型应用

OTW 最常见的用途是配合 `sui::package::claim()` 创建 `Publisher` 对象，或配合 **`sui::coin_registry::new_currency_with_otw` + `finalize`** 创建自定义代币（`coin::create_currency` 已废弃）：

```move
module examples::my_token;

use std::string;
use sui::coin_registry;

public struct MY_TOKEN has drop {}

fun init(otw: MY_TOKEN, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<MY_TOKEN>(
        otw,                                    // OTW 证明唯一性
        9,                                      // 精度
        string::utf8(b"MYT"),                   // 符号
        string::utf8(b"My Token"),              // 名称
        string::utf8(b"A demo token"),          // 描述
        string::utf8(b"https://example.com/icon.png"), // 图标 URL
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

## 初始化模式

### 模式一：能力对象（Capability Pattern）

这是最常见的 `init` 模式——创建一个权限对象来控制后续操作的访问。

```move
module examples::admin_cap;

public struct AdminCap has key, store {
    id: UID,
}

public struct Config has key {
    id: UID,
    paused: bool,
    fee_bps: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );

    transfer::share_object(Config {
        id: object::new(ctx),
        paused: false,
        fee_bps: 100,  // 1%
    });
}

public fun set_fee(_: &AdminCap, config: &mut Config, new_fee: u64) {
    config.fee_bps = new_fee;
}

public fun pause(_: &AdminCap, config: &mut Config) {
    config.paused = true;
}

public fun unpause(_: &AdminCap, config: &mut Config) {
    config.paused = false;
}
```

### 模式二：共享状态初始化

初始化全局共享状态，供所有用户使用：

```move
module examples::registry;

use sui::table::{Self, Table};

public struct Registry has key {
    id: UID,
    entries: Table<address, vector<u8>>,
    total_count: u64,
}

const EAlreadyRegistered: u64 = 0;

fun init(ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        entries: table::new(ctx),
        total_count: 0,
    };
    transfer::share_object(registry);
}

public fun register(registry: &mut Registry, data: vector<u8>, ctx: &TxContext) {
    let sender = ctx.sender();
    assert!(!registry.entries.contains(sender), EAlreadyRegistered);
    registry.entries.add(sender, data);
    registry.total_count = registry.total_count + 1;
}
```

### 模式三：Publisher + Display

结合 OTW 创建 `Publisher` 和 `Display` 对象，为 NFT 或其他对象类型设置链下展示属性：

```move
module examples::nft_init;

use std::string::utf8;
use sui::package;
use sui::display;

public struct NFT_INIT has drop {}

public struct GameNFT has key, store {
    id: UID,
    name: vector<u8>,
    image_url: vector<u8>,
    level: u64,
}

fun init(otw: NFT_INIT, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let keys = vector[
        utf8(b"name"),
        utf8(b"image_url"),
        utf8(b"description"),
        utf8(b"project_url"),
    ];
    let values = vector[
        utf8(b"{name}"),
        utf8(b"{image_url}"),
        utf8(b"Game NFT Level {level}"),
        utf8(b"https://example-game.com"),
    ];

    let mut disp = display::new_with_fields<GameNFT>(
        &publisher, keys, values, ctx,
    );
    display::update_version(&mut disp);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());
}
```

## 安全注意事项

### init 不是万能的安全保障

虽然 `init` 只执行一次，但仅依靠 `init` 函数本身并不能提供强安全保证。如果你需要证明某段逻辑确实只在模块发布时执行过一次，应该使用**一次性见证（OTW）**机制。

```move
module examples::secure_init;

use sui::types;

public struct SECURE_INIT has drop {}

public struct InitProof has key {
    id: UID,
}

fun init(otw: SECURE_INIT, ctx: &mut TxContext) {
    // 显式验证 OTW 合法性
    assert!(types::is_one_time_witness(&otw), 0);

    transfer::transfer(
        InitProof { id: object::new(ctx) },
        ctx.sender(),
    );
}
```

### 升级时不会重新调用

当你升级一个已发布的包时，`init` 函数**不会再次执行**。如果升级后需要执行初始化逻辑，你需要通过其他方式实现（例如提供一个需要 AdminCap 权限的初始化函数）。

```move
module examples::upgradeable;

public struct AdminCap has key {
    id: UID,
}

public struct State has key {
    id: UID,
    version: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    transfer::share_object(State {
        id: object::new(ctx),
        version: 1,
    });
}

/// 升级后手动调用的迁移函数
public fun migrate(_: &AdminCap, state: &mut State) {
    state.version = 2;
}
```

## 测试 init 函数

在单元测试中，`init` 函数不会自动调用。你需要手动调用它来测试初始化逻辑：

```move
#[test_only]
module examples::shop_tests;

use examples::shop;

#[test]
fun init_runs() {
    let mut ctx = tx_context::dummy();
    // 在测试中手动调用 init
    shop::init_for_testing(&mut ctx);
}
```

为了支持测试，通常需要在模块中添加一个测试辅助函数：

```move
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
```

## 小结

`init` 函数是 Sui Move 的模块初始化器，在模块发布时自动调用且仅调用一次。它必须命名为 `init`、保持私有、没有返回值，参数为可选的 OTW 加上 TxContext。最常见的用途包括创建管理员权限对象（AdminCap 模式）、初始化共享状态、以及配合 OTW 创建 Publisher 和代币类型。需要注意的是，包升级时 `init` 不会重新执行，因此对于可升级合约需要设计额外的迁移机制。安全敏感的初始化操作应结合 OTW 机制来提供更强的保证。
