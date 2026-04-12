module ch06_10_refs::refs;

public fun bump(r: &mut u64) {
    *r = *r + 1;
}

public fun demo(): u64 {
    let mut x = 1u64;
    bump(&mut x);
    x
}
