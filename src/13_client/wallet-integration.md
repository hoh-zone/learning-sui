# 钱包集成

将 dApp 与 Sui 钱包集成是构建用户友好的去中心化应用的关键步骤。Sui 采用 Wallet Standard 规范，确保不同钱包之间的互操作性。dApp Kit 提供了开箱即用的 React 组件和 Hooks，大大简化了钱包集成的工作。

## Wallet Standard

Sui 钱包遵循 Wallet Standard 规范，定义了钱包应实现的标准接口：

- **连接/断开**：用户授权 dApp 访问钱包
- **获取账户**：读取用户地址和公钥
- **签名交易**：请求用户签名交易
- **签名消息**：请求用户签名任意消息

所有兼容的钱包（Sui Wallet、Suiet、Martian 等）都实现了这些接口。

## 使用 dApp Kit 集成钱包

### 项目设置

```bash
npm install @mysten/dapp-kit-react @mysten/sui
```

### 配置 dApp Kit

```tsx
// src/dapp-kit.ts
import { createDAppKit } from "@mysten/dapp-kit-react";
import { SuiGrpcClient } from "@mysten/sui/grpc";

export const dAppKit = createDAppKit({
  networks: ["devnet", "testnet", "mainnet"],
  defaultNetwork: "testnet",
  createClient(network) {
    return new SuiGrpcClient({ network });
  },
});
```

TypeScript 模块增强（使 Hooks 返回正确类型）：

```typescript
declare module "@mysten/dapp-kit-react" {
  interface Register {
    dAppKit: typeof dAppKit;
  }
}
```

### 设置 Provider

```tsx
// src/main.tsx
import React from "react";
import ReactDOM from "react-dom/client";
import { DAppKitProvider } from "@mysten/dapp-kit-react";
import { dAppKit } from "./dapp-kit";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <DAppKitProvider dAppKit={dAppKit}>
    <App />
  </DAppKitProvider>
);
```

## 连接钱包

### ConnectButton

最简单的方式——使用内置的连接按钮：

```tsx
import { ConnectButton } from "@mysten/dapp-kit-react";

function Header() {
  return (
    <nav>
      <h1>My dApp</h1>
      <ConnectButton />
    </nav>
  );
}
```

`ConnectButton` 自动处理：

- 发现可用钱包
- 显示钱包选择列表
- 连接和断开操作
- 显示已连接地址

### 获取当前账户

```tsx
import { useCurrentAccount } from "@mysten/dapp-kit-react";

function WalletStatus() {
  const account = useCurrentAccount();

  if (!account) {
    return <p>Please connect your wallet</p>;
  }

  return (
    <div>
      <p>Connected: {account.address}</p>
      <p>
        Short: {account.address.slice(0, 6)}...{account.address.slice(-4)}
      </p>
    </div>
  );
}
```

## 签名与发送交易

### 使用 useDAppKit

```tsx
import { Transaction } from "@mysten/sui/transactions";
import {
  useCurrentAccount,
  useCurrentClient,
  useDAppKit,
} from "@mysten/dapp-kit-react";
import { useState } from "react";

function MintNFTForm({ onMinted }: { onMinted: () => void }) {
  const account = useCurrentAccount();
  const client = useCurrentClient();
  const dAppKit = useDAppKit();
  const [isLoading, setIsLoading] = useState(false);

  const handleMint = async () => {
    if (!account) return;

    setIsLoading(true);
    try {
      const tx = new Transaction();

      const hero = tx.moveCall({
        target: `${PACKAGE_ID}::hero::mint_hero`,
        arguments: [],
      });
      tx.transferObjects([hero], account.address);

      const result = await dAppKit.signAndExecuteTransaction({
        transaction: tx,
      });

      if (result.$kind === 'FailedTransaction') {
        throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
      }
      await client.waitForTransaction({ digest: result.Transaction.digest });

      // 通知父组件刷新
      onMinted();
    } catch (error) {
      console.error("Mint failed:", error);
    } finally {
      setIsLoading(false);
    }
  };

  if (!account) return null;

  return (
    <button onClick={handleMint} disabled={isLoading}>
      {isLoading ? "Minting..." : "Mint Hero"}
    </button>
  );
}
```

### 签名消息

```tsx
function SignMessageButton() {
  const dAppKit = useDAppKit();
  const account = useCurrentAccount();

  const handleSign = async () => {
    if (!account) return;

    const message = new TextEncoder().encode("Hello, Sui!");
    const result = await dAppKit.signPersonalMessage({
      message,
    });

    console.log("Signature:", result.signature);
  };

  return <button onClick={handleSign}>Sign Message</button>;
}
```

## 显示用户资产

### 获取拥有的对象

```tsx
import {
  useCurrentAccount,
  useCurrentClient,
} from "@mysten/dapp-kit-react";
import { useState, useEffect, useCallback } from "react";

function OwnedHeroes({ refreshKey }: { refreshKey: number }) {
  const client = useCurrentClient();
  const account = useCurrentAccount();
  const [heroes, setHeroes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchHeroes = useCallback(async () => {
    if (!account) return;
    setLoading(true);
    try {
      const { data } = await client.core.listOwnedObjects({
        owner: account.address,
        filter: {
          StructType: `${PACKAGE_ID}::hero::Hero`,
        },
        include: { content: true, display: true },
      });
      setHeroes(data);
    } catch (e) {
      console.error("Failed to fetch heroes:", e);
    } finally {
      setLoading(false);
    }
  }, [client, account]);

  useEffect(() => {
    fetchHeroes();
  }, [account?.address, refreshKey, fetchHeroes]);

  if (loading) return <p>Loading...</p>;
  if (heroes.length === 0) return <p>No heroes found</p>;

  return (
    <ul>
      {heroes.map((hero) => (
        <li key={hero.data?.objectId}>
          {hero.data?.display?.data?.name || hero.data?.objectId}
        </li>
      ))}
    </ul>
  );
}
```

## 完整 App 组装

```tsx
import { useState } from "react";
import { ConnectButton, useCurrentAccount } from "@mysten/dapp-kit-react";

function App() {
  const account = useCurrentAccount();
  const [refreshKey, setRefreshKey] = useState(0);

  return (
    <div>
      <header>
        <h1>Hero Game</h1>
        <ConnectButton />
      </header>

      {account && (
        <main>
          <WalletStatus />
          <MintNFTForm onMinted={() => setRefreshKey((k) => k + 1)} />
          <OwnedHeroes refreshKey={refreshKey} />
        </main>
      )}
    </div>
  );
}
```

### 自动刷新流程

```
用户点击 Mint → signAndExecuteTransaction → waitForTransaction → onMinted()
                                                                       │
                                                               setRefreshKey(k+1)
                                                                       │
                                                               useEffect 触发
                                                                       │
                                                               fetchHeroes() 重新查询
```

## 网络切换

dApp Kit 支持在不同网络间切换：

```tsx
import { useCurrentNetwork, useSwitchNetwork } from "@mysten/dapp-kit-react";

function NetworkSelector() {
  const currentNetwork = useCurrentNetwork();
  const switchNetwork = useSwitchNetwork();

  return (
    <select
      value={currentNetwork}
      onChange={(e) => switchNetwork(e.target.value)}
    >
      <option value="devnet">Devnet</option>
      <option value="testnet">Testnet</option>
      <option value="mainnet">Mainnet</option>
    </select>
  );
}
```

## 小结

- Sui 采用 Wallet Standard 规范，确保不同钱包间的互操作性
- dApp Kit 提供 `ConnectButton`、`useCurrentAccount`、`useDAppKit` 等开箱即用工具
- `DAppKitProvider` 包裹应用根组件，提供钱包连接和客户端能力
- 使用 `dAppKit.signAndExecuteTransaction` 请求用户签名并执行交易
- `waitForTransaction` 确保交易被索引后再刷新 UI
- 通过 `refreshKey` 模式实现交易后的自动数据刷新
