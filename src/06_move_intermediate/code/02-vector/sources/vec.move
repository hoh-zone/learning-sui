module ch06_02_vector::vec;

use std::vector;

public fun push_three(): u64 {
    let mut v = vector::empty();
    vector::push_back(&mut v, 1u64);
    vector::push_back(&mut v, 2u64);
    vector::push_back(&mut v, 3u64);
    *vector::borrow(&v, 2)
}
