# 动态字段查询

动态字段（Dynamic Fields）和动态对象字段（Dynamic Object Fields）是 Sui 中实现灵活数据结构的关键特性。在客户端查询这些字段需要专门的 API。本节将介绍如何使用 TypeScript SDK 查询和读取动态字段。

## 动态字段 vs 动态对象字段

| 特性 | 动态字段 (DF) | 动态对象字段 (DOF) |
| --- | --- | --- |
| 值类型 | 任意类型 | 必须是对象（有 `key`） |
| 独立访问 | 不能独立访问 | 可通过 ID 独立访问 |
| Move API | `dynamic_field` | `dynamic_object_field` |
| 适用场景 | 简单键值存储 | 嵌套对象（如装备） |

## getDynamicFields

列出对象的所有动态字段：

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

const { data: dynamicFields } = await client.core.listDynamicFields({
  parentId: "0xPARENT_OBJECT_ID",
});

console.log("Dynamic fields:", dynamicFields);
```

### 返回结构

```typescript
{
  data: [
    {
      name: {
        type: "0x1::string::String",
        value: "sword"
      },
      bcsName: "...",
      type: "DynamicObject",   // 或 "DynamicField"
      objectType: "0xPKG::blacksmith::Sword",
      objectId: "0xSWORD_ID",
      version: 42,
      digest: "..."
    },
    // ... 更多字段
  ],
  nextCursor: null,   // 分页游标
  hasNextPage: false
}
```

### 按类型过滤

```typescript
const { data: allFields } = await client.core.listDynamicFields({
  parentId: heroId,
});

// 过滤出 Sword 类型的动态对象字段
const swords = allFields.filter(
  (field) => field.objectType?.includes("Sword")
);

console.log(`Hero has ${swords.length} swords`);
```

## getDynamicField

获取特定动态字段的完整对象数据（v2：`client.core.getDynamicField`）：

```typescript
const swordData = await client.core.getDynamicField({
  parentId: heroId,
  name: {
    type: "0x1::string::String",
    value: "sword",
  },
});

if (swordData.data?.content?.dataType === "moveObject") {
  const fields = swordData.data.content.fields as any;
  console.log(`Sword name: ${fields.name}`);
  console.log(`Sword damage: ${fields.damage}`);
}
```

### name 参数格式

`name` 参数需要指定类型和值：

```typescript
// 字符串键
{
  type: "0x1::string::String",
  value: "my_key"
}

// u64 键
{
  type: "u64",
  value: "42"
}

// 地址键
{
  type: "address",
  value: "0xABC..."
}

// 自定义结构体键
{
  type: "0xPKG::module::KeyType",
  value: { /* BCS 编码的值 */ }
}
```

## 完整示例：查询 Hero 的武器

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";

const PACKAGE_ID = "0x...";

interface Sword {
  objectId: string;
  name: string;
  damage: number;
  specialEffects: string[];
}

async function getHeroSwords(
  client: SuiGrpcClient,
  heroId: string,
): Promise<Sword[]> {
  // 步骤 1: 列出所有动态字段
  const { data: dynamicFields } = await client.core.listDynamicFields({
    parentId: heroId,
  });

  // 步骤 2: 过滤 Sword 类型的字段
  const swordFields = dynamicFields.filter(
    (field) => field.objectType === `${PACKAGE_ID}::blacksmith::Sword`
  );

  // 步骤 3: 获取每把 Sword 的详细数据
  const swords: Sword[] = [];

  for (const field of swordFields) {
    const swordObj = await client.core.getDynamicField({
      parentId: heroId,
      name: field.name,
    });

    if (swordObj.data?.content?.dataType === "moveObject") {
      const fields = swordObj.data.content.fields as any;
      swords.push({
        objectId: swordObj.data.objectId,
        name: fields.name,
        damage: Number(fields.damage),
        specialEffects: fields.special_effects || [],
      });
    }
  }

  return swords;
}

// 使用
const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});
const swords = await getHeroSwords(client, "0xHERO_ID");
swords.forEach((sword) => {
  console.log(`${sword.name}: ${sword.damage} damage`);
});
```

## 批量查询优化

当需要查询大量动态字段时，可以使用 `client.core.getObjects` 优化：

```typescript
async function getHeroSwordsOptimized(
  client: SuiGrpcClient,
  heroId: string,
): Promise<Sword[]> {
  // 列出所有动态字段
  const { data: dynamicFields } = await client.core.listDynamicFields({
    parentId: heroId,
  });

  const swordFields = dynamicFields.filter(
    (field) => field.objectType?.includes("Sword")
  );

  if (swordFields.length === 0) return [];

  // 批量获取所有 Sword 对象
  const swordIds = swordFields.map((f) => f.objectId);
  const { data: objects } = await client.core.getObjects({
    objectIds: swordIds,
    include: { content: true },
  });

  return objects
    .filter((obj) => obj.data?.content?.dataType === "moveObject")
    .map((obj) => {
      const fields = (obj.data!.content as any).fields;
      return {
        objectId: obj.data!.objectId,
        name: fields.name,
        damage: Number(fields.damage),
        specialEffects: fields.special_effects || [],
      };
    });
}
```

## Table 和 Bag 的动态字段查询

Move 中的 `Table`、`Bag`、`ObjectTable`、`ObjectBag` 底层都使用动态字段实现，查询方式相同：

```typescript
// 查询 Table 的内容
const { data: tableEntries } = await client.core.listDynamicFields({
  parentId: tableObjectId,
});

// 获取特定条目
const entry = await client.core.getDynamicField({
  parentId: tableObjectId,
  name: {
    type: "address",
    value: "0xUSER_ADDRESS",
  },
});
```

## 小结

- `client.core.listDynamicFields` 列出对象的所有动态字段，返回字段名、类型和对象 ID
- `client.core.getDynamicField` 获取特定动态字段的完整对象数据
- 动态字段的 `name` 参数需要同时指定类型和值
- 对大量字段可使用 `client.core.getObjects` 批量查询优化性能
- `Table`、`Bag` 等集合类型底层使用动态字段，查询方式相同
