# dApp Kit 前端开发

本节讲解如何使用 `@mysten/dapp-kit-react` 构建 React 前端应用，包括连接钱包、查询链上数据、构造和签名交易。dApp Kit 提供 `createDAppKit` + `DAppKitProvider` 以及一套 React hooks，大幅简化 Sui dApp 前端的开发。（旧版 `@mysten/dapp-kit` 已废弃，新项目请使用 `@mysten/dapp-kit-react`。）

## 项目初始化

### 使用脚手架创建项目

```bash
npm create @mysten/dapp
# 按提示操作：
# - 选择 "React app with dApp Kit"
# - 输入项目名称
# - 选择包管理器

cd my-dapp
pnpm install
pnpm run dev
```

### 安装依赖（手动配置）

```bash
pnpm add @mysten/dapp-kit-react @mysten/sui @tanstack/react-query
```

## 应用配置

### Provider 设置

使用 `createDAppKit` 创建实例，并用 `DAppKitProvider` 包裹应用；客户端推荐使用 `SuiGrpcClient`：

```typescript
// src/dapp-kit.ts
import { createDAppKit } from '@mysten/dapp-kit-react';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const GRPC_URLS: Record<string, string> = {
  testnet: 'https://fullnode.testnet.sui.io:443',
  mainnet: 'https://fullnode.mainnet.sui.io:443',
};

export const dAppKit = createDAppKit({
  networks: ['testnet', 'mainnet'],
  defaultNetwork: 'testnet',
  createClient: (network) =>
    new SuiGrpcClient({ network, baseUrl: GRPC_URLS[network] }),
  autoConnect: true,
});

declare module '@mysten/dapp-kit-react' {
  interface Register {
    dAppKit: typeof dAppKit;
  }
}
```

```tsx
// src/main.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { DAppKitProvider, ConnectButton } from '@mysten/dapp-kit-react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { dAppKit } from './dapp-kit';
import App from './App';

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <DAppKitProvider dAppKit={dAppKit}>
        <ConnectButton />
        <App />
      </DAppKitProvider>
    </QueryClientProvider>
  </React.StrictMode>,
);
```

## 连接钱包

### ConnectButton 组件

```typescript
// src/components/WalletConnect.tsx
import { ConnectButton, useCurrentAccount } from '@mysten/dapp-kit-react';

export function WalletConnect() {
  const account = useCurrentAccount();

  return (
    <div>
      <ConnectButton />
      {account && (
        <p>已连接: {account.address}</p>
      )}
    </div>
  );
}
```

### 使用钱包 Hooks

```typescript
import { useCurrentAccount, useCurrentWallet, useDAppKit } from '@mysten/dapp-kit-react';

function WalletInfo() {
  const account = useCurrentAccount();
  const wallet = useCurrentWallet();
  const dAppKit = useDAppKit();

  if (!account) return <p>请先连接钱包</p>;

  return (
    <div>
      <p>钱包: {wallet?.name}</p>
      <p>地址: {account.address}</p>
      <button onClick={() => dAppKit.disconnectWallet()}>断开连接</button>
    </div>
  );
}
```

## 查询链上数据

### 查询对象（HeroRegistry）

使用 `useCurrentClient` 获取客户端，配合 `useQuery` 查询；仅在需要时启用（如已选网络）：

```typescript
// src/components/HeroesList.tsx
import { useQuery } from '@tanstack/react-query';
import { useCurrentClient } from '@mysten/dapp-kit-react';

const REGISTRY_ID = '0x...'; // 你的 HeroRegistry 对象 ID

export function HeroesList() {
  const client = useCurrentClient();
  const { data, isPending, error } = useQuery({
    queryKey: ['object', REGISTRY_ID],
    queryFn: () => client!.core.getObject({ objectId: REGISTRY_ID, include: { content: true } }),
    enabled: !!client,
  });

  if (isPending) return <p>加载中...</p>;
  if (error) return <p>错误: {(error as Error).message}</p>;

  const content = data?.data?.content;
  const fields = content?.dataType === 'moveObject' ? (content.fields as any) : null;

  if (!fields) return <p>未找到注册表</p>;

  return (
    <div>
      <h2>所有英雄（共 {fields.counter} 个）</h2>
      <ul>
        {fields.ids.map((id: string) => (
          <li key={id}>
            <a
              href={`https://suiscan.xyz/testnet/object/${id}`}
              target="_blank"
              rel="noreferrer"
            >
              {id}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### 批量查询英雄详情

```typescript
import { useQuery } from '@tanstack/react-query';
import { useCurrentClient } from '@mysten/dapp-kit-react';

function HeroDetails({ heroIds }: { heroIds: string[] }) {
  const client = useCurrentClient();
  const { data } = useQuery({
    queryKey: ['getObjects', heroIds],
    queryFn: () => client!.core.getObjects({ objectIds: heroIds, include: { content: true } }),
    enabled: !!client && heroIds.length > 0,
  });

  if (!data) return null;

  return (
    <div className="hero-grid">
      {data.map((obj, i) => {
        const fields = obj.data?.content?.dataType === 'moveObject'
          ? (obj.data.content.fields as any)
          : null;
        if (!fields) return null;
        return <HeroCard key={i} fields={fields} />;
      })}
    </div>
  );
}

function HeroCard({ fields }: { fields: any }) {
  return (
    <div className="hero-card">
      <h3>{fields.name}</h3>
      <p>耐力: {fields.stamina}</p>
      <p>武器: {fields.weapon ? '已装备' : '无'}</p>
    </div>
  );
}
```

### 查询我的英雄

```typescript
// src/components/OwnedHeroes.tsx
import { useQuery } from '@tanstack/react-query';
import { useCurrentAccount, useCurrentClient } from '@mysten/dapp-kit-react';

const PACKAGE_ID = '0x...';

export function OwnedHeroes() {
  const account = useCurrentAccount();
  const client = useCurrentClient();

  const { data, isPending, refetch } = useQuery({
    queryKey: ['ownedObjects', account?.address, PACKAGE_ID],
    queryFn: () =>
      client!.core.listOwnedObjects({
        owner: account!.address,
        filter: { StructType: `${PACKAGE_ID}::hero::Hero` },
        include: { content: true },
      }),
    enabled: !!account?.address && !!client,
  });

  if (!account) return <p>请先连接钱包</p>;
  if (isPending) return <p>加载中...</p>;

  return (
    <div>
      <h2>我的英雄</h2>
      {data?.data?.map((obj) => {
        const fields = obj.data?.content?.dataType === 'moveObject'
          ? (obj.data.content.fields as any)
          : null;
        if (!fields) return null;
        return (
          <div key={obj.data?.objectId}>
            <p>{fields.name} - 耐力: {fields.stamina}</p>
          </div>
        );
      })}
    </div>
  );
}
```

## 签名与执行交易

### 创建英雄表单

```typescript
// src/components/CreateHeroForm.tsx
import { useState } from 'react';
import { useDAppKit, useCurrentClient } from '@mysten/dapp-kit-react';
import { Transaction } from '@mysten/sui/transactions';
import { useQueryClient } from '@tanstack/react-query';

const PACKAGE_ID = '0x...';
const REGISTRY_ID = '0x...';

export function CreateHeroForm() {
  const [heroName, setHeroName] = useState('');
  const [stamina, setStamina] = useState(100);
  const [weaponName, setWeaponName] = useState('');
  const [attack, setAttack] = useState(50);
  const [isPending, setIsPending] = useState(false);

  const client = useCurrentClient();
  const dAppKit = useDAppKit();
  const queryClient = useQueryClient();

  const handleMint = async () => {
    if (!client) return;
    setIsPending(true);
    try {
      const tx = new Transaction();

      const [hero] = tx.moveCall({
        target: `${PACKAGE_ID}::hero::new_hero`,
        arguments: [
          tx.pure.string(heroName || 'Hero'),
          tx.pure.u64(stamina),
          tx.object(REGISTRY_ID),
        ],
      });

      const [weapon] = tx.moveCall({
        target: `${PACKAGE_ID}::hero::new_weapon`,
        arguments: [
          tx.pure.string(weaponName || 'Sword'),
          tx.pure.u64(attack),
        ],
      });

      tx.moveCall({
        target: `${PACKAGE_ID}::hero::equip_weapon`,
        arguments: [hero, weapon],
      });

      const result = await dAppKit.signAndExecuteTransaction({ transaction: tx });
      if (result.$kind === 'FailedTransaction') {
        throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
      }
      await client.waitForTransaction({ digest: result.Transaction.digest });
      queryClient.invalidateQueries();
    } catch (e) {
      console.error('交易失败:', e);
    } finally {
      setIsPending(false);
    }
  };

  return (
    <div>
      <h2>创建英雄</h2>
      <div>
        <label>英雄名称:</label>
        <input
          value={heroName}
          onChange={(e) => setHeroName(e.target.value)}
          placeholder="输入英雄名称"
        />
      </div>
      <div>
        <label>耐力值:</label>
        <input
          type="number"
          value={stamina}
          onChange={(e) => setStamina(Number(e.target.value))}
        />
      </div>
      <div>
        <label>武器名称:</label>
        <input
          value={weaponName}
          onChange={(e) => setWeaponName(e.target.value)}
          placeholder="输入武器名称"
        />
      </div>
      <div>
        <label>攻击力:</label>
        <input
          type="number"
          value={attack}
          onChange={(e) => setAttack(Number(e.target.value))}
        />
      </div>
      <button onClick={() => handleMint()} disabled={isPending}>
        {isPending ? '铸造中...' : '铸造英雄'}
      </button>
    </div>
  );
}
```

## 完整 App 组装

```typescript
// src/App.tsx
import { ConnectButton } from '@mysten/dapp-kit-react';
import { HeroesList } from './components/HeroesList';
import { OwnedHeroes } from './components/OwnedHeroes';
import { CreateHeroForm } from './components/CreateHeroForm';

function App() {
  return (
    <div className="app">
      <header>
        <h1>Hero NFT DApp</h1>
        <ConnectButton />
      </header>

      <main>
        <section>
          <CreateHeroForm />
        </section>

        <section>
          <OwnedHeroes />
        </section>

        <section>
          <HeroesList />
        </section>
      </main>
    </div>
  );
}

export default App;
```

## 常用 Hooks 速查

| Hook | 用途 |
|------|------|
| `useCurrentAccount` | 获取当前连接的钱包账户 |
| `useCurrentWallet` | 获取当前钱包信息 |
| `useDAppKit` | 获取 dAppKit 实例（含 `signAndExecuteTransaction`、`disconnectWallet` 等） |
| `useCurrentClient` | 获取当前网络的 Sui 客户端（如 `SuiGrpcClient`） |
| `useSignPersonalMessage` | 签名个人消息 |

链上查询使用 `useCurrentClient` + `@tanstack/react-query` 的 `useQuery` / `useInfiniteQuery`，并设置 `enabled: !!account` 等条件。

## 小结

dApp Kit 前端开发的核心要点：

- 使用 `createDAppKit` + `DAppKitProvider` 配置应用，客户端推荐 `SuiGrpcClient`
- `ConnectButton` 提供开箱即用的钱包连接 UI
- 链上数据用 `useCurrentClient` + `useQuery` 查询，并设置 `enabled` 避免未连接时请求
- 交易使用 `dAppKit.signAndExecuteTransaction`，根据 `result.$kind` 判断成功/失败，成功后先 `client.waitForTransaction` 再 `queryClient.invalidateQueries`
- 利用 React Query 的缓存与失效机制减少重复请求
