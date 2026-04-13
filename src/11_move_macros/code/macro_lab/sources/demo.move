/// 第七章宏示例：自定义宏与 vector / option 标准库宏。
module ch07_macro_lab::demo;

macro fun add($a: u64, $b: u64): u64 {
    $a + $b
}

public fun three(): u64 {
    add!(1u64, 2u64)
}

#[test]
fun test_add_macro() {
    assert!(three() == 3);
}

#[test]
fun test_fold_and_do_ref() {
    let v = vector[1u64, 2, 3, 4, 5];
    let folded = v.fold!(0u64, |acc, e| acc + e);
    assert!(folded == 15);

    let mut sum = 0u64;
    let v2 = vector[1u64, 2, 3];
    v2.do_ref!(|e| sum = sum + *e);
    assert!(sum == 6);
}

#[test]
fun test_tabulate() {
    let indices = vector::tabulate!(5, |i| i);
    assert!(indices == vector[0u64, 1, 2, 3, 4]);
}

#[test]
fun test_option_do_and_destroy_or() {
    let s = option::some(21u64);
    let mut doubled = 0u64;
    s.do!(|x| doubled = x * 2);
    assert!(doubled == 42);

    let n = option::none<u64>();
    let z = n.destroy_or!(99u64);
    assert!(z == 99);
}
