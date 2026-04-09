# 地址（Address）

地址（Address）是 Sui 区块链上的唯一标识符，长度为 32 字节（256 位），以十六进制字符串表示。在 Sui 中，地址被广泛用于标识包、账户和对象，是连接链上各种实体的核心概念。

## 地址的格式

地址由 64 个十六进制字符组成，前缀为 `0x`：

```
0x06b36e07f3d5a3d76e66fc1b14735e7f4b0045c3ebca6f3b1c3bfb9d3bcda2a7
```

### 格式规则

| 规则 | 说明 |
|------|------|
| 长度 | 32 字节，64 个十六进制字符 |
| 前缀 | 以 `0x` 开头 |
| 大小写 | 不区分大小写，`0xABC` 和 `0xabc` 等价 |
| 短地址 | 不足 64 位的自动在左侧补零 |

### 短地址补零

为了书写方便，地址可以使用简写形式。不足 64 个字符的地址会自动在左侧补零：

```
0x1
= 0x0000000000000000000000000000000000000000000000000000000000000001

0x2
= 0x0000000000000000000000000000000000000000000000000000000000000002

0xdead
= 0x000000000000000000000000000000000000000000000000000000000000dead
```

在代码中使用短地址和完整地址效果相同：

```move
module example::demo;

use std::debug;

#[test]
fun address() {
    let addr1 = @0x1;
    let addr2 = @0x0000000000000000000000000000000000000000000000000000000000000001;
    assert_eq!(addr1, addr2);
}
```

## 保留地址

Sui 网络中有一些特殊的保留地址，用于系统级别的包和对象：

| 地址 | 名称 | 用途 |
|------|------|------|
| `0x1` | Move 标准库（`std`） | 提供基础类型和工具，如 `string`、`vector`、`option` 等 |
| `0x2` | Sui 框架（`sui`） | 提供 Sui 特有的功能，如 `object`、`transfer`、`coin`、`tx_context` 等 |
| `0x5` | Sui System | Sui 系统状态对象 |
| `0x6` | 系统时钟（`Clock`） | 全局共享的时钟对象，用于获取链上时间戳 |
| `0x8` | 随机数（`Random`） | 链上随机数生成器对象 |
| `0x403` | `DenyList` | 受管代币的拒绝列表 |

在代码中引用这些地址：

```move
module my_project::example;

use std::string;          // 来自 0x1
use sui::clock::Clock;    // 来自 0x2
use sui::coin::Coin;      // 来自 0x2
```

## 地址的用途

在 Sui 中，地址有三个主要用途：

### 1. 标识账户

每个用户账户由一个地址标识。这个地址从用户的公钥派生而来：

```
私钥 → 公钥 → 地址
```

用户通过其地址接收对象、发送交易。

### 2. 标识包

每个已发布的 Move 包都有一个唯一的地址。调用包中的函数时需要指定包的地址：

```move
module 0xabc123::marketplace;

// 该模块属于地址为 0xabc123 的包
```

### 3. 标识对象

Sui 上的每个对象也有一个唯一的地址（即对象 ID）。对象 ID 在创建时由系统分配。

## Move 中的 address 类型

在 Move 语言中，`address` 是一个内置的原始类型：

```move
module my_project::address_demo;

public fun show_address(): address {
    @0x1
}

public fun compare_addresses(a: address, b: address): bool {
    a == b
}

#[test]
fun address_type() {
    let system_addr = @0x1;
    let framework_addr = @0x2;
    assert!(system_addr != framework_addr);
}
```

### 地址与字符串转换

利用标准库可以在地址与字符串之间进行转换：

```move
module my_project::addr_utils;

use std::string::String;
use sui::address;

public fun addr_to_string(addr: address): String {
    address::to_string(addr)
}

public fun addr_length(): u64 {
    address::length()  // 返回 32
}
```

## 地址字面量的使用

在 Move 代码中，地址字面量以 `@` 符号开头：

```move
module my_project::literals;

const ADMIN: address = @0xA11CE;
const STD: address = @std;   // 使用命名地址，等价于 @0x1

fun check_admin(sender: address): bool {
    sender == ADMIN
}
```

命名地址（如 `@std`、`@sui`）在 `Move.toml` 的 `[addresses]` 段中定义，编译时会被替换为实际值。

## 小结

地址是 Sui 区块链上标识各种实体的核心概念。它是一个 32 字节的十六进制值，用于标识账户、包和对象。Move 语言中提供了 `address` 原始类型来操作地址，并通过 `@` 前缀表示地址字面量。Sui 网络中保留了若干特殊地址（如 `0x1`、`0x2`、`0x6`）用于系统组件。理解地址的格式和用途，是与 Sui 链上实体交互的基础。
