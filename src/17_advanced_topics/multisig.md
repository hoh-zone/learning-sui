# 多签（Multisig）

本节讲解 Sui 上的多重签名（Multisig）机制。多签允许多个密钥共同控制一个地址，通过设置权重和阈值来实现灵活的资产管理和权限控制。

## 多签概述

多签地址由多个公钥和一个阈值（threshold）定义。只有当签名的权重之和达到或超过阈值时，交易才会被执行。

```
┌────────────────────────────────────────────┐
│            多签 2-of-3 示例                  │
├────────────────────────────────────────────┤
│                                              │
│  密钥 A（权重 1）  ──┐                        │
│  密钥 B（权重 1）  ──┼── 阈值 = 2 ──► 执行    │
│  密钥 C（权重 1）  ──┘                        │
│                                              │
│  任意 2 个密钥签名即可执行交易                  │
│                                              │
└────────────────────────────────────────────┘
```

## 创建多签地址

### 使用 CLI 创建

```bash
# 生成三个密钥对
sui keytool generate ed25519
sui keytool generate ed25519
sui keytool generate ed25519

# 获取公钥
sui keytool list

# 创建多签地址（阈值=2，三个公钥各权重1）
sui keytool multi-sig-address \
  --pks <PK_A> <PK_B> <PK_C> \
  --weights 1 1 1 \
  --threshold 2
```

### 使用 TypeScript SDK

```typescript
import { MultiSigPublicKey } from '@mysten/sui/multisig';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

// 创建三个密钥对
const keypairA = new Ed25519Keypair();
const keypairB = new Ed25519Keypair();
const keypairC = new Ed25519Keypair();

// 创建多签公钥
const multiSigPublicKey = MultiSigPublicKey.fromPublicKeys({
  threshold: 2,
  publicKeys: [
    { publicKey: keypairA.getPublicKey(), weight: 1 },
    { publicKey: keypairB.getPublicKey(), weight: 1 },
    { publicKey: keypairC.getPublicKey(), weight: 1 },
  ],
});

// 获取多签地址
const multiSigAddress = multiSigPublicKey.toSuiAddress();
console.log('MultiSig Address:', multiSigAddress);
```

## 权重设置策略

### 等权模式

```typescript
// 3-of-5 等权多签
const multiSig = MultiSigPublicKey.fromPublicKeys({
  threshold: 3,
  publicKeys: [
    { publicKey: pk1, weight: 1 },
    { publicKey: pk2, weight: 1 },
    { publicKey: pk3, weight: 1 },
    { publicKey: pk4, weight: 1 },
    { publicKey: pk5, weight: 1 },
  ],
});
```

### 加权模式

```typescript
// 加权多签：CEO 有更高权重
const multiSig = MultiSigPublicKey.fromPublicKeys({
  threshold: 3,
  publicKeys: [
    { publicKey: ceoPk, weight: 2 },    // CEO: 权重 2
    { publicKey: ctoPk, weight: 1 },    // CTO: 权重 1
    { publicKey: cfoPk, weight: 1 },    // CFO: 权重 1
    { publicKey: cooFk, weight: 1 },    // COO: 权重 1
  ],
});
// CEO + 任意一人 = 3 ≥ 阈值
// 或 CTO + CFO + COO = 3 ≥ 阈值
```

## 交易签名与执行

### 构造交易

```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const client = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});

const tx = new Transaction();
tx.setSender(multiSigAddress);
tx.setGasOwner(multiSigAddress);

// 添加交易命令
tx.transferObjects(
  [tx.object('0x...')],
  tx.pure.address('0x...')
);

// 构建交易字节
const txBytes = await tx.build({ client });
```

### 收集签名

```typescript
// 签名者 A 签名
const sigA = await keypairA.signTransaction(txBytes);

// 签名者 B 签名
const sigB = await keypairB.signTransaction(txBytes);
```

### 组合并执行

```typescript
// 组合多签签名
const multiSigSignature = multiSigPublicKey.combinePartialSignatures([
  sigA.signature,
  sigB.signature,
]);

// 执行交易
const result = await client.core.executeTransaction({
  transaction: txBytes,
  signatures: [multiSigSignature],
  include: { effects: true },
});

if (result.$kind === 'FailedTransaction') {
  throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
}
await client.waitForTransaction({ digest: result.Transaction.digest });
```

## 使用 CLI 签名

```bash
# 各方分别签名
sui keytool sign \
  --address <SIGNER_A_ADDRESS> \
  --data <TX_BYTES_BASE64>

sui keytool sign \
  --address <SIGNER_B_ADDRESS> \
  --data <TX_BYTES_BASE64>

# 组合多签
sui keytool multi-sig-combine-partial-sig \
  --pks <PK_A> <PK_B> <PK_C> \
  --weights 1 1 1 \
  --threshold 2 \
  --sigs <SIG_A> <SIG_B>

# 执行交易
sui client execute-signed-tx \
  --tx-bytes <TX_BYTES_BASE64> \
  --signatures <MULTI_SIG>
```

## 多签管理 UpgradeCap

多签是管理包升级权限的理想方式：

```typescript
// 将 UpgradeCap 转移到多签地址
const tx = new Transaction();
tx.transferObjects(
  [tx.object(UPGRADE_CAP_ID)],
  tx.pure.address(multiSigAddress),
);

// 后续升级需要多签授权
async function upgradeWithMultisig() {
  const upgradeTx = new Transaction();
  upgradeTx.setSender(multiSigAddress);
  // ... 升级逻辑

  const txBytes = await upgradeTx.build({ client });

  // 收集足够的签名
  const sig1 = await keypairA.signTransaction(txBytes);
  const sig2 = await keypairB.signTransaction(txBytes);

  const multiSig = multiSigPublicKey.combinePartialSignatures([
    sig1.signature,
    sig2.signature,
  ]);

  const result = await client.core.executeTransaction({
    transaction: txBytes,
    signatures: [multiSig],
  });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await client.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

## 应用场景

| 场景 | 推荐配置 | 说明 |
|------|---------|------|
| 团队金库 | 3-of-5 等权 | 任意三人授权资金移动 |
| 包升级 | 2-of-3 等权 | 防止单点失败 |
| DAO 治理 | 加权投票 | 按持股比例分配权重 |
| 冷存储 | 2-of-3 不同设备 | 一个密钥离线存储 |
| 紧急操作 | CEO 高权重 | CEO 可快速响应 |

## 小结

- 多签通过多个密钥的组合签名来控制地址，提高安全性
- 权重和阈值机制支持灵活的签名策略
- 支持 Ed25519、Secp256k1 和 Secp256r1 多种密钥类型混合
- 多签特别适合管理 UpgradeCap、金库和关键权限
- 使用 CLI 或 TypeScript SDK 都可以创建和管理多签
- 交易签名可以异步收集，适合分布式团队
