# 动态对象字段

## 导读

本节对应 [§11.1](01-sui-framework.md) 中的 **`sui::dynamic_object_field`**：键值中的**值必须是 Sui 对象**（`key`），便于全节点**按对象索引**。与普通 [§11.7 · 动态字段](07-dynamic-fields.md) 的取舍是：是否要**把子对象当作一等资源**索引与转移。

- **前置**：[§11.7](07-dynamic-fields.md)（普通动态字段 API 与能力约束）  
- **后续**：[§11.10](10-dynamic-collections.md)（`ObjectTable` / `ObjectBag` 再封装一层）  

---

动态对象字段（Dynamic Object Fields）是 Sui 提供的一种高级存储机制，允许将 **独立对象** 以键值对的形式附加到父对象上。与普通动态字段不同，动态对象字段中存储的值仍然保持其独立对象身份——可以通过对象 ID 在链下被发现和直接访问。这使得动态对象字段成为构建需要保留对象可发现性的复杂数据结构的理想选择。

## 动态对象字段与普通动态字段的区别

在深入学习动态对象字段之前，我们需要理解它与普通动态字段（`dynamic_field`）的核心差异：

### 值约束不同

| 特性 | 动态字段 (`dynamic_field`) | 动态对象字段 (`dynamic_object_field`) |
|------|--------------------------|--------------------------------------|
| 值的能力约束 | `store` | `key + store`（必须是对象） |
| 值是否被包装 | 是（被包装进 `Field` 结构体） | 否（值保持独立存在） |
| 链下可发现性 | 丢失（无法通过 ID 查找） | 保留（可通过对象 ID 查找） |
| 成本 | 较低（加载 1 个对象） | 较高（加载 2 个对象） |

### 内部存储机制

普通动态字段将值直接包装在一个 `Field<Name, Value>` 对象中，值成为该对象的一部分，失去了独立身份。

动态对象字段则使用了一种巧妙的设计：内部创建一个 `Field<Name, ID>` 对象，仅存储子对象的 **ID 引用**，而子对象本身仍然作为顶层对象存在于全局存储中。这意味着：

- 子对象的 ID 保持不变，可以被外部直接引用
- 链下索引器可以通过 ID 查询到该对象
- 对象浏览器中可以直接看到该对象

## 模块定义与导入

动态对象字段定义在 `sui::dynamic_object_field` 模块中，通常使用缩写导入：

```move
use sui::dynamic_object_field as dof;
```

## 核心操作

### add — 添加动态对象字段

`add` 函数将一个对象作为动态对象字段附加到父对象上：

```move
public fun add<Name: copy + drop + store, Value: key + store>(
    object: &mut UID,
    name: Name,
    value: Value,
);
```

注意 `Value` 的约束是 `key + store`，意味着只有拥有 `key` 和 `store` 能力的结构体（即对象）才能作为值存储。

### borrow 和 borrow_mut — 借用字段

```move
public fun borrow<Name: copy + drop + store, Value: key + store>(
    object: &UID,
    name: Name,
): &Value;

public fun borrow_mut<Name: copy + drop + store, Value: key + store>(
    object: &mut UID,
    name: Name,
): &mut Value;
```

分别以不可变引用和可变引用的方式访问动态对象字段中存储的对象。

### remove — 移除字段

```move
public fun remove<Name: copy + drop + store, Value: key + store>(
    object: &mut UID,
    name: Name,
): Value;
```

移除动态对象字段并返回其中存储的对象，调用者可以决定如何处理该对象（转移、销毁等）。

### exists_ 和 id — 查询函数

```move
public fun exists_<Name: copy + drop + store>(object: &UID, name: Name): bool;

public fun id<Name: copy + drop + store>(object: &UID, name: Name): Option<ID>;
```

- `exists_` 检查指定名称的动态对象字段是否存在
- `id` 返回存储在动态对象字段中的对象 ID（如果存在）

`id` 函数是动态对象字段独有的，普通动态字段没有这个函数。它允许你在不借用值的情况下获取子对象的 ID。

## 完整代码示例

以下示例展示了一个仓库系统，使用动态对象字段来管理存储的物品：

```move
module examples::dynamic_object_fields_demo;

use sui::dynamic_object_field as dof;
use std::string::String;

public struct Warehouse has key {
    id: UID,
}

public struct StoredItem has key, store {
    id: UID,
    name: String,
    value: u64,
}

public fun create_warehouse(ctx: &mut TxContext): Warehouse {
    Warehouse { id: object::new(ctx) }
}

public fun store_item(
    warehouse: &mut Warehouse,
    name: String,
    item: StoredItem,
) {
    dof::add(&mut warehouse.id, name, item);
}

public fun borrow_item(warehouse: &Warehouse, name: String): &StoredItem {
    dof::borrow(&warehouse.id, name)
}

public fun take_item(warehouse: &mut Warehouse, name: String): StoredItem {
    dof::remove(&mut warehouse.id, name)
}

public fun has_item(warehouse: &Warehouse, name: String): bool {
    dof::exists_(&warehouse.id, name)
}
```

### 扩展：获取子对象 ID

利用 `id` 函数，我们可以在不借用子对象的情况下获取其 ID，这在某些场景下非常有用：

```move
public fun item_id(warehouse: &Warehouse, name: String): Option<ID> {
    dof::id(&warehouse.id, name)
}
```

### 扩展：更新子对象属性

通过 `borrow_mut` 获取可变引用，可以直接修改子对象的内部状态：

```move
public fun update_item_value(
    warehouse: &mut Warehouse,
    name: String,
    new_value: u64,
) {
    let item = dof::borrow_mut<String, StoredItem>(&mut warehouse.id, name);
    item.value = new_value;
}
```

## 链下可发现性

动态对象字段最重要的特性之一是保留了子对象的链下可发现性。这意味着：

1. **索引器支持**：全节点索引器可以通过子对象的 ID 直接查询到它
2. **对象浏览器**：用户可以在 Sui Explorer 中通过 ID 找到并查看子对象
3. **GraphQL 查询**：可以通过 `sui_getObject` API 使用子对象 ID 直接获取信息

这与普通动态字段形成鲜明对比——普通动态字段中的值被包装后，只能通过父对象来发现和访问。

## 性能与成本考量

使用动态对象字段时需要注意以下成本：

- **读取成本**：每次访问动态对象字段需要加载 **两个对象**（`Field` 包装器和子对象本身），而普通动态字段只需加载一个
- **Gas 消耗**：由于需要加载更多对象，Gas 消耗相应增加
- **存储成本**：子对象作为独立顶层对象存在，需要额外的存储开销

因此在性能敏感的场景中，如果不需要链下可发现性，优先考虑使用普通动态字段。

## 何时选择动态对象字段

### 适合使用动态对象字段的场景

- 子对象需要在链下被独立发现和查询（如 NFT 市场中的上架 NFT）
- 子对象可能需要被其他交易直接引用
- 需要通过 `id` 函数获取子对象 ID 而不加载完整对象
- 构建开放式协议，第三方需要查询和交互子对象

### 适合使用普通动态字段的场景

- 值不需要独立的对象身份（如简单数据类型 `u64`、`String` 等）
- 不需要链下可发现性
- 追求更低的 Gas 成本
- 值的类型不满足 `key + store` 约束

## 小结

动态对象字段是 Sui 中处理对象间动态组合关系的重要工具。它在保持子对象独立身份和可发现性的同时，实现了灵活的键值存储。核心要点包括：

- 值必须具有 `key + store` 能力，即必须是对象
- 子对象不会被包装，保留独立的对象 ID 和链下可发现性
- 提供 `add`、`remove`、`borrow`、`borrow_mut`、`exists_`、`id` 六个核心操作
- 相比普通动态字段，每次访问需要加载两个对象，成本更高
- 在需要链下可发现性的场景中（如 NFT、市场等）优先选择动态对象字段，否则使用普通动态字段以节省成本
