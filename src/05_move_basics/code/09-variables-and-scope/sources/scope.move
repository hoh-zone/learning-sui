module ch05_09_variables::scope;

public fun shadow_example(): u64 {
    let x = 1u64;
    let x = x + 2;
    x
}
