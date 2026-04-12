module ch07_03_typename::tn;

use std::type_name::{Self, TypeName};

public fun name_of_u64(): TypeName {
    type_name::with_defining_ids<u64>()
}

/// 实战练习：两个不同 struct，便于比较 `TypeName` 字符串。
public struct Foo has copy, drop {}

public struct Bar has copy, drop {}

public fun name_of_foo(): TypeName {
    type_name::with_defining_ids<Foo>()
}

public fun name_of_bar(): TypeName {
    type_name::with_defining_ids<Bar>()
}
