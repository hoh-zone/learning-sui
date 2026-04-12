module ch05_20_entry::entry_mod;

use sui::tx_context::TxContext;

public fun plain(x: u64): u64 {
    x + 1
}

entry fun bump(_ctx: &mut TxContext) {
}
