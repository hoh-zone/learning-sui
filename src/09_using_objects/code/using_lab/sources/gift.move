/// 第九章：转移与存储 API 的最小示例（`public_transfer`）。
module using_lab::gift;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::TxContext;

public struct Gift has key, store {
    id: UID,
    label: u64,
}

public fun mint(to: address, label: u64, ctx: &mut TxContext) {
    let g = Gift {
        id: object::new(ctx),
        label,
    };
    transfer::public_transfer(g, to);
}

public fun label(g: &Gift): u64 {
    g.label
}
