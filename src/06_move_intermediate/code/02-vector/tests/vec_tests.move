#[test_only]
module ch06_02_vector::vec_tests;

use std::vector;
use ch06_02_vector::vec;

#[test]
fun test_sum_empty() {
    let v = vector::empty();
    assert!(vec::sum_u64(&v) == 0);
}

#[test]
fun test_sum_three() {
    let mut v = vector::empty();
    vector::push_back(&mut v, 10u64);
    vector::push_back(&mut v, 20u64);
    vector::push_back(&mut v, 12u64);
    assert!(vec::sum_u64(&v) == 42);
}
