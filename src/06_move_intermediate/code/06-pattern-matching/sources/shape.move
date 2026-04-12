module ch06_06_match::shape;

public enum Shape has copy, drop {
    Circle(u64),
    Square(u64),
}

public fun area(s: &Shape): u64 {
    match (s) {
        Shape::Circle(r) => 3 * (*r) * (*r) / 1,
        Shape::Square(a) => (*a) * (*a),
    }
}
