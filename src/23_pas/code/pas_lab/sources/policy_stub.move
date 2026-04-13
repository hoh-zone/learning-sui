/// 第二十一章：PAS（许可资产标准）占位模块——完整策略与命名空间在独立协议仓库实现。
module ch21_pas_lab::policy_stub;

use sui::object;
use sui::tx_context::TxContext;

/// 与正文 Namespace 概念对齐的占位类型（无业务逻辑）。
public struct Namespace has key, store {
    id: object::UID,
    label: vector<u8>,
}

public fun schema_version(): u8 {
    1
}

public fun create_namespace(label: vector<u8>, ctx: &mut TxContext): Namespace {
    Namespace {
        id: object::new(ctx),
        label,
    }
}
