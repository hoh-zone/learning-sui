# 分页读取

当查询结果可能包含大量数据时（如某地址拥有数百个 NFT），Sui API 使用基于游标（cursor）的分页机制。本节将介绍如何正确处理分页，获取完整的数据集。

## 分页机制

Sui 的分页 API 返回三个关键字段：

```typescript
{
  data: [...],           // 当前页的数据
  nextCursor: "...",     // 下一页的游标（null 表示无更多数据）
  hasNextPage: true      // 是否有下一页
}
```

## 基本分页查询

### getOwnedObjects 分页

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

// 获取第一页
const firstPage = await client.core.listOwnedObjects({
  owner: userAddress,
  include: { type: true },
  limit: 50, // 每页最多 50 条
});

console.log(`Page 1: ${firstPage.data.length} objects`);
console.log(`Has next page: ${firstPage.hasNextPage}`);

// 获取第二页
if (firstPage.hasNextPage && firstPage.nextCursor) {
  const secondPage = await client.core.listOwnedObjects({
    owner: userAddress,
    include: { type: true },
    limit: 50,
    cursor: firstPage.nextCursor,
  });

  console.log(`Page 2: ${secondPage.data.length} objects`);
}
```

## 获取所有数据

### 循环分页

最常见的模式——循环获取所有页面：

```typescript
async function getAllOwnedObjects(
  client: SuiGrpcClient,
  owner: string,
): Promise<any[]> {
  const allObjects: any[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage) {
    const page = await client.core.listOwnedObjects({
      owner,
      include: { content: true, type: true },
      limit: 50,
      cursor,
    });

    allObjects.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;
  }

  return allObjects;
}

// 使用
const objects = await getAllOwnedObjects(client, userAddress);
console.log(`Total objects: ${objects.length}`);
```

### 带类型过滤的分页

```typescript
async function getAllHeroes(
  client: SuiGrpcClient,
  owner: string,
  packageId: string,
): Promise<any[]> {
  const allHeroes: any[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage) {
    const page = await client.core.listOwnedObjects({
      owner,
      filter: {
        StructType: `${packageId}::hero::Hero`,
      },
      include: { content: true, display: true },
      limit: 50,
      cursor,
    });

    allHeroes.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;
  }

  return allHeroes;
}
```

## getDynamicFields 分页

动态字段查询同样支持分页：

```typescript
async function getAllDynamicFields(
  client: SuiGrpcClient,
  parentId: string,
): Promise<any[]> {
  const allFields: any[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage) {
    const page = await client.core.listDynamicFields({
      parentId,
      limit: 50,
      cursor,
    });

    allFields.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;
  }

  return allFields;
}
```

## 查询交易记录分页

```typescript
async function getTransactionHistory(
  client: SuiGrpcClient,
  address: string,
  maxResults: number = 100,
): Promise<any[]> {
  const transactions: any[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage && transactions.length < maxResults) {
    const page = await client.core.queryTransactions({
      filter: {
        FromAddress: address,
      },
      include: { effects: true, events: true },
      limit: Math.min(50, maxResults - transactions.length),
      cursor,
      order: "descending",
    });

    transactions.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;
  }

  return transactions;
}
```

## 通用分页工具函数

创建一个可复用的分页工具：

```typescript
interface PaginatedResult<T> {
  data: T[];
  nextCursor: string | null | undefined;
  hasNextPage: boolean;
}

async function fetchAllPages<T>(
  fetcher: (cursor?: string | null) => Promise<PaginatedResult<T>>,
  maxItems?: number,
): Promise<T[]> {
  const allItems: T[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage) {
    if (maxItems && allItems.length >= maxItems) break;

    const page = await fetcher(cursor);
    allItems.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;
  }

  return maxItems ? allItems.slice(0, maxItems) : allItems;
}

// 使用
const allObjects = await fetchAllPages((cursor) =>
  client.core.listOwnedObjects({
    owner: userAddress,
    include: { type: true },
    limit: 50,
    cursor: cursor ?? undefined,
  })
);
```

## 性能优化

### 并行获取详情

列表查询后需要获取详情时，使用 `multiGetObjects` 替代循环：

```typescript
async function getOwnedHeroesWithDetails(
  client: SuiGrpcClient,
  owner: string,
  packageId: string,
): Promise<any[]> {
  // 步骤 1: 获取所有 Hero ID
  const ownedObjects = await fetchAllPages((cursor) =>
    client.core.listOwnedObjects({
      owner,
      filter: { StructType: `${packageId}::hero::Hero` },
      limit: 50,
      cursor: cursor ?? undefined,
    })
  );

  const heroIds = ownedObjects
    .map((obj) => obj.data?.objectId)
    .filter(Boolean) as string[];

  if (heroIds.length === 0) return [];

  // 步骤 2: 批量获取详情（每批 50 个）
  const batchSize = 50;
  const allDetails: any[] = [];

  for (let i = 0; i < heroIds.length; i += batchSize) {
    const batch = heroIds.slice(i, i + batchSize);
    const { data: details } = await client.core.getObjects({
      objectIds: batch,
      include: { content: true, display: true },
    });
    allDetails.push(...details);
  }

  return allDetails;
}
```

### 控制请求频率

避免过于频繁的 API 请求：

```typescript
function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithRateLimit<T>(
  fetcher: (cursor?: string | null) => Promise<PaginatedResult<T>>,
  delayMs: number = 100,
): Promise<T[]> {
  const allItems: T[] = [];
  let cursor: string | null | undefined = undefined;
  let hasNextPage = true;

  while (hasNextPage) {
    const page = await fetcher(cursor);
    allItems.push(...page.data);
    hasNextPage = page.hasNextPage;
    cursor = page.nextCursor;

    if (hasNextPage) await delay(delayMs);
  }

  return allItems;
}
```

## 小结

- Sui API 使用基于 cursor 的分页机制，通过 `nextCursor` 和 `hasNextPage` 控制
- 使用 while 循环遍历所有页面获取完整数据集
- 可以创建通用的 `fetchAllPages` 工具函数简化分页代码
- 获取详情时优先使用 `client.core.getObjects` 批量查询
- 注意控制请求频率和设置最大结果数，避免过载
