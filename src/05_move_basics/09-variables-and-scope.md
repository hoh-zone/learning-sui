# 局部变量与作用域

Move 中的局部变量采用词法（静态）作用域，通过 `let` 引入。使用 `mut` 标记的变量可以重新赋值或被可变借用。本节系统介绍变量声明、类型标注、解构、作用域、遮蔽（shadowing）以及 move 与 copy 的语义。

## let 绑定

使用 `let` 将名字绑定到值：

```move
module book::variables;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun let_bindings() {
    let x = 1;
    let y = x + x;
    assert_eq!(y, 2);
}
```

可以先声明后赋值（便于在分支或循环中赋初值）：

```move
#[test]
fun let_then_assign() {
    let x;
    if (true) {
        x = 1
    } else {
        x = 0
    };
    assert_eq!(x, 1);
}
```

变量在**赋值前不能使用**，且在**所有控制流路径上都必须被赋值**，否则类型检查会报错（例如 `let x; if (cond) x = 0; x + 1` 在 else 分支未赋 x 会报错；`while` 循环后的 x 也视为可能未赋值）。

## mut 可变变量

需要重新赋值或需要被 `&mut` 借用时，必须用 `let mut` 声明：

```move
#[test]
fun mut_var() {
    let mut x = 0;
    x = x + 1;
    assert_eq!(x, 1);
}
```

函数参数若需可变借用，也应使用 `mut`，例如 `fun f(mut v: vector<u64>)`。

## 变量命名规则

变量名可包含字母、数字和下划线，且**必须以小写字母或下划线开头**，不能以大写字母开头（大写用于类型或常量）：

```move
let x = 1;      // 合法
let _x = 1;     // 合法，下划线常用于“有意忽略”
let x0 = 1;     // 合法
// let X = 1;   // 非法
```

## 类型标注

多数情况下类型可推断，需要时可显式标注：

```move
let x: u64 = 0;
let v: vector<u8> = vector[];
let a: address = @0x0;
```

在以下情况类型标注是**必须的**：（1）泛型无法推断，例如空向量 `vector[]`；（2）发散表达式（如 `return`、`abort`、无 `break` 的 `loop`）的绑定，编译器无法从后续代码推断类型。类型标注写在**模式右侧**、等号左侧，例如 `let (x, y): (u64, u64) = (0, 1);`，而不是 `let (x: u64, y: u64) = ...`。

```move
let empty: vector<u64> = vector[];  // 必须标注元素类型
```

## 用元组一次绑定多个变量

`let` 可以用元组同时引入多个变量：

```move
#[test]
fun tuple_destructure() {
    let () = ();
    let (x, y) = (0u64, 1u64);
    let (a, b, c) = (true, 10u8, @0x1);
    assert_eq!(x + y, 1);
}
```

元组长度必须与模式匹配，且同一 `let` 中不能重复同名变量。

## 用结构体解构绑定

可以从结构体中解构出字段并绑定到局部变量：

```move
public struct Point has copy, drop {
    x: u64,
    y: u64,
}

#[test]
fun struct_destructure() {
    let Point { x, y } = Point { x: 1, y: 2 };
    assert_eq!(x + y, 3);
}

#[test]
fun struct_destructure_rename() {
    let Point { x: a, y: b } = Point { x: 10, y: 20 };
    assert_eq!(a, 10);
    assert_eq!(b, 20);
}
```

对引用解构会得到引用类型的绑定（`&t` / `&mut t`），不会消费原值。

## 忽略值：下划线

不需要绑定的值可用 `_` 忽略，避免“未使用变量”警告：

```move
let (x, _, z) = (1, 2, 3);  // 第二个值被忽略
```

## 块与作用域

用花括号 `{ }` 构成块；块内 `let` 只在该块内有效。块最后一个表达式（无分号）的值即为块的值：

```move
#[test]
fun block_scope() {
    let x = 0;
    let y = {
        let inner = 1;
        x + inner
    };
    assert_eq!(y, 1);
    // inner 在此不可见
}
```

内层块可以访问外层变量；外层不能访问内层声明的变量。

## 遮蔽（Shadowing）

同一作用域内再次用 `let` 声明同名变量会遮蔽之前的绑定，之后无法访问旧值：

```move
#[test]
fun shadowing() {
    let x = 0;
    assert_eq!(x, 0);
    let x = 1;  // 遮蔽
    assert_eq!(x, 1);
}
```

被遮蔽的变量若类型无 `drop` 能力，其值仍须在函数结束前被转移或销毁，不能“藏起来”就不管。

## 赋值

`mut` 变量可通过赋值 `x = e` 修改。赋值本身是表达式，类型为 `()`：

```move
let mut x = 0;
x = 1;
if (cond) x = 2 else x = 3;
```

## move 与 copy

- **copy**：复制值，原变量仍可使用；仅对具有 `copy` 能力的类型可用。
- **move**：将值移出变量，移出后该变量不可再使用。

未显式写 `copy` 或 `move` 时，编译器按以下规则**推断**：  
（1）有 `copy` 能力的类型默认 **copy**；  
（2）**引用**（`&T`、`&mut T`）默认 **copy**（特殊情况下在不再使用时可能按 move 处理以得到更清晰的借用错误）；  
（3）其他类型（无 copy 或资源类型）默认 **move**。

```move
let x = 1;
let y = copy x;  // 显式复制，x 仍可用
let z = move x;  // 移出后 x 不可再用
```

## 小结

- 用 `let` 引入局部变量，需要修改或可变借用时用 `let mut`。
- 变量名以小写或下划线开头；可选用类型标注。
- 可用元组或结构体解构一次绑定多个变量，用 `_` 忽略不需要的值。
- 块 `{ }` 限定作用域；块尾无分号的表达式为块的值。
- 同名 `let` 会遮蔽；赋值仅针对 `mut` 变量。
- 值的使用方式由 move/copy 语义决定，编译器会做推断。
