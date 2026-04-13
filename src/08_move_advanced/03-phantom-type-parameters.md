# `phantom` 类型参数

在[泛型基础](01-generics-basics.md)与[类型参数与能力约束](02-type-parameters-and-constraints.md)中，你已经能为类型参数加上 `copy`、`store` 等约束。本节专门讲 **`phantom`**：当某个类型参数**只用于在类型层面区分不同泛型实例**、**不出现在结构体字段里**时，必须用 `phantom` 声明——否则编译器会拒绝「未使用的类型参数」。

## 为什么需要 `phantom`

Move 要求：若类型参数 `T` **没有**出现在结构体的任何字段类型中，则必须标记为 **`phantom T`**。这样编译器知道：`T` 不参与该值的**运行时布局**，只参与**静态类型检查**。

典型用途：

- **代币 / 资产类型标签**：`Coin<phantom T>`、`Balance<phantom T>`，用 `T` 区分 `SUI`、`USDC` 等，链上数据里仍只有余额等字段。
- **关联某类型但不存储该类型值**：如 `Display<phantom T: key>`、`TypeKey<phantom T>`，在类型系统里「记住」`T`，字段里只放 `UID` 等。

## 基本写法

与配套示例 `code/03-phantom-type-parameters/sources/phantom_basics.move` 一致：

```move
public struct Marker<phantom T> has copy, drop {}

public struct Balance<phantom Currency> has store, drop {
    amount: u64,
}
```

- `Marker<T>` 没有任何字段用到 `T`，因此 **`phantom T`** 必填。
- `Balance<Currency>` 只有 `amount: u64`，`Currency` 仅作**货币种类标签**，也是 **`phantom Currency`**。

这样 `Balance<USD>` 与 `Balance<EUR>` 是**不同类型**，不能把一者的实例当成另一者使用；运行时并不存储 `USD` / `EUR` 的值。

## 与「非 phantom」的对比

一旦类型参数**出现在字段中**，它就是**真实存储的一部分**，**不能**再标 `phantom`：

```move
public struct Wrapper<T: store> has store {
    value: T,
}
```

这里 `T` 出现在 `value` 的类型里，故写 **`Wrapper<T>`**，不能写 `phantom T`。

## `phantom` 与能力约束

可以对 phantom 参数加约束，与框架中常见写法一致：

```move
public struct TagForKeyType<phantom T: key> has copy, drop {}
```

表示：`T` 必须是可作为链上对象根类型的 `key` 类型，但 `TagForKeyType` 本身仍可为零大小或仅含与 `T` 无关的字段。

## 常见错误

| 现象 | 原因 |
|------|------|
| 报错：未使用的类型参数 | 字段里没用到 `T` 却写了 `Struct<T>` 而非 `Struct<phantom T>` |
| 报错：phantom 使用不当 | 对**已经出现在字段里**的参数使用了 `phantom` |

## 小结

- **`phantom`**：类型参数**仅用于类型区分**，**不**出现在任何字段类型中。
- **非 phantom**：类型参数在字段中出现，参与值的布局与存储。
- 与 **`Coin<phantom T>`、`TreasuryCap<phantom T>`** 等框架类型读法一致；Witness / Display 等模式中会频繁见到（参见[第十三章 · Witness](../13_patterns/02-witness.md)等）。
