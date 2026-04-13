# 注册与 OTW：币种如何「一生成一次」

## 本节要回答的问题

- 为什么发币不只是一个 `struct`，而必须经过 **`coin_registry`** 与 **一次性见证（OTW）**？  
- **`CurrencyInitializer<T>`**、**`finalize`** 在 Move 类型系统里分别扮演什么角色？  
- **`new_currency_with_otw`** 与 **`new_currency`**（需传入 **`&mut CoinRegistry`**）各适用于什么场景？

**前置**：[§15.1 · 本章导论](01-overview.md)、[第十二章 · OTW](../13_patterns/03-one-time-witness.md)。  
**后续**：[§15.3 · 元数据](03-coin-metadata.md)。

---

## 原理：全局唯一的一条「币种档案」

Sui 希望每种代币 **`T`** 在生态里只有 **一条规范记录**：人类可读的名称与符号、小数位、供应与监管状态是否在 **`CoinRegistry`** 可查询。若允许任意模块随意「再声明一种同名同结构的币」，钱包与索引器将无法建立 **稳定、可验证的元数据来源**。

因此 Framework 把 **创建 `Currency<T>` 并挂入注册表** 设计成 **受控流程**：

1. **证明 `T` 是该包在发布时合法引入的类型** —— 用 **OTW**（`has drop`、与模块同名、仅在 `init` 收到一次值）。  
2. **在单事务内完成数据填充与登记** —— **`CurrencyInitializer<T>`** 作为 **热土豆**：必须在 **`finalize`** 中消费，避免半成品留在链上。  
3. **产出 `TreasuryCap<T>`** —— 与 **`Supply<T>`** 绑定，成为日后 **`mint` / `burn`** 的正门。

**精髓**：**OTW 不是装饰**，而是 **把「类型的创世」与「包发布」绑定** 的机制；**`finalize` 不是可选**，而是 **把 `Currency` 提交给 `CoinRegistry` 并交出 `MetadataCap`** 的终点。

---

## `new_currency_with_otw` 的典型 `init`

下列流程与本书示例包 `silver_coin` 一致（类型名 **`SILVER`** 仅为示例）：

```move
module example::silver;

use std::string;
use sui::coin_registry;

public struct SILVER() has drop;

const DECIMALS: u8 = 9;

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        otw,
        DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Hero currency"),
        string::utf8(b"https://example.com/silver.png"),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

**返回值含义**：

- **`initializer`**：**`CurrencyInitializer<SILVER>`** —— 内含尚未完成注册的 **`Currency<SILVER>`** 草稿与附加袋；**必须**在同一 `init`（或你设计的连贯调用链）中交给 **`finalize`**。  
- **`treasury_cap`**：**`TreasuryCap<SILVER>`** —— 已与该类型的 **`Supply`** 关联；发布后即可 **`coin::mint`**。  
- **`finalize`** 之后：**`Currency<SILVER>`** 进入 **`CoinRegistry`** 所管理的世界；你得到 **`MetadataCap<SILVER>`**，用于后续更新名称、描述、图标等（见 §15.3）。

---

## 与 `new_currency` 的对比（读懂文档用）

`coin_registry::new_currency` **不接收 OTW**，而是要求调用方持有 **`&mut CoinRegistry`**，并在 **`Currency` 已存在检查** 通过后创建 **`TreasuryCap`** 与 **`CurrencyInitializer`**。它适用于 **模块已发布之后**、在链上事务里**动态登记**新币种的设计（仍须满足 Framework 对 `T` 的约束，见源码中 `T: key` 等说明）。

对本书读者而言：**入门与教材示例优先掌握 `new_currency_with_otw` + `init`** 即可。

---

## 受监管：必须在 `finalize` 之前

若该币种需要 **DenyList** 能力，在 **`finalize` 之前** 对 **`initializer`** 调用 **`coin_registry::make_regulated`**，取得 **`DenyCapV2<T>`**。该操作 **不可逆**：`Currency` 上的监管状态会永久标记为受监管分支。详见 [§15.8](08-regulated-denylist.md)。

```text
new_currency_with_otw → [可选 make_regulated] → finalize → 得到 MetadataCap
```

---

## 常见误区

1. **忘记调用 `finalize`**：`CurrencyInitializer` 无法长期合法搁置；热土豆必须在构造路径上被消费。  
2. **以为 OTW 可以手动再造一个**：OTW 值只在包**首次发布**的 `init` 注入，无法复制。  
3. **混淆 `TreasuryCap` 与 `Currency`**：前者管 **供应与铸销权**；后者管 **登记簿上的类型档案**；二者由注册流程衔接，职责不同。

---

## 小结

**`new_currency_with_otw` + `finalize`** 是「**可被发现、可展示、可铸币**」的标准发币路径；**OTW** 保证类型级创世的一次性，**`CurrencyInitializer`** 保证注册流程完整。下一节逐项说明 **`Currency` 上对人展示的字段** 与 **`MetadataCap`** 的权限边界。
