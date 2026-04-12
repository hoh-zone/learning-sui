module ch07_01_generics::gen;

public fun identity<T: drop>(x: T): T {
    x
}

public fun zero_u64(): u64 {
    identity(0u64)
}
