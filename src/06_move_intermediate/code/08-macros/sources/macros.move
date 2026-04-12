module ch06_08_macros::macros;

macro fun add($a: u64, $b: u64): u64 {
    $a + $b
}

public fun three(): u64 {
    add!(1u64, 2u64)
}
