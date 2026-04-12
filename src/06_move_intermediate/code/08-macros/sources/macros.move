module ch06_08_macros::macros;

macro fun add($a: u64, $b: u64): u64 {
    $a + $b
}

public fun three(): u64 {
    add!(1u64, 2u64)
}

/// 实战练习：第二处宏展开（`10 + 20`）。
public fun thirty(): u64 {
    add!(10u64, 20u64)
}
