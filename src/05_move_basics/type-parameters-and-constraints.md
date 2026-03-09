# 类型参数与能力约束

对泛型类型参数施加 **能力约束**（ability constraints），可以要求类型具备 `copy`、`drop`、`store`、`key` 等能力。**幻影类型参数**（phantom）不占用存储空间，仅用于类型层面的区分，常用于实现类型安全的抽象（如不同货币）。

## 能力约束

对类型参数添加能力约束，要求传入的类型必须满足相应能力：

```move
module book::generic_constraints;

public struct Copyable<T: copy + drop> has copy, drop {
    value: T,
}

public struct Storable<T: store> has store {
    value: T,
}

public fun duplicate<T: copy>(value: &T): T {
    *value
}
```

常见约束组合：

| 约束 | 含义 |
|------|------|
| `T: drop` | T 可以被丢弃 |
| `T: copy` | T 可以被复制 |
| `T: copy + drop` | T 可复制和丢弃 |
| `T: store` | T 可存储在全局对象中 |
| `T: key + store` | T 可作为顶层对象 |

## 幻影类型参数

当类型参数未在结构体字段中使用、仅用于类型区分时，需用 `phantom` 标记：

```move
module book::generics_phantom;

public struct USD {}
public struct EUR {}

public struct Balance<phantom Currency> has store, drop {
    amount: u64,
}

public fun new_balance<Currency>(amount: u64): Balance<Currency> {
    Balance { amount }
}

public fun merge<Currency>(b1: &mut Balance<Currency>, b2: Balance<Currency>) {
    let Balance { amount } = b2;
    b1.amount = b1.amount + amount;
}
```

这样只能合并相同“货币”类型的余额，在编译期防止类型混用。

## 泛型与对象

在 Sui 中，泛型常与对象结合，实现通用对象容器（如 `Container<T: store> has key, store`），并通过 `store` 等能力约束保证类型可安全存储。

## 小结

- **能力约束**：`T: copy + drop`、`T: store` 等，确保类型参数满足所需能力
- **phantom**：不占存储，仅用于类型区分；零运行时开销、编译期类型安全
- **泛型对象**：结合 `key`/`store` 实现可存储的泛型对象
