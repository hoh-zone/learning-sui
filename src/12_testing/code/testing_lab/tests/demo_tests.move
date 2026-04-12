#[test_only]
module ch12_testing_lab::demo_tests;

use sui::test_scenario;
use ch12_testing_lab::demo::{Self, Counter};

#[test]
fun test_double_pure() {
    assert!(demo::double(21) == 42);
}

#[test]
fun test_shared_counter_scenario() {
    let mut s = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let c: Counter = demo::new_counter(ctx);
        demo::share(c);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let mut c = test_scenario::take_shared<Counter>(&s);
        demo::bump(&mut c);
        assert!(demo::read(&c) == 1);
        test_scenario::return_shared(c);
    };
    test_scenario::end(s);
}
