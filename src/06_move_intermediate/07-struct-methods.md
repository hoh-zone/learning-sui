# 结构体方法

Move 支持接收者语法（receiver syntax），允许使用点号 `e.f()` 的方式调用结构体的方法，这使得代码更加直观和面向对象。当函数的第一个参数是模块内定义的结构体类型时，就可以通过点号语法调用。理解方法的定义与调用方式，是编写优雅 Move 代码的重要一步。

## 方法定义

### 基本语法

如果一个函数的第一个参数是当前模块内定义的结构体类型（或其引用），那么该函数可以通过点号语法调用。第一个参数被称为"接收者"（receiver）：

```move
module book::method_basic;

public struct Counter has drop {
    value: u64,
}

public fun new(): Counter {
    Counter { value: 0 }
}

// 第一个参数是 &Counter，可通过 counter.value() 调用
public fun value(self: &Counter): u64 {
    self.value
}

#[test]
fun method_call() {
    let counter = new();
    assert_eq!(counter.value(), 0);  // 点号语法调用
    assert_eq!(value(&counter), 0);  // 传统调用方式，效果相同
}
```

### 三种接收者类型

接收者参数有三种形式，分别对应不同的访问权限：

```move
module book::method_example;

public struct Counter has drop {
    value: u64,
}

public fun new(): Counter {
    Counter { value: 0 }
}

// &self —— 不可变引用：只读访问
public fun value(self: &Counter): u64 {
    self.value
}

// &mut self —— 可变引用：可以修改
public fun increment(self: &mut Counter) {
    self.value = self.value + 1;
}

// &mut self 带额外参数
public fun add(self: &mut Counter, n: u64) {
    self.value = self.value + n;
}

// self（按值传递）—— 获取所有权，消耗该实例
public fun destroy(self: Counter): u64 {
    let Counter { value } = self;
    value
}

#[test]
fun methods() {
    let mut counter = new();
    assert_eq!(counter.value(), 0);

    counter.increment();
    counter.increment();
    counter.add(8);
    assert_eq!(counter.value(), 10);

    let final_value = counter.destroy();
    assert_eq!(final_value, 10);
}
```

三种接收者的适用场景：

| 接收者类型 | 语义 | 使用场景 |
|-----------|------|---------|
| `&self` | 不可变借用 | 读取数据、查询状态 |
| `&mut self` | 可变借用 | 修改状态、更新字段 |
| `self` | 获取所有权 | 销毁对象、转换类型 |

## 方法链式调用

当方法返回 `&mut self` 或可修改的引用时，可以进行链式调用。对于返回 `void` 的可变方法，需要分步调用：

```move
module book::method_chain;

public struct Builder has drop {
    name: vector<u8>,
    value: u64,
}

public fun new(): Builder {
    Builder { name: b"", value: 0 }
}

public fun set_name(self: &mut Builder, name: vector<u8>) {
    self.name = name;
}

public fun set_value(self: &mut Builder, value: u64) {
    self.value = value;
}

// getter 以字段名命名，无 get_ 前缀
public fun value(self: &Builder): u64 {
    self.value
}

#[test]
fun builder() {
    let mut builder = new();
    builder.set_name(b"test");
    builder.set_value(42);
    assert_eq!(builder.value(), 42);
}
```

## 方法别名

### use fun 语法

`use fun` 可以为函数创建方法别名，使得非当前模块定义的函数也能用点号语法调用：

```move
module book::method_alias;

public struct Wallet has drop {
    balance: u64,
}

public fun new(balance: u64): Wallet {
    Wallet { balance }
}

fun is_empty_check(w: &Wallet): bool {
    w.balance == 0
}

// 为 is_empty_check 创建方法别名
use fun is_empty_check as Wallet.is_empty;

#[test]
fun alias() {
    let wallet = new(100);
    assert!(!wallet.is_empty());  // 通过别名调用

    let empty_wallet = new(0);
    assert!(empty_wallet.is_empty());
}
```

### public use fun

`public use fun` 可以导出方法别名，使得其他模块在导入该类型时也能使用点号语法调用。只能对当前模块定义的类型使用 `public use fun`：

```move
module book::public_alias;

public struct Token has drop {
    amount: u64,
}

public fun new(amount: u64): Token {
    Token { amount }
}

fun token_amount(t: &Token): u64 {
    t.amount
}

fun token_is_zero(t: &Token): bool {
    t.amount == 0
}

// 导出别名，其他模块导入 Token 后也能使用这些方法
public use fun token_amount as Token.amount;
public use fun token_is_zero as Token.is_zero;

#[test]
fun public_alias() {
    let token = new(50);
    assert_eq!(token.amount(), 50);
    assert!(!token.is_zero());
}
```

## 自动关联

当一个模块被导入时，该模块中以其定义的结构体类型作为第一个参数的公共函数会自动关联为该类型的方法。无需手动创建别名，导入后即可使用点号语法：

```move
module book::auto_method;

public struct Circle has drop {
    radius: u64,
}

public fun new(radius: u64): Circle {
    Circle { radius }
}

public fun area_approx(self: &Circle): u64 {
    // 简化计算，使用 3 * r * r 近似
    3 * self.radius * self.radius
}
```

在其他模块中导入后直接使用：

```move
module book::use_circle;

use book::auto_method::{Self, Circle};

fun calculate() {
    let circle: Circle = auto_method::new(10);
    let area = circle.area_approx();  // 自动关联，直接使用点号语法
    assert_eq!(area, 300);
}
```

## 小结

Move 的接收者语法让代码具有面向对象的风格，使得函数调用更加直观。方法的第一个参数决定了访问权限：`&self` 只读、`&mut self` 可修改、`self` 获取所有权。`use fun` 为函数创建方法别名，`public use fun` 可以将别名导出供其他模块使用。当模块被导入时，符合条件的公共函数会自动关联为方法，无需额外配置。
