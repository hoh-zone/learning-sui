# 所有权与作用域

Move 语言采用所有权（Ownership）模型来管理值的生命周期。每个变量都有一个所有者和一个作用域，当作用域结束时，变量会被丢弃（drop）。所有权可以通过赋值或函数调用来转移，这种机制从根本上杜绝了悬垂引用和双重释放等内存安全问题。

## 作用域

### 函数作用域

每个函数定义一个作用域。在函数内声明的变量属于该函数所有，当函数执行结束时，所有局部变量都会被丢弃：

```move
module book::scope_basic;

public struct Ticket has drop {
    event: vector<u8>,
}

fun create_and_drop() {
    let _ticket = Ticket { event: b"Concert" };
    // 函数结束时，_ticket 自动被丢弃（需要 drop 能力）
}

#[test]
fun scope() {
    create_and_drop();
}
```

### 块作用域

花括号 `{ }` 创建子作用域（block scope）。子作用域中声明的变量在块结束时被丢弃，但可以通过块的最后一个表达式将值转移出去：

```move
module book::block_scope;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun block_scope() {
    let x = {
        let inner = 42u64;
        inner  // 将所有权转移到外部作用域
    };
    // inner 在这里不可用，但它的值已经转移给了 x
    assert_eq!(x, 42);

    let result = {
        let a = 10u64;
        let b = 20u64;
        a + b  // 块的返回值
    };
    assert_eq!(result, 30);
}
```

### 嵌套作用域

作用域可以嵌套。内层作用域可以访问外层作用域的变量，但外层作用域无法访问内层的局部变量：

```move
module book::nested_scope;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun nested() {
    let outer = 100u64;

    {
        let _inner = outer + 1;  // 可以访问外层变量
        assert_eq!(_inner, 101);
        // _inner 在块结束时被丢弃
    };

    // _inner 在这里不可用
    assert_eq!(outer, 100);  // outer 依然有效
}
```

## 所有权转移

### 函数调用时的所有权转移

当将一个不可复制的值作为参数传递给函数时，所有权会转移到被调用的函数。原变量变得无效，不能再使用：

```move
module book::ownership_example;

public struct Ticket has drop {
    event: vector<u8>,
}

public struct UniqueItem {
    value: u64,
}

public fun create_ticket(): Ticket {
    Ticket { event: b"Concert" }  // 所有权转移给调用者
}

public fun use_ticket(ticket: Ticket) {
    let Ticket { event: _ } = ticket;  // ticket 在这里被消耗
}

#[test]
fun ownership() {
    let ticket = create_ticket();    // ticket 归当前函数所有
    // ticket 的所有权转移给 use_ticket，此后不再有效
    use_ticket(ticket);
    // let _ = ticket.event;  // 错误！ticket 已经被移动
}
```

### 赋值时的所有权转移

将一个不可复制的值赋给另一个变量时，所有权也会转移：

```move
module book::ownership_transfer;

public struct Token has drop {
    value: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun assignment_move() {
    let token_a = Token { value: 100 };
    let token_b = token_a;  // 所有权从 token_a 转移到 token_b
    // assert_eq!(token_a.value, 100);  // 错误！token_a 已经被移动
    assert_eq!(token_b.value, 100);    // token_b 是有效的所有者
}
```

### 返回值的所有权转移

函数的返回值将所有权转移给调用者：

```move
module book::ownership_return;

public struct Wrapper has drop {
    value: u64,
}

fun make_wrapper(): Wrapper {
    Wrapper { value: 42 }
    // 所有权转移给调用者，不会在函数结束时被丢弃
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun return_ownership() {
    let wrapper = make_wrapper();  // 接收所有权
    assert_eq!(wrapper.value, 42);
    // wrapper 在测试函数结束时被丢弃
}
```

## 复制与移动

### 可复制类型

拥有 `copy` 能力的类型在赋值和传参时会自动复制，原变量仍然有效：

```move
module book::copy_example;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun copy_vs_move() {
    // u64 拥有 copy 能力，赋值时自动复制
    let a = 10u64;
    let b = a;      // a 被复制，仍然有效
    assert_eq!(a, 10);
    assert_eq!(b, 10);

    // bool 也拥有 copy 能力
    let flag = true;
    let flag_copy = flag;
    assert_eq!(flag, true);
    assert_eq!(flag_copy, true);
}
```

### 不可复制类型

没有 `copy` 能力的类型在赋值时会移动，原变量失效：

```move
module book::move_example;

public struct UniqueItem has drop {
    value: u64,
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun unique_move() {
    let item = UniqueItem { value: 1 };
    let item2 = item;  // item 被移动到 item2
    // assert_eq!(item.value, 1);  // 错误！item 已被移动
    assert_eq!(item2.value, 1);
}
```

### move 关键字

可以使用 `move` 关键字显式地表达所有权转移的意图，让代码更加清晰：

```move
module book::explicit_move;

public struct Resource has drop {
    data: u64,
}

fun consume(resource: Resource) {
    let Resource { data: _ } = resource;
}

#[test]
fun explicit_move() {
    let resource = Resource { data: 42 };
    consume(move resource);  // 显式移动
    // resource 在这里不再有效
}
```

## 析构与 drop

### 显式析构

对于没有 `drop` 能力的类型，必须显式析构（解包）来消耗它们：

```move
module book::destruct_example;

public struct Receipt {
    amount: u64,
    paid: bool,
}

public fun create_receipt(amount: u64): Receipt {
    Receipt { amount, paid: true }
}

const ENotPaid: u64 = 0;

// 必须通过解包来消耗 Receipt
public fun verify_and_consume(receipt: Receipt): u64 {
    let Receipt { amount, paid } = receipt;
    assert!(paid, ENotPaid);
    amount
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun destruct() {
    let receipt = create_receipt(500);
    let amount = verify_and_consume(receipt);
    assert_eq!(amount, 500);
}
```

### drop 能力

拥有 `drop` 能力的类型可以在作用域结束时自动丢弃，无需显式析构：

```move
module book::drop_example;

public struct Droppable has drop {
    value: u64,
}

public struct NotDroppable {
    value: u64,
}

#[test]
fun auto_drop() {
    let _d = Droppable { value: 1 };
    // 函数结束时自动丢弃，无需处理

    let nd = NotDroppable { value: 2 };
    // 必须显式析构
    let NotDroppable { value: _ } = nd;
}
```

## 小结

Move 的所有权模型确保了每个值在任意时刻只有一个所有者。值通过赋值、函数参数和返回值来转移所有权。拥有 `copy` 能力的类型可以复制，不可复制类型在赋值时会移动，原变量随即失效。作用域（函数和块）限定了变量的生命周期，作用域结束时变量被丢弃。没有 `drop` 能力的类型必须显式析构，这一机制可以用来实现"不可丢弃"的资源模式，保证重要操作不会被遗漏。
