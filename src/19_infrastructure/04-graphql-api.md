# GraphQL API

本节介绍 Sui 的 GraphQL API。GraphQL 提供了比 JSON-RPC 更灵活的查询能力，支持精确的字段选择、嵌套查询和强类型系统，适合构建复杂的数据查询场景。

## 端点

| 网络 | GraphQL 端点 |
|------|-------------|
| Mainnet | `https://sui-mainnet.mystenlabs.com/graphql` |
| Testnet | `https://sui-testnet.mystenlabs.com/graphql` |

GraphQL IDE（交互式查询工具）可通过浏览器直接访问上述 URL。

## 基础查询

### 查询链信息

```graphql
query {
  chainIdentifier
  epoch {
    epochId
    startTimestamp
    endTimestamp
    referenceGasPrice
  }
}
```

### 查询对象

```graphql
query GetObject {
  object(address: "0x...") {
    objectId
    version
    digest
    owner {
      ... on AddressOwner {
        owner {
          address
        }
      }
      ... on Shared {
        initialSharedVersion
      }
    }
    asMoveObject {
      contents {
        type { repr }
        json
      }
    }
  }
}
```

### 查询地址拥有的对象

```graphql
query OwnedObjects {
  address(address: "0x...") {
    objects(
      filter: { type: "0xPACKAGE::hero::Hero" }
      first: 10
    ) {
      nodes {
        objectId
        asMoveObject {
          contents {
            json
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
```

## 交易查询

### 查询交易详情

```graphql
query GetTransaction {
  transactionBlock(digest: "...") {
    digest
    sender {
      address
    }
    effects {
      status
      gasEffects {
        gasSummary {
          computationCost
          storageCost
          storageRebate
        }
      }
      objectChanges {
        nodes {
          outputState {
            objectId
            asMoveObject {
              contents { json }
            }
          }
        }
      }
    }
  }
}
```

### 查询地址的交易历史

```graphql
query TransactionHistory {
  address(address: "0x...") {
    transactionBlocks(
      first: 20
      scanLimit: 100
      filter: {}
    ) {
      nodes {
        digest
        effects {
          status
          timestamp
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
```

## 事件查询

```graphql
query Events {
  events(
    filter: {
      eventType: "0xPACKAGE::hero::HeroCreated"
    }
    first: 20
  ) {
    nodes {
      sendingModule {
        name
        package { address }
      }
      type { repr }
      json
      timestamp
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## 分页

GraphQL API 使用基于游标的分页：

```graphql
# 第一页
query FirstPage {
  objects(
    filter: { type: "0xPACKAGE::hero::Hero" }
    first: 10
  ) {
    nodes {
      objectId
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}

# 下一页：使用上一页的 endCursor
query NextPage {
  objects(
    filter: { type: "0xPACKAGE::hero::Hero" }
    first: 10
    after: "eyJj..."  # endCursor from previous page
  ) {
    nodes {
      objectId
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## TypeScript 客户端

### 使用 fetch 调用

```typescript
const GRAPHQL_URL = 'https://sui-testnet.mystenlabs.com/graphql';

async function queryGraphQL(query: string, variables?: Record<string, any>) {
  const response = await fetch(GRAPHQL_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  });

  const result = await response.json();
  if (result.errors) {
    throw new Error(result.errors[0].message);
  }
  return result.data;
}

// 使用示例
const data = await queryGraphQL(`
  query GetHeroes($owner: SuiAddress!) {
    address(address: $owner) {
      objects(filter: { type: "0xPACKAGE::hero::Hero" }, first: 10) {
        nodes {
          objectId
          asMoveObject {
            contents { json }
          }
        }
      }
    }
  }
`, { owner: '0x...' });
```

### 使用 graphql-request 库

```typescript
import { GraphQLClient, gql } from 'graphql-request';

const client = new GraphQLClient(GRAPHQL_URL);

const query = gql`
  query GetObject($id: SuiAddress!) {
    object(address: $id) {
      objectId
      version
      asMoveObject {
        contents {
          type { repr }
          json
        }
      }
    }
  }
`;

const data = await client.request(query, { id: '0x...' });
```

## 动态字段查询

```graphql
query DynamicFields {
  object(address: "0x...") {
    dynamicFields(first: 10) {
      nodes {
        name {
          json
        }
        value {
          ... on MoveValue {
            json
          }
          ... on MoveObject {
            contents {
              json
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
```

## GraphQL vs JSON-RPC

| 方面 | GraphQL | JSON-RPC |
|------|---------|----------|
| 字段选择 | 精确请求需要的字段 | 返回预定义的字段集 |
| 嵌套查询 | 一次请求获取关联数据 | 可能需要多次请求 |
| 类型系统 | 强类型 schema | 文档型 |
| 分页 | 游标分页 | limit/offset |
| 过滤 | 丰富的过滤参数 | 有限的过滤选项 |
| 工具支持 | GraphQL IDE、代码生成 | Postman 等通用工具 |

## 小结

- Sui GraphQL API 提供比 JSON-RPC 更灵活的查询能力
- 使用精确的字段选择减少网络传输和解析开销
- 游标分页适合处理大量数据
- 嵌套查询可以在单次请求中获取关联数据
- GraphQL IDE 是探索和调试查询的好工具
- 适合构建需要复杂查询的应用前端和后端服务
