# Lambda 与代码块参数

## 语法

Lambda **只能**作为宏的参数出现，用于表示「一段代码」。类型写法为：

```text
|T1, T2, ...| -> R
```

无返回类型时默认为 `()`。

示例类型：

```text
|u64, u64| -> u128
|&mut vector<u8>|
```

定义 lambda 值时：

```move
|x| 2 * x
|x: u64| -> u64 { x + 1 }
|a, b| a + b
```

## 捕获

Lambda 体可以**使用当前作用域中的变量**（与常见语言中「捕获」直觉类似），但须满足 Move 的所有权与借用规则——因为展开后仍是普通 Move 代码。

## 与标准库宏配合

`vector` 的 `do!`、`fold!` 以及 `option::do!` 等均接受 lambda，用于表达「对每个元素做什么」「若为 `some` 则做什么」。详见 [§7.6](06-vector-macros.md)、[§7.7](07-option-and-builtins.md)。

## 小结

**`|...| -> R` 只能出现在宏参数位置**；这是 Move 为宏单独扩展的语法。写完 lambda 后，务必用 `sui move build` 验证展开后的类型是否满足约束。
