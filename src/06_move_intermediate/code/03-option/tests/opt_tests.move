#[test_only]
module ch06_03_option::opt_tests;

use std::option;
use ch06_03_option::opt;

#[test]
fun test_unwrap_some() {
    assert!(opt::unwrap_or_zero(option::some(7u64)) == 7);
}

#[test]
fun test_unwrap_none() {
    let n: option::Option<u64> = option::none();
    assert!(opt::unwrap_or_zero(n) == 0);
}
