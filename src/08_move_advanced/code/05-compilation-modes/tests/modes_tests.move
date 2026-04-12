#[test_only]
module ch07_04_modes::modes_tests;

use ch07_04_modes::lib;

#[test]
fun t_always_here() {
    assert!(lib::always_here() == 1);
}
