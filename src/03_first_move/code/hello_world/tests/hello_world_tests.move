#[test_only]
module hello_world::hello_world_tests;

use hello_world::hello_world;
use std::string::String;

#[test]
fun test_hello_world() {
    let s: String = hello_world::hello_world();
    assert!(s == b"Hello, World!".to_string());
}
