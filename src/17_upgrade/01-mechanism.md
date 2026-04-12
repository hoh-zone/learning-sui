# 升级机制与 UpgradeCap

在 Sui 上，已发布的包是**不可变对象**——字节码一旦上链就永远不会改变。包升级通过发布一个**与原始包链接的新版本**来实现：旧包保持不变，新包获得新的 Package ID，但继承其类型系统，共享对象通过迁移函数过渡到新版本。

本节讲解升级的唯一凭证 UpgradeCap、三步升级流程、兼容性规则和 CLI 操作。

## UpgradeCap — 升级的唯一凭证

当你发布一个包时，Sui 自动创建一个 `UpgradeCap` 对象并发送给发布者：

```move
// 来自 sui::package 模块
public struct UpgradeCap has key, store {
    id: UID,
    package: ID,       // 原始包的 ID
    version: u64,      // 当前版本号
    policy: u8,        // 升级策略
}
```

**重要特性：**

- 每个包只有一个 `UpgradeCap`——谁持有它，谁就能升级这个包
- `UpgradeCap` 具有 `store` 能力，可以转移给他人、存入多签钱包、或被自定义合约管理
- 如果 `UpgradeCap` 被销毁（`make_immutable()`），包将永远无法升级
- **必须安全保管**——丢失意味着失去升级能力，泄露意味着任何人都能升级

## 升级流程

升级分为三个原子步骤：

```
┌──────────────────────────────────────────────────────────┐
│  步骤 1: 授权（Authorize）                                │
│  出示 UpgradeCap → 获得 UpgradeTicket                    │
│  ┌─────────┐         ┌──────────────┐                    │
│  │UpgradeCap│ ──────→ │UpgradeTicket │                   │
│  └─────────┘         └──────────────┘                    │
├──────────────────────────────────────────────────────────┤
│  步骤 2: 发布（Publish）                                  │
│  提交新字节码 + UpgradeTicket → 链上验证兼容性             │
│  ┌──────────────┐  ┌──────────┐     ┌───────────────┐   │
│  │UpgradeTicket │ +│ 新字节码  │ ──→ │UpgradeReceipt │   │
│  └──────────────┘  └──────────┘     └───────────────┘   │
├──────────────────────────────────────────────────────────┤
│  步骤 3: 提交（Commit）                                   │
│  UpgradeReceipt 确认升级完成，更新 UpgradeCap             │
│  ┌───────────────┐  ┌─────────┐                         │
│  │UpgradeReceipt │→ │UpgradeCap│ version + 1             │
│  └───────────────┘  └─────────┘                         │
└──────────────────────────────────────────────────────────┘
```

在 CLI 中，`sui client upgrade` 命令自动完成以上三步。新版本的包获得自己的地址（新的 Package ID），但与原始包保持链接关系。

## 兼容性规则

升级必须保持**向后兼容**。核心原则：**依赖你的包的代码不应因升级而失效。**

### 什么可以改、什么不能改

| 元素 | 可以删除? | 可以改签名? | 可以改实现? |
|------|:---------:|:-----------:|:-----------:|
| **模块** | ❌ 不可删除 | — | — |
| **`public` 函数** | ❌ 不可删除 | ❌ 不可改 | ✅ 可以改 |
| **`public(package)` 函数** | ✅ 可以删除 | ✅ 可以改 | ✅ 可以改 |
| **`entry` 函数（非 public）** | ✅ 可以删除 | ✅ 可以改 | ✅ 可以改 |
| **`private` 函数** | ✅ 可以删除 | ✅ 可以改 | ✅ 可以改 |
| **`public` 结构体** | ❌ 不可删除 | ❌ 字段不可改 | — |
| **新模块** | ✅ 可添加 | — | — |
| **新函数** | ✅ 可添加 | — | — |
| **新结构体** | ✅ 可添加 | — | — |

用代码说明：

```move
module book::upgradable;

use std::string::String;

// ❌ 这个结构体不能被删除，字段不能被修改
public struct Book has key {
    id: UID,
    title: String,
}

// ❌ 这个函数不能被删除，签名不能改变
// ✅ 但函数体（实现）可以改
public fun create_book(ctx: &mut TxContext): Book {
    create_book_internal(ctx) // 这行代码可以换成别的实现
}

// ✅ 这个函数可以被删除、签名可以改
public(package) fun create_book_package(ctx: &mut TxContext): Book {
    create_book_internal(ctx)
}

// ✅ 这个函数可以被删除（因为不是 public）；entry 不能返回值
entry fun create_book_entry(ctx: &mut TxContext) {
    let book = create_book_internal(ctx);
    transfer::transfer(book, ctx.sender());
}

// ✅ 私有函数完全自由
fun create_book_internal(ctx: &mut TxContext): Book {
    abort 0
}
```

### 关键注意点

1. **`init` 不会在升级时重新运行**。如果新版本需要初始化逻辑，必须通过单独的迁移函数实现
2. **结构体字段不能增减**。如果需要给对象添加新字段，请使用动态字段（见第 17.4 节[数据迁移与向前兼容](04-migration.md)）
3. **`public` 是永久契约**。一旦声明为 `public`，函数签名就被永久锁定。设计时请慎重考虑哪些函数真正需要 `public`

### 设计建议

```move
// 🔴 不推荐：过早暴露 public 接口
public fun set_price(item: &mut Item, price: u64) { ... }

// 🟢 推荐：用 public(package) 保留灵活性，通过 entry 暴露
public(package) fun set_price_internal(item: &mut Item, price: u64) { ... }

entry fun set_price(item: &mut Item, price: u64) {
    set_price_internal(item, price);
}
```

`entry` 函数对外可调用但不会成为兼容性契约的一部分，升级时可以自由修改。

## CLI 操作

### 发布初始版本

```bash
cd my_package
sui client publish
```

发布成功后，记录输出中的关键信息：

```
╭──────────────────────────────────────────────────────╮
│ Published Objects                                     │
├──────────────────────────────────────────────────────┤
│ PackageID: 0x1a2b3c...   ← 记录这个                  │
╰──────────────────────────────────────────────────────╯

╭──────────────────────────────────────────────────────╮
│ Created Objects                                       │
├──────────────────────────────────────────────────────┤
│ ObjectID: 0x4d5e6f...                                │
│ ObjectType: 0x2::package::UpgradeCap   ← 记录这个    │
╰──────────────────────────────────────────────────────╯
```

### 执行升级

```bash
# 1. 修改代码
# 2. 构建（检查兼容性错误）
sui move build

# 3. 升级
sui client upgrade --upgrade-capability <UPGRADE_CAP_ID>
```

升级成功后会输出新的 Package ID。

## 小结

- 已发布的 Sui 包是不可变的，升级通过发布链接到原始包的新版本实现
- `UpgradeCap` 是升级的唯一凭证，必须安全保管
- 升级三步：授权 → 发布 → 提交（CLI 的 `sui client upgrade` 自动完成）
- 升级遵循严格的兼容性规则：`public` 函数和结构体是永久契约
- `init` 不会在升级时重新执行，需要单独的迁移函数
- 使用 `public(package)` 和 `entry` 代替 `public` 可以保留更多升级灵活性
