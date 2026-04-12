# Owner Coin：拆分、合并与从对象到嵌入

## 本节要回答的问题

- 为什么同一地址下会有 **多枚 `Coin<T>`**，与「账户模型一条余额」有何不同？  
- **`split` / `join`** 与 **`sui::pay`** 提供的便捷方法各在什么场景胜出？  
- **`into_balance` / `from_balance`** 与 **`coin::take` / `put`** 如何分工？

**前置**：[§14.4](04-treasury.md)、[第十一章 §11.11](../11_programmability/11-balance-and-coin.md)。  
**后续**：[§14.6](06-shared-currency.md)。

---

## 原理：一枚 `Coin` 是一个对象

**`Coin<T>`** 有 **`UID`**，是 **独立拥有的资源**。同一地址可以并行持有 **多枚** **`Coin<T>`**，总余额是 **各对象 `value` 之和**（加上若使用了 **§14.7** 的地址资金，则还有另一套口径——后文强调）。

**为什么这样设计**：  
- **PTB 并行性与可组合性**：不同 `Coin` 可作为不同输入输出组合；  
- **找零自然**：`split` 产生新 `UID`，无需全局账户锁；  
- **与 Sui 对象模型一致**：转移的是 **对象引用**，不是隐式全局账本。

**精髓**：**Owner Coin = 「可点的、可数的硬币对象」**；若你只熟悉「账户一条余额」，需要把思维切换到 **对象列表 + 聚合**。

---

## `split` 与 `join`

```move
use sui::coin::{Self, Coin};

/// 从一枚 Coin 拆出指定最小单位额度，余数留在原对象上
public fun make_change<T>(c: &mut Coin<T>, amount: u64, ctx: &mut TxContext): Coin<T> {
    coin::split(c, amount, ctx)
}

/// 将 other 合并进 base，销毁 other 的 UID
public fun merge_into<T>(base: &mut Coin<T>, other: Coin<T>) {
    coin::join(base, other);
}
```

- **`divide_into_n`**：均分成多枚新 `Coin`，余数留在原对象（适合均分奖励）。  
- **`split_vec` / `join_vec`**：按向量额度批量拆分/合并，**PTB 多输出** 时常用。

---

## `sui::pay`：方法语法糖

`coin.move` 通过 **`public use fun`** 将 **`pay`** 模块中的函数挂到 **`Coin`** 上，例如 **`split_and_transfer`**、**`divide_and_keep`** 等（以当前 `pay.move` 为准）。

链下组装交易时，**SUI Gas 币** 与 **其他 `Coin`** 的找零、拆分经常与这些 API 一起出现；**读 SDK/PTB 文档时**，看到「在 `Coin` 上调用 `split_and_transfer`」即来源于此。

---

## `Balance` 与 `Coin` 互转

| 操作 | 典型用途 |
|------|-----------|
| **`coin::into_balance`** | 把 **`Coin`** 消掉 **`UID`**，得到 **`Balance<T>`**，嵌入池子、金库、自定义结构体。 |
| **`coin::from_balance`** | 把 **`Balance<T>`** 包回 **`Coin`** 并 **`public_transfer`**。 |
| **`coin::take(&mut Balance, amount, ctx)`** | 从已有 **`Balance`** 扣款并 **新建** **`Coin`**。 |
| **`coin::put(&mut Balance, Coin)`** | 把 **`Coin`** 并入 **`Balance`**。 |

**金库示例**（模式与 §14.13 一致）：

```move
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};

public struct Vault<phantom T> has key {
    id: UID,
    inner: Balance<T>,
}

public fun deposit<T>(v: &mut Vault<T>, c: Coin<T>) {
    balance::join(&mut v.inner, coin::into_balance(c));
}

public fun withdraw<T>(v: &mut Vault<T>, amount: u64, ctx: &mut TxContext): Coin<T> {
    coin::take(&mut v.inner, amount, ctx)
}
```

---

## 常见误区

1. **以为 `join` 会留下两枚 `Coin`**：`join` 会 **销毁** 被合并进来的那枚的 **`UID`**，只增加目标对象的余额。  
2. **在自定义模块外随意 `into_balance`**：得到 **`Balance`** 后必须 **立即** 放入某处有 **`store`** 的容器或 **`Coin`**，否则违反资源安全。  
3. **忽略多 `Coin` 与 Gas**：小额 `Coin` 过多会增加 PTB 选择输入的复杂度；钱包通常会 **自动合并**（merge）以优化。

---

## 小结

**用户侧开放环路操作 = 对 `Coin` 对象做拆分/合并/转移，或在合约内转为 `Balance` 记账**。下一节说明：**全链共享的 `Currency` 登记** 与 **个人持有的 `Coin`** 不是同一层概念。
