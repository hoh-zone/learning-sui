# 元组与 Unit

Move 支持元组形式的表达式，用于多返回值和解构；同时提供 **unit** 类型 `()`，表示“无有意义值”。元组在字节码层并不存在独立表示，因此不能绑定到局部变量、不能存入结构体、也不能作为泛型类型参数实例化，只能在表达式（尤其是返回值）中使用。

## Unit 类型 `()`

Unit 是“空元组”，类型为 `()`，常用于无返回值的函数：

```move
module book::unit_example;

public fun do_nothing(): () {
    ()
}

public fun do_nothing_implicit() {
    // 无返回类型时默认为 ()
}
```

空块或块尾带分号时，块的值也是 `()`。

## 元组字面量

元组由括号内逗号分隔的表达式构成，类型为 `(T1, T2, ...)`。注意**单元素** `(e)` 只是括号，类型仍是 `e` 的类型，不是单元素元组：

```move
module book::tuples;

public fun returns_unit(): () {
    ()
}

public fun returns_pair(): (u64, bool) {
    (0, false)
}

public fun returns_three(): (u64, u8, address) {
    (1, 2, @0x42)
}
```

## 元组解构

在 `let` 或赋值中可对元组解构，按位置绑定到多个局部变量：

```move
#[test]
fun destructure() {
    let () = ();
    let (x, y): (u64, u64) = (0, 1);
    let (a, b, c) = (@0x0, 0u8, true);

    (x, y) = (2, 3);
    assert_eq!(x, 2);
    assert_eq!(y, 3);
}
```

元组长度必须与模式一致，否则会报错。

## 多返回值

函数返回多个值时，在类型和 return 处使用元组语法；调用方用解构接收：

```move
public fun swap(a: u64, b: u64): (u64, u64) {
    (b, a)
}

#[test]
fun use_swap() {
    let (x, y) = swap(1, 2);
    assert_eq!(x, 2);
    assert_eq!(y, 1);
}
```

Move 不允许在结构体中存储引用，因此多返回值（尤其是包含引用时）依赖元组语法实现。

## 小结

- `()` 是 unit 类型，表示“无值”；无返回类型的函数即返回 `()`。
- 元组 `(e1, e2, ...)` 用于多返回值和解构，不能存到变量或结构体。
- 通过 `let (a, b, ...) = ...` 或赋值解构元组，长度需匹配。
