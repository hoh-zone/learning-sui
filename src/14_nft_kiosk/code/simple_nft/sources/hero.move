/// 第十四章：最小 NFT 对象（`key + store` + UID）。
module simple_nft::hero;

use std::string::String;
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::TxContext;

public struct Hero has key, store {
    id: UID,
    name: String,
}

public fun mint(name: String, ctx: &mut TxContext): Hero {
    Hero {
        id: object::new(ctx),
        name,
    }
}

public fun transfer_to(hero: Hero, recipient: address) {
    transfer::public_transfer(hero, recipient);
}

public fun name(h: &Hero): String {
    h.name
}
