module ch05_08_expression::expr;

public fun choose(use_first: bool, a: u64, b: u64): u64 {
    if (use_first) { a } else { b }
}
