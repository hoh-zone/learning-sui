module ch05_04_integers::math;

public fun sum_u64(a: u64, b: u64): u64 {
    a + b
}

/// 三数相加（实战练习）。注意：与 `+` 一样在溢出时 abort，生产环境可用 `u64::checked_add` 等模式。
public fun sum_three(a: u64, b: u64, c: u64): u64 {
    a + b + c
}

public fun hex_literal(): u8 {
    0x0a
}
