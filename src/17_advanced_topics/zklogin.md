# ZKLogin 零知识登录

本节讲解 Sui 的 ZKLogin 认证机制。ZKLogin 允许用户通过熟悉的 OAuth 提供商（Google、Facebook 等）登录，同时通过零知识证明保护隐私。用户无需管理助记词或私钥即可拥有链上地址。

## ZKLogin 原理

### 核心思想

ZKLogin 将 OAuth 身份（如 Google 账号）映射到一个 Sui 地址，无需暴露用户的 OAuth 身份信息：

```
┌──────────────────────────────────────────────┐
│              ZKLogin 流程                      │
├──────────────────────────────────────────────┤
│                                                │
│  用户 ──► OAuth 登录 ──► JWT Token              │
│                              │                 │
│                              ▼                 │
│                     临时密钥对 + JWT            │
│                              │                 │
│                              ▼                 │
│                     零知识证明（ZKP）            │
│                              │                 │
│                              ▼                 │
│                     Sui 地址（确定性派生）       │
│                              │                 │
│                              ▼                 │
│                     签名并发送交易              │
│                                                │
└──────────────────────────────────────────────┘
```

### 关键特性

- **无助记词**：用 Google/Facebook 账号即可登录
- **隐私保护**：零知识证明确保链上不暴露 OAuth 身份
- **确定性地址**：同一个 OAuth 账号始终映射到同一个 Sui 地址
- **兼容性**：与所有 Sui 功能完全兼容

## 四步实现流程

### 第一步：生成临时密钥对和配置

```typescript
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { generateNonce, generateRandomness } from '@mysten/sui/zklogin';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const suiClient = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});

// 生成临时密钥对
const ephemeralKeypair = new Ed25519Keypair();

// 获取当前 epoch
const { epoch } = await suiClient.getLatestSuiSystemState();
const maxEpoch = Number(epoch) + 2; // 临时密钥有效期

// 生成随机数
const randomness = generateRandomness();

// 计算 nonce（用于 OAuth）
const nonce = generateNonce(
  ephemeralKeypair.getPublicKey(),
  maxEpoch,
  randomness,
);
```

### 第二步：OAuth 认证

```typescript
// 构造 OAuth URL（以 Google 为例）
const GOOGLE_CLIENT_ID = process.env.VITE_GOOGLE_CLIENT_ID!;
const REDIRECT_URI = 'http://localhost:5173/callback';

const oauthUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
oauthUrl.searchParams.set('client_id', GOOGLE_CLIENT_ID);
oauthUrl.searchParams.set('redirect_uri', REDIRECT_URI);
oauthUrl.searchParams.set('response_type', 'id_token');
oauthUrl.searchParams.set('scope', 'openid email');
oauthUrl.searchParams.set('nonce', nonce);

// 将用户重定向到 OAuth 页面
window.location.href = oauthUrl.toString();
```

回调处理：

```typescript
// 从 URL hash 中获取 JWT
const hash = window.location.hash.substring(1);
const params = new URLSearchParams(hash);
const jwtToken = params.get('id_token')!;

// 解码 JWT（不验证签名，仅读取内容）
import { jwtDecode } from 'jwt-decode';
const decodedJwt = jwtDecode(jwtToken);
```

### 第三步：生成零知识证明

```typescript
import { getZkLoginSignature } from '@mysten/sui/zklogin';

// 准备证明请求负载
const zkProofPayload = {
  jwt: jwtToken,
  extendedEphemeralPublicKey: ephemeralKeypair.getPublicKey().toBase64(),
  maxEpoch: maxEpoch,
  jwtRandomness: randomness,
  salt: userSalt, // 用户特定的盐值
  keyClaimName: 'sub',
};

// 向证明服务请求 ZKP
const zkProofResponse = await fetch('https://prover.mystenlabs.com/v1', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(zkProofPayload),
});

const zkProof = await zkProofResponse.json();
```

### 第四步：创建钱包并发送交易

```typescript
import { computeZkLoginAddress, getZkLoginSignature } from '@mysten/sui/zklogin';

// 派生 Sui 地址
const zkLoginAddress = computeZkLoginAddress({
  claimName: 'sub',
  claimValue: decodedJwt.sub!,
  iss: decodedJwt.iss!,
  aud: GOOGLE_CLIENT_ID,
  userSalt: BigInt(userSalt),
});

console.log('ZKLogin Address:', zkLoginAddress);

// 构造并签名交易
const tx = new Transaction();
tx.setSender(zkLoginAddress);
// ... 添加交易命令

const { bytes, signature: ephSignature } = await tx.sign({
  client: suiClient,
  signer: ephemeralKeypair,
});

// 组合 ZKLogin 签名
const zkLoginSignature = getZkLoginSignature({
  inputs: {
    ...zkProof,
    addressSeed: addressSeed.toString(),
  },
  maxEpoch,
  userSignature: ephSignature,
});

// 执行交易
const result = await suiClient.core.executeTransaction({
  transaction: bytes,
  signatures: [zkLoginSignature],
});

if (result.$kind === 'FailedTransaction') {
  throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
}
await suiClient.waitForTransaction({ digest: result.Transaction.digest });
```

## React 组件示例

### ZKLogin 上下文

```typescript
// src/contexts/AppContext.tsx
import React, { createContext, useState, useContext } from 'react';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

interface AppState {
  ephemeralKeypair: Ed25519Keypair | null;
  jwt: string | null;
  zkProof: any | null;
  zkAddress: string | null;
  maxEpoch: number;
  randomness: string;
}

const AppContext = createContext<{
  state: AppState;
  setState: React.Dispatch<React.SetStateAction<AppState>>;
} | null>(null);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AppState>({
    ephemeralKeypair: null,
    jwt: null,
    zkProof: null,
    zkAddress: null,
    maxEpoch: 0,
    randomness: '',
  });

  return (
    <AppContext.Provider value={{ state, setState }}>
      {children}
    </AppContext.Provider>
  );
}

export const useAppState = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error('useAppState must be used within AppProvider');
  return context;
};
```

### 登录按钮组件

```typescript
// src/components/ZkLogin/LoginButton.tsx
import { useAppState } from '../../contexts/AppContext';

export function LoginButton() {
  const { state } = useAppState();

  const handleLogin = () => {
    if (!state.ephemeralKeypair) {
      alert('请先生成临时密钥对');
      return;
    }
    // 重定向到 OAuth
    window.location.href = buildOAuthUrl(state);
  };

  return (
    <button onClick={handleLogin} disabled={!state.ephemeralKeypair}>
      使用 Google 登录
    </button>
  );
}
```

## 环境配置

```bash
# .env
VITE_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
VITE_SUI_NETWORK=testnet
VITE_PROVER_URL=https://prover.mystenlabs.com/v1
```

### Google Cloud 配置

1. 创建 Google Cloud 项目
2. 启用 OAuth 2.0 API
3. 配置 OAuth 同意屏幕
4. 创建 OAuth 客户端 ID（Web 应用类型）
5. 添加授权重定向 URI

## 安全注意事项

| 要点 | 说明 |
|------|------|
| 盐值管理 | 用户盐值必须持久存储，丢失则无法恢复地址 |
| 临时密钥有效期 | 建议 2-3 个 epoch，过期需重新认证 |
| JWT 验证 | 虽然 ZKP 已验证，前端仍应基本检查 JWT |
| HTTPS | OAuth 回调必须使用 HTTPS（本地开发除外） |
| 证明服务 | 使用 Mysten Labs 提供的证明服务或自建 |

## 小结

- ZKLogin 让用户通过 OAuth 登录直接获得 Sui 链上地址
- 四步流程：生成临时密钥 → OAuth 认证 → 生成 ZKP → 签名交易
- 零知识证明确保链上不暴露用户的 OAuth 身份信息
- 同一 OAuth 账号 + 盐值始终派生出同一个 Sui 地址
- 适合面向普通用户的 dApp，降低 Web3 入门门槛
- 妥善管理盐值——丢失盐值意味着无法访问对应的链上资产
