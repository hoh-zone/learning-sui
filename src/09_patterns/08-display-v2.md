# Object Display V2 与 Display Registry

Display V2 是 Sui 基于 **Display Registry**（系统对象 `0xd`）的新一代对象展示机制，用于解决 V1 依赖事件索引、难以维护以及仅支持 `key` 类型等问题。本节将介绍 V2 的设计动机、与 V1 的对比、核心 API 及迁移方式。

参考：[MystenLabs/sui#23710](https://github.com/MystenLabs/sui/pull/23710)（Display Registry 框架）、[MystenLabs/sui#25753](https://github.com/MystenLabs/sui/pull/25753)（Display V2 文档）。**若 PR 已合并**，请以当前 `main` 分支上的 `sui::display_registry` 与[官方文档](https://docs.sui.io/)为准，PR 链接仅作设计背景。

---

## 为什么需要 Display V2

### V1 的局限

| 问题 | 说明 |
|------|------|
| **索引依赖事件** | V1 通过 `DisplayCreated<T>` 等事件发现 Display，索引器必须正确消费事件并维护状态，难以保证一致性与可恢复性。 |
| **每类型多个 Display** | 同一类型 `T` 可以有多个 `Display<T>` 对象，链下需要决定「用哪一个」，缺乏唯一规范。 |
| **仅支持 `T: key`** | `Display<T>` 要求 `T: key`，无法为「非顶层对象」（如动态字段中的值）定义展示。 |
| **无固定查询点** | 没有像 CoinRegistry 那样「按类型推导地址」的固定查询点，不利于前端与索引器稳定拉取。 |

### V2 的目标

1. **固定查询点**：Display 信息挂在 **DisplayRegistry**（`0xd`）下，通过 **派生地址（derived object）** 或注册表 API 查询，依赖**活对象集**而非事件，索引更简单、可靠。
2. **每类型一个 Display**：每种类型在 registry 下对应**一个** Display 槽位，避免「N 个 Display 选谁」的问题。
3. **支持非 `key` 类型**：V2 不要求 `T: key`，可为更多类型（含非顶层对象）配置展示。
4. **可迁移、可废弃 V1**：提供从 `Display<T>`（V1）和 `Publisher` 迁移到 V2 的路径，以及 V1 的最终废弃与删除。

---

## V1 与 V2 对比

| 维度 | **V1（display.move）** | **V2（display_registry）** |
|------|------------------------|----------------------------|
| **每类型 Display 数量** | 可有 **N 个** `Display<T>` | **1 个**  per type（由 registry + 类型键派生） |
| **发现方式** | **事件**（如 `DisplayCreated<T>`），索引器监听事件 | **派生地址 / 注册表**，固定查找点，基于活对象 |
| **类型约束** | `T: key`（仅顶层对象） | **不要求 `T: key`**，可支持非顶层对象 |
| **存储位置** | 独立 `Display<T>` 对象，由用户/合约持有 | 挂在 **DisplayRegistry**（`0xd`）下，确定性地址 |
| **创建权限** | 需 **Publisher**，创建后对象可转移 | 需 **Publisher** 或内部 **Permit**，创建后可选 **share** |
| **更新权限** | 持有 `Display<T>` 的人 | 持有 **DisplayCap** 的人（claim 自 Publisher 或迁移） |
| **索引与前端** | 依赖事件回溯，易出现漏/重 | 按类型推导或查 registry，行为确定 |

简要结论：V2 用「**一个 registry + 每类型一个 Display + 派生地址**」替代「多个 Display + 事件」，使展示数据可预测、可稳定查询，并为非 `key` 类型和未来扩展（如 init 参数）留出空间。

---

## Display Registry 与系统对象 `0xd`

- **DisplayRegistry** 是 Sui 的**系统级共享对象**，在协议升级时由系统在 epoch 边界创建，地址为 **`0xd`**（与 CoinRegistry `0xc` 类似）。
- 所有 V2 的 Display 都「挂在」该 Registry 下：通过 **derived_object** 分配**确定性派生地址**，在该地址创建 **Display** 对象。当前实现可能为全局单一槽位；后续版本可能按类型 `T` 扩展为「每类型一个」Display，与文档中的「1 per type」一致。
- 链下和前端可以基于 DisplayRegistry 与派生规则（或索引器 API）查询 Display，无需依赖事件。

---

## 核心类型与 API（display_registry）

以下 API 基于 [PR #23710](https://github.com/MystenLabs/sui/pull/23710) 中的 `sui::display_registry` 模块，实际发布时可能有小幅命名或签名调整。

### 类型概览

| 类型 | 说明 |
|------|------|
| **DisplayRegistry** | 系统对象，根命名空间，地址 `0xd`。 |
| **Display** | 实际存储展示字段的对象，含 `fields: VecMap<String, String>`，可选 `cap_id`。 |
| **DisplayCap** | 能力对象：持有者可更新/清空该 Display（set / unset / clear）。 |
| **SystemMigrationCap** | 系统迁移用能力，用于批量把 V1 Display 迁入 V2，用后销毁。 |

### 创建 Display（V2）

**方式一：用 Publisher 创建（推荐）**

```move
use sui::display_registry;
use sui::package::Publisher;

/// 为当前包下的类型在 DisplayRegistry 中创建 V2 Display，并拿到 DisplayCap
public fun create_display_v2(
    registry: &mut DisplayRegistry,
    publisher: &mut Publisher,
    ctx: &mut TxContext,
): (Display, DisplayCap) {
    display_registry::new_with_publisher(registry, publisher, ctx)
}
```

- 要求 `publisher.from_package<T>()` 对要展示的类型 `T` 成立（即该 Publisher 来自定义 `T` 的包）。
- 返回的 **Display** 需要由调用方 **share** 或转移；**DisplayCap** 由调用方持有，用于后续更新。

**方式二：分享 Display**

创建后若希望所有人可读、仅 Cap 持有者可写，可共享 Display：

```move
let (display, cap) = display_registry::new_with_publisher(registry, publisher, ctx);
display_registry::share(display);
// 将 cap 转给需要更新权限的地址
transfer::public_transfer(cap, ctx.sender());
```

### 更新 Display（set / unset / clear）

只有持有 **DisplayCap** 的地址可以修改对应 Display 的字段：

```move
// 设置或覆盖字段
display_registry::set(display, &cap, std::string::utf8(b"name"), std::string::utf8(b"{name}"));
display_registry::set(display, &cap, std::string::utf8(b"image_url"), std::string::utf8(b"https://cdn.example.com/{id}.png"));

// 删除字段
display_registry::unset(display, &cap, std::string::utf8(b"thumbnail_url"));

// 清空所有字段后重新设置
display_registry::clear(display, &cap);
```

模板语法与 V1 一致：使用 `{field_name}` 引用对象字段，在链下渲染时替换。

### 读取 Display

```move
// 只读访问字段表
let fields = display_registry::fields(display);
// 或查询 cap 是否已被 claim
let cap_opt = display_registry::cap_id(display);
```

链下可通过「DisplayRegistry + 类型派生地址」或 RPC/索引器按类型查询到唯一 Display 对象，再读其 `fields`。

---

## 从 V1 迁移到 V2

### 迁移路径一：已有 `Display<T>`（V1）→ 同内容 V2

若链上已存在 V1 的 `Display<T>`，可在 V2 启用后，用其内容在 Registry 中创建 V2 Display，并销毁 V1 对象：

```move
use sui::display_registry;
use sui::display::Display as LegacyDisplay;

/// 将 V1 Display<T> 迁移为 V2，并销毁 V1 对象
public fun migrate_v1_to_v2<T: key>(
    registry: &mut DisplayRegistry,
    legacy: LegacyDisplay<T>,
    ctx: &mut TxContext,
): (Display, DisplayCap) {
    display_registry::migrate_v1_to_v2(registry, legacy, ctx)
}
```

迁移后，V2 的 Display 拥有与 V1 相同的字段内容，Cap 返回给调用方；V1 对象被销毁，不再存在。

### 迁移路径二：先创建空 V2，再 claim Cap（用 V1 或 Publisher）

若希望「先占住」V2 槽位，再通过「交还 V1」或「用 Publisher 证明」来领取 **DisplayCap**：

- **用 V1 领取 Cap**：调用 `display_registry::claim(display, legacy_display, ctx)`，会销毁 V1 并得到 **DisplayCap**；之后可调用 `delete_legacy` 删除其它 V1 副本（若框架支持）。
- **用 Publisher 领取 Cap**：调用 `display_registry::claim_with_publisher(display, publisher, ctx)`，不销毁任何对象，仅证明包所有权并领取 **DisplayCap**。

### 删除 V1 Display（在 Cap 已 claim 之后）

在 V2 的 Display 已存在且其 **DisplayCap** 已被 claim 的前提下，允许删除对应的 V1 对象，避免链上同时存在两套展示数据：

```move
display_registry::delete_legacy(display, legacy_display);
```

---

## 系统迁移（批量 V1 → V2）

协议升级时会创建 **DisplayRegistry** 和 **SystemMigrationCap**。拥有 **SystemMigrationCap** 的地址（如多签系统地址）可调用 **system_migration**，用预置的 keys/values 在 Registry 下创建 Display（通常用于批量导入历史 V1 数据）。迁移脚本只需执行一次；之后各类型可再通过 **migrate_v1_to_v2** 或 **new_with_publisher** 做细粒度创建/更新。**SystemMigrationCap** 在全局迁移完成后可通过 **destroy_system_migration_cap** 销毁。

---

## 标准字段与模板语法（与 V1 一致）

V2 的 Display 仍使用与 V1 相同的**标准字段名**和**模板语法**，便于现有前端与钱包复用：

| 字段 | 用途 |
|------|------|
| `name` | 对象名称 |
| `description` | 描述 |
| `image_url` | 主图 URL |
| `link` | 详情页链接 |
| `project_url` | 项目主页 |
| `creator` | 创建者 |
| `thumbnail_url` | 缩略图 URL |

模板中使用 `{field_name}` 引用对象字段，例如 `"{name}"`、`"https://example.com/{id}.png"`。

---

## 小结

- **Display V2** 基于 **DisplayRegistry**（`0xd`），通过 **derived object** 实现「每类型一个 Display」和**固定查询点**，不再依赖事件索引。
- **V1 vs V2**：V1 允许多个 Display、依赖事件、仅 `T: key`；V2 为每类型一个、按 registry 派生地址查询、不要求 `T: key`。
- 创建使用 **new_with_publisher(registry, publisher, ctx)**，更新使用 **DisplayCap** 配合 **set / unset / clear**；Display 可 **share** 供只读。
- 迁移：**migrate_v1_to_v2** 将 V1 内容迁入 V2 并销毁 V1；**claim** / **claim_with_publisher** 用于在已有 V2 Display 上领取 **DisplayCap**；**delete_legacy** 用于在 Cap 已 claim 后删除 V1 对象。
- 标准字段与模板语法与 V1 一致，便于生态兼容；后续 V1 的 `display.move` 将在独立 PR 中标记废弃并最终移除。
