# 相等比较

Move 提供两种相等运算：`==`（相等）和 `!=`（不相等）。两者都要求两个操作数类型相同，且比较会**消费**参与比较的值，因此只有具有 `drop` 能力的类型可以直接用 `==` / `!=` 比较；否则应先借用再比较。

## 基本用法

| 语法 | 含义 |
|------|------|
| `==` | 两操作数值相等则为 `true`，否则 `false` |
| `!=` | 两操作数值不相等则为 `true`，否则 `false` |

```move
module book::equality;

#[test]
fun equality_basic() {
    assert!(0 == 0);
    assert!(1u128 != 2u128);
    assert!(b"hello" != b"world");
}
```

## 类型要求

两边类型必须一致；可用于所有类型（包括自定义结构体，只要该类型有 `drop` 能力）：

```move
public struct S has copy, drop {
    f: u64,
}

#[test]
fun struct_equality() {
    let s1 = S { f: 1 };
    let s2 = S { f: 1 };
    assert!(s1 == s2);
    assert!(s1 != S { f: 2 });
}
```

## 引用比较

比较引用时，比较的是**所指的值**，与引用是 `&` 还是 `&mut` 无关；`&T` 与 `&mut T` 可以互相比较（底层类型须相同）。语义上等价于在需要不可变引用的地方对 `&mut` 做一次 `freeze` 再比较：

```move
#[test]
fun ref_equality() {
    let x = 0;
    let mut y = 1;
    let r = &x;
    let m = &mut y;
    assert!(r != m);  // 0 != 1
    assert!(r == r);
    assert!(m == m);
    // 等价于：r == freeze(m)、freeze(m) == r 等
}
```

两边的**底层类型**必须相同，例如 `&u64` 与 `&vector<u8>` 不能比较。

## 无 drop 类型：先借用再比较

没有 `drop` 能力的值不能直接被 `==` / `!=` 消费，否则会报错。应使用引用比较：

```move
public struct Coin has store {
    value: u64,
}

public fun coins_equal(c1: &Coin, c2: &Coin): bool {
    c1 == c2  // 比较引用指向的值
}
```

### Move 2024：自动借用

Move 2024 中，若一边是引用、另一边是值，会**自动对值做不可变借用**再比较，因此无需手写 `&`：

```move
let r = &0;
r == 0;   // true，0 被自动借用为 &0
0 == r;   // true
r != 1;   // false
```

自动借用始终是**不可变借用**。

## 避免不必要的 copy

对大型值或向量，用引用比较可避免复制：

```move
assert!(&v1 == &v2);   // 推荐
assert!(copy v1 == copy v2);  // 可能产生大拷贝
```

## 小结

- `==`、`!=` 要求两操作数类型相同，可用于有 `drop` 的类型及引用。
- 无 `drop` 的类型需通过引用比较（`&a == &b`）。
- 大值或向量建议用引用比较以减少 copy。
