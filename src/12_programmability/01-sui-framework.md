# Sui Framework 概览

## 导读

本节是**第十二章的入口**：建立 **`move-stdlib` / `sui-framework` / `sui-system`** 与 **`std` / `sui` / `sui_system`** 的对应关系，并给出 **集合选型总表**。后续 [§12.2](02-transaction-context.md)～[§12.14](14-randomness.md) 文首均设有「导读」，可反复回到本节对照模块名。

- **建议顺序**：读完本节 → [§12.2](02-transaction-context.md) 起按章内「建议阅读路线」推进（见 [章索引](00-index.md)）。  

---

编写 Sui 合约时，你写的 `module` 会编译进自己的**包（package）**，但类型与函数大量来自三条「公共底座」：**Move 标准库**（`std::`）、**Sui Framework**（`sui::`），以及可选的 **Sui System**（`sui_system::`）。三者源码集中在官方仓库的 `crates/sui-framework/packages/` 下，本节说明它们的**分工、依赖关系、常用模块与集合选型**，并单独交代 **sui-system** 在应用开发中的位置。§12.2 起再按主题深入各 API。

---

## 一、源码包布局与依赖（`crates/sui-framework/packages`）

在 [Sui 仓库](https://github.com/MystenLabs/sui) 中，与链上 Move 合约直接相关的三个包通常如下（目录名 → Move 包名 → 默认命名地址）：

| 目录 | Move 包名 | 命名地址（约定） | 依赖 |
|------|-----------|------------------|------|
| `move-stdlib/` | **MoveStdlib** | `std` → `0x1` | 无：纯 Move，与是否 Sui 无关 |
| `sui-framework/` | **Sui** | `sui` → `0x2` | 依赖 **MoveStdlib** |
| `sui-system/` | **SuiSystem** | `sui_system` → `0x3` | 依赖 **MoveStdlib** + **Sui** |

**你在项目里最常写的 `Move.toml` 只声明一条 `Sui` 依赖**，编译器会解析出 `Sui` 所依赖的 **MoveStdlib**，无需再手写 `MoveStdlib` 条目（除非你做本地 fork 或特殊覆盖）。**SuiSystem** 不会自动进你的包：只有当你要调用**质押、验证者、系统参数**等链级模块时，才在 `Move.toml` 里**额外**增加对 `sui-system` 包的依赖（见第四节）。

```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
```

`rev` 与 mainnet / testnet 对齐方式见[第六章 §6.11 · Move 2024 Edition](../06_move_intermediate/11-move-2024.md)。工具链会为 `std`、`sui` 等解析到已发布的框架地址，因此业务代码里直接写 `std::vector::empty()`、`sui::coin::Coin` 即可，一般**不必**在自有 `Move.toml` 的 `[addresses]` 里重复填 `0x1` / `0x2`（除非教程或本地测试有特殊占位需求）。

**阅读源码时的习惯**：想查「`option` 怎么实现的」→ 打开 `move-stdlib/sources/option.move`；想查「`Table` 的 `add` 有什么前置条件」→ 打开 `sui-framework/sources/table.move`。把目录名与 `use` 路径对应起来，查文档会快很多。

---

## 二、Move 标准库（`move-stdlib` → `std::`）

**MoveStdlib** 是所有 Sui Move 包的**共同地基**：它只依赖 Move 语言本身，**不包含** `UID`、转移、共享对象等概念。你可以把它理解为：**在任何 Move 链上都会存在的一套核心库**；Sui 在之上叠了 `sui::` 才出现「对象 + 交易」模型。

### 2.1 日常最常用的模块

- **`std::vector`**：可变长数组，字面量 `vector[1,2,3]`、下标、`push_back`、配合[第十一章 · 宏函数](../11_move_macros/06-vector-macros.md)里的 `do!` / `fold!` 等。第六章 §6.2 已系统讲解。  
- **`std::option`**：`Option<T>` 与 `some` / `none`，安全访问与模式匹配见 §6.3。  
- **`std::string` / `std::ascii`**：UTF-8 字符串与 ASCII 字符串，NFT 元数据、错误消息等常用。

### 2.2 序列化、哈希与类型信息

- **`std::bcs`**：BCS 编解码的底层能力。合约里若要对任意 `copy + drop` 的值做字节化，会用到；**Sui 侧**还提供了 **`sui::bcs`**（§12.12），在「与链下交互、解析输入字节」场景更常出现，二者关系可以理解为：**语言层 `std::bcs` 与链上封装 `sui::bcs` 分工配合**，具体 API 以本章 BCS 一节为准。  
- **`std::hash`**：基础哈希原语。  
- **`std::type_name`**：取类型的运行时名字，与[第八章 · 类型反射](../08_move_advanced/04-type-reflection.md)中的 `type_name` 用法一致。

### 2.3 数值、位集与其它

- **整数模块 `u8` … `u256`**：常提供该宽度下的饱和运算、位运算等辅助（依版本为准）。  
- **`fixed_point32`、`uq32_32`、`uq64_64`**：定点与无符号有理数，适合价格、比率。  
- **`bit_vector`**：位集；**`bool`**：布尔小工具。  
- **`macros`**：标准库宏（见[第十一章](../11_move_macros/00-index.md)）。  
- **`unit_test`、`debug`**：测试与调试，**不应**出现在可发布模块的生产路径里。

下面是一段**只使用 `std`**、不涉及 `sui::` 的片段（便于体会「标准库与链解耦」）：

```move
module example::stdlib_only;

use std::vector;
use std::option::{Self, Option};

public fun sum_or_zero(maybe: Option<u64>): u64 {
    if (maybe.is_some()) {
        maybe.destroy_some()
    } else {
        maybe.destroy_none();
        0
    }
}

public fun accumulate(v: vector<u64>): u64 {
    let mut i = 0;
    let len = v.length();
    let mut s = 0u64;
    while (i < len) {
        s = s + v[i];
        i = i + 1;
    };
    s
}
```

**小结**：业务逻辑里大量「算数、拼 `vector`、处理 `Option`」都在 **`std::`** 完成；一旦涉及 **`UID`、转移、`Coin`、动态字段**，就要叠到 **`sui::`** 上。

---

## 三、Sui Framework（`sui-framework` → `sui::`）

**Sui** 包在 MoveStdlib 之上实现 **Sui 的对象模型与系统对象交互**。源码位于 `sui-framework/sources/`，模块数量多，建议按**功能块**记地图，需要细节时再点进具体 `.move` 文件。

### 3.1 隐式导入：不必写 `use` 的三个模块

编译器会为每个模块**自动**引入：

- **`sui::object`** — `UID`、`ID`、`object::new(ctx)`、`object::id(&obj)` 等；  
- **`sui::tx_context`** — `TxContext` 与 `ctx.sender()`、`ctx.fresh_id()` 等（§12.2）；  
- **`sui::transfer`** — `transfer`、`public_transfer`、`share_object`、`freeze_object` 等（[第十章](../10_using_objects/00-index.md)）。

因此下面代码**无需**任何 `use sui::object` 也能编译：

```move
module examples::implicit;

public struct Thing has key {
    id: UID,
}

public fun mint(ctx: &mut TxContext): Thing {
    Thing { id: object::new(ctx) }
}

public fun send(t: Thing, to: address) {
    transfer::public_transfer(t, to);
}
```

其它 `sui::` 子模块（如 `event`、`clock::Clock`）仍要**显式** `use`，否则编译器不知道你要缩短哪个名字。

### 3.2 对象、包与展示

- **`object`**：对象身份与 `UID` 生命周期，是[第九章 · 对象模型](../09_object_model/00-index.md)的代码载体。  
- **`transfer`**：所有权、共享、冻结；与 `key` / `store` 能力约束一起决定你能调用哪一组 API。  
- **`package`**：`Publisher`、`UpgradeCap`、包升级流程，与[第十二章 · 设计模式](../13_patterns/00-index.md)中的 OTW、Publisher 模式直接相关。  
- **`display` / `display_registry`**：为类型配置链下展示模板（名称、链接、图片字段等），NFT 章节会再用到。

**最小可读示例**：创建一个带 `UID` 的对象并转给调用者；`artifact_id` 演示如何读 `ID`：

```move
module examples::object_demo;

public struct Artifact has key {
    id: UID,
    power: u64,
}

public fun create_artifact(power: u64, ctx: &mut TxContext): Artifact {
    Artifact { id: object::new(ctx), power }
}

public fun artifact_id(a: &Artifact): ID {
    object::id(a)
}

public fun destroy_artifact(a: Artifact) {
    let Artifact { id, power: _ } = a;
    id.delete();
}
```

### 3.3 时间与随机数（依赖系统共享对象）

- **`clock`**：`Clock` 提供**只读**链上时间（毫秒），对应系统共享对象地址 **`0x6`**，§12.5 会讲如何在交易里传入 `Clock`。  
- **`random`**：链上随机数对象（地址 **`0x8`**）与公平性约定，见 §12.14。

### 3.4 动态存储：字段、对象字段与派生对象

- **`dynamic_field`**：给任意有 `UID` 的对象挂**键值对**，键类型可以不同（异构），§12.7。  
- **`dynamic_object_field`**：值必须是 **Sui 对象**，便于索引与查询，§12.8。  
- **`derived_object`**：由父对象与确定性规则「派生」子对象地址，注册表、命名对象等模式见 §12.9。

### 3.5 集合与经济（与后文章节对应）

**集合**：`vec_map`、`vec_set`（§12.6）；`table`、`bag`、`object_table`、`object_bag`、`linked_table`、`table_vec`（§12.10）；另有 **`priority_queue`** 用最大堆实现优先级队列，元素需满足 `drop`，适合「每次取当前最高优先级」的调度，**与 `Table` 的用途不同**，不要混用场景。

**代币与资产**：`balance`、`coin`、原生 **`SUI`**（`sui::sui::SUI`）见 §12.11；`token`、**`coin_registry`**、**Kiosk** 等与[第十五章 · 代币](../15_tokens/00-index.md)、[第十六章 · NFT](../16_nft_kiosk/00-index.md)衔接。

### 3.6 工具与密码学

- **`sui::bcs`**：合约内 BCS 构造与解析，§12.12。  
- **`hex`**：十六进制编解码。  
- **`borrow`**：「借出对象必须归还」类安全封装。  
- **`types`**：如 `is_one_time_witness`，配合 `package::claim`，见下文示例。  
- **`event`**：`emit`，§12.4。  
- **`crypto/*`**：哈希、签名、BLS、Groth16 等，§12.13。

### 3.7 事件与 OTW（连贯示例）

链上通知链下常用 **`event::emit`**；**一次性见证**常用 **`types` + `package`**：

```move
module examples::emit_and_otw;

use sui::event;
use sui::package;
use sui::types;

public struct Demo has key {
    id: UID,
}

public struct CreatedEvent has copy, drop {
    owner: address,
}

public struct BOOK_OTW has drop {}

fun init(otw: BOOK_OTW, ctx: &mut TxContext) {
    assert!(types::is_one_time_witness(&otw), 0);
    let pub = package::claim(otw, ctx);
    let obj = Demo { id: object::new(ctx) };
    event::emit(CreatedEvent { owner: ctx.sender() });
    transfer::public_transfer(pub, ctx.sender());
    transfer::transfer(obj, ctx.sender());
}
```

（`BOOK_OTW` 命名需与包名规则一致，完整约定见 OTW 专节。）

---

## 四、集合类型对比与选型（重点）

Sui 在 **`sui::`** 里提供了多类容器，**没有**「万能的一种」：差别在于数据**住在宿主对象内部**还是**拆到动态（对象）字段里**，以及**键值是否同质**、**值是否必须是子对象**。

### 4.1 总览表

| 类型（模块） | 数据存放位置 | 键 | 值 | 典型规模 | 备注 |
|--------------|--------------|----|----|----------|------|
| **`VecMap<K,V>`** | 宿主对象**内部** | 有序键值映射 | `K`、`V` 同质 | 小 | 随宿主整体读写，实现简单 |
| **`VecSet<K>`** | 宿主对象内部 | 去重集合 | — | 小 | 同上 |
| **`Table<K,V>`** | **动态字段** | 同质 | 非对象值 | **大** | 最常用可扩展 KV |
| **`Bag`** | 动态字段 | **异构** | 异构 | 中到大 | 键类型可不同 |
| **`ObjectTable<K,V>`** | **动态对象字段** | 同质 | **必须是 `key` 对象** | 大 | 值独立索引、可转移 |
| **`ObjectBag`** | 动态对象字段 | 异构 | 对象 | 中到大 | 与 `Bag` 类似 |
| **`LinkedTable<K,V>`** | 动态字段 | 同质 | 同质 | 大 | **保序**、可顺序遍历 |
| **`TableVec<T>`** | 动态字段 | 下标 | 同质 | 中到大 | 类似可增长的「外置向量」 |
| **`PriorityQueue<T>`** | 宿主对象内（堆） | — | `T: drop` | 视场景 | **按优先级弹出**，非通用 KV |

### 4.2 用场景说话

- **几十个以内的配置项**（例如「模块级参数名 → 值」），且总字节不大：用 **`VecMap`**，读写在一次对象加载内完成，逻辑直观。  
- **用户量上来、条目成千上万**：用 **`Table`** 或 **`LinkedTable`**（需要插入顺序时），避免把整张表塞进单个 `vector`。  
- **值本身是 NFT 或其它链上对象**：用 **`ObjectTable` / `ObjectBag`**，否则对象无法作为普通 `V` 塞进 `Table` 的 value 里（需满足对象模型约束）。  
- **同一容器里键类型都不一致**（例如多种资源混放）：用 **`Bag` / `ObjectBag`**，取出时要按类型分支。  
- **调度、拍卖、任务队列**等「每次取极值」：考虑 **`PriorityQueue`**，而不是强行用 `VecMap` 扫描。

### 4.3 一段对照示例（VecMap 与 Table）

下面展示**同一「注册表」语义**的两种承载方式：左侧数据在**对象内部**，右侧数据在**动态字段**（适合变大）。

```move
module examples::collection_compare;

use sui::table::{Self, Table};
use sui::vec_map::{Self, VecMap};

/// 小规模：配置与元数据放在 VecMap 里即可。
public struct SmallRegistry has key {
    id: UID,
    /// 例如：配置名 -> 配置值（均不宜过长）
    settings: VecMap<vector<u8>, vector<u8>>,
}

/// 大规模：每个 address 一条记录用 Table 单独挂动态字段，避免单对象过大。
public struct LargeRegistry has key {
    id: UID,
    profiles: Table<address, vector<u8>>,
}

public fun new_small(ctx: &mut TxContext): SmallRegistry {
    SmallRegistry {
        id: object::new(ctx),
        settings: vec_map::empty(),
    }
}

public fun new_large(ctx: &mut TxContext): LargeRegistry {
    LargeRegistry {
        id: object::new(ctx),
        profiles: table::new(ctx),
    }
}
```

具体增删 API 见 §12.6、§12.10；这里只需建立**选型直觉**。

---

## 五、sui-system 包（`sui-system` → `sui_system::`）

**SuiSystem** 源码在 `packages/sui-system/`，命名地址一般为 **`sui_system`（`0x3`）**。它在 **MoveStdlib + Sui Framework** 之上，实现**整条链的共识与质押层逻辑**，例如（名称随版本可能调整，以源码为准）：

- **`sui_system::sui_system`**：系统状态封装、与 epoch、验证者集合相关的入口；  
- **`staking_pool`、`validator`、`validator_set`**：质押池与验证者；  
- **`genesis`**：创世相关（多在系统层使用）。

**对普通应用开发者的建议**：

1. **默认只依赖 `Sui` 包** 即可完成代币、NFT、业务对象、动态字段等绝大多数教程与产品需求。  
2. 只有当你明确要写 **质押、委托、读取/修改与系统状态强相关的逻辑** 时，再在 `Move.toml` 增加 **sui-system** 依赖，例如：

```toml
# 示例：仅在确有需要时增加（路径与 rev 须与你的工具链一致）
# SuiSystem = { git = "...", subdir = "crates/sui-framework/packages/sui-system", rev = "framework/mainnet" }
```

3. **系统模块的公开接口会随协议升级而变化**，本书 §12.1 只建立概念边界；具体函数签名、权限与错误码务必以**当前网络**的官方文档与 `sui-system/sources/` 为准。

---

## 六、使用建议（落地）

1. **先想清数据落在 `std` 还是 `sui`**：纯计算与 `vector`/`Option` → `std`；`UID`、转移、`Coin` → `sui`。  
2. **隐式模块不要重复 `use`**：保持 `object::` / `transfer::` / `ctx` 一眼可读。  
3. **集合按第四节表选型**，单对象内 **`VecMap` 过大**会导致发布与读写压力，尽早改用 `Table` 系。  
4. **查 API 以源码为准**：本地克隆 Sui 仓库后，在 `crates/sui-framework/packages/` 下用编辑器搜索模块名最快。

---

## 小结

- **三层包**：`move-stdlib`（MoveStdlib / `std`）提供语言级能力；`sui-framework`（Sui / `sui`）提供对象、转移、集合、代币与密码学等链上能力；`sui-system`（SuiSystem / `sui_system`）提供共识与质押等**系统层**能力，按需依赖。  
- **Move 标准库**侧重 `vector`、`option`、字符串、BCS、类型名与数值工具；**Sui Framework** 在此基础上实现你每天在合约里面对的绝大部分 API。  
- **集合**没有银弹：对象内 **VecMap/VecSet**、动态字段 **Table/LinkedTable/Bag**、对象索引 **ObjectTable/ObjectBag**、调度 **PriorityQueue**，按数据规模与值是否对象来选。  
- **sui-system** 与业务框架分离，普通合约先掌握 **`std` + `sui`** 即可。  

读完本节，可按目录顺序继续 §12.2（交易上下文）→ §12.4（事件）→ … → 把本章串成一条完整动手路径。
