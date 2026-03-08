# 原始类型

原始类型（Primitive Types）是 Move 语言内置的基础数据类型，是构建所有复杂类型的基石。Move 提供了布尔类型和多种位宽的无符号整数类型，所有原始类型都拥有 `copy`、`drop` 和 `store` 能力。理解原始类型及其操作是编写 Move 程序的根基。

## 变量与赋值

### let 绑定

Move 使用 `let` 关键字声明变量。变量默认是 **不可变的**（immutable）：

```move
module book::variables;

#[test]
fun let_binding() {
    let x = 10;      // 不可变变量
    let y: u64 = 20; // 显式类型标注
    assert_eq!(x + y, 30);
}
```

### 可变变量

使用 `let mut` 声明可变变量，可以在后续修改其值：

```move
module book::mutable_vars;

#[test]
fun mut_binding() {
    let mut counter = 0u64;
    counter = counter + 1;
    counter = counter + 1;
    assert_eq!(counter, 2);
}
```

### 变量遮蔽

Move 允许在同一作用域内重新声明同名变量，新变量会 **遮蔽**（shadow）旧变量。遮蔽后的变量可以是不同的类型：

```move
module book::shadowing;

#[test]
fun shadow() {
    let x = 10u64;
    let x = x + 5;     // 遮蔽旧的 x
    assert_eq!(x, 15);

    let y = 100u64;
    let y = (y as u128); // 遮蔽，且类型不同
    assert_eq!(y, 100u128);
}
```

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

## 整数类型

Move 提供六种无符号整数类型，没有有符号整数：

| 类型 | 位宽 | 范围 |
|------|------|------|
| `u8` | 8位 | 0 ~ 255 |
| `u16` | 16位 | 0 ~ 65,535 |
| `u32` | 32位 | 0 ~ 4,294,967,295 |
| `u64` | 64位 | 0 ~ 18,446,744,073,709,551,615 |
| `u128` | 128位 | 0 ~ 2¹²⁸-1 |
| `u256` | 256位 | 0 ~ 2²⁵⁶-1 |

### 整数字面量

整数字面量可以使用后缀指定类型，也可以使用下划线分隔提高可读性：

```move
module book::int_literals;

#[test]
fun literals() {
    let a: u8 = 255;
    let b = 1_000_000u64;       // 下划线分隔
    let c = 0xFF_u8;            // 十六进制
    let d: u128 = 1_000_000_000_000;
    let e: u256 = 0;

    assert_eq!(a, 255);
    assert_eq!(b, 1000000);
}
```

### 算术运算符

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `+` | 加法 | `10 + 20` |
| `-` | 减法 | `30 - 10` |
| `*` | 乘法 | `5 * 6` |
| `/` | 整除 | `100 / 3` → `33` |
| `%` | 取余 | `100 % 3` → `1` |

### 位运算符

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `&` | 按位与 | `0xFF & 0x0F` → `0x0F` |
| `\|` | 按位或 | `0xF0 \| 0x0F` → `0xFF` |
| `^` | 按位异或 | `0xFF ^ 0x0F` → `0xF0` |
| `<<` | 左移 | `1 << 3` → `8` |
| `>>` | 右移 | `16 >> 2` → `4` |

### 比较运算符

| 运算符 | 说明 |
|--------|------|
| `==` | 等于 |
| `!=` | 不等于 |
| `<` | 小于 |
| `>` | 大于 |
| `<=` | 小于等于 |
| `>=` | 大于等于 |

```move
module book::primitive_examples;

#[test]
fun primitives() {
    // Boolean
    let is_valid: bool = true;
    let is_empty = false;
    let result = is_valid && !is_empty;

    // Integers
    let a: u8 = 255;
    let b: u64 = 1_000_000;
    let c: u128 = 1_000_000_000_000;
    let d: u256 = 0;

    // Type casting
    let x: u8 = 10;
    let y: u64 = (x as u64) + 100;

    // Arithmetic
    let sum = 10u64 + 20;
    let diff = 30u64 - 10;
    let product = 5u64 * 6;
    let quotient = 100u64 / 3;
    let remainder = 100u64 % 3;
}
```

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

## 溢出保护

Move 的整数运算在运行时具有 **溢出保护**。当运算结果超出类型范围时，程序会产生运行时错误（abort），而不是静默地回绕（wrapping）：

```move
module book::overflow;

#[test]
#[expected_failure(abort_code = /* arithmetic error */)]
fun overflow() {
    let max: u8 = 255;
    let _result = max + 1; // 运行时 abort，不会回绕为 0
}
```

这一设计确保了链上资产运算的安全性，避免因溢出导致的漏洞。

## 类型推断与显式标注

Move 编译器通常可以根据上下文推断变量类型，但在某些情况下需要显式标注：

```move
module book::type_inference;

#[test]
fun inference() {
    let a = 42;             // 编译器从使用场景推断类型
    let b: u64 = 42;        // 显式标注为 u64
    let c = 42u8;           // 通过后缀指定为 u8
    let d = (42 as u128);   // 通过 as 指定为 u128

    assert_eq!(b, (a as u64));
}
```

当编译器无法推断类型时（例如变量未被使用，或者存在多种可能的类型），你需要显式标注类型。

## 小结

原始类型是 Move 程序的数据基础。本节核心要点：

- **变量声明**：`let` 创建不可变变量，`let mut` 创建可变变量，支持变量遮蔽
- **布尔类型**：`true`/`false`，支持 `&&`、`||`、`!` 逻辑运算，短路求值
- **整数类型**：u8、u16、u32、u64、u128、u256，全部为无符号
- **运算符**：算术（+、-、*、/、%）、位运算（&、|、^、<<、>>）、比较（==、!=、<、>、<=、>=）
- **类型转换**：使用 `as` 关键字进行显式转换，大转小会截断
- **溢出保护**：运行时检测溢出并 abort，而非静默回绕
