module ch07_03_typename::tn;

use std::type_name::{Self, TypeName};

public fun name_of_u64(): TypeName {
    type_name::with_defining_ids<u64>()
}
