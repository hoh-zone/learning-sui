# 地址资金：`send_funds`、赎回与两套「余额口径」

## 本节要回答的问题

- **`public_transfer(Coin)`** 与 **`coin::send_funds`** 有什么本质区别？  
- **`Withdrawal<Balance<T>>`** 是什么，为何需要 **`split` / `join`**？  
- 产品展示的「余额」应如何声明：**仅 `Coin` 对象**、**仅地址 accumulator**，还是 **两者之和**？

**前置**：[§15.5](05-owner-coin.md)。  
**后续**：[§15.11 · Accumulator 细节](11-accumulator-protocol.md)。

---

## 原理：对象余额 vs 协议层地址聚合

**常规转账**：**`transfer::public_transfer(coin, recipient)`** —— **owner 变为 recipient**，**`Coin` 对象 ID 仍存在**，Explorer 在对方地址下列出该对象。

**`send_funds`**：**`coin::send_funds(coin, recipient)`** 在实现上等价于 **`coin.into_balance()`** 后调用 **`balance::send_funds(balance, recipient)`**。  
传入的 **`Coin` 被消费**，其价值记入 **与 `recipient` 地址关联的协议层资金聚合**（由 **`funds_accumulator` / `accumulator`** 协同实现，细节见 §15.11）。

**精髓**：前者是 **「整币易手」**；后者是 **「把币拆掉，记入地址维度的另一本账」**。若产品只统计 **`Coin` 对象列表**，会 **看不到** 后者对应的数值——这是 **口径事故** 的高发区。

---

## 代码路径（与 Framework 一致）

```move
use sui::coin::{Self, Coin};

public fun tip_to_address_funds<T>(c: Coin<T>, recipient: address) {
    coin::send_funds(c, recipient);
}
```

**赎回**：凭 **`funds_accumulator::Withdrawal<Balance<T>>`**（在 **`Balance` 模块中特化为 `Withdrawal<sui::balance::Balance<T>>`** 这一层包装，以你使用的别名与版本为准），调用 **`coin::redeem_funds(withdrawal, ctx)`** 得到 **`Coin<T>`**。

```move
use sui::coin::{Self, Coin};
use sui::funds_accumulator;

public fun claim_to_coin(
    w: funds_accumulator::Withdrawal<sui::balance::Balance<SILVER>>,
    ctx: &mut TxContext,
): Coin<SILVER> {
    coin::redeem_funds(w, ctx)
}
```

**`Withdrawal`** 支持 **`split` / `join`**：大额赎回可拆成多笔 **`Withdrawal`** 在同一 PTB 或跨调用组合（**同一 owner** 约束见模块内 **`EOwnerMismatch`**）。

---

## 何时用哪种机制

| 场景 | 建议 |
|------|------|
| 用户间点对点转账、DEX、NFT 标价支付 | **`Coin` + `public_transfer`**（或钱包/SDK 封装） |
| 协议要把价值 **折叠进地址结算层**、与 **`settled_funds_value`** 等读数对齐 | **`send_funds` / redeem** 路径 |
| 应用内金库、AMM 池 | **自定义对象里的 `Balance`**（§15.13），**通常不走** 全局地址 accumulator |

---

## 常见误区

1. **把 `send_funds` 当成「隐形转账」**：对象侧 **不再有同一枚 `Coin`**，索引方式必须切换。  
2. **AMM 池余额与 `send_funds` 混谈**：池子一般是 **共享对象内 `Balance`**，不是 **用户地址 accumulator**。  
3. **忘记在文档里写清「余额定义」**：对终端用户必须说明 **Explorer 某栏** 统计的是哪一类。

---

## 小结

**`send_funds` 引入第二本账：地址维度的聚合资金**；与 **`Coin` 对象列表** 并行。下一节：**合规** —— **DenyList** 如何限制 **被禁地址使用 `Coin` 作为输入**。
