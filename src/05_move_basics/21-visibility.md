# 可见性修饰符

可见性修饰符控制模块成员（函数、结构体等）的访问范围，是 Move 模块化设计的核心机制。Move 提供四种可见性级别：私有（private）、公共（public）、包内可见（public(package)）和入口（entry），每种级别对应不同的访问权限和使用场景。合理使用可见性可以实现良好的封装，保护模块的内部实现细节。

## 私有可见性（private）

### 默认访问级别

不添加任何修饰符的函数默认是私有的，只能在定义它的模块内部调用：

```move
module book::private_example;

// 私有函数 —— 只有本模块内部可以调用
fun internal_helper(): u64 {
    42
}

fun another_helper(): u64 {
    // 同一模块内，可以调用私有函数
    internal_helper() + 8
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun private_only_in_module() {
    assert_eq!(internal_helper(), 42);
    assert_eq!(another_helper(), 50);
}
```

私有函数是模块封装的基础。将实现细节隐藏在私有函数中，只暴露必要的公共接口，是良好 API 设计的关键。

## 公共可见性（public）

### 对外开放的接口

使用 `public` 修饰的函数可以被任何模块调用，是模块对外暴露的 API：

```move
module book::public_example;

const EInvalid: u64 = 0;

// 公共函数 —— 任何模块都可以调用
public fun calculate(a: u64, b: u64): u64 {
    validate(a, b);
    a + b
}

// 内部验证逻辑保持私有
fun validate(a: u64, b: u64) {
    assert!(a > 0 && b > 0, EInvalid);
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun public_calculate() {
    assert_eq!(calculate(3, 7), 10);
}
```

需要注意：**一旦函数被标记为 `public`，它就成为模块的公共 API。在包升级时，不能删除或更改已有的 `public` 函数签名**，否则会破坏依赖它的外部模块。

## 包内可见性（public(package)）

### 包级别的共享

`public(package)` 允许同一个包（package）内的所有模块调用该函数，但包外的模块无法访问。它取代了早期版本中的 `friend` 机制：

```move
module book::package_example;

// 包内可见 —— 同一个包的模块可以调用，外部包不行
public(package) fun package_helper(): u64 {
    100
}

// 公共函数调用包内函数
public fun public_api(): u64 {
    package_helper() * 2
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun package_visibility() {
    assert_eq!(package_helper(), 100);
    assert_eq!(public_api(), 200);
}
```

`public(package)` 非常适合用于包内多个模块之间的协作函数，这些函数需要被包内其他模块使用，但不应该暴露给外部。

## 入口可见性（entry）

### 交易的入口点

`entry` 函数可以直接从 Sui 交易中被调用，但**不能**从其他 Move 模块调用。它是连接链下客户端和链上逻辑的桥梁：

```move
module book::entry_example;

public struct Greeting has key {
    id: UID,
    text: vector<u8>,
}

// 入口函数 —— 只能从交易调用，不能被其他模块调用
entry fun create_greeting(text: vector<u8>, ctx: &mut TxContext) {
    let greeting = Greeting {
        id: object::new(ctx),
        text,
    };
    transfer::transfer(greeting, ctx.sender());
}

// entry 函数作为交易入口，不可被其他模块调用，也不返回值（与 public 二选一，不要写 public entry）
entry fun update_greeting(greeting: &mut Greeting, text: vector<u8>) {
    greeting.text = text;
}
```

## 可见性对比示例

### 完整的可见性示例

将所有可见性级别放在一个模块中对比：

```move
module book::visibility_example;

// 私有 —— 仅本模块可调用
fun internal_helper(): u64 { 42 }

// 公共 —— 任何模块都可调用
public fun public_api(): u64 { internal_helper() }

// 包内可见 —— 同一包的模块可调用
public(package) fun package_helper(): u64 { 100 }

// 入口 —— 仅从交易调用
entry fun do_something(ctx: &mut TxContext) {
    let _ = ctx;
}
```

### 从其他模块调用

下面展示在同一包的另一个模块中，哪些函数可以调用，哪些不行：

```move
module book::try_access;

use book::visibility_example;

fun test() {
    visibility_example::public_api();      // OK —— 公共函数
    visibility_example::package_helper();   // OK —— 同一包内
    // visibility_example::internal_helper(); // 错误！私有函数不可调用
    // visibility_example::do_something();    // 错误！entry 函数不能被模块调用
}
```

## 结构体字段的可见性

### 字段始终是私有的

Move 中结构体的字段始终是私有的，无法直接从模块外部访问。需要通过公共函数来提供读写接口：

```move
module book::field_visibility;

public struct User has drop {
    name: vector<u8>,
    age: u64,
}

public fun new(name: vector<u8>, age: u64): User {
    User { name, age }
}

// 通过公共函数提供读取接口
public fun name(user: &User): &vector<u8> {
    &user.name
}

public fun age(user: &User): u64 {
    user.age
}

// 通过公共函数提供修改接口
public fun set_age(user: &mut User, new_age: u64) {
    user.age = new_age;
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun field_access() {
    let mut user = new(b"Alice", 25);
    assert_eq!(age(&user), 25);

    set_age(&mut user, 26);
    assert_eq!(age(&user), 26);
}
```

> **重要提示**：虽然结构体字段在代码层面是私有的，但这并不意味着数据是机密的。链上对象的所有数据都是公开可读的。字段的私有性是一种编程封装，不是数据隐私保护。

## 小结

Move 提供四种可见性级别来控制函数的访问范围：`private`（默认）仅模块内部可见，`public` 对所有模块开放，`public(package)` 限制在同一包内，`entry` 仅供交易直接调用。结构体的字段始终是私有的，需要通过公共函数暴露读写接口。合理运用可见性修饰符是良好模块设计的基础——暴露最小必要的接口，隐藏内部实现细节。
