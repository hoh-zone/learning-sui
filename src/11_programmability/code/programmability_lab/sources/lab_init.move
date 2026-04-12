/// 第十章实战：`init` 仅在发布时运行一次，向部署者发放 `LabAdminCap`。
module programmability_lab::lab_init;

use sui::object;
use sui::transfer;
use sui::tx_context::TxContext;

public struct LabAdminCap has key, store {
    id: object::UID,
}

fun init(ctx: &mut TxContext) {
    transfer::public_transfer(
        LabAdminCap {
            id: object::new(ctx),
        },
        tx_context::sender(ctx),
    );
}
