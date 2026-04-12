# BCS 序列化

BCS（Binary Canonical Serialization）是 Move 生态系统中使用的标准二进制序列化格式，最初由 Diem（前 Libra）项目设计。它提供了一种确定性的、紧凑的二进制编码方式，用于在链上进行数据的序列化和反序列化。Sui 在 `sui::bcs` 模块中提供了完整的 BCS 编解码支持，使得智能合约可以处理跨模块、跨链的数据交换。

## BCS 格式概述

### 核心设计原则

BCS 格式遵循以下设计原则：

1. **确定性**：相同的数据结构始终编码为完全相同的字节序列，保证了共识安全性
2. **紧凑性**：使用最少的字节来表示数据，减少链上存储成本
3. **非自描述性**：编码结果中不包含类型信息，解码时必须提前知道数据的类型布局

### 编码规则

| 类型 | 编码方式 |
|------|---------|
| `bool` | 1 字节：`0x00`（false）或 `0x01`（true） |
| `u8` | 1 字节，直接存储 |
| `u16` / `u32` / `u64` / `u128` / `u256` | 小端序（Little-Endian） |
| `address` | 32 字节，直接存储 |
| `vector<T>` | ULEB128 编码的长度 + 每个元素的 BCS 编码 |
| `Option<T>` | 编码为 `vector<T>`（None = 空向量，Some(v) = 单元素向量） |
| `struct` | 各字段按声明顺序依次编码（无字段名、无分隔符） |
| `enum` | ULEB128 变体索引 + 变体数据的 BCS 编码 |

### ULEB128 编码

ULEB128（Unsigned Little-Endian Base 128）是一种变长整数编码，用于表示向量长度等可变大小的值。短长度（0-127）仅需 1 字节，长度越大使用的字节越多。

## 编码：bcs::to_bytes

`bcs::to_bytes` 将任何具有 `drop` 能力的值序列化为字节向量：

```move
use sui::bcs;

let value: u64 = 1000;
let bytes: vector<u8> = bcs::to_bytes(&value);
```

任何 Move 值——基本类型、结构体、向量等——只要具有适当的能力，都可以被 BCS 编码。

## 解码：BCS 包装器与 peel 函数

BCS 解码使用 `BCS` 包装器结构体和一系列 `peel_*` 函数来逐字段提取数据：

### 创建 BCS 解码器

```move
let mut bcs = bcs::new(bytes);
```

### 基本类型解码

```move
let bool_val = bcs.peel_bool();
let u8_val = bcs.peel_u8();
let u16_val = bcs.peel_u16();
let u32_val = bcs.peel_u32();
let u64_val = bcs.peel_u64();
let u128_val = bcs.peel_u128();
let u256_val = bcs.peel_u256();
let addr = bcs.peel_address();
```

### 向量解码

```move
// 解码 vector<u8>（最常用）
let bytes = bcs.peel_vec_u8();

// 解码 vector<u64>
let numbers = bcs.peel_vec_u64();

// 解码 vector<address>
let addresses = bcs.peel_vec_address();

// 通用向量解码（使用 peel_vec! 宏）
let custom_vec = bcs.peel_vec!(|bcs| bcs.peel_u64());
```

### Option 解码

```move
// 解码 Option<u64>
let maybe_val = bcs.peel_option!(|bcs| bcs.peel_u64());
```

## 完整代码示例

### 玩家数据编解码

```move
module examples::bcs_demo;

use sui::bcs;

public struct PlayerData has drop {
    name: vector<u8>,
    score: u64,
    level: u8,
}

/// Encode data to BCS bytes
public fun encode_player(): vector<u8> {
    let player = PlayerData {
        name: b"Alice",
        score: 1000,
        level: 5,
    };
    bcs::to_bytes(&player)
}

/// Decode BCS bytes back to structured data
public fun decode_player(bytes: vector<u8>): (vector<u8>, u64, u8) {
    let mut bcs = bcs::new(bytes);
    let name = bcs.peel_vec_u8();
    let score = bcs.peel_u64();
    let level = bcs.peel_u8();
    (name, score, level)
}

/// Decode a vector of addresses
public fun decode_address_list(bytes: vector<u8>): vector<address> {
    let mut bcs = bcs::new(bytes);
    bcs.peel_vec!(|bcs| bcs.peel_address())
}
```

### 结构体逐字段解码

由于 BCS 不是自描述的，解码结构体时必须按照字段声明的**精确顺序**逐个提取每个字段：

```move
module examples::bcs_struct;

use sui::bcs;

public struct GameConfig has drop {
    max_players: u64,
    entry_fee: u64,
    reward_pool: u64,
    is_active: bool,
    admin: address,
}

public fun decode_config(bytes: vector<u8>): GameConfig {
    let mut bcs = bcs::new(bytes);
    GameConfig {
        max_players: bcs.peel_u64(),
        entry_fee: bcs.peel_u64(),
        reward_pool: bcs.peel_u64(),
        is_active: bcs.peel_bool(),
        admin: bcs.peel_address(),
    }
}
```

## 嵌套结构解码

对于包含嵌套向量和 Option 的复杂结构，需要组合使用多种 peel 函数：

```move
module examples::bcs_complex;

use sui::bcs;

public fun decode_complex(
    bytes: vector<u8>
): (vector<u8>, vector<u64>, Option<address>) {
    let mut bcs = bcs::new(bytes);

    let name = bcs.peel_vec_u8();

    let scores = bcs.peel_vec!(|bcs| bcs.peel_u64());

    let maybe_referee = bcs.peel_option!(|bcs| bcs.peel_address());

    (name, scores, maybe_referee)
}
```

## 链下参数构造

BCS 的一个重要应用场景是**链下构造参数**。前端或后端应用可以使用 BCS 将复杂数据结构编码为字节数组，然后作为 `vector<u8>` 参数传入链上函数。链上合约再使用 `peel_*` 函数解码。

典型工作流程：

1. **链下**：使用 JavaScript/Python/Rust 的 BCS 库将结构化数据编码为字节数组
2. **交易调用**：将字节数组作为 `vector<u8>` 参数传入 Move 函数
3. **链上**：使用 `bcs::new` 和 `peel_*` 函数解码字节数组，还原为结构化数据

```move
module examples::bcs_params;

use sui::bcs;

public fun process_batch_transfer(data: vector<u8>) {
    let mut bcs = bcs::new(data);
    let recipients = bcs.peel_vec!(|bcs| bcs.peel_address());
    let amounts = bcs.peel_vec!(|bcs| bcs.peel_u64());
    let count = vector::length(&recipients);
    assert_eq!(count, vector::length(&amounts));
    let mut i = 0;
    while (i < count) {
        let _recipient = *vector::borrow(&recipients, i);
        let _amount = *vector::borrow(&amounts, i);
        // 执行转账逻辑...
        i = i + 1;
    };
}
```

## 注意事项

### 字段顺序至关重要

BCS 编码不包含字段名，完全依赖于字段的声明顺序。如果编码方和解码方使用的字段顺序不一致，将导致数据损坏或运行时错误。

### 不支持跳过字段

BCS 解码器必须按顺序读取所有字段。不能跳过中间字段只读取后面的字段——必须从头依次 peel。

### 剩余字节

解码完成后，如果 BCS 缓冲区中仍有未读取的字节，可以使用 `bcs.into_remainder_bytes()` 获取剩余字节。这在处理变长数据时非常有用。

## 小结

BCS 是 Sui/Move 生态系统中数据序列化的标准格式，核心要点包括：

- 采用确定性的二进制编码，使用小端序和 ULEB128 变长整数
- 非自描述格式——解码时必须知道数据的完整类型布局
- 编码使用 `bcs::to_bytes(&value)` 一步完成
- 解码使用 `bcs::new(bytes)` 创建解码器，然后通过 `peel_*` 系列函数逐字段提取
- 向量使用 `peel_vec!` 宏解码，Option 使用 `peel_option!` 宏解码
- 结构体按字段声明顺序逐个解码，顺序不可更改
- 常用于链下构造链上参数的场景，前端通过 BCS 编码复杂参数传递给 Move 合约
