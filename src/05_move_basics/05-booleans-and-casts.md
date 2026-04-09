# 布尔与类型转换

布尔类型与类型转换是 Move 基础类型的重要组成部分。布尔用于条件与逻辑判断；`as` 用于在不同整数类型之间进行显式转换。

## 布尔类型

布尔类型 `bool` 只有两个值：`true` 和 `false`。

### 逻辑运算符

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `&&` | 逻辑与 | `true && false` → `false` |
| `\|\|` | 逻辑或 | `true \|\| false` → `true` |
| `!` | 逻辑非 | `!true` → `false` |

```move
module book::bool_example;

#[test]
fun bool_ops() {
    let a = true;
    let b = false;

    assert!(a && !b);     // true && true = true
    assert!(a || b);      // true || false = true
    assert!(!(a && b));   // !(true && false) = true
}
```

逻辑与 `&&` 和逻辑或 `||` 支持 **短路求值**：如果左操作数已经能确定结果，右操作数不会被求值。

## 类型转换

Move 使用 `as` 关键字在不同整数类型之间进行显式转换：

```move
module book::casting;

#[test]
fun casting() {
    let x: u8 = 42;
    let y: u64 = (x as u64);
    let z: u128 = (y as u128);
    let w: u256 = (z as u256);

    // 也可以从大类型转到小类型（会截断）
    let big: u64 = 300;
    let small: u8 = (big as u8); // 300 % 256 = 44
    assert_eq!(small, 44);
}
```

> **注意**：从大类型向小类型转换时会发生截断，高位被丢弃。

## 小结

- **布尔类型**：`true`/`false`，支持 `&&`、`||`、`!`，短路求值
- **类型转换**：使用 `as` 关键字进行显式转换，大转小会截断
