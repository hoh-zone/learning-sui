# 条件分支（if / else）

Move 使用 `if/else` 实现条件分支。与许多语言不同，Move 中的 `if/else` 是 **表达式**，可以返回值，两个分支的返回类型必须一致。

## 基本语法

`if` 表达式根据布尔条件选择执行路径：

```move
module book::if_basic;

public fun is_positive(n: u64): bool {
    if (n > 0) {
        true
    } else {
        false
    }
}

#[test]
fun if_positive() {
    assert!(is_positive(10));
    assert!(!is_positive(0));
}
```

## 作为表达式使用

`if/else` 可以返回值，此时两个分支的返回类型必须一致：

```move
module book::if_expression;

public fun abs_diff(a: u64, b: u64): u64 {
    if (a > b) { a - b } else { b - a }
}

public fun max(a: u64, b: u64): u64 {
    if (a >= b) { a } else { b }
}

public fun describe(n: u64): vector<u8> {
    if (n == 0) {
        b"zero"
    } else if (n < 10) {
        b"small"
    } else if (n < 100) {
        b"medium"
    } else {
        b"large"
    }
}

#[test]
fun expression_if() {
    assert_eq!(abs_diff(10, 3), 7);
    assert_eq!(max(5, 8), 8);
    assert_eq!(describe(0), b"zero");
    assert_eq!(describe(5), b"small");
    assert_eq!(describe(50), b"medium");
    assert_eq!(describe(200), b"large");
}
```

## 无 else 分支

当 `if` 不作为表达式使用时（即不返回值），可以省略 `else` 分支：

```move
module book::if_no_else;

#[test]
fun no_else() {
    let mut result = 0u64;
    let condition = true;

    if (condition) {
        result = 42;
    };

    assert_eq!(result, 42);
}
```

## 小结

- **if/else**：条件分支，可作为表达式返回值
- **分支类型**：作为表达式时，两个分支的返回类型必须一致
- **无 else**：不返回值时可以省略 `else`
