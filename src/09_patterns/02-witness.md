# Witness 模式

Witness（见证者）模式是 Move 中一种强大的授权机制。其核心思想是：**通过构造某个类型的实例来证明对该类型的所有权**。由于 Move 的封装规则规定只有定义结构体的模块才能创建该结构体的实例，因此 Witness 可以作为一种类型级别的"身份证明"。

本章将详细介绍 Witness 模式的原理、实现方式以及在 Sui 框架中的实际应用。

## 什么是 Witness

在 Move 中，**结构体只能在定义它的模块内被构造**。这条规则是 Witness 模式的基础。如果一个函数要求传入类型 `T` 的实例作为参数，那么只有定义 `T` 的模块才能调用该函数——因为只有该模块能创建 `T` 的实例。

这个被传入的实例就被称为 **Witness**（见证者），它"见证"了调用方确实拥有对该类型的控制权。

### 核心规则

```
结构体打包规则（Struct Packing Rule）：
只有定义结构体 S 的模块 M 才能创建 S 的实例。
```

这意味着，如果模块 A 定义了 `struct GOLD {}`，那么任何其他模块都无法凭空创建 `GOLD {}` 实例。这就是 Witness 模式的安全基础。

## 基本实现

### 定义需要 Witness 的泛型接口

```move
module examples::witness;

/// 一个需要见证者才能创建的泛型容器
public struct TypedContainer<phantom T> has key {
    id: UID,
    count: u64,
}

/// 创建新容器 - 需要类型 T 的见证者
public fun new_container<T: drop>(
    _witness: T,
    ctx: &mut TxContext,
): TypedContainer<T> {
    TypedContainer {
        id: object::new(ctx),
        count: 0,
    }
}
```

关键细节：

- `phantom T`：表示 `T` 仅在类型层面使用，不实际存储在结构体中
- `_witness: T`：参数名前的下划线表示值本身不被使用，类型才是关键
- `T: drop`：要求 `T` 具有 `drop` 能力，这样 witness 在使用后可以被自动丢弃

### 使用 Witness

```move
module examples::use_witness;

use examples::witness;

/// 我们的见证者类型 - 只有本模块能创建它
public struct GOLD has drop {}

/// 创建一个 GOLD 类型的容器
public fun create_gold_container(ctx: &mut TxContext): witness::TypedContainer<GOLD> {
    witness::new_container(GOLD {}, ctx)
}
```

在这个例子中：

1. `GOLD` 结构体定义在 `use_witness` 模块中
2. 只有 `use_witness` 模块能创建 `GOLD {}` 实例
3. 因此只有 `use_witness` 模块能调用 `new_container<GOLD>`
4. 得到的容器类型为 `TypedContainer<GOLD>`，在类型层面与其他容器区分

## Witness 与 drop 能力

Witness 类型通常具有 `drop` 能力，这意味着它在使用后可以被自动销毁。这是因为 Witness 的价值在于**创建的瞬间**——它证明了调用方有权创建该类型，使用完毕后就没有存在的必要了。

```move
module examples::witness_drop;

/// 带 drop 的 Witness - 使用后自动销毁
public struct MyWitness has drop {}

/// 不带 drop 的 Witness - 必须显式消耗
public struct StrictWitness {}

public fun use_droppable(_w: MyWitness) {
    // MyWitness 在函数结束时自动丢弃
}

public fun use_strict(w: StrictWitness) {
    // 必须显式解构
    let StrictWitness {} = w;
}
```

不带 `drop` 的 Witness 更加严格——它要求使用方必须显式处理该值，不能忽略。这在某些需要强制执行流程的场景下非常有用（详见 Hot Potato 模式）。

## 工厂模式与 Witness

Witness 模式常用于实现类型安全的工厂模式——由一个通用模块提供创建逻辑，由各业务模块通过 Witness 来定制化：

```move
module examples::token_factory;

use std::string::String;

/// 泛型代币 - 由 Witness 决定类型
public struct Token<phantom T> has key, store {
    id: UID,
    name: String,
    value: u64,
}

/// 用 Witness 创建特定类型的代币
public fun create_token<T: drop>(
    _witness: T,
    name: String,
    value: u64,
    ctx: &mut TxContext,
): Token<T> {
    Token {
        id: object::new(ctx),
        name,
        value,
    }
}

/// 合并同类型代币
public fun merge<T>(token: &mut Token<T>, other: Token<T>) {
    let Token { id, name: _, value } = other;
    id.delete();
    token.value = token.value + value;
}

/// 拆分代币
public fun split<T>(
    token: &mut Token<T>,
    amount: u64,
    ctx: &mut TxContext,
): Token<T> {
    assert!(token.value >= amount, 0);
    token.value = token.value - amount;
    Token {
        id: object::new(ctx),
        name: token.name,
        value: amount,
    }
}
```

```move
module examples::game_gold;

use std::string::String;
use examples::token_factory;

/// 游戏金币的 Witness
public struct GAME_GOLD has drop {}

public fun mint_gold(
    amount: u64,
    ctx: &mut TxContext,
): token_factory::Token<GAME_GOLD> {
    token_factory::create_token(
        GAME_GOLD {},
        std::string::utf8(b"Game Gold"),
        amount,
        ctx,
    )
}
```

这种设计的优势：

- `token_factory` 提供通用的代币逻辑（创建、合并、拆分）
- 各业务模块通过 Witness 创建专属代币类型
- 类型系统保证 `Token<GAME_GOLD>` 和 `Token<SILVER>` 不会混淆

## 在 Sui 框架中的应用

### sui::balance 中的 Supply

Sui 框架中的 `Balance` 和 `Supply` 就是 Witness 模式的典型应用：

```move
// sui::balance 模块的简化版本
public struct Supply<phantom T> has store {
    value: u64,
}

public struct Balance<phantom T> has store {
    value: u64,
}

/// 创建新的 Supply 需要 Witness
public fun create_supply<T: drop>(_witness: T): Supply<T> {
    Supply { value: 0 }
}

/// 通过 Supply 增发 Balance
public fun increase_supply<T>(supply: &mut Supply<T>, value: u64): Balance<T> {
    supply.value = supply.value + value;
    Balance { value }
}
```

（已废弃的）`coin::create_currency` 以及当前推荐的 **`coin_registry::new_currency_with_otw`** 内部都会用到 `balance::create_supply`（通过 **`coin::new_treasury_cap`** 等），OTW 用于确保每种货币的 Supply 只被创建一次。

## phantom 类型参数

在 Witness 模式中，经常会看到 `phantom` 关键字：

```move
public struct Container<phantom T> has key, store {
    id: UID,
    value: u64,
}
```

`phantom` 表示类型参数 `T` 不在结构体的字段中实际使用，它只用于在类型层面区分不同的实例。这有两个好处：

1. **无存储开销**：`T` 不占用实际存储空间
2. **能力推断更灵活**：`Container<T>` 的能力不受 `T` 的能力限制

## Witness 模式 vs Capability 模式

| 维度 | Witness | Capability |
|------|---------|------------|
| 授权方式 | 类型构造权 | 对象所有权 |
| 生命周期 | 通常即用即弃 | 持久存在 |
| 存储需求 | 无 | 占用链上存储 |
| 转移性 | 不可转移（绑定模块） | 可转移给其他账户 |
| 撤销 | 无需撤销 | 可销毁撤销 |
| 适用场景 | 类型级别的一次性授权 | 账户级别的持续授权 |

## 小结

Witness 模式利用 Move 的结构体打包规则，将类型的构造权转化为一种授权机制。它特别适用于泛型系统中的类型级别授权，如代币工厂、通用容器等场景。Witness 通常是轻量级的（具有 `drop` 能力），在证明完成后即被丢弃。与 Capability 模式相比，Witness 更适合一次性的类型证明，而 Capability 更适合持续的权限管理。两种模式经常配合使用，构建出安全、灵活的授权体系。
