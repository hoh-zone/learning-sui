# 受监管代币与 DenyList：在输入侧拦截

## 本节要回答的问题

- **「受监管」** 在 **`Currency`** 与 **`coin`** 两层如何体现？  
- **DenyList** 限制的是 **转账** 还是 **把 `Coin` 当输入**？  
- **`deny_list_v2_add`** 与 **epoch** 对运营 UI 意味着什么？

**前置**：[§15.2](02-registry-otw.md)（**`make_regulated` 须在 `finalize` 前**）。  
**后续**：[§15.9 · Token](09-token-intro.md)。

---

## 原理：仍用 `Coin<T>`，但在验证层加闸

**受监管路径**下，币种仍是 **`Coin<T>`**（`key + store`），钱包与 DeFi 的 **对象模型不变**。  
额外引入：

1. **`Currency<T>`** 上的 **`Regulated`** 状态与 **`DenyCap` 相关 ID**；  
2. 全局 **`DenyList`** 共享对象中的 **按类型、按地址** 的配置；  
3. **`DenyCapV2<T>`** —— 只有持有者能向 **`DenyList`** **写入** 对该类型 **`T`** 的封禁/解封意图。

**精髓**：合规往往在 **「某地址是否能把该 `Coin` 作为交易输入使用」** 这一层生效（具体规则以节点与 Framework 版本为准），而不是简单禁止 **链上对象存在**。

---

## 创世：`make_regulated`

在 **`coin_registry::finalize` 之前**：

```move
// 示意：在 init 中，于 finalize 之前
// let deny_cap = coin_registry::make_regulated(&mut initializer, allow_global_pause, ctx);
// let metadata_cap = coin_registry::finalize(initializer, ctx);
// transfer::public_transfer(deny_cap, admin);
```

**不可逆**：一旦标记为受监管，**不能**再「改回完全无监管」的同一路径；迁移需查 **`migrate_regulated_state_*`** 等官方迁移 API。

---

## 运维：`coin::deny_list_v2_add` / `remove`

典型调用需要：

- **`&mut DenyList`**（全局共享对象引用）；  
- **`&mut DenyCapV2<T>`**；  
- 目标 **`address`**。

**epoch 语义**：`deny_list` 模块使用 **按 epoch 生效的配置**（**`next_epoch`** 路径）。运营系统应展示 **「已提交 / 尚未在当前 epoch 生效」**，避免用户误以为 **即时封禁或即时解封**。

**保留地址**：部分 **系统保留地址** **不可** 写入黑名单（见 **`deny_list.move`** 中 **`RESERVED`** 向量）。

---

## 与 Token 闭环的关系

**`Coin` + DenyList** 解决的是 **开放环路下的合规输入控制**；  
若需要 **每笔转移都经策略**（积分、许可消费），应评估 **`Token` + `TokenPolicy`**（§15.9–14.10）。二者可并存于不同产品阶段。

---

## 常见误区

1. **以为 DenyList 会「没收余额」**：它解决的是 **使用/输入限制** 语义，不是自动销毁对象。  
2. **在 `finalize` 之后再 `make_regulated`**：规范路径要求 **在 `finalize` 前** 调用（见 **`coin_registry`** 签名）。  
3. **忽略多签与职责分离**：**`DenyCapV2`** 应等同于 **高敏运营密钥**。

---

## 小结

**受监管 = `Currency` 状态 + `DenyCapV2` + 全局 `DenyList` 配置**；**开放环路的组合性仍在，但输入侧多了一道合规闸**。下一节进入 **闭环 `Token`**。
