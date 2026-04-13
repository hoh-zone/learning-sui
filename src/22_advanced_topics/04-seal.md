# Seal 去中心化密钥管理

本节深入讲解 Seal——Sui 上的去中心化密钥管理（DSM）服务。Seal 允许你加密数据并通过 Move 智能合约定义的访问策略控制谁可以解密。它填补了区块链基础设施中的一个关键空白：虽然区块链解决了身份认证（"你是谁？"），但缺少原生的加密模型（"在什么条件下你可以解密什么？"）。

## 核心概念

### 基于身份的加密（IBE）

Seal 结合了两个核心思想：

1. **IBE（Identity-Based Encryption）**：任何字符串都可以作为公钥，无需密钥交换基础设施
2. **链上访问策略**：Move 合约定义谁有权获取解密密钥

```
IBE 身份 = [packageId] || [id]
            ─────────    ────
            命名空间      策略特定标识符
```

## 架构

### 双支柱设计

```
┌──────────────────────────────────────────────┐
│              Seal 架构                         │
├──────────────────────────────────────────────┤
│                                                │
│  链上（Sui）                                    │
│  ├── Move 包定义访问策略                         │
│  ├── seal_approve* 函数作为"守门人"              │
│  └── 包地址 = IBE 身份命名空间                   │
│                                                │
│  链下（Key Servers）                            │
│  ├── 持有 IBE 主密钥（msk）                      │
│  ├── 通过 dry run 评估 seal_approve*             │
│  ├── 策略通过则派生并返回解密密钥                 │
│  └── 无状态，可水平扩展                          │
│                                                │
└──────────────────────────────────────────────┘
```

### 加密流程（本地操作，不联系密钥服务器）

1. 选择策略（`packageId`）并构造身份 `id`
2. 选择密钥服务器集合和阈值 `t`（如 2-of-3）
3. 生成随机对称密钥 `k_sym`
4. 使用 `k_sym` 和 AES-256-GCM 加密数据
5. 使用 Shamir 秘密共享将 `k_sym` 分成 `n` 份
6. 使用每个密钥服务器的公钥和 IBE 身份加密每份
7. 打包为 `EncryptedObject`

### 解密流程（需要与密钥服务器交互）

1. 构造 PTB 调用 `seal_approve*` 函数
2. 向至少 `t` 个密钥服务器请求派生密钥
3. 密钥服务器通过 dry run 验证策略
4. 策略通过则返回加密的 IBE 派生密钥
5. 使用 `t` 个派生密钥重建 `k_sym`
6. 使用 `k_sym` 解密数据

## 访问策略

### seal_approve 接口

```move
module my_package::access;

const ENoAccess: u64 = 0;

/// 只有指定地址可以解密
entry fun seal_approve(id: vector<u8>, ctx: &TxContext) {
    let caller_bytes = bcs::to_bytes(&ctx.sender());
    assert!(id == caller_bytes, ENoAccess);
}
```

### 内置访问模式

#### 私有数据

```move
/// 只有对象所有者可以解密
entry fun seal_approve(id: vector<u8>, ctx: &TxContext) {
    let caller = bcs::to_bytes(&ctx.sender());
    assert!(id == caller, ENoAccess);
}
```

#### 白名单

```move
/// 白名单地址可以解密
entry fun seal_approve(
    id: vector<u8>,
    list: &Allowlist,
    ctx: &TxContext,
) {
    assert!(allowlist::contains(list, ctx.sender()), ENoAccess);
}
```

#### 时间锁

```move
/// 到达指定时间后任何人可以解密
entry fun seal_approve(id: vector<u8>, c: &clock::Clock) {
    let mut prepared: BCS = bcs::new(id);
    let t = prepared.peel_u64();
    let leftovers = prepared.into_remainder_bytes();
    assert!(
        leftovers.length() == 0 && c.timestamp_ms() >= t,
        ENoAccess
    );
}
```

#### 订阅

```move
/// 持有有效订阅凭证的用户可以解密
entry fun seal_approve(
    id: vector<u8>,
    pass: &SubscriptionPass,
    c: &clock::Clock,
) {
    assert!(pass.is_valid(c.timestamp_ms()), ENoAccess);
}
```

#### 组合模式

```move
/// 组合时间限制和白名单
entry fun seal_approve(
    id: vector<u8>,
    list: &Allowlist,
    c: &clock::Clock,
    ctx: &TxContext,
) {
    let mut prepared: BCS = bcs::new(id);
    let expiry = prepared.peel_u64();
    assert!(c.timestamp_ms() <= expiry, EExpired);
    assert!(allowlist::contains(list, ctx.sender()), ENoAccess);
}
```

## TypeScript SDK 使用

### 安装

```bash
npm install @mysten/seal
```

### 配置密钥服务器

```typescript
import { SealClient } from '@mysten/seal';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const suiClient = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});

// Testnet 验证密钥服务器
const serverObjectIds = [
  '0x73d05d62c18d9374e3ea529e8e0ed6161da1a141a94d3f76ae3fe4e99356db75',
  '0xf5d14a81a982144ae441cd7d64b09027f116a468bd36e7eca494f750591623c8',
];

const sealClient = new SealClient({
  suiClient,
  serverConfigs: serverObjectIds.map(id => ({
    objectId: id,
    weight: 1,
  })),
  verifyKeyServers: false,
});
```

### 加密数据

```typescript
import { fromHEX } from '@mysten/bcs';

const { encryptedObject, key: backupKey } = await sealClient.encrypt({
  threshold: 2,
  packageId: fromHEX(packageId),
  id: fromHEX(identityId),
  data: new TextEncoder().encode('Secret message'),
});
```

### 创建会话密钥

```typescript
import { SessionKey } from '@mysten/seal';

const sessionKey = await SessionKey.create({
  address: suiAddress,
  packageId: fromHEX(packageId),
  ttlMin: 10, // 10 分钟有效期
  suiClient,
});

// 用户在钱包中签名
const message = sessionKey.getPersonalMessage();
const { signature } = await keypair.signPersonalMessage(message);
sessionKey.setPersonalMessageSignature(signature);
```

### 解密数据

```typescript
import { Transaction } from '@mysten/sui/transactions';

// 构建调用 seal_approve 的交易
const tx = new Transaction();
tx.moveCall({
  target: `${packageId}::access::seal_approve`,
  arguments: [
    tx.pure.vector('u8', fromHEX(identityId)),
  ],
});

const txBytes = await tx.build({
  client: suiClient,
  onlyTransactionKind: true,
});

// 解密
const decryptedBytes = await sealClient.decrypt({
  data: encryptedObject,
  sessionKey,
  txBytes,
});

const plaintext = new TextDecoder().decode(decryptedBytes);
```

## 密钥服务器模式

| 模式 | 特点 | 适用场景 |
|------|------|---------|
| **Open** | 接受任何包的请求 | 测试、公共服务 |
| **Permissioned** | 只服务白名单中的包，每客户端独立密钥 | 企业级部署 |
| **Committee** | DKG 分布式密钥，无单点持有完整密钥 | 高安全需求 |

## 安全模型

### 信任假设

| 假设 | 含义 |
|------|------|
| 密钥服务器诚实 | 阈值加密下，少于 `t` 个服务器被攻破即安全 |
| 全节点诚实 | 密钥服务器依赖全节点评估策略 |
| 策略正确 | Move 代码准确表达了预期的访问规则 |

### 阈值配置

| 配置 | 隐私保证 | 可用性保证 |
|------|---------|-----------|
| 1-of-1 | 无阈值保护 | 单点故障 |
| 2-of-3 | 容忍 1 个被攻破 | 容忍 1 个不可用 |
| 3-of-5 | 容忍 2 个被攻破 | 容忍 2 个不可用 |

### 信封加密

对于大文件或高敏感数据，使用信封加密模式：

```typescript
// 1. 本地生成对称密钥并加密数据
const localKey = crypto.getRandomValues(new Uint8Array(32));
const encryptedData = await aesEncrypt(data, localKey);

// 2. 使用 Seal 仅加密对称密钥
const { encryptedObject } = await sealClient.encrypt({
  threshold: 2,
  packageId: fromHEX(packageId),
  id: fromHEX(identityId),
  data: localKey, // 只加密密钥
});

// 3. 分别存储加密数据（Walrus）和加密密钥（Seal）
```

## 应用场景

| 场景 | 实现方式 |
|------|---------|
| 私密 NFT | 加密后存储在 Walrus，所有者解密 |
| 付费内容 | 订阅策略控制解密权限 |
| 密封投票 | 时间锁加密，到期后链上解密计票 |
| 抗 MEV 交易 | 时间锁加密订单，防止抢跑 |
| 端到端消息 | 以接收者地址为 ID 加密 |
| 代币门控 | 持有特定 NFT/代币才能解密 |

## 小结

- Seal 填补了区块链加密基础设施的空白
- 加密只需公钥和策略，不需要联系密钥服务器
- 解密需要密钥服务器通过 dry run 验证 Move 策略
- `seal_approve*` 函数是纯 Move 代码，可以组合任意链上状态
- 阈值加密 + 多密钥服务器保障安全性和可用性
- 信封加密模式适合大文件和高安全需求场景
- 密钥服务器选择是信任决策——选择可靠的运营者并多样化
