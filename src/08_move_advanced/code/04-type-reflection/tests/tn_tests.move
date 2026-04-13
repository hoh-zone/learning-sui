#[test_only]
module ch07_03_typename::tn_tests;

use std::ascii;
use std::type_name;
use ch07_03_typename::tn;

#[test]
fun test_foo_and_bar_names_differ() {
    let s1: ascii::String = type_name::into_string(tn::name_of_foo());
    let s2: ascii::String = type_name::into_string(tn::name_of_bar());
    assert!(s1 != s2);
}
