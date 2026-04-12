# 第十四章 · 实战练习

以下练习按难度递进。建议先在 **测试网** 完成 **实战一～三**，再视需要完成进阶项。

---

## 实战一：发布 `silver_coin` 并铸币

1. 进入 `src/14_tokens/code/silver_coin/`，执行 `sui move build`。  
2. 将包发布到测试网，记录 **包 ID** 与 **`TreasuryCap<SILVER>` 对象 ID**。  
3. 调用包内 **`mint_to_sender`**（或等价 `entry`），向自己铸少量 **`SILVER`**。  
4. **验收**：在浏览器或 `sui client` 中能看到 **类型为 `SILVER` 的 `Coin` 对象**，且总额与铸币量一致。

**要点复述**：本路径对应 [§14.2](02-registry-otw.md) 的 **`new_currency_with_otw` + `finalize`**；**`TreasuryCap`** 是铸币唯一入口（在供应策略允许的前提下）。

---

## 实战二：对照 `Currency` 元数据

1. 在链上定位 **`Currency<SILVER>`**（或当前版本等价展示路径）。  
2. 读出 **`symbol`、`decimals`**，用手算验证：若最小单位整数为 \(N\)，展示是否满足 \(N / 10^{\text{decimals}}\)。  
3. **验收**：能向他人说明 **`MetadataCap` 与 `TreasuryCap` 的职责分离**（见 [§14.3](03-coin-metadata.md)）。

---

## 实战三：`Coin` 拆分与转账

1. 使自己地址下至少有一枚 **足够大的 `Coin<SILVER>`**（或两枚可合并的小额）。  
2. 用 PTB：**`splitCoins`** 拆出小额，再 **`transferObjects`** 到第二个测试地址。  
3. **验收**：发送方 **各 `Coin` 余额之和** 加上接收方增加量，等于操作前 **可追踪的总额**（**gas 另计**）。

---

## 实战四（进阶）：受监管初始化

1. **复制** `silver_coin` 为新包名，在 **`finalize` 之前** 调用 **`coin_registry::make_regulated`**（仅测试网资产）。  
2. 部署后使用 **`coin::deny_list_v2_add`** 对 **测试地址** 做一次封禁（需 **`DenyList` 与 `DenyCapV2`** 引用）。  
3. **验收**：写出 **「提交封禁」与「当前 epoch 是否已生效」** 的差异说明（见 [§14.8](08-regulated-denylist.md)）。

---

## 实战五（进阶）：阅读 `token` 源码

1. 打开依赖中的 **`sui::token`**，梳理 **`new_policy` → `share_policy` → `from_coin` → `confirm_request`** 的调用链。  
2. 记录 **`allow` 与 `add_rule_for_action`** 在策略上的区别。  
3. **验收**：能解释 **`ActionRequest.approvals`** 与 **`TokenPolicy.rules`** 的匹配关系（见 [§14.10](10-token-policy.md)）。

---

## 实战六（进阶）：嵌入式金库

1. 仿 [§14.13](13-balance-vault-patterns.md)，实现 **`deposit` / `withdraw`**，并补 **`sui move test`** 或用 **测试场景** 验证 **余额守恒**。  
2. **验收**：能说明 **为何池内 `Balance` 不会单独出现在钱包对象列表中**。

---

## 阅读建议

完成上述练习后，建议用 **本书 §14.1 的四层模型图** 在白纸上 **默画一遍**，并能 **各举一例** 对应到 **`coin_registry` / `coin` / `balance` / `token`** 模块中的类型与函数。若能做到，说明本章主干已建立，可转入 **全栈或 NFT** 章节做串联。
