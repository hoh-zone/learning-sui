# TreasuryCap 与供应：谁有权「印钞」与「销账」

## 本节要回答的问题

- **`mint` 时** 链上多了什么、**`total_supply` 如何变**？  
- **`burn` 与 `Supply`**、**`Currency` 上的供应状态** 如何对齐？  
- **固定供应**、**仅销毁（burn-only）** 在 **`coin_registry`** 里如何表达？

**前置**：[§14.2](02-registry-otw.md)、[§14.3](03-coin-metadata.md)。  
**后续**：[§14.5 · Owner Coin](05-owner-coin.md)。

---

## 原理：`TreasuryCap<T>` 内含 `Supply<T>`

**`TreasuryCap<T>`** 是 **key + store** 能力对象，持有 **`Supply<T>`**。  
在 Sui 模型中，**非零的 `Balance<T>` 不能凭空出现**；流通中的 **`Coin`** 与 **`TreasuryCap` 尚未发出的部分** 共同由 **`Supply`** 记账。

**`coin::mint(cap, amount, ctx)`** 会：

1. 增加 **`Supply`** 中的已发行计数（总供应上界语义由 Framework 维护）；  
2. 新建一枚 **`Coin<T>`** 对象（带新 **`UID`**），其内 **`Balance<T>`** 为 `amount`。

**`coin::burn(cap, coin)`** 会销毁 **`Coin`**，并相应减少 **`Supply`**。

**精髓**：**`TreasuryCap` 是开放环路下增发/回收供应的正门**；丢了或泄露了 Cap，等价于把「印钞权」交给对方——生产环境必须用多签、分权或托管方案。

---

## 无限增发（典型：游戏奖励）

发行方长期根据规则 **`mint`**，把新 **`Coin`** 转给玩家地址：

```move
use sui::coin::{Self, TreasuryCap};
use sui::transfer;

public fun mint_reward<T>(
    cap: &mut TreasuryCap<T>,
    amount: u64,
    player: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(cap, amount, ctx);
    transfer::public_transfer(c, player);
}
```

**运营注意**：Cap 单点保管风险极高；应拆分 **冷/热权限** 或 **按赛季更换接收策略**。

---

## 查询总供应

对 **`&TreasuryCap<T>`** 使用 **`coin::total_supply`**（或当前版本等价 API）可读取与 **`Supply`** 一致的总量视图。  
在 **`Currency<T>`** 侧，若供应已登记为固定或 burn-only，还可用 **`coin_registry::total_supply`** 等只读接口（若该类型在 **`Currency`** 中暴露了聚合信息）——**以源码为准**。

---

## 固定供应（Fixed）

语义：**不再允许 `mint`**，总供应量锁死在当前 **`Supply`** 状态。

常见工程路径之一：在 **`init`** 中一次性 **`mint`** 全部计划量到指定地址，再调用 **`coin_registry`** 提供的 **`make_supply_fixed_init`**（在 **`finalize` 前** 对 **`CurrencyInitializer`**）或 **`make_supply_fixed`**（对已有 **`Currency`**），把 **`Supply`** 以 **`SupplyState::Fixed`** 等形式写入 **`Currency`**。

**注意**：`make_supply_fixed_init` 等函数通常要求 **当前 `TreasuryCap` 上已有非零供应**（否则无法证明「已创世」），详见模块内 **`EEmptySupply`** 等错误说明。

---

## 仅销毁（Burn-only）

语义：**禁止再 `mint`**，但允许 **`burn`** 减少流通。

对应 **`make_supply_burn_only_init`** / **`make_supply_burn_only`** 路径，**`Currency`** 中记录为 **`BurnOnly(Supply)`** 一类状态。

---

## 常见误区

1. **以为销毁用户手里的币不需要 `TreasuryCap`**：开放环路下 **`coin::burn`** 需要 **`&mut TreasuryCap`** 参与供应回滚；若业务是「用户把币打进合约再销」，需在合约里设计 **`burn` 调用路径**。  
2. **混淆「地址上 Coin 之和」与「total_supply」**：前者若含未计入的对象或跨对象，应用层应对齐索引；**`total_supply`** 是 **供应账本** 的权威值。  
3. **在固定供应后仍保留热钱包里的 `TreasuryCap`**：即使不能 `mint`，Cap 对象仍可能被用于 **`burn`** 等；是否销毁或冻结 Cap 属于治理与审计范围。

---

## 小结

**`TreasuryCap` 连接「账本上的总供应」与「链上实际 `Coin` 的创建/销毁」**；**`Currency` 的 `SupplyState` 表达「还能不能继续印」**。下一节转向用户侧：**多枚 `Coin` 对象、拆分合并与 `pay`**。
