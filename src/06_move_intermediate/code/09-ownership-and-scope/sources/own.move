module ch06_09_own::own;

public struct Box has drop {
    v: u64,
}

public fun consume(b: Box): u64 {
    let Box { v } = b;
    v
}
