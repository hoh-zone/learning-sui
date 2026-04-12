# 嵌入式 Balance：金库、池子与 Coin 互转

## 导读

**`Balance<T>`** 无 `key`，**不能**单独作为拥有型对象转移；典型用法是放在 **自定义结构体** 里管理 **奖池、质押池、库存**。与 **`Coin<T>`** 的转换靠 **`coin::into_balance` / `from_balance`**（或 **`balance::take` / `put`** 在已有 `Balance` 上操作）。

- **前置**：[§14.5](05-owner-coin.md)、[§11.11 · Balance 与 Coin](../11_programmability/11-balance-and-coin.md)  

---

## 奖池：存入与提取

```move
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};

public struct PrizePool<phantom T> has key {
    id: UID,
    pool: Balance<T>,
}

public fun deposit(pool: &mut PrizePool<SILVER>, coin: Coin<SILVER>) {
    balance::join(&mut pool.pool, coin::into_balance(coin));
}

public fun withdraw(pool: &mut PrizePool<SILVER>, amount: u64, ctx: &mut TxContext): Coin<SILVER> {
    coin::take(&mut pool.pool, amount, ctx)
}
```

## 与 `send_funds` 的区分

- **对象内 `Balance`**：读写完全由 **你的模块** 控制。  
- **`balance::send_funds`**：把余额送入 **协议级地址 accumulator**，语义与 **Explorer 展示** 相关，**不要**与「普通金库字段」混用，除非产品明确需要。

## 小结

**嵌入式 Balance** 是 DeFi、游戏金库、NFT 市场的默认记账方式；**开放环路** 末端再 **`take` 成 `Coin`** 给用户钱包。下一节是 **运维与版本** 提示。
