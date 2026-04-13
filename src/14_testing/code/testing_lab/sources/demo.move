/// 第十二章：可单测的纯函数 + 可配合 `test_scenario` 的链上对象。
module ch12_testing_lab::demo;

public struct Counter has key, store {
    id: object::UID,
    value: u64,
}

public fun double(x: u64): u64 {
    x * 2
}

public fun new_counter(ctx: &mut tx_context::TxContext): Counter {
    Counter {
        id: object::new(ctx),
        value: 0,
    }
}

#[allow(lint(share_owned))]
public fun share(self: Counter) {
    transfer::public_share_object(self);
}

public fun bump(self: &mut Counter) {
    self.value = self.value + 1;
}

public fun read(self: &Counter): u64 {
    self.value
}
