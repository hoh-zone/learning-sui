/// 第十四章：自定义 Coin（`coin_registry::new_currency_with_otw` + `finalize` 精简可编译版）。
module silver_coin::silver;

use std::string;
use sui::coin::{Self, TreasuryCap, Coin};
use sui::coin_registry;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

public struct SILVER() has drop;

const DECIMALS: u8 = 9;

fun init(otw: SILVER, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<SILVER>(
        otw,
        DECIMALS,
        string::utf8(b"SILVER"),
        string::utf8(b"Silver"),
        string::utf8(b"Book example token"),
        string::utf8(b""),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
}

public fun mint(
    treasury_cap: &mut TreasuryCap<SILVER>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(c, recipient);
}

public fun burn(treasury_cap: &mut TreasuryCap<SILVER>, c: Coin<SILVER>) {
    coin::burn(treasury_cap, c);
}

/// 实战练习：从 CLI / PTB 铸币到当前发送者（需传入 `TreasuryCap` 对象）。
entry fun mint_to_sender(
    treasury_cap: &mut TreasuryCap<SILVER>,
    amount: u64,
    ctx: &mut TxContext,
) {
    mint(treasury_cap, amount, tx_context::sender(ctx), ctx);
}
