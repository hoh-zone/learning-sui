module ch06_03_option::opt;

use std::option::{Self, Option};

public fun some_value(): Option<u64> {
    option::some(42u64)
}

public fun is_some(): bool {
    option::is_some(&some_value())
}

/// 实战练习：`None` 时返回默认 `0`（与 `std::option::destroy_with_default` 一致）。
public fun unwrap_or_zero(x: Option<u64>): u64 {
    option::destroy_with_default(x, 0u64)
}
