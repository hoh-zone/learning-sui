# Capability 模式

Capability（能力）模式是 Move on Sui 中最常用的访问控制模式之一。它通过将权限具象化为一个**拥有的对象**，实现了类型安全、可转移、可撤销的授权机制。与传统的地址检查方式相比，Capability 模式更加灵活，也更符合 Move 的面向资源编程范式。

本章将深入讲解 Capability 模式的设计理念、实现方式、命名规范及最佳实践。

## 什么是 Capability

Capability 是一个被特定账户拥有的对象，它的存在本身就代表了一种权限。在函数签名中，通过要求调用者传入某个 Capability 类型的引用，即可实现访问控制——只有拥有该对象的账户才能成功调用该函数。

这种设计理念源自 **Capability-Based Security**（基于能力的安全模型），核心思想是：**持有凭证即拥有权限**，无需在运行时检查调用者身份。

### 与传统地址检查的对比

传统方式通常在合约中硬编码管理员地址：

```move
const ADMIN: address = @0xABC;
const ENotAdmin: u64 = 0;

public fun admin_only(ctx: &TxContext) {
    assert!(ctx.sender() == ADMIN, ENotAdmin);
    // 执行操作...
}
```

这种方式存在明显缺陷：

- **不可迁移**：管理员地址硬编码在合约中，无法转移权限
- **不可升级**：更换管理员需要升级合约
- **缺乏类型安全**：地址只是一个值，编译器无法区分不同权限

Capability 模式完美解决了这些问题。

## 命名规范

Sui 社区约定 Capability 类型以 **`Cap`** 后缀命名：

| 名称 | 用途 |
|------|------|
| `AdminCap` | 管理员权限 |
| `OwnerCap` | 所有者权限 |
| `MinterCap` | 铸造权限 |
| `BurnCap` | 销毁权限 |
| `TreasuryCap` | 国库/资金管理权限 |
| `UpgradeCap` | 升级权限 |

这种命名让开发者一眼就能识别权限类型，提高了代码的可读性和可发现性。

## 基本实现

### 在 init 函数中创建 Capability

Capability 通常在模块的 `init` 函数中创建，并转移给合约部署者：

```move
module examples::capability;

use std::string::String;

/// 管理员能力 - 在 init 中仅创建一次
public struct AdminCap has key { id: UID }

/// 铸造能力 - 可授予特定账户
public struct MinterCap has key { id: UID }

public struct NFT has key, store {
    id: UID,
    name: String,
    creator: address,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );
}
```

`AdminCap` 只有 `key` 能力，没有 `store`，这意味着它不能通过 `public_transfer` 被任意转移——只有本模块定义的函数可以控制其流转。这是一种有意的设计选择，防止管理员权限被意外转让。

### 使用 Capability 作为函数参数

通过引用传入 Capability 来实现权限控制：

```move
/// 只有管理员才能创建铸造能力
public fun create_minter(
    _: &AdminCap,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(
        MinterCap { id: object::new(ctx) },
        recipient,
    );
}

/// 任何持有 MinterCap 的人都可以铸造 NFT
public fun mint(
    _: &MinterCap,
    name: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let nft = NFT {
        id: object::new(ctx),
        name,
        creator: ctx.sender(),
    };
    transfer::public_transfer(nft, recipient);
}

/// 管理员也可以直接铸造
public fun admin_mint(
    _: &AdminCap,
    name: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let nft = NFT {
        id: object::new(ctx),
        name,
        creator: ctx.sender(),
    };
    transfer::public_transfer(nft, recipient);
}
```

注意参数名使用了 `_`（下划线），表示我们不需要读取 Capability 的内容——它的存在本身就是授权证明。

## 撤销权限

Capability 模式的一大优势是权限可以被撤销。通过解构（destructure）Capability 对象来销毁它：

```move
/// 撤销铸造能力，通过销毁它
public fun revoke_minter(_: &AdminCap, cap: MinterCap) {
    let MinterCap { id } = cap;
    id.delete();
}
```

这要求管理员能够获取目标 `MinterCap` 对象。在实践中，这通常通过以下方式实现：

1. 持有者主动交还（将 cap 作为参数传入撤销函数）
2. 使用 `transfer::receive` 从对象地址接收

## 细粒度授权

通过定义多种 Capability 类型，可以实现精细的权限划分：

```move
module examples::fine_grained;

use std::string::String;

public struct AdminCap has key { id: UID }
public struct EditorCap has key { id: UID }
public struct ViewerCap has key { id: UID }

public struct Document has key, store {
    id: UID,
    title: String,
    content: String,
    published: bool,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        AdminCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

/// 管理员可以授予编辑权限
public fun grant_editor(
    _: &AdminCap,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(
        EditorCap { id: object::new(ctx) },
        recipient,
    );
}

/// 管理员可以授予查看权限
public fun grant_viewer(
    _: &AdminCap,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(
        ViewerCap { id: object::new(ctx) },
        recipient,
    );
}

/// 编辑者可以修改文档
public fun edit_document(
    _: &EditorCap,
    doc: &mut Document,
    new_content: String,
) {
    doc.content = new_content;
}

/// 管理员可以发布文档
public fun publish_document(
    _: &AdminCap,
    doc: &mut Document,
) {
    doc.published = true;
}
```

这种设计实现了**最小权限原则**——每个角色只拥有完成其任务所需的最低限度的权限。

## Capability 模式的优势

### 1. 可迁移性

权限可以通过转移 Capability 对象来转移给新账户，无需修改合约代码。

### 2. 类型安全

编译器在编译时就能检查权限——如果函数要求 `AdminCap` 引用，传入 `MinterCap` 会直接编译失败。

### 3. 可发现性

通过查看函数签名，立即就能知道调用该函数需要什么权限。无需阅读函数体内的断言逻辑。

### 4. 可组合性

多个模块可以共享同一个 Capability 类型，或者定义自己的 Capability 类型来构建复杂的权限体系。

### 5. 可审计性

链上可以追踪 Capability 对象的持有者，轻松审计谁拥有什么权限。

## 设计建议

| 建议 | 说明 |
|------|------|
| 使用 `key` 而非 `key, store` | 防止 Capability 被随意转移 |
| 在 `init` 中创建根 Capability | 确保只有部署者获得初始权限 |
| 使用引用 `&Cap` 而非值传递 | 避免意外消耗 Capability |
| 提供撤销函数 | 允许回收已授予的权限 |
| 按职责划分 Cap 类型 | 遵循最小权限原则 |

## 小结

Capability 模式是 Move on Sui 中实现访问控制的基石。它将权限物化为对象，利用类型系统在编译时提供安全保证。相比传统的地址检查方式，Capability 模式更加灵活、安全、可维护。在设计合约的权限体系时，应优先考虑使用 Capability 模式，并根据业务需求定义合理的 Capability 类型层级。
