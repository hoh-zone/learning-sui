module ch05_11_struct::point;

public struct Point has copy, drop {
    x: u64,
    y: u64,
}

public fun origin(): Point {
    Point { x: 0, y: 0 }
}
