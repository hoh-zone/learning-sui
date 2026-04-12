module ch07_02_constraints::phantom;

public struct Marker<phantom T> has copy, drop {}

public fun new_marker<T>(): Marker<T> {
    Marker {}
}
