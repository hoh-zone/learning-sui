# 受监管与 DenyList：DenyCapV2 与地址限制

## 导读

**受监管代币（regulated coin）** 在 **`Currency<T>`** 上标记为 **`Regulated`**，并持有 **`DenyCapV2<T>`**。链上 **`sui::deny_list::DenyList`** 共享对象按 **类型 + 地址** 记录黑名单；验证器在用户把 **`Coin<T>`** 作为**输入**参与交易时检查——被禁地址无法**花费**该币（具体语义以当前节点与 Framework 为准）。

- **前置**：[§14.2 · 注册与 OTW](02-registry-otw.md)（`make_regulated` 在 **`finalize` 之前**调用）  
- **后续**：[§14.9 · Token 入门](09-token-intro.md)  

---

## 在创世流程中打开「受监管」

在 **`coin_registry::finalize`** 之前，对 **`CurrencyInitializer<T>`** 调用 **`make_regulated`**（**不可逆**），得到 **`DenyCapV2<T>`**：

```move
use sui::coin_registry;

// 在 init 内，在 finalize 之前：
// let deny_cap = coin_registry::make_regulated(&mut initializer, /* allow_global_pause */ false, ctx);
// ... 再 finalize，并 transfer deny_cap 给管理员
```

`make_regulated` 内部会 **`coin::new_deny_cap_v2`**，并把 **`Currency`** 的 regulated 状态设为带 **`DenyCap`** 的版本。详见 `coin_registry.move` 注释。

## DenyList 与 v2 API（概念）

**`DenyList`** 是全局共享对象；对某一 **`Coin` 类型 `T`** 的增删通过 **`coin::deny_list_v2_add` / `deny_list_v2_remove`**（需 **`&mut DenyList`** 与 **`&mut DenyCapV2<T>`**）。常见模式：

1. 合规运营方持有 **`DenyCapV2`**（或多签托管）。  
2. 需要封禁地址时发起交易，写入 **下一 epoch** 起生效的配置（`deny_list` 模块使用 **Config** 做 **按 epoch 迁移**）。  
3. 使用 **`deny_list_v2_contains_current_epoch`** 在链下或视图层查询当前 epoch 是否仍被封禁。

> **注意**：保留地址、系统地址等 **不可写入** 黑名单（见 `deny_list.move` 中 **`RESERVED`** 常量）。

## 与开放环路 Coin 的配合

受监管分支仍使用 **`Coin<T>`**（`key + store`），钱包与 DEX 集成路径不变；差异在于 **输入对象层面的拒绝**，而不是把币改成另一种类型。

## 小结

**合规 = `Currency` 状态 + `DenyCapV2` + 全局 `DenyList` 条目**。初始化时一次选定是否受监管；运营期通过 Cap 维护名单。下一节进入 **闭环：`Token<T>`**。
