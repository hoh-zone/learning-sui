# gRPC 事件流

本节讲解如何使用 Sui 的 gRPC 服务实现实时事件订阅。相比 RPC 轮询，gRPC 提供更低延迟和更高效的数据推送能力。

## gRPC vs RPC 轮询

| 特性 | RPC 轮询 | gRPC 流 |
|------|---------|---------|
| 延迟 | 取决于轮询间隔 | 近实时 |
| 效率 | 大量空查询 | 只推送有数据的内容 |
| 连接方式 | HTTP 短连接 | 长连接流 |
| 数据格式 | JSON | Protocol Buffers |
| 适用场景 | 简单索引 | 实时索引、监控 |

## 合约准备：事件发射

gRPC 索引器消费的是链上事件。确保合约正确发射事件：

```move
module indexer_sample::indexer_sample;

use std::string::String;
use sui::event;

public struct UsersCounter has key {
    id: UID,
    count: u64,
}

/// 用户注册事件
public struct UserRegistered has copy, drop {
    owner: address,
    name: String,
    users_id: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(UsersCounter {
        id: object::new(ctx),
        count: 0,
    });
}

public fun register_user(
    name: String,
    counter: &mut UsersCounter,
    ctx: &mut TxContext,
) {
    counter.count = counter.count + 1;

    event::emit(UserRegistered {
        owner: ctx.sender(),
        name,
        users_id: counter.count,
    });
}
```

## TypeScript gRPC 客户端

### 安装依赖

```bash
npm install @mysten/sui
```

### Checkpoint 订阅

```typescript
import { SuiGRPCClient } from '@mysten/sui/client';

const GRPC_URL = 'https://grpc.testnet.sui.io:443';
const PACKAGE_ID = process.env.PACKAGE_ID!;
const MODULE_NAME = 'indexer_sample';

async function startIndexer() {
  const grpcClient = new SuiGRPCClient(GRPC_URL);

  const stream = grpcClient.subscriptionService.subscribeCheckpoints({
    readMask: {
      paths: ['transactions.events'],
    },
  });

  console.log('Subscribed to checkpoint stream...');

  for await (const checkpoint of stream) {
    for (const tx of checkpoint.transactions ?? []) {
      for (const event of tx.events ?? []) {
        processEvent(event);
      }
    }
  }
}
```

### 事件过滤与处理

```typescript
const FULL_EVENT_NAME = `${PACKAGE_ID}::${MODULE_NAME}::UserRegistered`;

function processEvent(event: any) {
  if (event.eventType !== FULL_EVENT_NAME) return;

  const decoded = decodeEventData(event.bcs);
  console.log('Event Data:', decoded);

  // 写入数据库或触发业务逻辑
  saveToDatabase(decoded);
}
```

### BCS 解码

事件数据使用 BCS（Binary Canonical Serialization）编码。解码时结构必须精确匹配 Move 的 struct 定义：

```typescript
import { bcs } from '@mysten/bcs';
import { fromBase64 } from '@mysten/bcs';

const USER_REGISTERED_EVENT_BCS = bcs.struct('UserRegistered', {
  owner: bcs.Address,
  name: bcs.string(),
  users_id: bcs.u64(),
});

function decodeEventData(bcsData: string) {
  const bytes = fromBase64(bcsData);
  return USER_REGISTERED_EVENT_BCS.parse(bytes);
}

// 解码结果示例：
// {
//   owner: '0x1234...abcd',
//   name: 'Alice',
//   users_id: '1'
// }
```

## 完整索引器实现

```typescript
import { SuiGRPCClient } from '@mysten/sui/client';
import { bcs, fromBase64 } from '@mysten/bcs';

const GRPC_URL = process.env.GRPC_URL || 'https://grpc.testnet.sui.io:443';
const PACKAGE_ID = process.env.PACKAGE_ID!;
const MODULE_NAME = process.env.MODULE_NAME || 'indexer_sample';
const FULL_EVENT_NAME = `${PACKAGE_ID}::${MODULE_NAME}::UserRegistered`;

const UserRegisteredBCS = bcs.struct('UserRegistered', {
  owner: bcs.Address,
  name: bcs.string(),
  users_id: bcs.u64(),
});

async function main() {
  const grpcClient = new SuiGRPCClient(GRPC_URL);

  console.log(`Starting indexer for package: ${PACKAGE_ID}`);
  console.log(`Listening for event: ${FULL_EVENT_NAME}`);

  const stream = grpcClient.subscriptionService.subscribeCheckpoints({
    readMask: {
      paths: ['transactions.events'],
    },
  });

  console.log('Subscribed to checkpoint stream...');

  for await (const checkpoint of stream) {
    const checkpointSeq = checkpoint.sequenceNumber;

    for (const tx of checkpoint.transactions ?? []) {
      for (const event of tx.events ?? []) {
        if (event.eventType === FULL_EVENT_NAME) {
          try {
            const decoded = UserRegisteredBCS.parse(
              fromBase64(event.bcs)
            );

            console.log(`[Checkpoint ${checkpointSeq}] New user registered:`);
            console.log(`  Owner: ${decoded.owner}`);
            console.log(`  Name: ${decoded.name}`);
            console.log(`  User ID: ${decoded.users_id}`);

            // 在这里写入数据库
            await saveUser(decoded);
          } catch (err) {
            console.error('Failed to decode event:', err);
          }
        }
      }
    }
  }
}

async function saveUser(data: { owner: string; name: string; users_id: string }) {
  // 写入数据库的逻辑
  console.log('Saved user to database:', data.name);
}

main().catch(console.error);
```

## 错误处理与重连

```typescript
async function startWithRetry(maxRetries = 5) {
  let retries = 0;

  while (retries < maxRetries) {
    try {
      await main();
    } catch (error) {
      retries++;
      const delay = Math.min(1000 * Math.pow(2, retries), 30000);
      console.error(`Connection lost. Retry ${retries}/${maxRetries} in ${delay}ms`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  console.error('Max retries reached. Exiting.');
  process.exit(1);
}

startWithRetry();
```

## 事件重放

gRPC 支持从指定 checkpoint 开始重放事件，用于：

- 索引器重启后恢复
- 回填历史数据
- 调试和测试

```typescript
const stream = grpcClient.subscriptionService.subscribeCheckpoints({
  startCheckpoint: lastProcessedCheckpoint + 1n, // 从上次处理的下一个开始
  readMask: {
    paths: ['transactions.events'],
  },
});
```

## 测试集成

```typescript
// tests/registerUser.test.ts
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Transaction } from '@mysten/sui/transactions';

test('should successfully register a new user', async () => {
  const client = new SuiGrpcClient({
    network: 'testnet',
    baseUrl: 'https://fullnode.testnet.sui.io:443',
  });
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::${MODULE_NAME}::register_user`,
    arguments: [
      tx.pure.string('Alice'),
      tx.object(USERS_COUNTER_OBJECT_ID),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await client.waitForTransaction({ digest: result.Transaction.digest });

  expect(result.Transaction.digest).toBeDefined();
});
```

## 小结

- gRPC 提供低延迟的实时事件流，适合需要即时响应的索引器
- 使用 `subscribeCheckpoints` 订阅 checkpoint 流并过滤事件
- BCS 解码是处理事件数据的关键，结构必须与 Move struct 精确匹配
- 实现断线重连和指数退避，确保索引器的高可用性
- 支持从指定 checkpoint 重放，用于恢复和回填数据
- 持久化最后处理的 checkpoint 序号，确保重启不丢数据
