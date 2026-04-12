#[test_only]
module simple_nft::hero_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use simple_nft::hero::{Self, Hero};

#[test]
fun test_mint_hero() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let h = hero::mint(string::utf8(b"Sword"), ctx);
        hero::transfer_to(h, @0xA);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let h: Hero = test_scenario::take_from_sender(&s);
        assert!(hero::name(&h) == string::utf8(b"Sword"));
        test_scenario::return_to_sender(&s, h);
    };
    test_scenario::end(s);
}
