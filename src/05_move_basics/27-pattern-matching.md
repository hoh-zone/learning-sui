# 模式匹配

`match` 表达式根据枚举的变体进行分支处理，支持解构变体数据、通配符与穷尽性检查。配合枚举使用，可以安全、优雅地处理多种情况。

## 基本模式匹配

`match` 根据枚举的变体进行分支，每个分支用 `=>` 连接模式与结果：

```move
module book::match_basic;

public enum Coin has copy, drop {
    Penny,
    Nickel,
    Dime,
    Quarter,
}

public fun value_in_cents(coin: &Coin): u64 {
    match (coin) {
        Coin::Penny => 1,
        Coin::Nickel => 5,
        Coin::Dime => 10,
        Coin::Quarter => 25,
    }
}
```

## 穷尽性检查

`match` 必须 **穷尽** 所有可能的变体，遗漏变体会导致编译错误。

## 通配符模式

使用 `_` 匹配所有未显式列出的变体：

```move
public fun is_urgent(p: &Priority): bool {
    match (p) {
        Priority::Critical => true,
        Priority::High => true,
        _ => false,
    }
}
```

## 解构变体数据

在 `match` 中可以解构变体携带的数据；使用 `..` 可忽略命名字段变体中的全部字段：

```move
public fun get_click_x(event: &Event): Option<u64> {
    match (event) {
        Event::Click { x, y: _ } => option::some(*x),
        _ => option::none(),
    }
}

// 忽略所有字段
Color::Custom { .. } => b"Custom"
```

## match 作为表达式

`match` 是表达式，可以返回值；所有分支的返回类型必须一致。

## 常见模式

- **is_variant 检查函数**：用 `match` 实现 `is_active(s)`、`is_paused(s)` 等
- **try_into 转换函数**：变体匹配时返回 `option::some(...)`，否则返回 `option::none()`

## 小结

- **match**：必须穷尽所有变体，支持通配符 `_`
- **解构**：在 match 中绑定变体数据，`..` 忽略所有字段
- **作为表达式**：match 可返回值，分支类型必须一致
