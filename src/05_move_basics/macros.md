# 宏函数

宏函数（macro function）在**编译时**在调用处展开，参数按表达式替换而非先求值再传参，并可接收 **lambda** 形式的代码块。Move 的宏仍然有类型约束，因此可以像普通函数一样使用，也支持[方法语法](./struct-methods.md)和 `use fun`。

## 语法

宏用 `macro fun` 定义；**类型参数**和**值参数**名必须以 `$` 开头，以区别于普通函数：

```move
module book::macro_basic;

macro fun add_three($x: u64, $y: u64, $z: u64): u64 {
    $x + $y + $z
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun use_macro() {
    let sum = add_three!(1, 2, 3);
    assert_eq!(sum, 6);
}
```

- 以 `$` 开头的参数在编译期按**表达式**替换（不是先求值再代入）。
- 调用宏时使用 `macro_name!(...)`，与普通函数调用的括号形式区分。
- 若宏需要接收“一段代码”，可使用 **lambda** 类型参数（见下文）。

## Lambda

Lambda 只能作为宏的参数出现，用于把“一段代码”传给宏。类型写法为 `|T1, T2, ...| -> R`，无返回类型时默认为 `()`：

```move
|u64, u64| -> u128        // 两个 u64，返回 u128
|&mut vector<u8>|         // 一个参数，返回 ()
```

定义 lambda 时：

```move
|x| 2 * x
|x: u64| -> u64 { x + 1 }
|a, b| a + b
```

Lambda 可以**捕获**外层变量（在 lambda 内使用当前作用域中的变量）。

## 标准库中的向量宏

Move 标准库为 `vector` 提供了一批宏，替代手写 `while` 循环，使代码更简洁：

| 宏 | 含义 |
|----|------|
| `vec.do!( \|e\| ... )` | 对每个元素执行一次，消费向量 |
| `vec.do_ref!( \|e\| ... )` | 对每个元素的引用执行 |
| `vec.do_mut!( \|e\| ... )` | 对每个元素的可变引用执行 |
| `vec.destroy!( \|e\| ... )` | 消费向量，对每个元素调用给定函数（常用于销毁无 drop 的元素） |
| `vec.fold!(init, \|acc, e\| ... )` | 从左到右折叠为一个值 |
| `vec.filter!( \|e\| cond )` | 过滤（要求元素类型有 drop） |
| `n.do!( \|_\| ... )` | 将某操作重复 n 次（如 `32u8.do!(\|_\| ...)`) |
| `vector::tabulate!(n, \|i\| ...)` | 生成长度为 n 的向量，元素由下标 i 计算 |

示例：

```move
module book::vector_macros;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun do_and_fold() {
    let v = vector[1u64, 2, 3, 4, 5];
    let mut sum = 0u64;
    v.do_ref!(|e| sum = sum + *e);
    assert_eq!(sum, 15);

    let folded = v.fold!(0u64, |acc, e| acc + e);
    assert_eq!(folded, 15);
}

#[test]
fun tabulate() {
    let indices = vector::tabulate!(5, |i| i);
    assert_eq!(indices, vector[0u64, 1, 2, 3, 4]);
}
```

## Option 宏

`option::do!(opt, |value| ...)` 在为 `some` 时执行 lambda；`opt.destroy_or!(default)` 或 `opt.destroy_or!(abort E)` 用于取出值或提供默认/中止。

## 小结

- 宏用 `macro fun` 定义，类型与值参数以 `$` 开头，调用形式为 `name!(...)`。
- Lambda 类型为 `|T1, T2| -> R`，只能作为宏参数，可捕获外层变量。
- 标准库提供 `vector` 的 `do!`、`fold!`、`tabulate!`、`destroy!` 等宏，以及 `option` 的 `do!`、`destroy_or!`，推荐优先使用宏替代手写循环。
