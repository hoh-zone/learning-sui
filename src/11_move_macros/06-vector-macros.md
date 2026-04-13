# 标准库：向量宏

`std::vector` 与整数类型上的扩展宏（如 `do!` 在 `u8` 上）用于替代手写 `while` 循环，代码更短、更不易写出越界或漏改下标的 bug。

## 常用宏一览

| 宏 | 含义 |
|----|------|
| `vec.do!(\|e\| …)` | 按值遍历，**消费**向量 |
| `vec.do_ref!(\|e\| …)` | 不可变引用遍历 |
| `vec.do_mut!(\|e\| …)` | 可变引用遍历 |
| `vec.destroy!(\|e\| …)` | 消费向量，常用于元素类型**无 `drop`** 时需逐枚「处理掉」 |
| `vec.fold!(init, \|acc, e\| …)` | 从左到右折叠 |
| `vec.filter!(\|e\| …)` | 过滤（要求元素类型具备 **`drop`**） |
| `n.do!(\|_\| …)` | 对 `u8` 等量执行固定次数（如 `3u8.do!(…)`） |
| `vector::tabulate!(n, \|i\| …)` | 生成长度为 `n` 的向量，元素由下标计算 |

## 示例

```move
#[test]
fun sum_by_ref() {
    let v = vector[1u64, 2, 3, 4, 5];
    let mut sum = 0u64;
    v.do_ref!(|e| sum = sum + *e);
    assert!(sum == 15);
}

#[test]
fun fold_and_tabulate() {
    let v = vector[1u64, 2, 3];
    let folded = v.fold!(0u64, |acc, e| acc + e);
    assert!(folded == 6);

    let indices = vector::tabulate!(4, |i| i);
    assert!(indices == vector[0u64, 1, 2, 3]);
}
```

## 使用建议

- 需要**下标**时用 `tabulate!` 或配合 `enumerate` 式模式（依标准库版本为准）；单纯遍历优先 `do_ref!` / `do_mut!`。
- **`filter!`** 要求元素可 `drop`，否则无法丢弃被筛掉的元素。

完整可编译示例见本章 [`code/macro_lab/`](code/README.md)。
