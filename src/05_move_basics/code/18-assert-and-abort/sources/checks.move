module ch05_18_assert::checks;

const E_OOPS: u64 = 1;

public fun check_positive(x: u64) {
    assert!(x > 0, E_OOPS);
}

public fun abort_if_zero(x: u64): u64 {
    if (x == 0) {
        abort E_OOPS
    };
    x
}
