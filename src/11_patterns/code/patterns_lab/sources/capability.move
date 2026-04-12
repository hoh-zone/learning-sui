/// 第十一章：Capability 模式最小示例（AdminCap）。
module patterns_lab::capability;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

public struct AdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let cap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(cap, tx_context::sender(ctx));
}

public fun is_admin(_cap: &AdminCap): bool {
    true
}

#[test_only]
public fun create_for_test(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}
