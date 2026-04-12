#[test_only]
module ch05_18_assert::checks_tests;

use ch05_18_assert::checks;

#[test]
fun test_check_positive_ok() {
    checks::check_positive(1);
}

/// Clever Error：`abort_code` 会随源码行变化，此处仅用 `expected_failure` 断言「会失败」。
#[test]
#[expected_failure]
fun test_check_positive_fails_on_zero() {
    checks::check_positive(0);
}

#[test]
fun test_abort_if_zero_ok() {
    assert!(checks::abort_if_zero(5) == 5);
}

#[test]
#[expected_failure]
fun test_abort_if_zero_fails() {
    checks::abort_if_zero(0);
}
