# TypeScript SDK 集成

本节讲解如何使用 `@mysten/sui` TypeScript SDK 与链上 Move 合约交互。我们将覆盖 SDK 安装配置、客户端初始化、交易构造、签名执行和结果解析的完整流程。

## 安装与配置

### 安装依赖

```bash
npm install @mysten/sui
# 或
pnpm add @mysten/sui
```

### 客户端初始化

推荐使用 gRPC 客户端（`SuiGrpcClient`）；可选 JSON-RPC（`SuiJsonRpcClient`）。

```typescript
import { SuiGrpcClient } from '@mysten/sui/grpc';

const devnetClient = new SuiGrpcClient({
  network: 'devnet',
  baseUrl: 'https://fullnode.devnet.sui.io:443',
});
const testnetClient = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});
const mainnetClient = new SuiGrpcClient({
  network: 'mainnet',
  baseUrl: 'https://fullnode.mainnet.sui.io:443',
});
const localClient = new SuiGrpcClient({
  network: 'local',
  baseUrl: 'http://127.0.0.1:9000',
});
```

### 密钥管理

```typescript
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromBase64 } from '@mysten/bcs';

// 从私钥创建
const keypair = Ed25519Keypair.fromSecretKey(
  fromBase64(process.env.PRIVATE_KEY!)
);

// 获取地址
const address = keypair.toSuiAddress();
console.log('Address:', address);
```

## 交易构造

### Transaction 基础

```typescript
import { Transaction } from '@mysten/sui/transactions';

const tx = new Transaction();

// 设置 gas 预算
tx.setGasBudget(10_000_000);
```

### 调用 Move 函数

```typescript
const PACKAGE_ID = '0x...';
const REGISTRY_ID = '0x...';

function mintHero(tx: Transaction, name: string, stamina: number) {
  tx.moveCall({
    target: `${PACKAGE_ID}::hero::new_hero`,
    arguments: [
      tx.pure.string(name),
      tx.pure.u64(stamina),
      tx.object(REGISTRY_ID),
    ],
  });
}

function mintWeapon(tx: Transaction, name: string, attack: number) {
  tx.moveCall({
    target: `${PACKAGE_ID}::hero::new_weapon`,
    arguments: [
      tx.pure.string(name),
      tx.pure.u64(attack),
    ],
  });
}
```

### 组合 PTB：一笔交易完成多个操作

```typescript
function mintHeroWithWeapon(
  tx: Transaction,
  heroName: string,
  stamina: number,
  weaponName: string,
  attack: number,
) {
  // 铸造英雄（返回 Hero 对象）
  const [hero] = tx.moveCall({
    target: `${PACKAGE_ID}::hero::new_hero`,
    arguments: [
      tx.pure.string(heroName),
      tx.pure.u64(stamina),
      tx.object(REGISTRY_ID),
    ],
  });

  // 铸造武器（返回 Weapon 对象）
  const [weapon] = tx.moveCall({
    target: `${PACKAGE_ID}::hero::new_weapon`,
    arguments: [
      tx.pure.string(weaponName),
      tx.pure.u64(attack),
    ],
  });

  // 装备武器
  tx.moveCall({
    target: `${PACKAGE_ID}::hero::equip_weapon`,
    arguments: [hero, weapon],
  });
}
```

## 签名与执行

### 签名并执行交易

执行后根据 `result.$kind` 判断成功（`Transaction`）或失败（`FailedTransaction`），失败时抛出错误；成功后建议再调用 `waitForTransaction` 等待确认。

```typescript
async function executeTransaction(tx: Transaction) {
  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  if (result.$kind === 'FailedTransaction') {
    throw new Error(
      result.FailedTransaction.status.error?.message ?? 'Transaction failed'
    );
  }

  console.log('Digest:', result.Transaction.digest);
  await client.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

## 数据查询

### 查询对象

```typescript
// 查询单个对象
async function getHeroRegistry() {
  const obj = await client.core.getObject({
    objectId: REGISTRY_ID,
    include: { content: true },
  });

  if (obj.data?.content?.dataType === 'moveObject') {
    const fields = obj.data.content.fields as any;
    console.log('Counter:', fields.counter);
    console.log('Hero IDs:', fields.ids);
  }
}

// 批量查询对象
async function getHeroes(heroIds: string[]) {
  const objects = await client.core.getObjects({
    objectIds: heroIds,
    include: { content: true },
  });

  return objects.map(obj => {
    if (obj.data?.content?.dataType === 'moveObject') {
      return obj.data.content.fields;
    }
    return null;
  });
}
```

### 查询用户拥有的对象

```typescript
async function getOwnedHeroes(owner: string) {
  const objects = await client.core.listOwnedObjects({
    owner,
    filter: {
      StructType: `${PACKAGE_ID}::hero::Hero`,
    },
    include: { content: true },
  });

  return objects.data;
}
```

### 查询事件

```typescript
async function getHeroEvents() {
  const events = await client.queryEvents({
    query: {
      MoveEventModule: {
        module: 'hero',
        package: PACKAGE_ID,
      },
    },
    order: 'descending',
    limit: 50,
  });

  return events.data;
}
```

## 端到端测试

### 测试框架配置

```typescript
// jest.config.ts
export default {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testTimeout: 30000,
};
```

### 编写 E2E 测试

```typescript
import { describe, it, expect, beforeAll } from '@jest/globals';
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';

describe('Hero E2E Tests', () => {
  let client: SuiGrpcClient;
  let keypair: Ed25519Keypair;

  beforeAll(() => {
    client = new SuiGrpcClient({
      network: 'testnet',
      baseUrl: 'https://fullnode.testnet.sui.io:443',
    });
    keypair = Ed25519Keypair.fromSecretKey(/* ... */);
  });

  it('should mint a hero successfully', async () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::hero::new_hero`,
      arguments: [
        tx.pure.string('Test Hero'),
        tx.pure.u64(100),
        tx.object(REGISTRY_ID),
      ],
    });

    const result = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: tx,
    });

    if (result.$kind === 'FailedTransaction') {
      throw new Error(result.FailedTransaction.status.error?.message);
    }
    await client.waitForTransaction({ digest: result.Transaction.digest });
  });

  it('should mint hero with weapon in single PTB', async () => {
    const tx = new Transaction();
    mintHeroWithWeapon(tx, 'Warrior', 100, 'Excalibur', 50);

    const result = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: tx,
    });

    if (result.$kind === 'FailedTransaction') {
      throw new Error(result.FailedTransaction.status.error?.message);
    }
    await client.waitForTransaction({ digest: result.Transaction.digest });
  });
});
```

### 运行测试

```bash
npm test
# 或
npx jest --verbose
```

## BCS 编码

与合约的高级交互可能需要 BCS 编码：

```typescript
import { bcs } from '@mysten/bcs';

// 定义事件结构对应 Move struct
const HeroCreatedEvent = bcs.struct('HeroCreated', {
  hero_id: bcs.Address,
  name: bcs.string(),
  stamina: bcs.u64(),
});

// 解码事件数据
function decodeHeroEvent(eventBcsData: Uint8Array) {
  return HeroCreatedEvent.parse(eventBcsData);
}
```

## 小结

TypeScript SDK 集成的核心要点：

- 推荐使用 `SuiGrpcClient`（`@mysten/sui/grpc`）连接 Sui 网络
- 通过 `Transaction` 类构造可编程交易块（PTB）
- `moveCall` 调用 Move 函数，参数通过 `tx.pure.*` 和 `tx.object()` 传递
- 执行后根据 `result.$kind` 判断成功/失败，成功后调用 `waitForTransaction` 等待确认
- 使用 `client.core.getObject`、`client.core.listOwnedObjects`、`client.core.getObjects` 等方法查询链上状态（v2 Core API，`include` 替代 `options`）
- BCS 编码/解码用于处理事件数据和复杂参数
