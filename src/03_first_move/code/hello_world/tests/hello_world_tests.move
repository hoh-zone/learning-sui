#[test_only]
module hello_world::hello_world_tests;

use hello_world::hello_world::{Self, Hello};
use std::unit_test::destroy;

#[test]
fun test_greeting() {
    let ctx = &mut tx_context::dummy();
    let hello: Hello = hello_world::new_hello(ctx);
    assert!(hello_world::greeting(&hello) == b"Hello, World!".to_string());
    destroy(hello);
}
