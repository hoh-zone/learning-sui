module ch05_20_entry::entry_mod;

use sui::tx_context::TxContext;

#[error]
const EPingNeedPositive: vector<u8> = b"ping requires n > 0";

public fun plain(x: u64): u64 {
    x + 1
}

/// 空 `entry`（仅用于发布后可成功上链调用）。
entry fun bump(_ctx: &mut TxContext) {
}

/// 实战练习：带参数的 `entry`，`n == 0` 时触发 Clever Error。
entry fun ping(_ctx: &mut TxContext, n: u64) {
    assert!(n > 0, EPingNeedPositive);
}
