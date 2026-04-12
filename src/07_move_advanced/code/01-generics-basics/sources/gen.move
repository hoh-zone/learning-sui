module ch07_01_generics::gen;

public fun identity<T: drop>(x: T): T {
    x
}

public fun zero_u64(): u64 {
    identity(0u64)
}

/// 实战练习：同时需要 `copy` 与 `drop`，才能返回两个 `T`（否则无法复制 `x`）。
public fun duplicate_pair<T: copy + drop>(x: T, y: T): (T, T) {
    (identity(x), identity(y))
}

// 若写成 `fn bad<T: drop>(x: T): (T, T) { (x, x) }` 会因缺少 `copy` 无法编译——请读者尝试。
