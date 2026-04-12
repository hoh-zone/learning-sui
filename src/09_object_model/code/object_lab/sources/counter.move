/// 第八章对象模型：带 `key` 与 `UID` 的最小链上对象示例。
module object_lab::counter;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::TxContext;

public struct Counter has key, store {
    id: UID,
    value: u64,
}

public fun new(ctx: &mut TxContext): Counter {
    Counter {
        id: object::new(ctx),
        value: 0,
    }
}

public fun share(self: Counter) {
    transfer::public_share_object(self);
}

public fun value(self: &Counter): u64 {
    self.value
}

public fun bump(self: &mut Counter) {
    self.value = self.value + 1;
}

/// 实战练习：将计数归零。
public fun reset(self: &mut Counter) {
    self.value = 0;
}
