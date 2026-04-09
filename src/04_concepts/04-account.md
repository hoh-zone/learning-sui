# 账户模型

在 Sui 中，账户（Account）代表区块链上的一个用户身份。账户由私钥生成，通过对应的地址来标识。每个账户可以拥有对象、发送交易，是用户与 Sui 网络交互的入口。

## 账户的生成

账户的生成遵循一条从私钥到地址的推导链：

```
私钥（Private Key）
    ↓ 数学推导
公钥（Public Key）
    ↓ 哈希运算
地址（Address）
```

### 密钥对

密钥对（Key Pair）由公钥和私钥组成：

- **私钥**：必须严格保密，用于对交易进行数字签名。持有私钥即拥有账户的完全控制权。
- **公钥**：可以公开分享，用于验证签名的合法性。
- **地址**：从公钥通过哈希运算派生，是账户在链上的唯一标识。

使用 Sui CLI 生成新的密钥对：

```bash
sui client new-address ed25519
```

输出示例：

```
╭─────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.           │
├────────────────┬────────────────────────────────────────┤
│ alias          │ tender-garnet                          │
│ address        │ 0xa11c...                             │
│ keyScheme      │ ed25519                                │
╰────────────────┴────────────────────────────────────────╯
```

## 支持的密码学方案

Sui 支持多种密码学签名方案，这种特性被称为**密码学敏捷性**（Cryptographic Agility）：

| 方案 | 说明 | 典型用途 |
|------|------|----------|
| **Ed25519** | 高性能的椭圆曲线签名算法 | 默认方案，大多数场景的首选 |
| **Secp256k1** | 与比特币、以太坊相同的曲线 | 兼容现有加密货币生态 |
| **Secp256r1** | NIST 标准曲线，又称 P-256 | 硬件安全模块（HSM）和 Passkey 支持 |
| **zkLogin** | 基于零知识证明的社交登录 | 用 Google、Facebook 等账号生成链上身份 |

### 密码学敏捷性

Sui 的密码学敏捷性意味着不同的签名方案可以共存于同一网络中。用户可以根据需求选择最合适的方案：

```bash
# 使用 Ed25519（默认）
sui client new-address ed25519

# 使用 Secp256k1（兼容比特币/以太坊）
sui client new-address secp256k1

# 使用 Secp256r1（兼容 Passkey/硬件安全模块）
sui client new-address secp256r1
```

所有方案生成的地址格式完全相同，都是 32 字节的地址，在链上可以无差别地使用。

## zkLogin — 社交登录上链

zkLogin 是 Sui 独有的创新特性，允许用户通过社交账号（如 Google、Facebook、Apple、Twitch 等）直接生成区块链账户，无需管理私钥或助记词。

### 工作原理

```
用户使用 Google 登录
    ↓
获取 OAuth JWT Token
    ↓
生成零知识证明（ZKP）
    ↓
将证明映射为 Sui 地址
    ↓
用户获得链上账户
```

zkLogin 的核心价值在于：

- **降低门槛**：用户无需理解密钥管理、助记词等区块链概念
- **隐私保护**：零知识证明确保社交账号信息不会泄露到链上
- **安全性**：即使 OAuth 提供商被攻破，攻击者也无法获取用户的私钥

## 账户与对象的关系

账户是对象的"所有者"。在 Sui 的面向对象模型中，账户可以：

- **拥有对象**：对象可以归属于某个地址（账户）
- **发送交易**：修改自己拥有的对象、调用智能合约函数
- **接收转移**：接受其他账户转移过来的对象

```move
module my_project::wallet;

use sui::coin::Coin;
use sui::sui::SUI;

public fun send_coin(
    coin: Coin<SUI>,
    recipient: address,
) {
    transfer::public_transfer(coin, recipient);
}
```

在上面的例子中，`recipient` 就是接收方的账户地址。

## 交易与签名

每一笔提交到 Sui 网络的交易都必须由发送者的私钥签名。签名过程确保：

1. **身份认证**：证明交易确实由该地址的所有者发起
2. **完整性**：交易内容在传输过程中未被篡改
3. **不可否认**：发送者无法否认曾发送过该交易

```
交易构建（Transaction）
    ↓
私钥签名（Sign）
    ↓
提交到网络（Submit）
    ↓
验证者验证签名（Verify）
    ↓
执行交易（Execute）
```

### 使用 CLI 发送交易

```bash
# 查看当前活跃地址
sui client active-address

# 转账 SUI
sui client transfer-sui --to 0xRECIPIENT --sui-coin-object-id 0xCOIN_ID --amount 1000
```

CLI 在执行交易时会自动使用当前活跃地址对应的私钥进行签名。

## 多地址管理

一个用户可以同时管理多个地址（账户），Sui CLI 提供了相应的管理工具：

```bash
# 查看所有地址
sui client addresses

# 切换活跃地址
sui client switch --address 0xYOUR_ADDRESS
```

## 小结

Sui 的账户模型基于公钥密码学，通过"私钥 → 公钥 → 地址"的推导链生成用户身份。Sui 支持 Ed25519、Secp256k1、Secp256r1 三种密码学方案，并通过 zkLogin 实现社交账号登录上链，大幅降低了用户使用门槛。账户通过地址标识，可以拥有对象、发送交易，是用户与 Sui 链上世界交互的桥梁。
