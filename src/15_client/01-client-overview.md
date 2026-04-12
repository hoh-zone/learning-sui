# Sui Client SDK 概览

与 Sui 区块链交互需要客户端 SDK。Sui 官方提供了 TypeScript SDK 作为主要的客户端开发工具，同时社区也维护了 Rust、Python 等语言的 SDK。此外，dApp Kit 为 React 开发者提供了开箱即用的组件和 Hooks。本节将概览各 SDK 的特点和适用场景。

## TypeScript SDK

TypeScript SDK（`@mysten/sui`）是最成熟、最常用的 Sui 客户端库，适用于前端 dApp、Node.js 服务和脚本工具。

### 安装

```bash
npm install @mysten/sui
```

### 初始化客户端

推荐使用 **gRPC 客户端**（`SuiGrpcClient`），性能更好；需要 JSON-RPC 时使用 `SuiJsonRpcClient`：

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

// 推荐：gRPC 客户端
const testnetClient = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

const mainnetClient = new SuiGrpcClient({
  network: "mainnet",
  baseUrl: "https://fullnode.mainnet.sui.io:443",
});
```

```typescript
// 可选：JSON-RPC 客户端（旧 API，仍可用）
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from "@mysten/sui/jsonRpc";

const client = new SuiJsonRpcClient({
  url: getJsonRpcFullnodeUrl("testnet"),
  network: "testnet",
});
```

可用网络：

| 网络 | 用途 |
| --- | --- |
| `devnet` | 开发测试，频繁重置 |
| `testnet` | 集成测试，较稳定 |
| `mainnet` | 生产环境 |
| `localnet` | 本地开发 |

### 查询余额

```typescript
// v2：使用 client.core.listBalances，再按 coinType 汇总
const { data: balances } = await client.core.listBalances({
  owner: "0xYOUR_ADDRESS",
});
const suiBalance = balances.find((b) => b.coinType === "0x2::sui::SUI");
console.log(`Balance: ${suiBalance?.totalBalance ?? 0}`);
```

### 使用水龙头

在 devnet/testnet 上可以免费获取测试 SUI：

```typescript
import { getFaucetHost, requestSuiFromFaucetV2 } from "@mysten/sui/faucet";

await requestSuiFromFaucetV2({
  host: getFaucetHost("devnet"),
  recipient: "0xYOUR_ADDRESS",
});
```

### 密钥管理

```typescript
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

// 生成新密钥对
const keypair = new Ed25519Keypair();

// 从私钥导入
const keypairFromSecret = Ed25519Keypair.fromSecretKey(secretKey);

// 从助记词导入
const keypairFromMnemonic = Ed25519Keypair.deriveKeypair(mnemonic);

console.log(`Address: ${keypair.toSuiAddress()}`);
```

## gRPC 与 JSON-RPC

**SuiGrpcClient**（见上文「初始化客户端」）使用二进制 gRPC 协议，为当前推荐方式。**SuiJsonRpcClient** 使用 JSON-RPC，兼容旧版节点或工具时可选。

## dApp Kit（React）

dApp Kit 为 React 开发者提供了完整的 Sui dApp 开发工具包：

### 安装

```bash
npm install @mysten/dapp-kit-react
```

### 配置 Provider

```tsx
import { createDAppKit, DAppKitProvider } from "@mysten/dapp-kit-react";
import { SuiGrpcClient } from "@mysten/sui/grpc";

const dAppKit = createDAppKit({
  networks: ["devnet", "testnet", "mainnet"],
  defaultNetwork: "testnet",
  createClient(network) {
    return new SuiGrpcClient({ network });
  },
});

function App() {
  return (
    <DAppKitProvider dAppKit={dAppKit}>
      <MyApp />
    </DAppKitProvider>
  );
}
```

### 核心 Hooks

```tsx
import {
  ConnectButton,
  useCurrentAccount,
  useCurrentClient,
  useDAppKit,
} from "@mysten/dapp-kit-react";

function MyComponent() {
  const account = useCurrentAccount();
  const client = useCurrentClient();
  const dAppKit = useDAppKit();

  if (!account) return <ConnectButton />;

  return <p>Connected: {account.address}</p>;
}
```

### 签名并执行交易

```tsx
import { Transaction } from "@mysten/sui/transactions";
import { useDAppKit, useCurrentAccount, useCurrentClient } from "@mysten/dapp-kit-react";

function MintButton() {
  const dAppKit = useDAppKit();
  const client = useCurrentClient();
  const account = useCurrentAccount();

  const handleMint = async () => {
    const tx = new Transaction();
    const hero = tx.moveCall({
      target: `${PACKAGE_ID}::hero::mint_hero`,
      arguments: [],
    });
    tx.transferObjects([hero], account!.address);

    const result = await dAppKit.signAndExecuteTransaction({
      transaction: tx,
    });

    if (result.$kind === "FailedTransaction") {
      throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
    }
    await client.waitForTransaction({ digest: result.Transaction.digest });
    console.log("Transaction digest:", result.Transaction.digest);
  };

  return <button onClick={handleMint}>Mint Hero</button>;
}
```

## Rust SDK

Sui Rust SDK 适用于后端服务、命令行工具和高性能应用：

```rust
use sui_sdk::SuiClientBuilder;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let sui = SuiClientBuilder::default()
        .build("https://fullnode.testnet.sui.io:443")
        .await?;

    let address = "0xYOUR_ADDRESS".parse()?;
    let balance = sui.coin_read_api().get_balance(address, None).await?;

    println!("Balance: {}", balance.total_balance);
    Ok(())
}
```

## SDK 选择指南

| 场景 | 推荐 SDK |
| --- | --- |
| React 前端 dApp | dApp Kit + TypeScript SDK |
| Node.js 后端服务 | TypeScript SDK |
| 命令行工具 | TypeScript SDK 或 Rust SDK |
| 高性能后端 | Rust SDK 或 gRPC Client |
| 脚本和自动化 | TypeScript SDK |
| 移动端 | TypeScript SDK (React Native) |

## 测试连接

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

async function testConnection() {
  const client = new SuiGrpcClient({
    network: "devnet",
    baseUrl: "https://fullnode.devnet.sui.io:443",
  });

  const chainId = await client.getChainIdentifier();
  console.log("Chain ID:", chainId);
}

testConnection();
```

## 小结

- TypeScript SDK 是最主要的 Sui 客户端库，覆盖所有常见操作
- 推荐使用 `SuiGrpcClient`（`@mysten/sui/grpc`）连接全节点；可选 `SuiJsonRpcClient`（`@mysten/sui/jsonRpc`）
- dApp Kit 为 React 提供了 Provider、Hooks 和 ConnectButton
- gRPC 客户端使用二进制协议，适合高性能场景
- Rust SDK 适用于后端服务和命令行工具
- 根据应用场景选择合适的 SDK 组合
