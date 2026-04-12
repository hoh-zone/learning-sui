module ch06_07_methods::counter;

public struct Counter has copy, drop {
    value: u64,
}

public fun new_counter(v: u64): Counter {
    Counter { value: v }
}

fun value(self: &Counter): u64 {
    self.value
}

public fun read(c: &Counter): u64 {
    c.value()
}
