module ch06_05_enum::color;

public enum Color has copy, drop, store {
    Red,
    Blue,
}

public fun pick(): Color {
    Color::Red
}
