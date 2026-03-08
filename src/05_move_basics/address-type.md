# 地址类型（address）

地址类型 `address` 是 Move 语言中的一种特殊类型，占用 32 字节（256 位），用于表示区块链上的位置标识。在 Sui 中，地址既用于标识账户（用户钱包），也用于标识对象（Object）。掌握地址类型及其转换方法，是与链上资源交互的基础。

## 地址字面量

地址字面量以 `@` 符号开头，可以使用十六进制值或命名地址：

```move
module book::address_literal;

#[test]
fun address_literal() {
    // 十六进制字面地址
    let addr1 = @0x0;
    let addr2 = @0x1;
    let addr3 = @0x2;

    // 命名地址（在 Move.toml 中定义）
    let std_addr = @std;   // 等价于 @0x1
    let sui_addr = @sui;   // 等价于 @0x2
}
```

常见的预定义地址：

| 地址 | 命名地址 | 说明 |
|------|----------|------|
| `@0x1` | `@std` | Move 标准库 |
| `@0x2` | `@sui` | Sui Framework |
| `@0x6` | — | 系统时钟对象 |

## 地址与 u256 之间的转换

地址本质上是一个 256 位的数值，因此可以与 `u256` 类型互相转换：

```move
module book::address_u256;

#[test]
fun address_u256() {
    let addr = @0x1;

    // address -> u256
    let addr_as_u256: u256 = addr.to_u256();
    assert_eq!(addr_as_u256, 1u256);

    // u256 -> address
    let addr_from_u256 = address::from_u256(addr_as_u256);
    assert_eq!(addr, addr_from_u256);
}
```

## 地址与字节数组之间的转换

地址可以转换为 32 字节的 `vector<u8>`，也可以从字节数组还原：

```move
module book::address_bytes;

#[test]
fun address_bytes() {
    let addr = @0x1;

    // address -> vector<u8>（32字节）
    let bytes: vector<u8> = addr.to_bytes();
    assert_eq!(bytes.length(), 32);

    // vector<u8> -> address
    let addr_from_bytes = address::from_bytes(bytes);
    assert_eq!(addr, addr_from_bytes);
}
```

> **注意**：`address::from_bytes` 要求传入的 `vector<u8>` 长度恰好为 32 字节，否则会产生运行时错误。

## 地址与字符串之间的转换

地址可以转换为十六进制字符串表示：

```move
module book::address_examples;

use std::string::String;

#[test]
fun address() {
    let addr = @0x1;
    let named_addr = @std;

    // Convert to u256
    let addr_as_u256: u256 = addr.to_u256();
    let addr_from_u256 = address::from_u256(addr_as_u256);
    assert_eq!(addr, addr_from_u256);

    // Convert to bytes
    let bytes: vector<u8> = addr.to_bytes();
    let addr_from_bytes = address::from_bytes(bytes);
    assert_eq!(addr, addr_from_bytes);

    // Convert to string
    let addr_str: String = addr.to_string();
}
```

## 地址与对象 ID 的关系

在 Sui 中，每个对象（Object）都有一个唯一的 ID，类型为 `sui::object::ID`。对象 ID 本质上也是一个地址值，两者之间存在密切关系：

```move
module book::address_and_id;

use sui::object;

public fun id_to_address(id: &object::ID): address {
    object::id_to_address(id)
}

public fun address_to_id(addr: address): object::ID {
    object::id_from_address(addr)
}
```

### 理解地址的双重角色

在 Sui 网络中，地址扮演着双重角色：

1. **账户地址**：每个用户钱包对应一个地址，用于发送交易和持有对象
2. **对象地址**：每个链上对象都有一个唯一的地址（即对象 ID）

两者在格式上完全相同，都是 32 字节的十六进制值。区别在于语义：账户地址是由公钥派生的，而对象地址是在对象创建时由系统生成的。

## 转换方法汇总

| 方法 | 说明 | 方向 |
|------|------|------|
| `addr.to_u256()` | 地址转 u256 | address → u256 |
| `address::from_u256(n)` | u256 转地址 | u256 → address |
| `addr.to_bytes()` | 地址转字节数组 | address → vector\<u8\> |
| `address::from_bytes(bytes)` | 字节数组转地址 | vector\<u8\> → address |
| `addr.to_string()` | 地址转十六进制字符串 | address → String |
| `object::id_to_address(id)` | 对象 ID 转地址 | ID → address |
| `object::id_from_address(addr)` | 地址转对象 ID | address → ID |

## 小结

地址类型是 Move 与区块链交互的核心类型。本节核心要点：

- 地址是 32 字节（256 位）的特殊类型，用 `@` 前缀表示
- 支持十六进制字面量（`@0x1`）和命名地址（`@std`）
- 提供与 `u256`、`vector<u8>`、`String` 之间的双向转换方法
- 在 Sui 中，地址既标识账户也标识对象，对象 ID 本质上就是一个地址
