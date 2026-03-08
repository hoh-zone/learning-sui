# 读取链上对象

与 Sui 区块链交互的第一步通常是读取链上数据。TypeScript SDK 提供了丰富的查询方法，可以按 ID 获取单个对象、批量获取多个对象，以及按条件过滤。本节将介绍这些核心读取操作。

## getObject

获取单个对象的完整信息：

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

const object = await client.core.getObject({
  objectId: "0xOBJECT_ID",
  include: {
    content: true,   // 返回对象内容（字段值）
    type: true,      // 返回对象类型
    owner: true,     // 返回所有者信息
    display: true,   // 返回 Display 渲染结果
  },
});
```

### 返回结构

```typescript
{
  data: {
    objectId: "0x...",
    version: "123",
    digest: "...",
    type: "0xPKG::hero::Hero",
    owner: {
      AddressOwner: "0xOWNER_ADDRESS"
    },
    content: {
      dataType: "moveObject",
      type: "0xPKG::hero::Hero",
      fields: {
        id: { id: "0x..." },
        health: "100",
        stamina: "10"
      }
    },
    display: {
      data: {
        name: "Hero #1",
        image_url: "https://...",
        description: "..."
      }
    }
  }
}
```

### 解析对象字段

```typescript
interface Hero {
  health: number;
  stamina: number;
}

function parseHero(data: any): Hero {
  const fields = data.data?.content?.fields;
  if (!fields) throw new Error("Invalid hero data");

  return {
    health: Number(fields.health),
    stamina: Number(fields.stamina),
  };
}

const object = await client.core.getObject({
  objectId: heroId,
  include: { content: true },
});

const hero = parseHero(object);
console.log(`Health: ${hero.health}, Stamina: ${hero.stamina}`);
```

## multiGetObjects

批量获取多个对象，比循环调用 `getObject` 更高效：

```typescript
const { data: objects } = await client.core.getObjects({
  objectIds: ["0xOBJ1", "0xOBJ2", "0xOBJ3"],
  include: { content: true, type: true },
});

objects.forEach((obj) => {
  if (obj.data) {
    console.log(`Object ${obj.data.objectId}: ${obj.data.type}`);
  } else {
    console.log("Object not found or error:", obj.error);
  }
});
```

## getOwnedObjects

获取某地址拥有的所有对象：

```typescript
const { data: ownedObjects } = await client.core.listOwnedObjects({
  owner: "0xOWNER_ADDRESS",
  include: { content: true, type: true },
});

console.log(`Total objects: ${ownedObjects.length}`);
ownedObjects.forEach((item) => {
  console.log(`  ${item.data?.objectId}: ${item.data?.type}`);
});
```

### 按类型过滤

```typescript
const { data: heroes } = await client.core.listOwnedObjects({
  owner: userAddress,
  filter: {
    StructType: `${PACKAGE_ID}::hero::Hero`,
  },
  include: { content: true, display: true },
});
```

### 过滤器类型

| 过滤器 | 说明 | 示例 |
| --- | --- | --- |
| `StructType` | 按对象类型过滤 | `"0xPKG::module::Type"` |
| `Package` | 按包 ID 过滤 | `"0xPKG_ID"` |
| `MatchAll` | 组合多个过滤条件（AND） | `[filter1, filter2]` |
| `MatchAny` | 满足任一条件（OR） | `[filter1, filter2]` |
| `MatchNone` | 排除条件 | `[filter1]` |

## 处理对象版本

Sui 对象有版本概念。默认获取最新版本，也可指定特定版本：

```typescript
// 获取特定版本（v2：使用 getObject 的 version 或等价 API）
const historicalObject = await client.core.getObject({
  objectId,
  version: 42,
  include: { content: true },
});
```

## 错误处理

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

async function safeGetObject(client: SuiGrpcClient, id: string) {
  try {
    const result = await client.core.getObject({
      objectId: id,
      include: { content: true },
    });

    if (result.error) {
      if (result.error.code === "notExists") {
        console.log("Object does not exist");
        return null;
      }
      if (result.error.code === "deleted") {
        console.log("Object has been deleted");
        return null;
      }
      throw new Error(`Unknown error: ${result.error.code}`);
    }

    return result.data;
  } catch (e) {
    console.error("Failed to fetch object:", e);
    return null;
  }
}
```

## 完整示例：读取 Hero NFT

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

const PACKAGE_ID = "0x...";

interface HeroData {
  objectId: string;
  health: number;
  stamina: number;
  swordIds: string[];
}

async function getHeroData(
  client: SuiGrpcClient,
  heroId: string,
): Promise<HeroData> {
  // 获取 Hero 对象
  const hero = await client.core.getObject({
    objectId: heroId,
    include: { content: true, type: true },
  });

  if (!hero.data?.content || hero.data.content.dataType !== "moveObject") {
    throw new Error("Invalid hero object");
  }

  const fields = hero.data.content.fields as any;

  // 获取动态对象字段（装备的武器）
  const { data: dynamicFields } = await client.core.listDynamicFields({
    parentId: heroId,
  });

  const swordIds = dynamicFields
    .filter((df) => df.objectType?.includes("Sword"))
    .map((df) => df.objectId);

  return {
    objectId: hero.data.objectId,
    health: Number(fields.health),
    stamina: Number(fields.stamina),
    swordIds,
  };
}

// 使用
const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});
const hero = await getHeroData(client, "0xHERO_ID");
console.log(hero);
```

## 小结

- `client.core.getObject` 获取单个对象，通过 `include` 控制返回的信息粒度
- `client.core.getObjects` 批量获取对象，适合需要同时读取多个对象的场景
- `client.core.listOwnedObjects` 获取地址拥有的对象，支持按类型过滤
- 对象字段在 `content.fields` 中，需要手动解析类型
- 始终做好错误处理，对象可能不存在或已被删除
