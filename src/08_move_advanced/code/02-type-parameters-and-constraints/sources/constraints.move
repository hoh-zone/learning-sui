/// 与正文 7.2「能力约束」示例对应（非 phantom）。
module ch07_02_constraints::constraints;

public struct Copyable<T: copy + drop> has copy, drop {
    value: T,
}

public struct Storable<T: store> has store {
    value: T,
}

public fun duplicate<T: copy>(value: &T): T {
    *value
}

public fun copyable_value<T: copy + drop>(c: &Copyable<T>): &T {
    &c.value
}

public fun storable_value<T: store>(s: &Storable<T>): &T {
    &s.value
}
