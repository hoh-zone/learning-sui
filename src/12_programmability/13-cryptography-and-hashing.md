# 密码学与哈希

## 导读

本节对应 [§12.1](01-sui-framework.md) 中的 **`sui::crypto/*`** 与相关哈希模块：在链上做哈希、签名验证、ZK 相关原语等。**安全模型**与 Gas 成本与具体算法绑定，生产环境务必对照**当前**框架源码与审计建议。

- **前置**：[§12.1](01-sui-framework.md)、[§12.12](12-bcs.md)（字节与承诺常一起出现）  
- **后续**：[第十八章 · 安全](../20_security/00-index.md)（误用密码学的常见坑）  

---

密码学原语是区块链安全的基石。Sui 在 Move 标准库和框架中提供了丰富的密码学工具，包括多种哈希函数和数字签名验证算法。这些工具使得智能合约可以在链上执行内容完整性校验、承诺-揭示方案、签名验证等常见密码学操作，为构建安全可靠的去中心化应用提供底层保障。

## 哈希函数

### 概述

哈希函数将任意长度的输入数据映射为固定长度的输出（哈希值/摘要），具有以下核心性质：

- **确定性**：相同输入始终产生相同输出
- **不可逆性**：无法从哈希值反推出原始数据
- **雪崩效应**：输入的微小变化会导致输出的巨大变化
- **抗碰撞性**：极难找到两个不同的输入产生相同的输出

### sui::hash 模块

`sui::hash` 模块提供了四种主流哈希函数，全部返回 256 位（32 字节）的哈希值：

| 函数 | 算法 | 输出长度 | 典型用途 |
|------|------|---------|---------|
| `sha2_256` | SHA-2 256 | 32 字节 | 通用哈希、与比特币兼容 |
| `sha3_256` | SHA-3 256 | 32 字节 | 通用哈希、与以太坊兼容 |
| `blake2b256` | BLAKE2b-256 | 32 字节 | 高性能哈希 |
| `keccak256` | Keccak-256 | 32 字节 | 以太坊签名兼容 |

### 基本用法

```move
module examples::crypto_demo;

use sui::hash;

/// Hash data using SHA2-256
public fun hash_sha2(data: &vector<u8>): vector<u8> {
    hash::sha2_256(*data)
}

/// Hash data using SHA3-256
public fun hash_sha3(data: &vector<u8>): vector<u8> {
    hash::sha3_256(*data)
}

/// Hash data using Blake2b-256
public fun hash_blake2b(data: &vector<u8>): vector<u8> {
    hash::blake2b256(*data)
}

/// Verify content integrity
public fun verify_content(
    content: vector<u8>,
    expected_hash: vector<u8>,
): bool {
    let actual_hash = hash::sha3_256(content);
    actual_hash == expected_hash
}
```

### 哈希函数选择建议

- **SHA2-256**：最广泛使用的哈希算法，与比特币生态兼容
- **SHA3-256**：SHA-2 的后继者，安全边际更高，与部分以太坊操作兼容
- **BLAKE2b-256**：速度最快的通用哈希函数，适合性能敏感场景
- **Keccak-256**：以太坊的核心哈希算法，在需要与以太坊互操作时使用

## 应用场景：承诺-揭示方案

承诺-揭示（Commit-Reveal）是密码学中经典的两阶段协议，广泛用于链上投票、拍卖、随机数生成等场景。其基本流程：

1. **承诺阶段**：参与者提交数据的哈希值（承诺），不暴露原始数据
2. **揭示阶段**：参与者公开原始数据，合约验证其与承诺的一致性

```move
module examples::commit_reveal;

use sui::hash;

public struct Commitment has key {
    id: UID,
    hash: vector<u8>,
    revealed: bool,
}

public fun commit(data_hash: vector<u8>, ctx: &mut TxContext) {
    let commitment = Commitment {
        id: object::new(ctx),
        hash: data_hash,
        revealed: false,
    };
    transfer::transfer(commitment, ctx.sender());
}

public fun reveal(commitment: &mut Commitment, data: vector<u8>) {
    let hash = hash::sha3_256(data);
    assert!(hash == commitment.hash, 0);
    commitment.revealed = true;
}
```

### 增强的承诺方案

为防止彩虹表攻击（当数据空间较小时，攻击者可预计算所有可能值的哈希），可以在承诺中加入随机盐值（salt）：

```move
module examples::salted_commit;

use sui::hash;

public struct SaltedCommitment has key {
    id: UID,
    hash: vector<u8>,
    revealed: bool,
}

public fun commit_with_salt(
    salted_hash: vector<u8>,
    ctx: &mut TxContext,
) {
    let commitment = SaltedCommitment {
        id: object::new(ctx),
        hash: salted_hash,
        revealed: false,
    };
    transfer::transfer(commitment, ctx.sender());
}

public fun reveal_with_salt(
    commitment: &mut SaltedCommitment,
    data: vector<u8>,
    salt: vector<u8>,
) {
    let mut combined = data;
    vector::append(&mut combined, salt);
    let hash = hash::sha3_256(combined);
    assert!(hash == commitment.hash, 0);
    commitment.revealed = true;
}
```

用户在链下将 `data + salt` 拼接后计算哈希并提交承诺。揭示时同时提供原始数据和盐值，合约重新计算哈希并验证。

## 数字签名验证

### Ed25519 签名

Ed25519 是一种基于 Edwards 曲线的高性能数字签名算法，Sui 在 `sui::ed25519` 模块中提供了验证支持：

```move
use sui::ed25519;

/// 验证 Ed25519 签名
/// signature: 64 字节签名
/// public_key: 32 字节公钥
/// msg: 被签名的原始消息
public fun ed25519_verify(
    signature: &vector<u8>,
    public_key: &vector<u8>,
    msg: &vector<u8>,
): bool;
```

典型应用场景：

- 验证链下服务器签发的授权凭证
- 跨链消息验证
- Oracle 数据源签名验证

### ECDSA 签名

Sui 还支持两种 ECDSA 曲线的签名验证：

#### secp256k1（比特币/以太坊使用的曲线）

```move
use sui::ecdsa_k1;

/// 验证 secp256k1 签名并恢复公钥
public fun secp256k1_ecrecover(
    signature: &vector<u8>,  // 65 字节（含恢复标志）
    msg: &vector<u8>,        // 32 字节哈希
    hash: u8,                // 0 = keccak256, 1 = sha256
): vector<u8>;               // 返回 33 字节压缩公钥

/// 直接验证
public fun secp256k1_verify(
    signature: &vector<u8>,
    public_key: &vector<u8>,
    msg: &vector<u8>,
    hash: u8,
): bool;
```

#### secp256r1（NIST P-256，WebAuthn 使用的曲线）

```move
use sui::ecdsa_r1;

public fun secp256r1_ecrecover(
    signature: &vector<u8>,
    msg: &vector<u8>,
    hash: u8,               // 0 = keccak256, 1 = sha256
): vector<u8>;

public fun secp256r1_verify(
    signature: &vector<u8>,
    public_key: &vector<u8>,
    msg: &vector<u8>,
    hash: u8,
): bool;
```

## 实战：签名授权验证

以下示例展示了如何使用 Ed25519 签名验证来实现链下授权机制：

```move
module examples::auth;

use sui::ed25519;
use sui::hash;
use sui::bcs;

public struct AuthConfig has key {
    id: UID,
    authorized_signer: vector<u8>,
}

public fun create_config(
    signer_pubkey: vector<u8>,
    ctx: &mut TxContext,
) {
    let config = AuthConfig {
        id: object::new(ctx),
        authorized_signer: signer_pubkey,
    };
    transfer::share_object(config);
}

public fun execute_with_auth(
    config: &AuthConfig,
    action: vector<u8>,
    signature: vector<u8>,
) {
    let is_valid = ed25519::ed25519_verify(
        &signature,
        &config.authorized_signer,
        &action,
    );
    assert!(is_valid, 0);
    // 签名有效，执行授权操作...
}
```

## 实战：内容哈希注册表

利用哈希函数构建一个内容完整性验证系统：

```move
module examples::content_registry;

use sui::hash;
use sui::table::{Self, Table};

public struct Registry has key {
    id: UID,
    entries: Table<vector<u8>, address>,
}

public fun create(ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        entries: table::new(ctx),
    };
    transfer::share_object(registry);
}

public fun register_content(
    registry: &mut Registry,
    content: vector<u8>,
    ctx: &TxContext,
) {
    let hash = hash::sha3_256(content);
    assert!(!table::contains(&registry.entries, hash), 0);
    table::add(&mut registry.entries, hash, ctx.sender());
}

public fun verify_ownership(
    registry: &Registry,
    content: vector<u8>,
    claimed_owner: address,
): bool {
    let hash = hash::sha3_256(content);
    if (!table::contains(&registry.entries, hash)) {
        return false
    };
    *table::borrow(&registry.entries, hash) == claimed_owner
}
```

## 安全注意事项

1. **不要用哈希生成随机数**：哈希函数是确定性的，仅用已知的链上数据（如区块号、时间戳）作为输入无法生成安全的随机数。应使用 `sui::random` 模块
2. **选择合适的哈希函数**：跨链互操作时必须使用目标链相同的哈希算法（如以太坊使用 Keccak-256）
3. **签名消息格式**：验证签名时，链上和链下必须使用完全相同的消息格式和序列化方式
4. **防止重放攻击**：签名验证应包含唯一标识（如 nonce 或时间戳），防止同一签名被重复使用

## 小结

Sui 提供了全面的密码学工具链，核心要点包括：

- **哈希函数**：`sui::hash` 模块支持 SHA2-256、SHA3-256、BLAKE2b-256 和 Keccak-256 四种算法，均返回 32 字节摘要
- **常见应用**：内容完整性校验、承诺-揭示方案、数据指纹生成
- **Ed25519 签名验证**：通过 `sui::ed25519` 模块进行高性能签名验证
- **ECDSA 签名验证**：支持 secp256k1（比特币/以太坊兼容）和 secp256r1（WebAuthn 兼容）两种曲线
- 承诺-揭示方案应加入盐值防止彩虹表攻击
- 签名验证需注意消息格式一致性和重放攻击防护
