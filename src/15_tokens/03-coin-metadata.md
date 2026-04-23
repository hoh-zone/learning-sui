# 元数据与 MetadataCap：链上「说明书」与谁有权改

## 本节要回答的问题

- **`Currency<T>`** 里哪些字段给人类读、哪些给协议读？  
- 钱包如何拿到 **decimals / symbol**，与 **`TreasuryCap`** 无关？  
- **`MetadataCap<T>`** 能做什么、不能做什么？

**前置**：[§15.2](02-registry-otw.md)。  
**后续**：[§15.4](04-treasury.md)。

---

## `Currency<T>` 存什么

在 `coin_registry` 模块中，**`Currency<T>`** 是 **key 对象**，由 **`CoinRegistry`** 统一索引，主要承载：

- **展示向**：`decimals`、`name`、`symbol`、`description`、`icon_url`。  
- **状态向**：**供应状态**（`SupplyState`，如是否已固定、是否仅销毁）、**监管状态**（`RegulatedState`）、**`TreasuryCap` / `MetadataCap` / Deny 相关 ID** 等。

**精髓**：**元数据回答「这是什么币」**；**`TreasuryCap` 回答「还能不能铸/怎么销」**。二者在治理上应可分离——运营改图标不应自动等于能增发。

---

## 精度 `decimals`：只影响人类换算

链上金额始终是 **`u64` 最小单位**（整数）。**`decimals`** 只告诉前端：

`展示数额 = 链上整数 ÷ (10 ^ decimals)`

**例**：`decimals = 9` 时，链上 `1_000_000_000` 最小单位通常展示为 **1.000000000** 个币。

常见取值：**9**（与 SUI 习惯一致）、**6**（法币锚定常见表述）、**0**（不可分割积分）。选错 `decimals` 会导致钱包与 DEX 显示数量差 **10 的幂**，属于**上线后极难向用户解释**的错误，应在测试网用真实 UI 验一遍。

---

## 只读访问：`coin_registry` 提供的 getter

对已有 **`&Currency<T>`** 引用时，Framework 提供与展示直接相关的只读函数（名称以当前版本为准），例如：

- **`coin_registry::decimals`**、**`name`**、**`symbol`**、**`description`**、**`icon_url`**  
- **`is_regulated`**、**`is_supply_fixed`**、**`is_supply_burn_only`**  
- **`treasury_cap_id`**、**`metadata_cap_id`**、**`deny_cap_id`**（若存在）

钱包、浏览器后端在解析到 **`Currency<T>`** 对象后，用上述函数即可渲染，**无需**持有 `TreasuryCap`。

---

## 更新元数据：必须持有 `MetadataCap<T>`

在 **`finalize`** 时若 **`MetadataCap`** 被认领，后续修改 **`name` / `description` / `icon_url`** 等需通过 **`coin_registry::set_name`**、**`set_description`**、**`set_icon_url`** 等函数，且传入 **`&MetadataCap<T>`** 作为授权。

**设计意图**：把「品牌与文案变更」权限交给 **`MetadataCap` 持有者**（可为多签或 DAO），与 **`TreasuryCap` 持有者**分离。

若 **`MetadataCap` 被删除**（若版本支持 **`delete_metadata_cap`** 路径），则部分展示字段可能变为**不可再改**——具体以源码与迁移说明为准。

---

## `RegulatedCoinMetadata` 与展示

受监管路径下，链上可能另有 **`RegulatedCoinMetadata<T>`** 等结构用于展示合规标签或迁移信息。与 [§15.8](08-regulated-denylist.md) 一并阅读。

---

## 常见误区

1. **以为 `symbol` 会约束链上类型**：类型由 **包地址 + 模块 + 结构名** 唯一确定；`symbol` 只是字符串。  
2. **把 `decimals` 当成乘数**：它是 **十进制小数位数**，不是「1 个币 = 多少最小单位」的魔法常数以外的第二个存储。  
3. **在链上逻辑里用 `symbol` 做分支**：应使用 **类型 `T`** 或 **TypeName**，不要用展示字符串。

---

## 小结

**`Currency` = 可查询的链上说明书 + 供应/监管状态摘要**；**`MetadataCap` = 修改说明书中「可编辑章节」的钥匙**。下一节讨论 **`TreasuryCap`** 与 **总供应** 的变动规律。
