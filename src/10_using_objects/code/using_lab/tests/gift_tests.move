#[test_only]
module using_lab::gift_tests;

use sui::test_scenario::{Self, Scenario};
use using_lab::gift::{Self, Gift};

#[test]
fun test_transfer_gift() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    let bob = @0xB;
    {
        let ctx = test_scenario::ctx(&mut s);
        gift::mint(bob, 7, ctx);
    };
    test_scenario::next_tx(&mut s, bob);
    {
        let g: Gift = test_scenario::take_from_sender(&s);
        assert!(gift::label(&g) == 7);
        test_scenario::return_to_sender(&s, g);
    };
    test_scenario::end(s);
}
