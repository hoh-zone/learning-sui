module ch05_17_loops::loops;

public fun sum_to(n: u64): u64 {
    let mut i = 0u64;
    let mut s = 0u64;
    while (i < n) {
        i = i + 1;
        s = s + i;
    };
    s
}
