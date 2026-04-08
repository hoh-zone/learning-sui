# 引用

引用（Reference）允许在不转移所有权的情况下访问值。Move 提供两种引用类型：不可变引用 `&T`（只读访问）和可变引用 `&mut T`（读写访问）。引用是 Move 中最常用的参数传递方式，通过借用检查器（borrow checker）在编译期保证引用的安全使用。

## 引用运算符一览

| 语法 | 类型 | 说明 |
|------|------|------|
| `&e` | `&T`（e: T 且 T 非引用） | 创建不可变引用 |
| `&mut e` | `&mut T` | 创建可变引用 |
| `&e.f` | `&T`（e.f: T） | 对字段 f 的不可变引用 |
| `&mut e.f` | `&mut T` | 对字段 f 的可变引用 |
| `freeze(e)` | `&T`（e: &mut T） | 将可变引用转为不可变引用 |

`&e.f` / `&mut e.f` 既可对结构体直接取字段引用，也可在已有引用上“延伸”（如 `&s_ref.f`）。同一模块内的嵌套结构体可链式写：`&a.b.c`。注意：**引用不能再次取引用**，即不存在 `&&T`。

## 引用类型

### 不可变引用 &T

不可变引用提供只读访问，不能通过它修改值：

```move
module book::immutable_ref;

public struct Wallet has drop {
    balance: u64,
}

public fun new(balance: u64): Wallet {
    Wallet { balance }
}

// 接收不可变引用，只能读取
public fun balance(wallet: &Wallet): u64 {
    wallet.balance
}

#[test]
fun immutable_ref() {
    let wallet = new(100);
    let b = balance(&wallet);   // 创建不可变引用
    assert_eq!(b, 100);
    // wallet 仍然有效，所有权没有转移
    assert_eq!(balance(&wallet), 100);
}
```

### 可变引用 &mut T

可变引用提供读写访问，可以修改被引用的值：

```move
module book::mutable_ref;

public struct Wallet has drop {
    balance: u64,
}

public fun new(balance: u64): Wallet {
    Wallet { balance }
}

// 接收可变引用，可以修改值
public fun deposit(wallet: &mut Wallet, amount: u64) {
    wallet.balance = wallet.balance + amount;
}

public fun balance(wallet: &Wallet): u64 {
    wallet.balance
}

#[test]
fun mutable_ref() {
    let mut wallet = new(100);
    deposit(&mut wallet, 50);      // 创建可变引用
    assert_eq!(balance(&wallet), 150);
    deposit(&mut wallet, 30);
    assert_eq!(balance(&wallet), 180);
}
```

## 实际案例：地铁卡

用一个地铁卡的例子来理解引用的三种使用方式——购买（获取所有权）、出示（不可变借用）、刷卡（可变借用）、回收（转移所有权）：

```move
module book::reference_example;

public struct Card has drop {
    rides: u64,
}

const ENoRides: u64 = 0;

// 购买：返回拥有的 Card
public fun purchase(): Card {
    Card { rides: 5 }
}

// 出示：不可变借用（只读）
public fun remaining_rides(card: &Card): u64 {
    card.rides
}

// 刷卡：可变借用（修改）
public fun use_ride(card: &mut Card) {
    assert!(card.rides > 0, ENoRides);
    card.rides = card.rides - 1;
}

// 回收：获取所有权（消耗）
public fun recycle(card: Card) {
    let Card { rides: _ } = card;
}

#[test]
fun references() {
    let mut card = purchase();

    // 不可变借用 —— 只是查看
    assert_eq!(remaining_rides(&card), 5);

    // 可变借用 —— 修改状态
    use_ride(&mut card);
    use_ride(&mut card);
    assert_eq!(remaining_rides(&card), 3);

    // 移动 —— 转移所有权
    recycle(card);
    // card 在这里不再有效
}
```

## 解引用

### 使用 * 解引用

对引用使用 `*` 运算符可以获取引用指向的值的副本。被引用的类型必须拥有 `copy` 能力：

```move
module book::deref_example;

#[test]
fun deref() {
    let value = 42u64;
    let ref_value = &value;

    // 解引用获取值的副本
    let copied = *ref_value;
    assert_eq!(copied, 42);
    assert_eq!(value, 42);  // 原值不受影响
}
```

### 通过可变引用修改

可以通过解引用可变引用来修改值。**读** `*e` 要求被引用类型有 `copy` 能力（读会复制值）；**写** `*e1 = e2` 要求被引用类型有 `drop` 能力（写会丢弃旧值）。因此不能通过引用复制或销毁“资源”类型（如无 copy/drop 的资产）。

```move
module book::deref_mut;

#[test]
fun deref_mut() {
    let mut value = 10u64;
    let ref_mut = &mut value;
    *ref_mut = 20;
    assert_eq!(value, 20);
}
```

### freeze 与子类型

在需要 `&T` 的地方可以传入 `&mut T`：编译器会在需要时插入 `freeze`，将可变引用视为不可变使用。因此类型系统把 **`&mut T` 当作 `&T` 的子类型**：任何接受 `&T` 的表达式也可以接受 `&mut T`，反之则不成立（不能把 `&T` 赋给 `&mut T` 或传给需要 `&mut T` 的参数）。

### 引用的复制与写入规则

在 Move 中，**引用可以被多次复制**，同一时刻存在多个对同一值的引用（包括多个 `&mut`）在类型上是被允许的；只有在**通过可变引用写入**时，才要求该可变引用是“唯一可写”的。这与许多语言里“同一时刻仅一个可变借用”的直觉不同，但写入前的唯一性保证同样严格。

### 引用不可存储

引用和元组是**仅有的**不能作为结构体字段类型存储的类型，因此引用不能进入全局存储或 Sui 对象，只能在一次执行过程中临时存在，程序结束时全部销毁。

## 借用规则

### 基本规则

Move 的借用检查器确保引用的安全使用，遵循以下规则：

1. **在任意时刻**，对同一个值要么有一个可变引用，要么有多个不可变引用，但不能同时拥有两者
2. **引用不能悬垂**——被引用的值在引用存在期间不能被移动或丢弃
3. **不能返回对局部变量的引用**——局部变量在函数结束时被丢弃，引用会变成悬垂引用

```move
module book::borrow_rules;

public struct Data has drop, copy {
    value: u64,
}

#[test]
fun multiple_immutable() {
    let data = Data { value: 42 };
    let ref1 = &data;
    let ref2 = &data;
    // 多个不可变引用可以同时存在
    assert_eq!(ref1.value, 42);
    assert_eq!(ref2.value, 42);
}

#[test]
fun mutable_exclusive() {
    let mut data = Data { value: 42 };
    let ref_mut = &mut data;
    // 可变引用期间，不能有其他引用
    ref_mut.value = 100;
    assert_eq!(data.value, 100);
}
```

### 引用不能返回局部变量

函数不能返回对局部变量的引用，因为局部变量在函数结束后就不存在了：

```move
module book::no_dangling;

public struct Container has drop {
    value: u64,
}

// 这是正确的 —— 返回对参数的引用（getter 以字段名命名，无 get_ 前缀）
public fun value(container: &Container): &u64 {
    &container.value
}

// 以下代码无法编译：
// fun dangling_ref(): &u64 {
//     let local = 42u64;
//     &local  // 错误！local 在函数结束时被丢弃
// }

#[test]
fun ref_to_field() {
    let container = Container { value: 99 };
    let value_ref = value(&container);
    assert_eq!(*value_ref, 99);
}
```

## 引用与所有权的选择

在设计函数签名时，选择合适的参数类型：

| 参数类型 | 含义 | 调用后原值 |
|---------|------|-----------|
| `T` | 获取所有权 | 原变量失效 |
| `&T` | 不可变借用 | 原变量仍有效 |
| `&mut T` | 可变借用 | 原变量仍有效（可能被修改） |

```move
module book::ref_choice;

public struct Account has drop {
    balance: u64,
}

// 获取所有权 —— 消耗 Account
public fun close(account: Account): u64 {
    let Account { balance } = account;
    balance
}

// 不可变借用 —— 只读查询（getter 以字段名命名）
public fun balance(account: &Account): u64 {
    account.balance
}

// 可变借用 —— 修改状态
public fun deposit(account: &mut Account, amount: u64) {
    account.balance = account.balance + amount;
}

#[test]
fun ref_choice() {
    let mut account = Account { balance: 100 };

    // 查询 —— 不可变借用
    assert_eq!(balance(&account), 100);

    // 修改 —— 可变借用
    deposit(&mut account, 50);
    assert_eq!(balance(&account), 150);

    // 关闭 —— 转移所有权
    let final_balance = close(account);
    assert_eq!(final_balance, 150);
}
```

## 小结

引用是 Move 中访问值的核心机制。不可变引用 `&T` 提供只读访问，可变引用 `&mut T` 提供读写访问，两者都不会转移所有权。借用检查器在编译期确保同一时刻不会同时存在可变引用和不可变引用，也不允许返回对局部变量的引用。在设计函数签名时，应根据需要选择参数类型：只读查询用 `&T`，需要修改用 `&mut T`，需要消耗或转移用 `T`。
