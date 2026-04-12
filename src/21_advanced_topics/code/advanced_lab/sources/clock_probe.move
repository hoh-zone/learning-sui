/// 第二十章：读取链上 `Clock`（共享对象 `0x6`）的毫秒时间戳。
module ch20_advanced_lab::clock_probe;

use sui::clock::{Self, Clock};

public fun timestamp_ms(clock: &Clock): u64 {
    clock::timestamp_ms(clock)
}
