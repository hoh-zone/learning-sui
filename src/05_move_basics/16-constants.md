# 常量

常量（Constants）是使用 `const` 关键字定义的模块级不可变值。常量在编译时确定，存储在字节码中，每次使用时会被复制到使用位置。它们用于定义配置值、限制条件、错误码等在整个模块中共用的固定值。合理使用常量可以避免代码中出现难以理解的"魔术数字"，提升代码的可读性和可维护性。

## 基本语法

### 常量声明

常量使用 `const` 关键字声明，必须指定类型和初始值：

```move
module book::const_basic;

const MAX_SUPPLY: u64 = 1_000_000;
const DEFAULT_PRICE: u64 = 100;
const IS_TESTNET: bool = true;
const ADMIN_ADDRESS: address = @0x1;
const APP_NAME: vector<u8> = b"MyApp";
```

### 名称约束

常量名称 **必须以大写字母开头**，这是编译器强制要求的规则。

社区约定使用两种命名风格：

- **ALL_CAPS_WITH_UNDERSCORES** — 用于普通常量值
- **EPascalCase** — 用于错误码常量（E 前缀 + 大驼峰）

```move
module book::const_naming;

// 普通常量：全大写 + 下划线分隔
const MAX_RETRIES: u64 = 3;
const DEFAULT_TIMEOUT: u64 = 5000;
const BASE_URL: vector<u8> = b"https://api.sui.io";

// 错误码常量：E 前缀 + 驼峰命名
const ENotAuthorized: u64 = 0;
const EInsufficientBalance: u64 = 1;
const EItemNotFound: u64 = 2;
const EExceedsMaxSupply: u64 = 3;
```

## 支持的类型

常量只能使用以下类型：

| 类型 | 示例 |
|------|------|
| `bool` | `const FLAG: bool = true;` |
| `u8` ~ `u256` | `const MAX: u64 = 100;` |
| `address` | `const ADDR: address = @0x1;` |
| `vector<u8>` | `const NAME: vector<u8> = b"hello";` |

> **注意**：常量不支持自定义结构体类型、`String`、`Option` 等复杂类型。如需使用这些类型的常量值，应通过函数封装。

```move
module book::const_types;

const BOOL_CONST: bool = false;
const U8_CONST: u8 = 255;
const U64_CONST: u64 = 1_000_000;
const U128_CONST: u128 = 1_000_000_000_000;
const U256_CONST: u256 = 0;
const ADDR_CONST: address = @0xCAFE;
const BYTES_CONST: vector<u8> = b"Hello, Move!";
```

## 常量是模块私有的

常量只能在定义它们的模块内部使用，无法被其他模块直接访问。这是 Move 的设计决策——如果需要将常量值暴露给外部模块，应通过公开函数（getter）来实现。

### 配置模式

```move
module book::const_config;

const MAX_SUPPLY: u64 = 1_000_000;
const DEFAULT_PRICE: u64 = 100;
const MIN_STAKE: u64 = 1_000;

// 通过公开函数暴露常量值
public fun max_supply(): u64 { MAX_SUPPLY }
public fun default_price(): u64 { DEFAULT_PRICE }
public fun min_stake(): u64 { MIN_STAKE }

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun config_getters() {
    assert_eq!(max_supply(), 1_000_000);
    assert_eq!(default_price(), 100);
    assert_eq!(min_stake(), 1_000);
}
```

这种模式在智能合约开发中非常常见，它将常量值的访问控制权保留在定义模块中，同时允许外部读取。

## 错误码常量

在 Move 中，`assert!` 宏的第二个参数是一个错误码。使用常量定义错误码比直接使用数字更具可读性：

```move
module book::const_errors;

const ENotOwner: u64 = 0;
const EInsufficientFunds: u64 = 1;
const EInvalidAmount: u64 = 2;

public struct Wallet has drop {
    owner: address,
    balance: u64,
}

public fun withdraw(wallet: &mut Wallet, amount: u64, caller: address): u64 {
    assert!(caller == wallet.owner, ENotOwner);
    assert!(amount > 0, EInvalidAmount);
    assert!(wallet.balance >= amount, EInsufficientFunds);

    wallet.balance = wallet.balance - amount;
    amount
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun withdraw_ok() {
    let mut wallet = Wallet { owner: @0x1, balance: 1000 };
    let amount = withdraw(&mut wallet, 100, @0x1);
    assert_eq!(amount, 100);
    assert_eq!(wallet.balance, 900);
}

#[test]
#[expected_failure(abort_code = ENotOwner)]
fun not_owner() {
    let mut wallet = Wallet { owner: @0x1, balance: 1000 };
    withdraw(&mut wallet, 100, @0x2); // 非 owner 调用，触发 abort
}
```

### 错误码命名建议

| 前缀 | 含义 | 示例 |
|------|------|------|
| `ENotX` | 条件不满足 | `ENotOwner`、`ENotAuthorized` |
| `EInsufficientX` | 数量不足 | `EInsufficientBalance`、`EInsufficientFunds` |
| `EInvalidX` | 输入无效 | `EInvalidAmount`、`EInvalidAddress` |
| `EAlreadyX` | 重复操作 | `EAlreadyInitialized`、`EAlreadyExists` |
| `EExceedsX` | 超出限制 | `EExceedsMaxSupply`、`EExceedsLimit` |

## 常量的存储方式

常量存储在编译后的字节码中，每次使用时会被 **复制** 到使用位置。这意味着：

- 常量不占用链上存储空间（不是对象）
- 每次引用常量都是一次值复制
- 对于大型 `vector<u8>` 常量，频繁使用可能增加字节码大小

```move
module book::const_storage;

const LARGE_BYTES: vector<u8> = b"This is a relatively long constant string value";

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun constant_copy() {
    let a = LARGE_BYTES;
    let b = LARGE_BYTES;   // 独立的副本

    assert!(a == b);
    assert_eq!(a.length(), b.length());
}
```

## 不可变性

常量是真正不可变的——一旦定义，无法在运行时修改。任何试图对常量赋值的操作都会导致编译错误：

```move
module book::const_immutable;

const VALUE: u64 = 42;

public fun value(): u64 {
    // VALUE = 100;  // 编译错误：无法对常量赋值
    VALUE
}
```

如果需要可修改的全局状态，应使用链上对象（Object）来存储。

## 完整示例

```move
module book::constants_example;

const MAX_SUPPLY: u64 = 1_000_000;
const DEFAULT_PRICE: u64 = 100;
const ADMIN_ADDRESS: address = @0x1;
const APP_NAME: vector<u8> = b"MyApp";

const ENotAuthorized: u64 = 0;
const EInsufficientBalance: u64 = 1;

public fun max_supply(): u64 { MAX_SUPPLY }
public fun default_price(): u64 { DEFAULT_PRICE }

public fun check_authorized(addr: address) {
    assert!(addr == ADMIN_ADDRESS, ENotAuthorized);
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun constants_example() {
    assert_eq!(max_supply(), 1_000_000);
    assert_eq!(default_price(), 100);
    check_authorized(@0x1);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun unauthorized() {
    check_authorized(@0x99);
}
```

## 小结

常量是 Move 模块中不可变的固定值。本节核心要点：

- **声明语法**：`const NAME: Type = value;`，名称必须大写字母开头
- **命名规范**：普通常量用 `ALL_CAPS`，错误码用 `EPascalCase`
- **支持的类型**：`bool`、整数类型、`address`、`vector<u8>`
- **模块私有**：常量只在定义模块内可见，通过公开函数暴露给外部
- **配置模式**：使用 `public fun xxx(): Type { CONSTANT }` 暴露常量值
- **错误码**：使用 `E` 前缀命名，配合 `assert!` 进行条件检查
- **存储方式**：编译时嵌入字节码，每次使用时复制
- **不可变性**：定义后无法修改，需要可变状态请使用链上对象
