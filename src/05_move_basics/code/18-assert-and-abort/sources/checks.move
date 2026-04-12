module ch05_18_assert::checks;

#[error]
const E_OOPS: vector<u8> = b"Value must be strictly positive";

public fun check_positive(x: u64) {
    assert!(x > 0, E_OOPS);
}

public fun abort_if_zero(x: u64): u64 {
    if (x == 0) {
        abort E_OOPS
    };
    x
}
