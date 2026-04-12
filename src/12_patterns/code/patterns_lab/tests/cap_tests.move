#[test_only]
module patterns_lab::cap_tests;

use sui::test_scenario::{Self, Scenario};
use sui::transfer;
use sui::tx_context::sender;
use patterns_lab::capability::{Self, AdminCap};

#[test]
fun test_mint_cap() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let cap = capability::create_for_test(ctx);
        transfer::public_transfer(cap, sender(ctx));
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let cap: AdminCap = test_scenario::take_from_sender(&s);
        assert!(capability::is_admin(&cap));
        test_scenario::return_to_sender(&s, cap);
    };
    test_scenario::end(s);
}
