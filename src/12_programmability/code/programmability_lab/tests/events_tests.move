#[test_only]
module programmability_lab::events_tests;

use programmability_lab::events;

#[test]
fun test_emit() {
    events::emit_tick(42);
}
