module ch05_19_functions::funcs;

fun private_add(a: u64, b: u64): u64 {
    a + b
}

public fun public_sum(a: u64, b: u64): u64 {
    private_add(a, b)
}
