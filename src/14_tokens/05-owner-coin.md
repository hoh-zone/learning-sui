# Owner Coin：持有、拆分、合并与 pay

## 导读

**Owner Coin** 指地址 **`拥有`** 的 **`Coin<T>` 对象**（`key + store`）：可 **`public_transfer`**，可在 **`&mut Coin`** 上 **`split` / `join`**。Framework 还通过 **`sui::pay`** 为 `Coin` 提供了 **`split_vec`、`join_vec`、`split_and_transfer`、`divide_and_keep`** 等方法语法（见 `coin.move` 的 `public use fun`）。

- **前置**：[§14.4](04-treasury.md)  
- **后续**：[§14.7](07-funds-accumulator.md)  

---

## split 与 join

```move
use sui::coin::{Self, Coin};

/// 从一枚大币拆出一枚小币（找零）
public fun make_change(c: &mut Coin<SILVER>, amount: u64, ctx: &mut TxContext): Coin<SILVER> {
    coin::split(c, amount, ctx)
}

/// 把两枚合并为一枚（销毁其中一枚的 UID）
public fun merge_into(base: &mut Coin<SILVER>, other: Coin<SILVER>) {
    coin::join(base, other);
}
```

## 批量拆分与 divide

- **`divide_into_n`**：均分多份（余数留在原币）。  
- **`split_vec` / `join_vec`**：按向量额度拆分/合并，适合 **PTB 里多输出**。

## split_and_transfer（常用）

```move
// 方法语法（由 pay 模块提供）：
// coin.split_and_transfer(amount, recipient, ctx);
```

链下组装交易时，常与 **Gas 币 SUI** 的找零一起出现。

## Balance 与 Coin 互转

- **`coin::into_balance`**：拆掉 `Coin` 包装，得到 **`Balance<T>`** 嵌入自定义对象。  
- **`coin::from_balance`**：把 **`Balance<T>`** 再包成 **`Coin<T>`** 转走。

```move
public fun tuck_into_vault(vault: &mut MyVault, c: Coin<SILVER>) {
    let b = coin::into_balance(c);
    balance::join(&mut vault.inner, b);
}
```

## 小结

**Owner Coin** 模型就是「**一枚对象 = 一笔余额**」；需要 **嵌入结构体** 时用 **Balance**。下一节区分 **共享的注册表** 与 **自有 Coin**。
