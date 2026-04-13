/// 第十章：链上事件（`event::emit`）最小示例。
module programmability_lab::events;

use sui::event;

public struct CounterEvent has copy, drop {
    value: u64,
    tick: u8,
}

public fun emit_tick(value: u64, tick: u8) {
    event::emit(CounterEvent { value, tick });
}
