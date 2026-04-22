# 一次性见证（One Time Witness）

一次性见证（One Time Witness，简称 OTW）是 Witness 模式的特殊变体，它由系统保证**在整个合约生命周期中只被创建一次**。OTW 是 Sui 框架中许多核心功能的基础，包括代币创建（**`coin_registry::new_currency_with_otw`**）和发布者声明（`package::claim`）。

本章将详细介绍 OTW 的定义规则、系统行为以及典型应用场景。

## OTW 的定义规则

要让一个类型成为合法的 OTW，必须满足以下**全部条件**：

1. **名称为模块名的大写形式**：如模块名为 `my_token`，则 OTW 类型名必须为 `MY_TOKEN`
2. **只有 `drop` 能力**：不能有 `copy`、`key`、`store` 等其他能力
3. **没有任何字段**：必须是空结构体
4. **不是泛型**：不能有类型参数

```move
module examples::my_token;

/// 合法的 OTW：
/// ✅ 名称 = 模块名大写 (my_token → MY_TOKEN)
/// ✅ 只有 drop 能力
/// ✅ 没有字段
/// ✅ 不是泛型
public struct MY_TOKEN has drop {}
```

以下是一些**不合法**的 OTW 示例：

```move
module examples::bad_otw;

/// ❌ 名称不匹配模块名
public struct TOKEN has drop {}

/// ❌ 有额外能力
public struct BAD_OTW has drop, copy {}

/// ❌ 有字段
public struct BAD_OTW2 has drop { value: u64 }

/// ❌ 是泛型
public struct BAD_OTW3<T> has drop {}
```

## 系统如何提供 OTW

OTW 实例不是由开发者手动创建的，而是由 **Sui 运行时在模块发布时自动创建**，并作为 `init` 函数的第一个参数传入：

```move
module examples::my_token;

public struct MY_TOKEN has drop {}

fun init(otw: MY_TOKEN, ctx: &mut TxContext) {
    // otw 是系统创建的唯一实例
    // 在 init 执行完毕后，再也无法获得 MY_TOKEN 的实例
}
```

关键行为：

- `init` 函数在模块**发布时**被调用，且**只调用一次**
- OTW 实例由运行时在调用 `init` 前创建
- `init` 结束后，由于 OTW 有 `drop` 能力，实例被丢弃
- 由于 OTW 没有 `copy` 能力，无法复制
- 由于模块外无法构造 OTW，`init` 之外也无法获得新的实例

因此，OTW 实例在整个区块链历史中**确实只存在过一次**。

## 验证 OTW

Sui 框架提供了 `sui::types::is_one_time_witness` 函数来验证一个值是否是合法的 OTW：

```move
module examples::my_token;

const ENotOneTimeWitness: u64 = 0;

public struct MY_TOKEN has drop {}

fun init(otw: MY_TOKEN, ctx: &mut TxContext) {
    assert!(sui::types::is_one_time_witness(&otw), ENotOneTimeWitness);

    let (initializer, treasury_cap) = sui::coin_registry::new_currency_with_otw<MY_TOKEN>(
        otw, 6,
        std::string::utf8(b"MTK"),
        std::string::utf8(b"My Token"),
        std::string::utf8(b"Example token using OTW"),
        std::string::utf8(b""),
        ctx,
    );
    let metadata_cap = sui::coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

`is_one_time_witness` 会检查：

1. 该类型是否只有 `drop` 能力
2. 该类型是否没有字段
3. 该类型名称是否与模块名大写匹配

许多 Sui 框架函数（如 **`coin_registry::new_currency_with_otw`**）内部都会调用此检查，确保传入的确实是 OTW。

## OTW 的典型应用

### 1. 创建代币（coin_registry::new_currency_with_otw）

这是 OTW 最常见的用途。**`coin_registry::new_currency_with_otw`** 要求传入 OTW 以确保每种代币只能被创建一次（旧 API `coin::create_currency` 已废弃）：

```move
module examples::usdc;

use std::string;
use sui::coin_registry;

public struct USDC has drop {}

fun init(otw: USDC, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<USDC>(
        otw, 6,
        string::utf8(b"USDC"),
        string::utf8(b"USD Coin"),
        string::utf8(b"Stablecoin pegged to USD"),
        string::utf8(b""),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

为什么需要 OTW？因为 `new_currency_with_otw` 内部会创建该代币的 `TreasuryCap` 与链上 `Currency`，若允许多次调用会产生重复注册，破坏代币唯一性。

### 2. 声明 Publisher（package::claim）

`Publisher` 对象证明了某个地址是某个包的发布者，用于创建 `Display` 和 `TransferPolicy`：

```move
module examples::my_nft;

use sui::package;

public struct MY_NFT has drop {}

public struct GameItem has key, store {
    id: UID,
    name: std::string::String,
}

fun init(otw: MY_NFT, ctx: &mut TxContext) {
    // 用 OTW 声明 Publisher 身份
    let publisher = package::claim(otw, ctx);
    transfer::public_transfer(publisher, ctx.sender());
    
    // 若声明后立即转移，可直接使用 claim_and_keep，效果同上
    // package::claim_and_keep(otw, ctx);
}
```

### 3. 自定义一次性初始化

你也可以利用 OTW 确保某些操作只执行一次：

```move
module examples::singleton;

const ENotOneTimeWitness: u64 = 0;

public struct SINGLETON has drop {}

public struct GlobalConfig has key {
    id: UID,
    max_supply: u64,
    is_paused: bool,
}

fun init(otw: SINGLETON, ctx: &mut TxContext) {
    assert!(sui::types::is_one_time_witness(&otw), ENotOneTimeWitness);

    let config = GlobalConfig {
        id: object::new(ctx),
        max_supply: 1_000_000,
        is_paused: false,
    };

    // 共享全局配置对象 - 只会创建一次
    transfer::share_object(config);
}
```

## OTW 与普通 Witness 的区别

| 特征 | OTW | 普通 Witness |
|------|-----|-------------|
| 创建次数 | 系统保证仅一次 | 模块内可多次创建 |
| 创建方式 | 系统自动传入 init | 手动构造 |
| 命名要求 | 必须是模块名大写 | 无特殊要求 |
| 能力限制 | 只能有 drop | 无限制（通常有 drop） |
| 用途 | 全局唯一初始化 | 类型级别授权 |

## 常见错误

### 错误 1：在 init 外尝试创建 OTW

```move
module examples::wrong;

public struct WRONG has drop {}

public fun create_otw(): WRONG {
    WRONG {} // 编译报错，非法构造
}
```

### 错误 2：OTW 名称不匹配

```move
module examples::token;

// ❌ 名称应为 TOKEN（模块名大写），不是 Token
public struct Token has drop {}

fun init(otw: Token, ctx: &mut TxContext) {
    // 编译报错，非法参数，应改为 public struct TOKEN has drop {}
}
```

### 错误 3：忘记消耗 OTW

```move
module examples::forgot;

public struct FORGOT has drop {}

fun init(_otw: FORGOT, ctx: &mut TxContext) {
    // 没有使用 otw！
    // 虽然 drop 能力允许自动丢弃，但这通常意味着忘记了初始化逻辑
}
```

这不会导致编译错误（因为有 `drop`），但通常意味着遗漏了重要的初始化步骤。

## 小结

一次性见证（OTW）是 Sui 生态中的核心模式，它利用系统级保证实现了真正的"只执行一次"语义。OTW 必须满足严格的定义规则：模块名大写、仅有 `drop` 能力、无字段、非泛型。它的主要用途包括代币创建、Publisher 声明以及全局唯一初始化。理解 OTW 对于使用 Sui 框架的高级功能至关重要——几乎所有需要"一次性初始化"的场景都依赖于这一模式。
