# 嵌入式 Balance：池子、金库与与协议资金的边界

## 本节要回答的问题

- 为什么 **DeFi/游戏金库** 几乎总是 **`Balance` 字段 + 模块入口**，而不是 **`send_funds` 堆地址**？  
- **`coin::take` / `put`** 与 **`into_balance` / `from_balance`** 如何选？  
- **自定义聚合** 与 **全局 accumulator** 各适用于什么信任模型？

**前置**：[§14.5](05-owner-coin.md)、[§11.11](../11_programmability/11-balance-and-coin.md)。

---

## 原理：`Balance` 无 `UID`，适合「账内数」

**`Balance<T>`** 只有 **`store`**，**不能**单独作为拥有型对象出现在全局对象集里。放在 **`Pool`、`Vault`、`Escrow`** 里时：

- **读写路径完全由你的模块逻辑控制**；  
- **不占用** 用户地址下的 **`Coin` 对象列表**；  
- **与 `TreasuryCap` 的 mint/burn** 通过 **`Coin` 进出** 衔接。

**精髓**：**应用内记账 = 嵌入式 `Balance`**；**协议级地址资金 = §14.7/14.11**；二者 **不要默认互通**。

---

## 奖池：存入与提取

```move
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};

public struct PrizePool<phantom T> has key {
    id: UID,
    pool: Balance<T>,
}

public fun deposit<T>(p: &mut PrizePool<T>, c: Coin<T>) {
    balance::join(&mut p.pool, coin::into_balance(c));
}

public fun withdraw<T>(p: &mut PrizePool<T>, amount: u64, ctx: &mut TxContext): Coin<T> {
    coin::take(&mut p.pool, amount, ctx)
}
```

**初始化**：**`pool`** 通常为 **`balance::zero()`**；**充值** 只能来自 **`Coin`** 或 **`mint`**，不能凭空 **`join` 非零**。

---

## 选型：`take`/`put` vs `into_balance`/`from_balance`

- **`take` / `put`**：在 **已有 `Balance` 字段** 与 **`Coin`** 之间 **部分存取**，**UID 始终在 `Coin` 侧新建/销毁**。  
- **`into_balance` / `from_balance`**：**整枚 `Coin` ↔ 整块 `Balance`**，适合 **整单入账/出账**。

---

## 与 `send_funds` 的对比

| 机制 | 控制者 | 典型场景 |
|------|--------|-----------|
| **对象内 `Balance`** | **你的模块** | AMM、拍卖托管、游戏仓库 |
| **`balance::send_funds`** | **协议 accumulator 语义** | 需要与 **`settled_funds_value`** 等 **系统级读数** 对齐的结算 |

---

## 常见误区

1. **在公开函数里 `into_balance` 后忘记 `join`**：会导致 **资源泄漏** 或 **编译失败**（视上下文）。  
2. **把池子 `Balance` 当用户余额**：用户侧应 **`withdraw` 得 `Coin`** 后再展示为「可转资产」。  
3. **混用两种聚合不告知用户**：同一地址 **既有 `Coin` 又有 settled 资金** 时，**产品必须拆分说明**。

---

## 小结

**嵌入式 `Balance` 是应用层资产记账的默认答案**；**全局 accumulator 是协议层结算的补充工具**。下一节：**上线运维与版本误解**。
