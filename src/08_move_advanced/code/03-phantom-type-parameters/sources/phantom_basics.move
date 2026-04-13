/// 与正文 7.3「phantom 类型参数」对应。
module ch07_03_phantom::phantom_basics;

/// 类型参数 T 未出现在任何字段中 → 必须使用 `phantom`
public struct Marker<phantom T> has copy, drop {}

public fun new_marker<T>(): Marker<T> {
    Marker {}
}

/// 货币标记：编译期区分 USD / EUR，运行时不存储类型值
public struct USD {}

public struct EUR {}

public struct Balance<phantom Currency> has store, drop {
    amount: u64,
}

public fun new_balance<Currency>(amount: u64): Balance<Currency> {
    Balance { amount }
}

public fun merge<Currency>(b1: &mut Balance<Currency>, b2: Balance<Currency>) {
    let Balance { amount } = b2;
    b1.amount = b1.amount + amount;
}

/// T 出现在字段中 → **不能**对该参数使用 `phantom`
public struct Wrapper<T: store> has store {
    value: T,
}

public fun wrap_value<T: store>(value: T): Wrapper<T> {
    Wrapper { value }
}

public fun unwrap_value<T: store>(w: Wrapper<T>): T {
    let Wrapper { value } = w;
    value
}

/// 常见：phantom + 能力约束（与框架中 `Coin<phantom T>`、`Display<phantom T: key>` 类似）
public struct TagForKeyType<phantom T: key> has copy, drop {}
