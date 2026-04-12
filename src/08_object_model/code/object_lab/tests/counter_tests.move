#[test_only]
module object_lab::counter_tests;

use sui::test_scenario::{Self, Scenario};
use object_lab::counter::{Self, Counter};

#[test]
fun test_counter_object() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let c: Counter = counter::new(ctx);
        counter::share(c);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let mut c = test_scenario::take_shared<Counter>(&s);
        counter::bump(&mut c);
        test_scenario::return_shared(c);
    };
    test_scenario::end(s);
}
