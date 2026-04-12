# Accumulator 与地址级资金：实现视角

## 导读

**`send_funds`** 把 **`Balance<T>`**（或经 **`coin::send_funds`** 把 **`Coin<T>`** 拆成余额后）记入 **按地址聚合的 accumulator**，用于 **共识层可见的「地址资金」视图**；**`redeem_funds`** 则凭 **`Withdrawal<Balance<T>>`** 取回 **`Balance`** 再包成 **`Coin`**。**`sui::accumulator::AccumulatorRoot`** 与 **`funds_accumulator`** 协同工作；应用还可读取 **`settled_funds_value`** 做只读查询。

- **前置**：[§14.7](07-funds-accumulator.md)  
- **后续**：[§14.13 · 金库模式](13-balance-vault-patterns.md)  

---

## 数据流（与 Framework 对齐）

```text
Coin<T> --coin::into_balance--> Balance<T> --balance::send_funds(addr)--> 地址 addr 的 accumulator
Withdrawal<Balance<T>> --balance::redeem_funds--> Balance<T> --into_coin--> Coin<T>
```

**`coin::send_funds`** 实现为：

```move
public fun send_funds<T>(coin: Coin<T>, recipient: address) {
    balance::send_funds(coin.into_balance(), recipient);
}
```

**`coin::redeem_funds`** 把 **`Withdrawal<Balance<T>>`** 赎回为 **`Coin<T>`**（内部 **`balance::redeem_funds` + `into_coin`**）。

## Withdrawal：拆分与合并

**`sui::funds_accumulator::Withdrawal<T>`** 支持 **`split` / `join`**（`public use fun`），便于在 **PTB** 里把大额赎回拆成多步或合并多笔 **`Withdrawal`**（需 **同一 owner**）。

## 只读：settled_funds_value

**`balance::settled_funds_value<T>(root, address)`** 读取 **当前共识 commit 开始时** 某地址上 **`Balance<T>`** 的聚合值（实现依赖 **`AccumulatorRoot`** 的 **u128** 存储，防止累加溢出）。适合 **索引器、仪表盘** 与 **链上模块** 的只读定价/风控——注意与 **对象级 `Coin` 余额** 的展示可能不一致，需产品层说明。

## 与 Owner Coin 的边界

| 机制 | 用户感知 |
|------|-----------|
| 钱包里的 **`Coin` 对象** | Explorer 上按 **对象** 展示 |
| **`send_funds` 聚合余额** | 通过 **`settled_funds_value`** 与赎回路径体现 |

## 小结

把 **Accumulator** 理解成 **地址维度的资金账本**；**`Coin`** 仍是 **可点对象**。开发钱包或结算系统时，明确产品展示的是 **对象余额**、**聚合余额** 还是二者之和。下一节 **游戏/双币综合**；再下一节 **金库内 `Balance` 模式**。
