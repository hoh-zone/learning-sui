#[test_only]
module ch07_01_generics::gen_tests;

use ch07_01_generics::gen;

#[test]
fun test_duplicate_pair_u64() {
    let (a, b) = gen::duplicate_pair(1u64, 2u64);
    assert!(a == 1 && b == 2);
}
