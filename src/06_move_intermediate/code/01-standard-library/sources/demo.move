module ch06_01_stdlib::demo;

use std::vector;

public fun empty_vec_len(): u64 {
    let v = vector::empty<u64>();
    vector::length(&v)
}
