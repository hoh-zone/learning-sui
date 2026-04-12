module ch05_07_tuples::pair;

public fun swap_pair(a: u64, b: u64): (u64, u64) {
    (b, a)
}

public fun unit_ret(): () {
    ()
}
