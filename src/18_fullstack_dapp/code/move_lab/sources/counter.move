/// 第十六章 Move 侧：发布时发给部署者的计数器，供前端用 PTB 调用 `entry`。
module ch16_move_lab::counter;

public struct Counter has key, store {
    id: object::UID,
    n: u64,
}

fun init(ctx: &mut tx_context::TxContext) {
    transfer::public_transfer(
        Counter {
            id: object::new(ctx),
            n: 0,
        },
        tx_context::sender(ctx),
    );
}

entry fun bump(self: &mut Counter) {
    self.n = self.n + 1;
}

public fun value(self: &Counter): u64 {
    self.n
}
