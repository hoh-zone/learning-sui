# 泛型

泛型（Generics）允许类型和函数在不指定具体类型的情况下进行定义，从而实现代码的复用和抽象。泛型是 Move 集合类型、框架设计以及许多高级模式的基础。通过类型参数和能力约束，Move 的泛型系统既灵活又安全。

## 泛型函数

### 基本语法

泛型函数使用尖括号 `<T>` 声明类型参数。类型参数可以用在参数类型、返回类型和函数体中：

```move
module book::generic_fun;

// 泛型函数：返回传入的值
public fun identity<T>(value: T): T {
    value
}

// 多个类型参数
public fun make_pair<T, U>(first: T, second: U): (T, U) {
    (first, second)
}

#[test]
fun generic_fun() {
    let x = identity(42u64);
    assert_eq!(x, 42);

    let flag = identity(true);
    assert_eq!(flag, true);

    let (a, b) = make_pair(10u64, true);
    assert_eq!(a, 10);
    assert_eq!(b, true);
}
```

编译器通常可以根据上下文推断类型参数，无需显式指定。

### 显式类型标注

当编译器无法推断类型时，可以使用 `function_name<Type>()` 的语法显式指定类型参数：

```move
module book::generic_explicit;

public fun default<T: drop>(): T {
    abort 0
}

public fun zero(): u64 {
    // 必须显式指定类型参数
    // default()  // 错误：编译器无法推断 T
    0
}
```

## 泛型结构体

### 基本泛型结构体

结构体也可以使用泛型类型参数：

```move
module book::generic_struct;

// 泛型容器
public struct Container<T: drop> has drop {
    value: T,
}

public fun new<T: drop>(value: T): Container<T> {
    Container { value }
}

public fun value<T: drop + copy>(container: &Container<T>): T {
    container.value
}

#[test]
fun container() {
    let int_container = new(42u64);
    assert_eq!(value(&int_container), 42);

    let bool_container = new(true);
    assert_eq!(value(&bool_container), true);
}
```

### 多类型参数

结构体可以有多个类型参数：

```move
module book::generic_pair;

public struct Pair<T: copy + drop, U: copy + drop> has copy, drop {
    first: T,
    second: U,
}

public fun new_pair<T: copy + drop, U: copy + drop>(
    first: T, second: U
): Pair<T, U> {
    Pair { first, second }
}

public fun first<T: copy + drop, U: copy + drop>(pair: &Pair<T, U>): T {
    pair.first
}

public fun second<T: copy + drop, U: copy + drop>(pair: &Pair<T, U>): U {
    pair.second
}

#[test]
fun pair() {
    let pair = new_pair(42u64, true);
    assert_eq!(pair.first, 42);
    assert_eq!(pair.second, true);

    let string_pair = new_pair(b"hello", b"world");
    assert_eq!(string_pair.first, b"hello");
    assert_eq!(string_pair.second, b"world");
}
```

## 能力约束

### 约束类型参数

可以对类型参数添加能力约束（ability constraints），要求传入的类型必须具备特定的能力：

```move
module book::generic_constraints;

// T 必须可复制和可丢弃
public struct Copyable<T: copy + drop> has copy, drop {
    value: T,
}

// T 必须可存储
public struct Storable<T: store> has store {
    value: T,
}

public fun duplicate<T: copy>(value: &T): T {
    *value
}

#[test]
fun constraints() {
    let x = 42u64;
    let copied = duplicate(&x);
    assert_eq!(copied, 42);
    assert_eq!(x, 42);
}
```

常见的能力约束组合：

| 约束 | 含义 |
|------|------|
| `T: drop` | T 可以被丢弃 |
| `T: copy` | T 可以被复制 |
| `T: copy + drop` | T 可以复制和丢弃 |
| `T: store` | T 可以存储在全局对象中 |
| `T: key + store` | T 可以作为顶层对象 |

## 幻影类型参数

### phantom 关键字

当类型参数没有在结构体的字段中使用，只是用于类型层面的区分时，需要使用 `phantom` 关键字标记。幻影类型参数是一种强大的类型安全机制：

```move
module book::generics_example;

// 幻影类型标记 —— 用于区分不同的货币
public struct USD {}
public struct EUR {}
public struct CNY {}

// phantom Currency 不在字段中使用，仅用于类型区分
public struct Balance<phantom Currency> has store, drop {
    amount: u64,
}

public fun new_balance<Currency>(amount: u64): Balance<Currency> {
    Balance { amount }
}

public fun balance_amount<Currency>(b: &Balance<Currency>): u64 {
    b.amount
}

// 只能合并相同货币的余额
public fun merge<Currency>(
    b1: &mut Balance<Currency>,
    b2: Balance<Currency>,
) {
    let Balance { amount } = b2;
    b1.amount = b1.amount + amount;
}

#[test]
fun generics_phantom() {
    let pair = Pair { first: 42u64, second: true };
    assert_eq!(pair.first, 42);
    assert_eq!(pair.second, true);

    // 幻影类型防止混合不同货币
    let mut usd = new_balance<USD>(100);
    let eur = new_balance<EUR>(200);
    let cny = new_balance<CNY>(300);

    assert_eq!(balance_amount(&usd), 100);
    assert_eq!(balance_amount(&eur), 200);
    assert_eq!(balance_amount(&cny), 300);

    // 可以合并相同货币
    let usd2 = new_balance<USD>(50);
    merge(&mut usd, usd2);
    assert_eq!(balance_amount(&usd), 150);

    // 以下代码无法编译 —— 不同货币不能合并：
    // merge(&mut usd, eur);  // 错误！类型不匹配
}

public struct Pair<T: copy + drop, U: copy + drop> has copy, drop {
    first: T,
    second: U,
}
```

### 幻影类型的优势

幻影类型参数的核心价值在于：

- **零运行时开销**：幻影类型不占用任何存储空间
- **编译期类型安全**：在编译期就能捕获类型错误，如混合不同货币
- **灵活的能力推导**：幻影类型参数不影响外层结构体的能力

## 泛型与对象

### 泛型对象

在 Sui 中，泛型常与对象结合使用，实现通用的对象容器：

```move
module book::generic_object;

public struct Container<T: store> has key, store {
    id: UID,
    value: T,
}

public fun new<T: store>(value: T, ctx: &mut TxContext): Container<T> {
    Container {
        id: object::new(ctx),
        value,
    }
}

public fun extract<T: store>(container: Container<T>): T {
    let Container { id, value } = container;
    id.delete();
    value
}

public fun borrow<T: store>(container: &Container<T>): &T {
    &container.value
}

public fun borrow_mut<T: store>(container: &mut Container<T>): &mut T {
    &mut container.value
}
```

## 小结

泛型是 Move 中实现代码复用和类型抽象的核心机制。通过类型参数 `<T>`，函数和结构体可以在不指定具体类型的情况下编写通用逻辑。能力约束（如 `T: copy + drop`）确保类型参数满足必要的能力要求。幻影类型参数（`phantom`）不占用存储空间，仅用于类型层面的区分，常用于实现货币等同质化代币的类型安全。泛型与 Sui 对象模型结合，可以构建出灵活且类型安全的智能合约框架。
