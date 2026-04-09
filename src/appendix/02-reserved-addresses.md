# 保留地址

本附录列出 Sui 网络中的保留地址。这些地址在所有环境（mainnet、testnet、devnet、localnet）中保持不变，用于特定的原生操作。

## 地址一览

| 地址 | 名称 | 别名 | 用途 |
|------|------|------|------|
| `0x1` | Move 标准库 | `std` | 基础类型和工具函数 |
| `0x2` | Sui 框架 | `sui` | Sui 核心功能模块 |
| `0x5` | SuiSystem | — | 系统状态管理 |
| `0x6` | Clock | — | 链上时钟 |
| `0x8` | Random | — | 链上随机数 |
| `0xc` | CoinRegistry | — | 代币注册表 |
| `0x403` | DenyList | — | 代币冻结拒绝列表 |

## 详细说明

### 0x1 — Move 标准库（MoveStdlib）

提供 Move 语言的基础类型和工具：

```move
use std::string::String;
use std::option::{Self, Option};
use std::vector;
use std::type_name;
use std::ascii;
use std::bcs;
use std::hash;
use std::debug;
```

主要模块：

| 模块 | 用途 |
|------|------|
| `std::string` | UTF-8 字符串 |
| `std::option` | 可选值类型 |
| `std::vector` | 动态数组 |
| `std::bcs` | BCS 序列化/反序列化 |
| `std::hash` | 哈希函数（SHA2-256、SHA3-256） |
| `std::type_name` | 类型名称反射 |
| `std::ascii` | ASCII 字符串 |
| `std::debug` | 调试打印（仅测试可用） |
| `std::unit_test` | 测试断言工具 |

### 0x2 — Sui 框架（Sui Framework）

提供 Sui 区块链的核心功能：

```move
use sui::object::{Self, UID, ID};
use sui::transfer;
use sui::tx_context::TxContext;
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::event;
use sui::clock::Clock;
use sui::table::Table;
use sui::bag::Bag;
use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;
use sui::package;
use sui::display;
use sui::kiosk;
```

主要模块：

| 模块 | 用途 |
|------|------|
| `sui::object` | 对象创建和管理 |
| `sui::transfer` | 对象转移（转让、共享、冻结） |
| `sui::tx_context` | 交易上下文（发送者地址、创建 UID） |
| `sui::coin` | 同质化代币 |
| `sui::balance` | 余额管理 |
| `sui::event` | 事件发射 |
| `sui::clock` | 时间查询 |
| `sui::table` | 同构键值集合（动态字段） |
| `sui::bag` | 异构键值集合（动态字段） |
| `sui::dynamic_field` | 动态字段操作 |
| `sui::dynamic_object_field` | 动态对象字段操作 |
| `sui::package` | 包管理和升级 |
| `sui::display` | Display 标准（NFT 显示元数据） |
| `sui::kiosk` | Kiosk 交易协议 |
| `sui::ed25519` | Ed25519 签名验证 |
| `sui::hash` | Blake2b256 哈希 |
| `sui::random` | 链上随机数 |

### 0x5 — SuiSystem

管理 Sui 网络的系统状态：

```move
use sui::sui_system::SuiSystemState;
```

包含验证者集合、质押信息、Epoch 管理等系统级功能。

### 0x6 — Clock

提供链上时间戳：

```move
use sui::clock::Clock;

public fun do_time_check(clock: &Clock) {
    let now_ms = clock.timestamp_ms();
    // 使用时间戳...
}
```

在交易中使用：
```typescript
tx.moveCall({
  target: `${packageId}::my_module::do_time_check`,
  arguments: [tx.object('0x6')], // Clock 对象
});
```

### 0x8 — Random

提供链上可验证随机数：

```move
use sui::random::Random;

entry fun roll_dice(r: &Random, ctx: &mut TxContext) {
    let mut gen = r.new_generator(ctx);
    let result = gen.generate_u8_in_range(1, 6);
    // 使用随机数...
}
```

在交易中使用：
```typescript
tx.moveCall({
  target: `${packageId}::game::roll_dice`,
  arguments: [tx.object('0x8')],
});
```

### 0x403 — DenyList

管理代币冻结列表，用于合规场景：

```move
use sui::deny_list::DenyList;

/// 冻结某地址的代币
public fun freeze_address(
    deny_list: &mut DenyList,
    _cap: &DenyCap<MY_COIN>,
    addr: address,
) {
    deny_list.add(addr);
}
```

## 在 Move.toml 中的引用

从 Sui 1.45 开始，标准库和 Sui 框架的依赖是隐式的：

```toml
[package]
name = "my_package"
edition = "2024"

# 不需要显式声明 Sui 依赖
[dependencies]
# Sui, MoveStdlib, SuiSystem 自动导入
```

## 小结

- 保留地址在所有 Sui 网络环境中保持一致
- `0x1`（标准库）和 `0x2`（Sui 框架）是最常用的
- `0x6`（Clock）和 `0x8`（Random）是交易中常引用的系统对象
- 从 Sui 1.45 起，框架依赖自动导入，无需在 `Move.toml` 中声明
