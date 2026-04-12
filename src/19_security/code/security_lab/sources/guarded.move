/// 第十八章：能力对象（Capability）约束敏感操作的最小模式。
module ch18_security_lab::guarded;

public struct AdminCap has key, store {
    id: object::UID,
}

public struct Vault has key {
    id: object::UID,
    balance: u64,
}

/// 仅持有 `AdminCap` 的调用者可读取金库余额（示例：真实项目需额外检查 `TxContext::sender`）。
public fun read_balance(_cap: &AdminCap, v: &Vault): u64 {
    v.balance
}
