# 授权模式总结

在前面的章节中，我们分别学习了 Capability 模式、Witness 模式和一次性见证（OTW）模式。这三种模式共同构成了 Move on Sui 中授权体系的基石。本章将对这些模式进行横向对比，分析各自的适用场景，并展示如何组合使用它们来构建安全、灵活的授权架构。

## 三种授权模式回顾

### Capability 模式

**核心思想**：将权限具象化为一个拥有的对象。持有该对象即拥有对应权限。

```move
/// AdminCap 是一个权限对象
public struct AdminCap has key { id: UID }

/// 持有 AdminCap 才能调用
public fun admin_only(_: &AdminCap) {
    // 特权操作
}
```

**特点**：

- 权限是一个链上对象，有明确的生命周期
- 可以转移、销毁、追踪
- 适合持续性的角色授权

### Witness 模式

**核心思想**：通过构造某个类型的实例来证明对该类型的所有权。

```move
/// 只有定义模块能创建 GOLD
public struct GOLD has drop {}

/// 需要 Witness 来创建容器
public fun new_container<T: drop>(_witness: T): Container<T> {
    Container { value: 0 }
}
```

**特点**：

- 利用 Move 的结构体打包规则
- 轻量级，不占用链上存储
- 适合类型级别的一次性授权

### OTW 模式

**核心思想**：系统保证只存在一次的 Witness，用于全局唯一初始化。

```move
/// OTW：模块名大写，仅 drop，无字段
public struct MY_MODULE has drop {}

fun init(otw: MY_MODULE, ctx: &mut TxContext) {
    // 全局唯一的初始化逻辑
}
```

**特点**：

- 系统级保证只创建一次
- 严格的定义规则
- 适合代币创建、Publisher 声明等一次性操作

## 对比分析

### 核心维度对比

| 维度 | Capability | Witness | OTW |
|------|-----------|---------|-----|
| **授权载体** | 链上对象 | 类型实例 | 系统提供的类型实例 |
| **创建次数** | 可多次 | 可多次 | 仅一次 |
| **生命周期** | 持久存在 | 即用即弃 | 即用即弃 |
| **存储开销** | 占用存储 | 无 | 无 |
| **可转移** | ✅ | ❌（绑定模块） | ❌ |
| **可撤销** | ✅（销毁对象） | ❌ | ❌ |
| **授权粒度** | 账户级别 | 类型/模块级别 | 包级别 |
| **运行时检查** | 类型系统检查 | 类型系统检查 | 类型系统 + 运行时检查 |

### 适用场景对比

| 场景 | 推荐模式 | 原因 |
|------|---------|------|
| 管理员权限 | Capability | 需要持续授权，可能需要转移 |
| 角色权限（编辑者、审核者） | Capability | 多角色，需要细粒度控制 |
| 代币创建 | OTW | 必须保证全局唯一 |
| Publisher 声明 | OTW | 系统要求 |
| 泛型工厂 | Witness | 类型级别授权 |
| 插件/扩展系统 | Witness | 模块间的类型证明 |
| 全局配置初始化 | OTW | 只需执行一次 |
| 权限委托 | Capability | 可转移给其他账户 |

## 组合使用模式

在实际项目中，这三种模式经常组合使用。下面是一个综合示例：

```move
module examples::auth_combined;

use std::string::String;

/// Capability：管理员权限
public struct AdminCap has key { id: UID }

/// Witness：类型级别授权
public struct AuthWitness has drop {}

/// OTW：一次性初始化
public struct AUTH_COMBINED has drop {}

/// 注册表：结合多种授权模式
public struct Registry has key {
    id: UID,
    initialized: bool,
}

fun init(otw: AUTH_COMBINED, ctx: &mut TxContext) {
    // OTW 确保只初始化一次
    assert!(sui::types::is_one_time_witness(&otw), 0);

    // 创建管理员能力
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );

    // 创建并共享注册表
    let registry = Registry {
        id: object::new(ctx),
        initialized: true,
    };
    transfer::share_object(registry);
}

/// Cap 守护的操作：需要 AdminCap
public fun admin_action(_: &AdminCap, _registry: &mut Registry) {
    // 只有管理员能执行
}

/// Witness 守护的工厂函数
public fun create_typed<T: drop>(_witness: T, ctx: &mut TxContext): UID {
    object::new(ctx)
}

/// 模块内部使用自己的 Witness
public fun internal_create(ctx: &mut TxContext): UID {
    create_typed(AuthWitness {}, ctx)
}
```

### 实际项目架构示例

一个典型的 NFT 项目可能这样组合使用三种模式：

```move
module examples::nft_project;

use sui::package;
use sui::display;
use std::string::String;

/// OTW - 用于初始化
public struct NFT_PROJECT has drop {}

/// Capability - 管理员权限
public struct AdminCap has key { id: UID }

/// Capability - 铸造权限
public struct MinterCap has key { id: UID }

/// NFT 类型
public struct GameNFT has key, store {
    id: UID,
    name: String,
    level: u64,
    image_id: String,
}

/// 全局配置
public struct Config has key {
    id: UID,
    max_supply: u64,
    current_supply: u64,
    is_minting_active: bool,
}

fun init(otw: NFT_PROJECT, ctx: &mut TxContext) {
    // 1. OTW → Publisher → Display（一次性）
    let publisher = package::claim(otw, ctx);

    let keys = vector[
        std::string::utf8(b"name"),
        std::string::utf8(b"image_url"),
        std::string::utf8(b"description"),
    ];
    let values = vector[
        std::string::utf8(b"{name}"),
        std::string::utf8(b"https://nft.example.com/{image_id}.png"),
        std::string::utf8(b"Level {level} game NFT"),
    ];
    let mut disp = display::new_with_fields<GameNFT>(
        &publisher, keys, values, ctx,
    );
    display::update_version(&mut disp);

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());

    // 2. Capability → 管理员权限（持续性）
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );

    // 3. 全局配置（一次性创建，共享）
    let config = Config {
        id: object::new(ctx),
        max_supply: 10000,
        current_supply: 0,
        is_minting_active: false,
    };
    transfer::share_object(config);
}

/// AdminCap 守护：授予铸造权
public fun grant_minter(
    _: &AdminCap,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(
        MinterCap { id: object::new(ctx) },
        recipient,
    );
}

/// AdminCap 守护：开启/关闭铸造
public fun toggle_minting(
    _: &AdminCap,
    config: &mut Config,
) {
    config.is_minting_active = !config.is_minting_active;
}

/// MinterCap 守护：铸造 NFT
public fun mint(
    _: &MinterCap,
    config: &mut Config,
    name: String,
    image_id: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(config.is_minting_active, 0);
    assert!(config.current_supply < config.max_supply, 1);

    config.current_supply = config.current_supply + 1;

    let nft = GameNFT {
        id: object::new(ctx),
        name,
        level: 1,
        image_id,
    };
    transfer::public_transfer(nft, recipient);
}
```

在这个项目中：

- **OTW** 用于创建 Publisher 和 Display（一次性初始化）
- **AdminCap** 用于管理权限（授予铸造权、控制铸造开关）
- **MinterCap** 用于铸造权限（细粒度授权）

## 决策流程

选择授权模式时，可以按以下流程决策：

```
需要授权控制？
│
├── 是否需要一次性初始化？
│   ├── 是 → 使用 OTW
│   │   ├── 创建代币 → coin_registry::new_currency_with_otw + finalize
│   │   ├── 声明 Publisher → package::claim
│   │   └── 全局配置 → 在 init 中创建共享对象
│   │
│   └── 否 → 继续判断
│
├── 是否需要持续性的权限管理？
│   ├── 是 → 使用 Capability
│   │   ├── 单一管理员 → AdminCap
│   │   ├── 多角色 → AdminCap + EditorCap + ViewerCap
│   │   └── 可委托 → 转移 Cap 给其他账户
│   │
│   └── 否 → 继续判断
│
├── 是否需要类型级别的证明？
│   ├── 是 → 使用 Witness
│   │   ├── 泛型工厂 → T: drop 作为参数
│   │   └── 类型注册 → 用 Witness 绑定类型
│   │
│   └── 否 → 可能不需要特殊的授权模式
```

## 授权设计最佳实践

### 1. 最小权限原则

每种 Capability 只授予完成特定任务所需的最低限度权限：

```move
// ✅ 细粒度的权限划分
public struct MinterCap has key { id: UID }   // 只能铸造
public struct BurnerCap has key { id: UID }   // 只能销毁
public struct PauserCap has key { id: UID }   // 只能暂停

// ❌ 过于粗糙的权限
public struct GodCap has key { id: UID }      // 能做一切
```

### 2. 权限层级

建立清晰的权限层级，高级权限可以授予低级权限：

```move
// AdminCap 可以创建 MinterCap 和 BurnerCap
// MinterCap 只能铸造，不能创建其他 Cap
// BurnerCap 只能销毁，不能创建其他 Cap
```

### 3. 组合优于单一

不要试图用一种模式解决所有问题：

```move
// ✅ 组合使用
// OTW → 初始化
// Publisher → Display 和 TransferPolicy
// AdminCap → 业务管理
// Witness → 泛型类型系统

// ❌ 单一模式
// 仅用 AdminCap 做所有事情
```

### 4. 文档化权限要求

通过函数签名和文档清晰表达权限要求：

```move
/// 铸造 NFT
/// 
/// 需要：MinterCap（由 AdminCap 持有者授予）
/// 前置条件：铸造必须处于开启状态
public fun mint(_: &MinterCap, ...) { ... }
```

### 5. 提供撤销机制

对于 Capability 模式，始终提供撤销（销毁）权限的方法：

```move
public fun revoke(_: &AdminCap, cap: MinterCap) {
    let MinterCap { id } = cap;
    id.delete();
}
```

## 小结

Capability、Witness 和 OTW 是 Move on Sui 中三种核心的授权模式。Capability 将权限物化为可管理的对象，适合持续性的角色授权；Witness 利用类型构造权实现轻量级的模块间授权，适合泛型系统；OTW 通过系统级保证实现一次性初始化，是代币创建和 Publisher 声明的基础。在实际项目中，应根据具体需求组合使用这三种模式，遵循最小权限原则，构建安全、灵活、可维护的授权体系。理解这些模式之间的关系和各自的适用场景，是成为 Move on Sui 高级开发者的关键。
