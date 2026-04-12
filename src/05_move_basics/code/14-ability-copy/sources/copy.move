module ch05_14_ability_copy::copy_only;

public struct Score has copy, drop {
    v: u64,
}

public fun double(s: Score): u64 {
    let s2 = s;
    s.v + s2.v
}
