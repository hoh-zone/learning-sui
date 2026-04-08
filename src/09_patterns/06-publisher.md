# Publisher 权限

Publisher（发布者）是 Sui 框架提供的一种权限对象，用于**证明某个地址是某个包（package）的发布者**。它在创建 `Display` 对象和 `TransferPolicy` 时是必需的，是连接链上包与链下展示的关键桥梁。

本章将介绍 Publisher 的定义、获取方式、验证机制以及实际应用场景。

## Publisher 的定义

`Publisher` 定义在 `sui::package` 模块中，其结构如下（简化版）：

```move
// sui::package 模块中的定义（简化）
public struct Publisher has key, store {
    id: UID,
    package: String,
    module_name: String,
}
```

核心字段：

- `package`：包的地址（发布时确定）
- `module_name`：模块名称

Publisher 具有 `key` 和 `store` 能力，这意味着它是一个可以被自由转移和存储的对象。

## 获取 Publisher

Publisher 只能通过 `package::claim` 函数获取，该函数要求传入一个 OTW（一次性见证者）：

```move
module examples::my_publisher;

use sui::package;
use std::string::String;

public struct MY_PUBLISHER has drop {}

public struct Item has key, store {
    id: UID,
    name: String,
}

fun init(otw: MY_PUBLISHER, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    transfer::public_transfer(publisher, ctx.sender());
}
```

关键点：

1. `package::claim` 消耗 OTW，因此每个模块只能创建一个 Publisher
2. Publisher 被转移给部署者（`ctx.sender()`）
3. 使用 `public_transfer` 是因为 Publisher 有 `store` 能力

## 验证机制

Publisher 提供了两个验证函数来检查类型与 Publisher 的关系：

### from_module\<T\>

验证类型 `T` 是否定义在 Publisher 对应的模块中：

```move
/// 验证 Item 是否属于 Publisher 对应的模块
public fun authorized_action(publisher: &package::Publisher) {
    assert!(package::from_module<Item>(publisher), 0);
    // 只有当 Item 定义在 publisher 对应的模块中，才会通过
}
```

### from_package\<T\>

验证类型 `T` 是否定义在 Publisher 对应的包中（可以是不同模块）：

```move
/// 验证类型是否属于同一个包（可以是不同模块）
public fun package_level_check(publisher: &package::Publisher) {
    assert!(package::from_package<Item>(publisher), 0);
}
```

两者的区别：

| 函数 | 检查范围 | 用途 |
|------|---------|------|
| `from_module<T>` | 精确到模块 | 模块级别的权限验证 |
| `from_package<T>` | 整个包 | 包级别的权限验证 |

## Publisher 的核心用途

### 1. 创建 Display 对象

`Display<T>` 对象定义了类型 `T` 在钱包、浏览器等客户端中的展示方式。创建 `Display` 需要 Publisher 来证明调用者有权为该类型定义展示规则：

```move
module examples::hero_display;

use sui::package;
use sui::display;
use std::string::String;

public struct HERO_DISPLAY has drop {}

public struct Hero has key, store {
    id: UID,
    name: String,
    power: u64,
}

fun init(otw: HERO_DISPLAY, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let keys = vector[
        std::string::utf8(b"name"),
        std::string::utf8(b"description"),
        std::string::utf8(b"image_url"),
    ];

    let values = vector[
        std::string::utf8(b"{name}"),
        std::string::utf8(b"A hero with {power} power"),
        std::string::utf8(b"https://example.com/heroes/{name}.png"),
    ];

    let mut disp = display::new_with_fields<Hero>(
        &publisher,  // 需要 Publisher 引用
        keys,
        values,
        ctx,
    );
    display::update_version(&mut disp);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());
}
```

### 2. 创建 TransferPolicy

`TransferPolicy<T>` 定义了类型 `T` 在交易所/市场中的转移规则（如版税）。同样需要 Publisher：

```move
module examples::marketplace_policy;

use sui::package;
use sui::transfer_policy;

public struct MARKETPLACE_POLICY has drop {}

public struct Collectible has key, store {
    id: UID,
    rarity: u64,
}

fun init(otw: MARKETPLACE_POLICY, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let (policy, policy_cap) = transfer_policy::new<Collectible>(
        &publisher,  // 需要 Publisher
        ctx,
    );

    transfer::public_share_object(policy);
    transfer::public_transfer(policy_cap, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());
}
```

### 3. 类型权限验证

Publisher 也可以用作通用的权限验证机制：

```move
module examples::admin_ops;

use sui::package;
use std::string::String;

public struct Config has key {
    id: UID,
    name: String,
    value: u64,
}

/// 使用 Publisher 验证调用者身份
public fun update_config(
    publisher: &package::Publisher,
    config: &mut Config,
    new_value: u64,
) {
    // 验证 Publisher 确实属于定义 Config 的模块
    assert!(package::from_module<Config>(publisher), 0);
    config.value = new_value;
}
```

## Publisher 的安全考量

### Publisher 不是唯一的管理员方案

虽然 Publisher 可以用于权限控制，但它有一些限制：

1. **一个模块只有一个 Publisher**：不支持多管理员场景
2. **权限范围固定**：Publisher 的权限与模块/包绑定，无法细粒度控制
3. **可被转移**：如果 Publisher 被意外转移，权限也会随之转移

因此，对于复杂的权限管理场景，推荐结合 Capability 模式使用：

```move
module examples::combined_auth;

use sui::package;

public struct COMBINED_AUTH has drop {}

/// 自定义管理员能力
public struct AdminCap has key { id: UID }

fun init(otw: COMBINED_AUTH, ctx: &mut TxContext) {
    // Publisher 用于 Display 和 TransferPolicy
    let publisher = package::claim(otw, ctx);
    transfer::public_transfer(publisher, ctx.sender());

    // AdminCap 用于业务逻辑的权限控制
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

/// Display 相关操作用 Publisher
public fun setup_display(publisher: &package::Publisher) {
    assert!(package::from_module<AdminCap>(publisher), 0);
    // 设置 Display...
}

/// 业务操作用 AdminCap
public fun admin_action(_: &AdminCap) {
    // 执行管理操作...
}
```

### 保管好 Publisher

Publisher 是高权限对象，建议：

| 建议 | 原因 |
|------|------|
| 妥善保管 | 丢失后无法重新创建 |
| 不要随意转移 | 转移后原持有者失去权限 |
| 考虑冻结 | 如果不再需要修改 Display，可以冻结 Publisher |
| 使用多签钱包持有 | 防止单点故障 |

## Publisher 的生命周期

```
包发布
  │
  ├── init() 被调用
  │     │
  │     ├── package::claim(otw) → 创建 Publisher
  │     │
  │     └── transfer Publisher 给部署者
  │
  ├── 使用 Publisher 创建 Display
  │
  ├── 使用 Publisher 创建 TransferPolicy
  │
  └── 持续持有 Publisher 以便未来更新
       或冻结 Publisher（如果不再需要更新）
```

## 小结

Publisher 是 Sui 框架中证明包发布者身份的核心对象。它通过 `package::claim` 与 OTW 配合创建，确保每个模块只有一个 Publisher。Publisher 的主要用途是创建 `Display` 和 `TransferPolicy`，这两个功能是 Sui NFT 生态的基础。在实际项目中，应将 Publisher 与 Capability 模式结合使用——Publisher 负责框架级别的权限（Display、TransferPolicy），Capability 负责业务级别的权限控制。
