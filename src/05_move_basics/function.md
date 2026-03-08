# 函数

函数是 Move 程序的基本构建单元，所有的逻辑都封装在函数中执行。Move 使用 `fun` 关键字声明函数，支持参数、返回值、多返回值、以及多种可见性修饰符。理解函数的声明、调用与可见性规则，是编写 Move 模块的核心基础。

## 函数声明

### 基本语法

函数使用 `fun` 关键字声明，遵循蛇形命名法（snake_case）。函数体中最后一个表达式（不带分号）的值即为返回值：

```move
module book::function_basic;

fun add(a: u64, b: u64): u64 {
    a + b  // 最后一个表达式作为返回值，不加分号
}

#[test]
fun add_returns_sum() {
    assert_eq!(add(2, 3), 5);
}
```

### 无返回值函数

如果函数不需要返回值，返回类型可以省略。函数默认返回空元组 `()`（即 unit 类型）：

```move
module book::function_unit;

public fun do_nothing() {
    // 隐式返回 ()
}

public fun explicit_unit(): () {
    // 显式标注返回 ()
}
```

### 参数与类型标注

每个参数都必须显式标注类型。Move 是强类型语言，不支持类型推导用于函数签名：

```move
module book::function_params;

use std::string::String;

public fun greet(name: String, times: u64): String {
    let _ = times;
    name
}
```

## 返回值

### 单一返回值

函数体中最后一个不带分号的表达式就是返回值。也可以使用 `return` 关键字提前返回：

```move
module book::function_return;

public fun max(a: u64, b: u64): u64 {
    if (a > b) {
        return a  // 提前返回
    };
    b  // 最后表达式返回
}

#[test]
fun max_returns_larger() {
    assert_eq!(max(10, 20), 20);
    assert_eq!(max(30, 5), 30);
}
```

### 多返回值（元组）

Move 支持通过元组返回多个值。调用方使用解构来接收多个返回值：

```move
module book::function_tuple;

public fun swap(a: u64, b: u64): (u64, u64) {
    (b, a)
}

public fun min_max(a: u64, b: u64): (u64, u64) {
    if (a < b) {
        (a, b)
    } else {
        (b, a)
    }
}

#[test]
fun swap_returns_reversed() {
    let (x, y) = swap(1, 2);
    assert_eq!(x, 2);
    assert_eq!(y, 1);
}

#[test]
fun min_max_returns_ordered() {
    let (min, max) = min_max(30, 10);
    assert_eq!(min, 10);
    assert_eq!(max, 30);
}
```

### 忽略返回值

使用 `_` 可以忽略不需要的返回值：

```move
module book::function_ignore;

fun get_pair(): (u64, bool) {
    (42, true)
}

#[test]
fun ignore_return() {
    let (value, _) = get_pair();  // 忽略第二个返回值
    assert_eq!(value, 42);

    let (_, flag) = get_pair();   // 忽略第一个返回值
    assert_eq!(flag, true);
}
```

## 可见性修饰符

### 四种可见性

Move 函数有四种可见性级别，控制函数的调用范围：

```move
module book::function_example;

use std::string::String;

// 私有函数（默认）—— 仅模块内部可调用
fun add(a: u64, b: u64): u64 {
    a + b
}

// 公共函数 —— 任何模块都可调用
public fun multiply(a: u64, b: u64): u64 {
    a * b
}

// 包内可见 —— 同一包内的模块可调用
public(package) fun internal_multiply(a: u64, b: u64): u64 {
    a * b
}

// 入口函数 —— 可从交易直接调用，但不能被其他模块调用
entry fun create_greeting(name: String, ctx: &mut TxContext) {
    let _ = name;
    let _ = ctx;
}

#[test]
fun visibility_and_swap() {
    assert_eq!(add(2, 3), 5);
    assert_eq!(multiply(4, 5), 20);

    let (x, y) = swap_values(1, 2);
    assert_eq!(x, 2);
    assert_eq!(y, 1);

    let (_, second) = swap_values(10, 20);
    assert_eq!(second, 10);
}

fun swap_values(a: u64, b: u64): (u64, u64) {
    (b, a)
}
```

### entry 函数

`entry` 函数是 Sui 交易的入口点。它可以直接从客户端发起的交易中被调用，但不能从其他 Move 模块中调用。`entry` 函数的参数类型有一定限制——通常接受基础类型、对象和 `TxContext`：

```move
module book::entry_example;

public struct Counter has key {
    id: UID,
    value: u64,
}

entry fun create_counter(ctx: &mut TxContext) {
    let counter = Counter {
        id: object::new(ctx),
        value: 0,
    };
    transfer::transfer(counter, ctx.sender());
}

entry fun increment(counter: &mut Counter) {
    counter.value = counter.value + 1;
}
```

## 调用其他模块的函数

通过 `模块名::函数名()` 的语法可以调用其他模块的公共函数。需要先使用 `use` 语句导入模块：

```move
module book::caller_example;

use book::function_example;

fun call_public() {
    // 调用公共函数 —— OK
    let result = function_example::multiply(3, 4);
    assert!(result == 12);
}
```

## 小结

函数是 Move 程序的核心组成部分。使用 `fun` 关键字声明，遵循蛇形命名法。函数体中最后一个不带分号的表达式作为返回值，也支持通过元组返回多个值并用解构接收。Move 提供四种可见性级别：私有（默认）、`public`（公共）、`public(package)`（包内可见）和 `entry`（交易入口）。`entry` 函数是连接链下客户端与链上逻辑的桥梁，但不能被其他模块调用。
