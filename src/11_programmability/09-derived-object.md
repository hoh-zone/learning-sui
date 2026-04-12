# 派生对象（Derived Object）

## 导读

本节对应 [§11.1](01-sui-framework.md) 中的 **`sui::derived_object`**：在父对象与键上推导**确定性**子对象地址，适合注册表、命名空间与「可预测 ID」。与 [§11.7](07-dynamic-fields.md) / [§11.8](08-dynamic-object-fields.md) 的「运行时挂载」互补——这里强调**地址可事先算出**。

- **前置**：[§11.7](07-dynamic-fields.md)、[§11.8](08-dynamic-object-fields.md)、[§11.1](01-sui-framework.md)  
- **后续**：与 [§11.10](10-dynamic-collections.md) 中的表结构可组合使用（按业务选型）  

---

派生对象（Derived Object）是 Sui Framework 中用于**按父对象与键生成确定性地址**的机制。通过 `sui::derived_object`，你可以让某个对象的 ID 完全由「父对象 UID + 键」推导而出，从而实现可预测的地址、注册表去重以及按类型或键命名空间管理子对象。本节将详细介绍其 API、典型场景与注意事项。

## 为什么需要确定性地址

在默认情况下，`object::new(ctx)` 会为每个新对象分配一个**随机的**新 ID。但在以下场景中，我们更需要**确定性**的地址：

- **注册表（Registry）**：例如「每种代币类型 T 在 CoinRegistry 下对应唯一一个 Currency\<T\>」，希望同一类型 T 永远映射到同一个地址，便于链下按地址查询。
- **命名空间**：父对象作为命名空间，不同键对应不同子对象地址，且同一键不能重复注册。
- **可预测的 object ID**：前端或索引器希望在不发起交易的前提下，仅根据父 ID 和键就能算出子对象的 ID。

`derived_object` 提供的正是：**由 (父 UID, Key) 确定性地推导出 address/UID**，并在父对象上记录「该键已被占用」，从而保证同一键只能被 claim 一次。

## 与动态字段的关系

`derived_object` 在实现上依赖 **动态字段**（`dynamic_field`）：  
在父对象的 UID 上以 `Claimed(derived_id)` 为名存储一个标记，表示该派生 ID 已被占用。因此：

- **claim** 时会向父对象写入一条动态字段，用于防止同一 key 被重复 claim。
- **exists** 时只是查询该动态字段是否存在，不创建新对象。
- 派生出的 UID 一旦被 **claim**，就与父对象解耦使用，子对象可以独立存在、转移或共享，不要求父对象在交易中一起被访问（仅首次 claim 时需要父对象可变引用）。

## 模块与导入

```move
use sui::derived_object;
```

## 核心 API

| 函数 | 签名 | 说明 |
|------|------|------|
| **derive_address** | `fun derive_address<K: copy + drop + store>(parent: ID, key: K): address` | 根据父 ID 和键**计算**派生地址，不修改状态，不占用键。 |
| **claim** | `fun claim<K: copy + drop + store>(parent: &mut UID, key: K): UID` | 在父对象上**占用**该键，返回对应的派生 UID；同一键重复 claim 会 abort。 |
| **exists** | `fun exists<K: copy + drop + store>(parent: &UID, key: K): bool` | 查询该 (父, key) 是否已被 claim 过。 |

### derive_address

仅做**纯计算**：给定父对象的 `ID` 和键 `key`，返回一个确定的 `address`。不访问链上状态，不写入任何对象。可用于：

- 在未 claim 之前就预先知道「若用该 key claim，对象会落在哪个地址」。
- 链下或前端用相同算法推算子对象 ID（需与框架实现保持一致）。

```move
let parent_id = parent.id.to_inner();
let addr = derived_object::derive_address(parent_id, my_key);
// addr 每次对同一 parent_id + my_key 都相同
```

### claim

在**父对象的 UID** 上占用键 `key`，并返回一个**派生 UID**。内部会：

1. 用 `derive_address(parent, key)` 得到地址并转成 ID；
2. 检查父对象上是否已有 `Claimed(该 id)` 的动态字段；
3. 若无，则添加该动态字段，并返回由该地址构造的 `UID`。

返回的 UID 可直接用于构造新对象，使该对象「诞生」在派生地址上：

```move
let derived_uid = derived_object::claim(&mut parent.id, key);
let child = MyObject {
    id: derived_uid,
    field: value,
};
// child 的地址 = derive_address(parent.id.to_inner(), key)
```

同一 `(parent, key)` 只能 **claim 一次**；再次 claim 会触发 **EObjectAlreadyExists** 并 abort。

### exists

查询在给定父对象上，某键是否已被 claim 过（即是否已存在对应的 `Claimed` 动态字段）。  
注意：一旦 claim 过，即使之后把派生出的对象删掉（`object::delete`），**exists 仍为 true**，该键无法再次 claim。这样设计是为了避免「删掉子对象后重新 claim 同一键得到新对象」，保证派生地址的长期唯一性。

## Key 的类型约束与唯一性

键类型 `K` 必须满足 **`copy + drop + store`**。常见用法：

- **简单类型**：`u64`、`address`、`bool` 等。
- **字符串**：`std::string::String`、`std::ascii::String`（注意 `String` 与 `vector<u8>`、`ascii::String` 类型不同，会得到不同地址）。
- **结构体**：如 `CurrencyKey<T>()` 这种单例式 key，用于「按类型 T 派生」。

不同**类型**或不同**值**的 key 会得到不同的派生地址。例如：

- `derive_address(parent, b"foo".to_string())` 与 `derive_address(parent, b"foo")`（`vector<u8>`）**不等**；
- `derive_address(parent, key1)` 与 `derive_address(parent, key2)` 在 `key1 != key2` 时**不等**。

因此设计注册表时，键的选取（类型 + 取值）要能唯一标识一个「槽位」。

## 典型场景

### 1. 按类型注册：每个 T 一个槽位

在类型注册表（如 CoinRegistry）中，希望「每种类型 T 对应一个对象」。可以用**类型相关的 key**（例如一个只包含类型的结构体）作为键：

```move
use sui::derived_object;

public struct Registry has key { id: UID }

/// 用作派生键：同一类型 T 总是同一个 Key
public struct TypeKey<phantom T> has copy, drop, store {}

public fun register<T: key>(
    registry: &mut Registry,
    ctx: &mut TxContext,
): UID {
    derived_object::claim(&mut registry.id, TypeKey<T>())
}

public fun exists<T: key>(registry: &Registry): bool {
    derived_object::exists(&registry.id, TypeKey<T>())
}
```

这样每种 `T` 最多被注册一次，且对应地址唯一、可复现。

### 2. 按字符串键注册：命名槽位

用字符串（或其它业务键）做命名空间，每个键对应一个派生对象：

```move
public fun create_named_slot(
    registry: &mut Registry,
    name: std::string::String,
    ctx: &mut TxContext,
): UID {
    derived_object::claim(&mut registry.id, name)
}

public fun slot_exists(registry: &Registry, name: std::string::String): bool {
    derived_object::exists(&registry.id, name)
}
```

### 3. 先算地址再创建对象

若希望「先知道地址，再在后续逻辑里创建对象」，可以先用 `derive_address` 得到地址，再在需要时 `claim` 并用返回的 UID 构造对象：

```move
// 仅计算，不占用
let addr = derived_object::derive_address(registry.id.to_inner(), my_key);

// 需要时再占用并创建对象
let uid = derived_object::claim(&mut registry.id, my_key);
let obj = MyRecord { id: uid, data: ... };
```

## 完整示例：简单类型注册表

下面示例实现一个「按类型 T 注册单例对象」的注册表，并用派生对象保证每种类型只有一个实例、地址确定：

```move
module examples::type_registry;

use sui::derived_object;
use sui::transfer;
use std::string::String;

public struct Registry has key {
    id: UID,
}

/// 每种类型 T 对应一个「槽位」键
public struct TypeKey<phantom T> has copy, drop, store {}

/// 注册表中每类 T 存一条记录
public struct Record<T: store> has key {
    id: UID,
    name: String,
    value: T,
}

public fun new_registry(ctx: &mut TxContext): Registry {
    Registry { id: object::new(ctx) }
}

/// 为类型 T 注册一条记录；若 T 已注册则 abort
public fun register<T: key + store>(
    registry: &mut Registry,
    name: String,
    value: T,
    ctx: &mut TxContext,
) {
    assert!(!derived_object::exists(&registry.id, TypeKey<T>()), 0);
    let uid = derived_object::claim(&mut registry.id, TypeKey<T>());
    let record = Record<T> { id: uid, name, value };
    transfer::share_object(record); // 或 transfer::transfer(record, ctx.sender())
}

public fun is_registered<T: key>(registry: &Registry): bool {
    derived_object::exists(&registry.id, TypeKey<T>())
}
```

要点：

- 用 **TypeKey\<T\>** 做键，保证「每种 T 一个槽位」。
- **register** 中先 `exists` 再 `claim`，避免重复注册。
- **claim** 得到的 UID 直接用作 `Record` 的 `id`，这样 `Record<T>` 的 object ID 永远由 `(Registry.id, TypeKey<T>)` 确定。

## 在 CoinRegistry 中的用法

Sui 的 **CoinRegistry** 在 **finalize_registration** 中使用了派生对象：  
当一种新代币的 `Currency<T>` 被「注册」到链上时，会从 CoinRegistry 的 UID 和 **CurrencyKey\<T\>** 派生出该 Currency 的 UID，并作为共享对象发布。这样：

- 每种代币类型 `T` 在全局只有一个 `Currency<T>` 对象；
- 其地址由 `(CoinRegistry.id, CurrencyKey<T>)` 确定，索引器和前端可以稳定地按类型推算或查询。

你不需要自己实现该逻辑，但理解「派生对象 = 父 + 键 → 确定性 UID」有助于阅读框架中各类 Registry 的实现。

## 注意事项

1. **claim 不可逆**：一旦对某 (parent, key) 调用了 **claim**，该键就永远被视为已占用；即使之后用返回的 UID 创建的对象被删掉，**exists** 仍为 true，不能再次 claim 同一 key。
2. **键的类型与值都要一致**：链下或前端若想复现地址，键的类型和值必须与链上完全一致（例如都用 `String` 且内容相同）。
3. **父对象需可变**：只有 **claim** 需要 `&mut UID`；**derive_address** 和 **exists** 只需 `&UID` 或 `ID`。
4. **派生出的对象独立存在**：claim 返回的 UID 用于构造对象后，该对象与普通对象一样可以 transfer、share、freeze，不要求父对象同时存在或可访问（仅首次 claim 时需要父对象）。

## 小结

- **derived_object** 提供由 **(父 UID, Key)** 确定性地推导 **address/UID** 的能力，并保证同一键只能被 **claim** 一次。
- **derive_address** 只做计算；**claim** 占用键并返回 UID，用于在派生地址上创建对象；**exists** 查询键是否已被占用。
- 常用于**注册表**、**按类型或名称的命名空间**，以及需要**可预测 object ID** 的场景。
- 实现上依赖动态字段在父对象上记录「已占用的派生 ID」；派生出的对象之后可独立于父对象使用。
