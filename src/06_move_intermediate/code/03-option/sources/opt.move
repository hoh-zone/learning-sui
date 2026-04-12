module ch06_03_option::opt;

use std::option::{Self, Option};

public fun some_value(): Option<u64> {
    option::some(42u64)
}

public fun is_some(): bool {
    option::is_some(&some_value())
}
