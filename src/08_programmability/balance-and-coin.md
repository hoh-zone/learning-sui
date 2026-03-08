# Balance 与 Coin

`Balance<T>` 和 `Coin<T>` 是 Sui 代币经济体系的两大基石。`Balance<T>` 是一个轻量级的数值余额表示，而 `Coin<T>` 则是将 `Balance<T>` 包装为可独立流转的对象。理解这两者的关系及其配套的 `Supply<T>` 和 `TreasuryCap<T>` 机制，是构建任何涉及代币逻辑的 Sui 应用的基础。

## Balance — 原始数值余额

### 定义与能力

`Balance<T>` 定义在 `sui::balance` 模块中，其结构非常简单：

```move
public struct Balance<phantom T> has store {
    value: u64,
}
```

关键特征：

- **只有 `store` 能力**，没有 `key`——它不是一个独立对象，不能直接拥有对象 ID
- 使用 `phantom` 类型参数 `T` 来区分不同代币（如 `Balance<SUI>`、`Balance<USDC>` 等）
- 轻量级，适合作为其他对象的内部字段

### Balance 核心操作

```move
use sui::balance;

// 创建零余额
balance::zero<T>(): Balance<T>

// 查询余额值
balance::value<T>(balance: &Balance<T>): u64

// 合并两个余额（将 other 合并到 self 中）
balance::join<T>(self: &mut Balance<T>, other: Balance<T>): u64

// 拆分指定金额
balance::split<T>(self: &mut Balance<T>, amount: u64): Balance<T>

// 销毁零余额
balance::destroy_zero<T>(balance: Balance<T>)
```

`Balance` 不能凭空创建非零值——只能通过铸币（`Supply`）或从已有余额拆分得到。这是 Sui 代币安全模型的核心保证。

## Coin — 余额的对象包装

### 定义与能力

`Coin<T>` 定义在 `sui::coin` 模块中：

```move
public struct Coin<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
}
```

关键特征：

- 拥有 `key + store` 能力——它是一个独立的 Sui 对象
- 内部包含一个 `Balance<T>` 字段
- 可以被转移、共享、冻结等
- 在交易中作为输入/输出对象使用

### Coin 核心操作

```move
use sui::coin;

// 查询 Coin 中的余额值
coin::value<T>(coin: &Coin<T>): u64

// Coin → Balance 转换（消耗 Coin）
coin::into_balance<T>(coin: Coin<T>): Balance<T>

// Balance → Coin 转换（需要 TxContext 创建新对象）
coin::from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Coin<T>

// 创建零值 Coin
coin::zero<T>(ctx: &mut TxContext): Coin<T>

// 拆分 Coin
coin::split<T>(coin: &mut Coin<T>, amount: u64, ctx: &mut TxContext): Coin<T>

// 合并 Coin
coin::join<T>(self: &mut Coin<T>, other: Coin<T>)

// 销毁零值 Coin
coin::destroy_zero<T>(coin: Coin<T>)
```

### Coin 与 Balance 的转换

两者可以自由互转：

- `coin::into_balance(coin)` 将 `Coin` 解包为 `Balance`（销毁 Coin 对象）
- `coin::from_balance(balance, ctx)` 将 `Balance` 包装为新的 `Coin` 对象

这种转换是无损的，不会丢失任何代币价值。

## Supply 与 TreasuryCap — 代币铸造体系

### Supply

`Supply<T>` 记录了某种代币的总供应量，是铸币和销毁的底层机制：

```move
public struct Supply<phantom T> has store {
    value: u64,
}
```

### TreasuryCap

`TreasuryCap<T>` 是铸币权限的凭证，内部包含 `Supply<T>`：

```move
public struct TreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: Supply<T>,
}
```

持有 `TreasuryCap` 的地址拥有铸造和销毁该代币的权限。

## 创建新代币

使用 `coin::create_currency` 创建一种新代币，该函数利用一次性见证（One-Time Witness）确保每种代币只能被创建一次：

```move
module examples::my_coin;

use sui::coin::{Self, TreasuryCap, Coin};
use sui::balance::{Self, Balance};

public struct MY_COIN has drop {}

fun init(witness: MY_COIN, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency(
        witness,
        9, // decimals
        b"MYC",
        b"My Coin",
        b"An example coin",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury_cap, ctx.sender());
}

public fun mint(
    treasury_cap: &mut TreasuryCap<MY_COIN>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient);
}

public fun burn(
    treasury_cap: &mut TreasuryCap<MY_COIN>,
    coin: Coin<MY_COIN>,
) {
    coin::burn(treasury_cap, coin);
}
```

### create_currency 参数详解

| 参数 | 类型 | 说明 |
|------|------|------|
| `witness` | `T` | 一次性见证，确保唯一性 |
| `decimals` | `u8` | 小数位数（如 9 表示最小单位是十亿分之一） |
| `symbol` | `vector<u8>` | 代币符号（如 "SUI"） |
| `name` | `vector<u8>` | 代币全名 |
| `description` | `vector<u8>` | 代币描述 |
| `icon_url` | `Option<Url>` | 可选的图标 URL |
| `ctx` | `&mut TxContext` | 交易上下文 |

返回值是一个元组 `(TreasuryCap<T>, CoinMetadata<T>)`。通常将 `CoinMetadata` 冻结（freeze）以确保元数据不可篡改。

## 铸造与销毁

### 铸币流程

```move
// 方式 1：直接铸造为 Coin 对象
let coin = coin::mint(treasury_cap, amount, ctx);

// 方式 2：铸造为 Balance（不创建对象）
let balance = coin::mint_balance(treasury_cap, amount);
```

`mint_balance` 返回 `Balance<T>` 而不是 `Coin<T>`，适用于不需要立即创建独立对象的场景（如存入金库）。

### 销毁流程

```move
// 销毁 Coin，减少总供应量
coin::burn(treasury_cap, coin);
```

销毁操作会将代币从流通中永久移除，并相应减少 `Supply` 中记录的总供应量。

## 拆分与合并

### 拆分 Coin

```move
// 从一个 Coin 中拆出指定金额，创建新的 Coin
let new_coin = coin::split(&mut original_coin, 100, ctx);
```

### 合并 Coin

```move
// 将 other_coin 合并到 main_coin 中（other_coin 被消耗）
coin::join(&mut main_coin, other_coin);
```

## 实战：金库合约

以下示例展示了如何使用 `Balance` 构建一个共享金库，支持存入和提取 SUI 代币：

```move
module examples::vault;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

public struct Vault has key {
    id: UID,
    balance: Balance<SUI>,
}

public fun create(ctx: &mut TxContext) {
    let vault = Vault {
        id: object::new(ctx),
        balance: balance::zero(),
    };
    transfer::share_object(vault);
}

public fun deposit(vault: &mut Vault, coin: Coin<SUI>) {
    let coin_balance = coin::into_balance(coin);
    balance::join(&mut vault.balance, coin_balance);
}

public fun withdraw(
    vault: &mut Vault,
    amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    let withdrawn = balance::split(&mut vault.balance, amount);
    coin::from_balance(withdrawn, ctx)
}

public fun balance(vault: &Vault): u64 {
    balance::value(&vault.balance)
}
```

### 设计要点

在金库合约中，我们使用 `Balance<SUI>` 而不是 `Coin<SUI>` 作为内部存储，原因是：

1. **`Balance` 更轻量**：没有对象开销，不需要 UID
2. **合并更高效**：`balance::join` 直接修改数值，不涉及对象操作
3. **灵活性**：可以精确拆分任意金额，而不受限于已有 Coin 的面值

外部接口接受 `Coin<SUI>` 参数（因为用户持有的是 Coin 对象），内部通过 `into_balance` 转换后存储，提取时通过 `from_balance` 转回 `Coin` 返回给用户。

## Balance 与 Coin 的选择策略

| 场景 | 推荐类型 | 原因 |
|------|---------|------|
| 对象内部存储代币余额 | `Balance<T>` | 轻量、无对象开销 |
| 用户持有和转移代币 | `Coin<T>` | 是对象，可转移和交易 |
| 函数参数接收代币 | `Coin<T>` | 用户钱包中持有的是 Coin |
| 函数返回代币给用户 | `Coin<T>` | 需要对象才能被接收 |
| DeFi 协议内部记账 | `Balance<T>` | 高效合并和拆分 |

## 小结

`Balance` 和 `Coin` 构成了 Sui 代币系统的双层架构：

- **Balance<T>**：轻量级数值余额，只有 `store` 能力，适合作为对象内部字段进行高效代币管理
- **Coin<T>**：Balance 的对象包装，拥有 `key + store` 能力，是用户可见和可交互的代币形式
- **TreasuryCap<T>**：铸币权限凭证，通过一次性见证模式确保每种代币只能创建一次
- 铸造通过 `coin::mint` 或 `coin::mint_balance` 完成，销毁通过 `coin::burn` 完成
- Coin 支持 `split`（拆分）和 `join`（合并）操作
- 两者可通过 `into_balance` 和 `from_balance` 自由互转
- 合约内部通常使用 `Balance` 存储，外部接口使用 `Coin` 交互
