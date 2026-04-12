# TreasuryCap：铸造、销毁与供应策略

## 导读

**`TreasuryCap<T>`** 内含 **`Supply<T>`**，是开放环路 **`Coin<T>`** 铸/销的唯一正规入口（在保留 Cap 的前提下）。本节讲 **无限铸**、**固定上限**、**仅销毁** 等常见策略。与 [§14.5](05-owner-coin.md) 的「用户手中 Coin」形成上下游关系。

- **前置**：[§14.2](02-registry-otw.md)、[§14.3](03-coin-metadata.md)  
- **后续**：[§14.5](05-owner-coin.md)  

---

## 无限供应（游戏金币）

发行方长期 **`mint`** 奖励玩家，**`TreasuryCap`** 由多签或热钱包保管（生产环境务必拆分权限）。

```move
public fun mint_reward(
    cap: &mut TreasuryCap<GOLD>,
    amount: u64,
    player: address,
    ctx: &mut TxContext,
) {
    let c = sui::coin::mint(cap, amount, ctx);
    transfer::public_transfer(c, player);
}
```

## 固定供应：一次性铸完再锁

常见模式：`init` 内 **`mint`** 全部额度到金库地址，再把 **`TreasuryCap`**  **`transfer`** 到 **`AdminCap`** 锁仓对象，或调用 **`coin_registry`** 提供的 **冻结供应** API（如 `make_supply_fixed` 等，以当前版本为准）销毁后续铸币能力。

> 固定供应与 **对象级权限**、**升级策略** 强相关，上线前应用审计模板过一遍。

## 仅销毁（burn-only）

允许用户 **`coin::burn`** 回收流通量，但不再 **`mint`**——需配合 **`TreasuryCap`** 与 **`Supply`** 的受限形态（见 `coin_registry` 与 `Currency` 的状态迁移文档）。

## 查询总供应

```move
use sui::coin::TreasuryCap;

public fun circulating(cap: &TreasuryCap<T>): u64 {
    sui::coin::total_supply(cap)
}
```

## 小结

**TreasuryCap** 决定「还能不能印钞」；**用户钱包里的 Coin** 只是供应的子集。下一节讲 **Owner Coin 的拆分、合并与 `pay` 扩展**。
