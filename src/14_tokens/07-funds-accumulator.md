# 地址余额与资金流：send_funds、Withdrawal 与 Accumulator

## 导读

**`balance::send_funds`** 把 **`Balance<T>`** 写入 **按地址聚合的 accumulator**；**`coin::send_funds`** 是对 **`Coin<T>`** 的便捷封装：**先 `into_balance` 再 `send_funds`**。**`coin::redeem_funds`** 则把 **`Withdrawal<Balance<T>>`** 赎回为 **`Coin<T>`**（内部 **`balance::redeem_funds` + `into_coin`**）。协议层还有 **`AccumulatorRoot`**、**`settled_funds_value`** 等只读路径——详见 [§14.11](11-accumulator-protocol.md)。

- **前置**：[§14.5](05-owner-coin.md)  
- **深入**：[§14.11 · Accumulator 协议](11-accumulator-protocol.md)  

---

## send_funds：把价值记入「地址资金」

```move
use sui::coin::{Self, Coin};

public fun pool_tip(c: Coin<SUI>, recipient: address) {
    coin::send_funds(c, recipient);
}
```

语义：**销毁传入的 `Coin`**，将其余额并入 **recipient 地址** 在 accumulator 中的 **`Balance<T>`** 聚合（与 **对象级 `Coin` 列表** 是两套视图，产品展示需统一口径）。

## redeem_funds：凭 Withdrawal 取回 Coin

```move
use sui::coin::{Self, Coin};
use sui::funds_accumulator;

public fun claim(
    withdrawal: funds_accumulator::Withdrawal<sui::balance::Balance<SILVER>>,
    ctx: &mut TxContext,
): Coin<SILVER> {
    coin::redeem_funds(withdrawal, ctx)
}
```

**`Withdrawal`** 可在 **PTB** 中 **`split` / `join`**，用于拆分赎回额度或合并多笔（见 `funds_accumulator.move`）。

## 与 Owner Coin 的选择

| 场景 | 更自然的方式 |
|------|----------------|
| 用户钱包收款、通用转账 | **`Coin` + `public_transfer`** |
| 需要 **协议级地址资金**、与 **`settled_funds_value`** 对齐的结算 | **`send_funds` / redeem**（先读清当前版本文档） |

## 小结

把 **`Coin`** 想成 **可转移对象**；**`send_funds`** 把价值 **折叠进地址维度的聚合余额**。下一节 **合规：DenyList**。
