module ch05_16_conditionals::branch;

public fun max3(a: u64, b: u64, c: u64): u64 {
    let m = if (a > b) { a } else { b };
    if (m > c) { m } else { c }
}
