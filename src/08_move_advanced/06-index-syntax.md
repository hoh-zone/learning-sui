# 下标语法（Index Syntax）

Move 通过 **语法属性** 允许你为自定义类型定义像内置语法一样的操作，在编译期将写法“降级”为你提供的函数调用。**下标语法**（`#[syntax(index)]`）让你可以为类型定义类似 `v[i]`、`m[i,j]` 的索引访问，使 API 更直观、可链式使用。

## 概述

标准库中的 `vector` 通过 `#[syntax(index)]` 标记了 `borrow` 与 `borrow_mut`，因此支持 `v[i]`、`&v[i]`、`&mut v[i]`。你可以在**定义该类型的同一模块内**为自定义类型声明只读和可写的“下标”函数，满足一定规则后，该类型的值就可以使用 `obj[index_expr]` 形式的读写。

## 示例：矩阵类型

下面为矩阵类型定义下标访问，支持 `m[i, j]` 和 `&mut m[i, j]`：

```move
module matrix::matrix;

public struct Matrix<T> has drop {
    v: vector<vector<T>>,
}

#[syntax(index)]
public fun borrow<T>(s: &Matrix<T>, i: u64, j: u64): &T {
    vector::borrow(vector::borrow(&s.v, i), j)
}

#[syntax(index)]
public fun borrow_mut<T>(s: &mut Matrix<T>, i: u64, j: u64): &mut T {
    vector::borrow_mut(vector::borrow_mut(&mut s.v, i), j)
}

public fun make_matrix<T>(v: vector<vector<T>>): Matrix<T> {
    Matrix { v }
}
```

使用方式：

```move
let mut m = matrix::make_matrix(vector[
    vector[1, 0, 0],
    vector[0, 1, 0],
    vector[0, 0, 1],
]);
assert!(m[0, 0] == 1);
*(&mut m[1, 1]) = 2;
```

## 编译期如何翻译

编译器根据“只读 / 可变”和“是否再取引用”将下标表达式翻译为对应的函数调用：

| 写法 | 翻译为 |
|------|--------|
| `mat[i, j]`（只读，且类型有 copy） | `copy matrix::borrow(&mat, i, j)` |
| `&mat[i, j]` | `matrix::borrow(&mat, i, j)` |
| `&mut mat[i, j]` | `matrix::borrow_mut(&mut mat, i, j)` |

下标可与字段访问混合：`&input.vs[0].v[0]` 会按嵌套的 `borrow` 链正确解析。

## 定义规则

1. **属性与模块**：带有 `#[syntax(index)]` 的函数必须与“被索引的类型”在**同一模块**中定义。
2. **可见性**：下标函数必须是 `public`，以便在使用该类型的任意位置都能解析到。
3. **第一个参数（接收者）**：第一个参数必须是**引用**（`&T` 或 `&mut T`），且类型 `T` 必须是本模块定义的类型（不能是元组、类型参数或按值）。
4. **返回值**：只读版本返回 `&Element`，可写版本返回 `&mut Element`；可变性与第一个参数一致。
5. **成对**：每个类型最多一个“只读下标”和一个“可写下标”；只读与可写版本在类型参数个数、约束、其余参数类型上必须一致（仅可变性不同）。

### 不可作为下标接收者的类型

- 元组：`(A, B)` 不能作为第一个参数类型。
- 类型参数：`T` 不能作为接收者类型。
- 按值：第一个参数不能是值（必须是 `&` / `&mut`）。

### 只读与可写版本的类型兼容

两个版本必须：

- 类型参数个数、约束、使用方式一致；
- 除可变性外，第一个参数类型和返回类型一致；
- 除接收者外的所有参数类型完全一致。

这样无论当前表达式是只读还是可写，下标语义都一致。

## 小结

- 使用 `#[syntax(index)]` 在**同一模块**内为类型定义 `borrow`（只读）和 `borrow_mut`（可写），即可对该类型的值使用 `obj[index_expr]` 和 `&mut obj[index_expr]`。
- 编译器将下标按“是否可变、是否再取引用”翻译为对应函数调用。
- 自定义下标可带多个索引参数（如 `m[i, j]`），也可用于实现“带默认值的索引”等更复杂语义；具体规则见 [Move Reference - Index Syntax](https://move-book.com/reference/index-syntax)。
