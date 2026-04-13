# 函数定义与调用

函数是 Move 程序的基本构建单元，使用 `fun` 关键字声明。函数体最后一个不带分号的表达式即为返回值；支持通过元组返回多值并用解构接收。

## 基本语法

函数遵循蛇形命名法（snake_case）。每个参数都必须显式标注类型：

```move
module book::function_basic;

fun add(a: u64, b: u64): u64 {
    a + b  // 最后一个表达式作为返回值，不加分号
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun add_returns_sum() {
    assert_eq!(add(2, 3), 5);
}
```

## 无返回值与 Unit

如果函数不需要返回值，返回类型可以省略，默认返回空元组 `()`（unit 类型）：

```move
module book::function_unit;

public fun do_nothing() {
    // 隐式返回 ()
}

public fun explicit_unit(): () {
    ()
}
```

## 参数与类型标注

Move 是强类型语言，函数签名中的参数类型必须显式标注，不能依赖推导：

```move
module book::function_params;

use std::string::String;

public fun greet(name: String, times: u64): String {
    let _ = times;
    name
}
```

## 单一返回值与 return

函数体中最后一个不带分号的表达式就是返回值；也可以使用 `return` 提前返回：

```move
module book::function_return;

public fun max(a: u64, b: u64): u64 {
    if (a > b) {
        return a
    };
    b
}
```

## 多返回值（元组）

Move 支持通过元组返回多个值，调用方使用解构接收：

```move
module book::function_tuple;

public fun swap(a: u64, b: u64): (u64, u64) {
    (b, a)
}

public fun min_max(a: u64, b: u64): (u64, u64) {
    if (a < b) { (a, b) } else { (b, a) }
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun swap_returns_reversed() {
    let (x, y) = swap(1, 2);
    assert_eq!(x, 2);
    assert_eq!(y, 1);
}
```

## 忽略返回值

使用 `_` 可以忽略不需要的返回值：

```move
#[test]
fun ignore_return() {
    let (value, _) = get_pair();
    let (_, flag) = get_pair();
}
```

## 小结

- **声明**：`fun` 关键字，蛇形命名，参数必须显式类型
- **返回值**：最后表达式或 `return`；支持元组多返回值与解构
- **Unit**：无返回值时隐式返回 `()`
