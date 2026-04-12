# 表达式

在 Move 中，几乎所有的语法构造都是表达式（Expression），即它们会产生一个值。唯一的例外是 `let` 语句——它是语句（Statement），不产生值。这种"一切皆表达式"的设计让 Move 的代码风格更加简洁和富有表达力。

## 字面量表达式

字面量是最基本的表达式，直接表示一个值：

```move
module book::literals;

#[test]
fun literals() {
    // 布尔字面量
    let _b1 = true;
    let _b2 = false;

    // 整数字面量
    let _i1 = 42u64;
    let _i2 = 0xFF;        // 十六进制

    // 字节向量字面量
    let _bytes1 = b"hello"; // UTF-8 字符串转字节向量
    let _bytes2 = x"0A1B";  // 十六进制字节向量

    // 地址字面量
    let _addr = @0x1;
}
```

### 字节向量的两种写法

- `b"hello"`：将 UTF-8 字符串编码为 `vector<u8>`
- `x"0A1B"`：将十六进制值直接解析为 `vector<u8>`

## 运算符表达式

所有运算符都会产生一个值，因此它们也是表达式：

```move
module book::operator_expr;

#[test]
fun operators() {
    // 算术运算产生整数值
    let sum = 10 + 20;         // 30
    let product = 5 * 6;       // 30

    // 比较运算产生布尔值
    let is_equal = sum == product;  // true

    // 逻辑运算产生布尔值
    let is_positive = sum > 0;
    let combined = is_equal && is_positive; // true

    assert!(combined);
}
```

## 块表达式

用花括号 `{ }` 包裹的代码块本身也是一个表达式。块中最后一个表达式的值（**不带分号**）就是整个块的返回值：

```move
module book::block_expr;

#[test]
fun block_returns_value() {
    let x = {
        let a = 10;
        let b = 20;
        a + b  // 没有分号 = 返回值
    };
    assert_eq!(x, 30);

    // 嵌套块表达式
    let y = {
        let inner = {
            let c = 5;
            c * 2
        };
        inner + 10
    };
    assert_eq!(y, 20);
}
```

### 空块

空块 `{}` 返回单元值 `()`（unit type）：

```move
module book::empty_block;

#[test]
fun empty_block() {
    let _unit: () = {};
}
```

## 分号的作用

分号 `;` 用于终止一个表达式。被分号终止的表达式的值会被丢弃。如果分号后面没有其他表达式，编译器会自动插入单元值 `()`：

```move
module book::semicolons;

#[test]
fun semicolons() {
    // 带分号：值被丢弃，块返回 ()
    let _a: () = {
        10 + 20; // 值 30 被丢弃
    };

    // 不带分号：值被返回
    let b: u64 = {
        10 + 20 // 值 30 被返回
    };
    assert_eq!(b, 30);
}
```

> **常见错误**：函数末尾不小心加了分号，导致返回 `()` 而非预期值。这是新手最容易犯的错误之一。

## 函数调用作为表达式

函数调用也是表达式，其值为函数的返回值：

```move
module book::func_expr;

fun double(x: u64): u64 {
    x * 2
}

fun add(a: u64, b: u64): u64 {
    a + b
}

#[test]
fun func_as_expr() {
    // 函数调用的结果可以直接参与运算
    let result = add(double(5), double(3));
    assert_eq!(result, 16); // (5*2) + (3*2) = 16
}
```

## 控制流表达式

`if/else` 在 Move 中也是表达式，会产生一个值：

```move
module book::expression_examples;

#[test]
fun expressions_mixed() {
    // Literals
    let _bool_val = true;
    let _int_val = 42u64;
    let _hex_val = 0xFF;
    let _bytes = b"hello";

    // Block expression returns a value
    let x = {
        let a = 10;
        let b = 20;
        a + b  // no semicolon = return value
    };
    assert_eq!(x, 30);

    // if as expression
    let y = if (x > 20) { 1 } else { 0 };
    assert_eq!(y, 1);

    // Operators
    let sum = 10 + 20;
    let is_positive = sum > 0;
    assert!(is_positive);
}
```

当 `if/else` 作为表达式使用时，两个分支的返回类型必须一致：

```move
module book::if_expr;

#[test]
fun if_expr_grade() {
    let score = 85u64;

    let grade = if (score >= 90) {
        b"A"
    } else if (score >= 80) {
        b"B"
    } else if (score >= 70) {
        b"C"
    } else {
        b"D"
    };

    assert_eq!(grade, b"B");
}
```

## 表达式序列

多个表达式可以通过分号连接形成序列，最后一个表达式的值是整个序列的值：

```move
module book::expr_sequence;

fun compute(input: u64): u64 {
    let doubled = input * 2;
    let offset = doubled + 10;
    let result = offset / 3;
    result // 最后一个表达式的值作为函数返回值
}

#[test]
fun sequence() {
    assert_eq!(compute(10), 10); // (10*2 + 10) / 3 = 10
}
```

## 小结

表达式是 Move 语言的核心语法概念。本节核心要点：

- Move 中几乎一切都是表达式，唯一的例外是 `let` 语句
- **字面量**：布尔、整数、十六进制、字节向量（`b"..."`、`x"..."`）、地址都是表达式
- **块表达式**：`{ }` 中最后一个不带分号的表达式是块的返回值
- **分号**：终止表达式并丢弃其值，末尾加分号会导致返回 `()`
- **控制流**：`if/else` 也是表达式，两个分支返回类型必须一致
- **函数调用**：函数调用的结果可以直接作为表达式参与运算
