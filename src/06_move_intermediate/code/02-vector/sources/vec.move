module ch06_02_vector::vec;

use std::vector;

public fun push_three(): u64 {
    let mut v = vector::empty();
    vector::push_back(&mut v, 1u64);
    vector::push_back(&mut v, 2u64);
    vector::push_back(&mut v, 3u64);
    *vector::borrow(&v, 2)
}

/// 实战练习：空 vector 和为 `0`。
public fun sum_u64(nums: &vector<u64>): u64 {
    let mut i = 0;
    let len = vector::length(nums);
    let mut s = 0u64;
    while (i < len) {
        s = s + *vector::borrow(nums, i);
        i = i + 1;
    };
    s
}
