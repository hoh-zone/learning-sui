# 自定义索引器

本节讲解为什么需要自定义索引器以及如何实现。索引器是连接链上数据和应用业务逻辑的桥梁，支持复杂查询、历史数据分析和实时数据处理。

## 为什么需要索引器

RPC 节点的查询能力有限：

| 需求 | RPC 能力 | 索引器能力 |
|------|---------|-----------|
| 查询某用户的所有交易 | 仅最近部分 | 完整历史 |
| 按属性过滤 NFT | 不支持 | 自定义索引 |
| 聚合统计 | 不支持 | SQL 查询 |
| 复杂关联查询 | 不支持 | JOIN 操作 |
| 实时通知 | WebSocket（有限） | 自定义推送 |

## 索引器架构

```
┌──────────────────────────────────────────────────┐
│                 索引器架构                          │
├──────────────────────────────────────────────────┤
│                                                    │
│  Sui 全节点                                        │
│       │                                            │
│       ├── RPC 轮询（queryEvents）                   │
│       └── gRPC 流（subscribeCheckpoints）           │
│            │                                       │
│       ┌────▼────┐                                  │
│       │ 索引器   │                                  │
│       │         │                                  │
│       │ ├ 事件过滤                                  │
│       │ ├ BCS 解码                                  │
│       │ ├ 数据转换                                  │
│       │ └ 写入数据库                                │
│       └────┬────┘                                  │
│            │                                       │
│       ┌────▼────┐                                  │
│       │ 数据库   │ (PostgreSQL / SQLite)            │
│       └────┬────┘                                  │
│            │                                       │
│       ┌────▼────┐                                  │
│       │ API 层   │ (REST / GraphQL)                │
│       └─────────┘                                  │
│                                                    │
└──────────────────────────────────────────────────┘
```

## JavaScript/TypeScript 索引器

### 项目结构

```
indexer-js/
├── prisma/
│   └── schema.prisma          # 数据库 schema
├── indexer/
│   └── event-indexer.ts       # 事件索引核心逻辑
├── handlers/
│   └── hero.ts                # 事件处理器
├── types/
│   └── HeroEvent.ts           # 事件类型定义
├── config.ts                  # 配置
├── db.ts                      # 数据库连接
├── sui-utils.ts               # Sui 工具函数
├── server.ts                  # API 服务器
├── docker-compose.yml         # PostgreSQL
└── package.json
```

### 配置文件

```typescript
// config.ts
export const CONFIG = {
  NETWORK: 'testnet' as const,
  CONTRACT: {
    packageId: process.env.PACKAGE_ID!,
    module: 'hero',
  },
  POLLING_INTERVAL_MS: 2000,
};
```

### 事件索引核心

```typescript
// indexer/event-indexer.ts
import { EventId, SuiEvent, SuiEventFilter } from '@mysten/sui/client';
import { SuiGrpcClient } from '@mysten/sui/grpc';

type SuiEventsCursor = EventId | null | undefined;

type EventTracker = {
  type: string;
  filter: SuiEventFilter;
  callback: (events: SuiEvent[], type: string) => Promise<void>;
};

const EVENTS_TO_TRACK: EventTracker[] = [
  {
    type: `${CONFIG.CONTRACT.packageId}::hero`,
    filter: {
      MoveEventModule: {
        module: 'hero',
        package: CONFIG.CONTRACT.packageId,
      },
    },
    callback: handleHeroEvents,
  },
];

async function executeEventJob(
  client: SuiGrpcClient,
  tracker: EventTracker,
  cursor: SuiEventsCursor,
) {
  const { data, hasNextPage, nextCursor } = await client.queryEvents({
    query: tracker.filter,
    cursor,
    order: 'ascending',
  });

  await tracker.callback(data, tracker.type);

  if (nextCursor && data.length > 0) {
    await saveLatestCursor(tracker, nextCursor);
    return { cursor: nextCursor, hasNextPage };
  }

  return { cursor, hasNextPage: false };
}

async function runEventJob(
  client: SuiGrpcClient,
  tracker: EventTracker,
  cursor: SuiEventsCursor,
) {
  const result = await executeEventJob(client, tracker, cursor);

  setTimeout(
    () => runEventJob(client, tracker, result.cursor),
    result.hasNextPage ? 0 : CONFIG.POLLING_INTERVAL_MS,
  );
}

export async function setupListeners() {
  const client = new SuiGrpcClient({
    network: CONFIG.NETWORK,
    baseUrl: CONFIG.NETWORK === 'mainnet'
      ? 'https://fullnode.mainnet.sui.io:443'
      : 'https://fullnode.testnet.sui.io:443',
  });
  for (const event of EVENTS_TO_TRACK) {
    const cursor = await getLatestCursor(event);
    runEventJob(client, event, cursor);
  }
}
```

### 事件处理器

```typescript
// handlers/hero.ts
import { SuiEvent } from '@mysten/sui/client';
import { prisma } from '../db';

export async function handleHeroEvents(events: SuiEvent[]) {
  for (const event of events) {
    const fields = event.parsedJson as {
      hero_id: string;
      name: string;
      stamina: string;
      creator: string;
    };

    await prisma.hero.upsert({
      where: { heroId: fields.hero_id },
      update: {
        name: fields.name,
        stamina: parseInt(fields.stamina),
      },
      create: {
        heroId: fields.hero_id,
        name: fields.name,
        stamina: parseInt(fields.stamina),
        creator: fields.creator,
        createdAt: new Date(parseInt(event.timestampMs!)),
      },
    });
  }
}
```

### 游标持久化

```typescript
// 保存游标到数据库，确保重启后能从上次位置继续
async function saveLatestCursor(
  tracker: EventTracker,
  cursor: EventId,
) {
  await prisma.cursor.upsert({
    where: { id: tracker.type },
    update: {
      eventSeq: cursor.eventSeq,
      txDigest: cursor.txDigest,
    },
    create: {
      id: tracker.type,
      eventSeq: cursor.eventSeq,
      txDigest: cursor.txDigest,
    },
  });
}

async function getLatestCursor(tracker: EventTracker) {
  return prisma.cursor.findUnique({
    where: { id: tracker.type },
  });
}
```

### 数据库 Schema（Prisma）

```prisma
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model Hero {
  id        Int      @id @default(autoincrement())
  heroId    String   @unique
  name      String
  stamina   Int
  creator   String
  createdAt DateTime
}

model Cursor {
  id       String @id
  eventSeq String
  txDigest String
}
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: hero_indexer
      POSTGRES_USER: indexer
      POSTGRES_PASSWORD: password
    ports:
      - '5432:5432'
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## API 服务

```typescript
// server.ts
import express from 'express';
import { prisma } from './db';

const app = express();

app.get('/heroes', async (req, res) => {
  const heroes = await prisma.hero.findMany({
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  res.json(heroes);
});

app.get('/heroes/:id', async (req, res) => {
  const hero = await prisma.hero.findUnique({
    where: { heroId: req.params.id },
  });
  res.json(hero);
});

app.get('/stats', async (req, res) => {
  const totalHeroes = await prisma.hero.count();
  const avgStamina = await prisma.hero.aggregate({
    _avg: { stamina: true },
  });
  res.json({ totalHeroes, avgStamina: avgStamina._avg.stamina });
});

app.listen(3000, () => console.log('API running on :3000'));
```

## 启动流程

```bash
# 1. 启动 PostgreSQL
docker-compose up -d

# 2. 初始化数据库
npx prisma migrate dev

# 3. 启动索引器
npm start

# 4. 启动 API（如果分开的话）
npm run serve
```

## 小结

- 自定义索引器弥补了 RPC 节点查询能力的不足
- 架构模式：事件捕获 → 数据处理 → 存储 → API 暴露
- 使用游标持久化确保索引器重启后能从上次位置继续
- 使用 Prisma + PostgreSQL 实现高效的数据存储和查询
- 轮询模式简单可靠，适合大部分场景
- 对实时性要求高的场景可以使用 gRPC 流（见下节）
