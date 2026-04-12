# 泛型基础

泛型（Generics）允许在未指定具体类型的情况下定义函数和结构体，实现代码复用与抽象。Move 使用尖括号 `<T>` 声明类型参数，类型参数可用于参数类型、返回类型和函数体。

## 泛型函数

```move
module book::generic_fun;

public fun identity<T>(value: T): T {
    value
}

public fun make_pair<T, U>(first: T, second: U): (T, U) {
    (first, second)
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun generic_fun() {
    let x = identity(42u64);
    assert_eq!(x, 42);
    let (a, b) = make_pair(10u64, true);
    assert_eq!(a, 10);
    assert_eq!(b, true);
}
```

编译器通常可根据上下文推断类型参数。无法推断时，可使用 `function_name<Type>()` 显式指定。

## 泛型结构体

结构体也可以使用泛型类型参数：

```move
module book::generic_struct;

public struct Container<T: drop> has drop {
    value: T,
}

public fun new<T: drop>(value: T): Container<T> {
    Container { value }
}

public fun value<T: drop + copy>(container: &Container<T>): T {
    container.value
}
```

## 多类型参数

函数和结构体可以有多个类型参数：

```move
public struct Pair<T: copy + drop, U: copy + drop> has copy, drop {
    first: T,
    second: U,
}
```

## 小结

- **泛型函数**：`fun name<T>(...)`，类型参数可用于参数与返回值
- **泛型结构体**：`struct Name<T> { ... }`
- **类型推断**：多数情况可省略显式类型；必要时使用 `name<Type>()`
