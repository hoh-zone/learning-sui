# 类型参数与能力约束

对泛型类型参数施加 **能力约束**（ability constraints），可以要求类型具备 `copy`、`drop`、`store`、`key` 等能力。若类型参数**只作类型标签、不出现在字段中**，则需使用 **`phantom`**，详见下一节 **[§8.3 `phantom` 类型参数](03-phantom-type-parameters.md)**。

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

## 泛型与对象

在 Sui 中，泛型常与对象结合，实现通用对象容器（如 `Container<T: store> has key, store`），并通过 `store` 等能力约束保证类型可安全存储。

## 小结

- **能力约束**：`T: copy + drop`、`T: store` 等，确保类型参数满足所需能力
- **`phantom`**：单独成章，见 **[§8.3](03-phantom-type-parameters.md)**
- **泛型对象**：结合 `key`/`store` 实现可存储的泛型对象
