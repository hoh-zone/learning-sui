/// 第十四章：最小 NFT 对象（`key + store` + UID）。
module simple_nft::hero;

use std::string::{Self, String};
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

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

/// 实战练习：`entry` 铸造并转给交易发送者。
entry fun mint_to_sender(name_bytes: vector<u8>, ctx: &mut TxContext) {
    let h = mint(string::utf8(name_bytes), ctx);
    transfer::public_transfer(h, tx_context::sender(ctx));
}
