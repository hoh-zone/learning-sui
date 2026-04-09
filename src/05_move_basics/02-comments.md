# 注释

注释是代码中用于解释和说明的文本，不会被编译器执行。Move 语言支持三种注释方式：行注释、块注释和文档注释。合理使用注释可以大幅提升代码的可读性和可维护性，特别是文档注释能够用于自动生成 API 文档。

## 行注释

行注释以 `//` 开头，从 `//` 到该行末尾的所有内容都会被编译器忽略：

```move
module book::line_comments;

// 这是一个行注释
public fun add(a: u64, b: u64): u64 {
    a + b // 也可以放在代码后面
}
```

行注释适用于简短的说明，是最常用的注释形式。

## 块注释

块注释以 `/*` 开头，以 `*/` 结尾，可以跨越多行：

```move
module book::block_comments;

/* 这是一个块注释
   可以跨越多行
   适合用于较长的说明 */
public fun multiply(a: u64, b: u64): u64 {
    a * b
}

public fun complex_logic(x: u64): u64 {
    /* 临时禁用某段逻辑时也可以用块注释
    let temp = x * 2;
    temp + 1
    */
    x + 1
}
```

块注释支持嵌套，即你可以在块注释内部再嵌套一个块注释，这在临时注释掉一段已经包含块注释的代码时非常有用。

## 文档注释

文档注释以 `///` 开头，用于为模块、结构体、函数等生成文档。文档注释必须放在被注释项的 **正上方**：

```move
/// This is a doc comment for the module
module book::comments_example;

/// A simple counter struct
public struct Counter has key {
    id: UID,
    /// The current count value
    count: u64,
}

// This is a line comment
/* This is a block comment
   spanning multiple lines */

/// Increment the counter by 1
public fun increment(counter: &mut Counter) {
    counter.count = counter.count + 1;
}
```

### 文档注释的最佳实践

文档注释应该描述 **为什么** 和 **做什么**，而不是 **怎么做**（代码本身已经说明了怎么做）：

```move
module book::doc_best_practices;

/// 用户积分记录，用于奖励系统的积分追踪。
/// 积分不可转让，只能由系统增减。
public struct Points has key {
    id: UID,
    /// 当前积分余额
    balance: u64,
    /// 历史累计获得积分（不会因消费减少）
    total_earned: u64,
}

/// 为用户增加积分。
/// 同时更新当前余额和历史累计。
///
/// 参数：
/// - `points`: 积分记录的可变引用
/// - `amount`: 要增加的积分数量
public fun earn(points: &mut Points, amount: u64) {
    points.balance = points.balance + amount;
    points.total_earned = points.total_earned + amount;
}
```

## 空白字符

在 Move 中，空白字符（空格、制表符、换行符）对程序的语义没有影响，仅影响代码的可读性。以下两段代码在编译器看来完全等价：

```move
module book::whitespace_example;

public fun add(a: u64, b: u64): u64 { a + b }

public fun add_formatted(
    a: u64,
    b: u64,
): u64 {
    a + b
}
```

虽然空白不影响语义，但建议遵循社区代码风格约定，保持一致的缩进（4 个空格）和合理的换行，以提升代码可读性。

## 小结

注释是代码可读性的重要组成部分。本节核心要点：

- **行注释** `//`：最常用，适合简短说明
- **块注释** `/* */`：可跨行，支持嵌套，适合较长说明或临时禁用代码
- **文档注释** `///`：放在定义之前，用于生成 API 文档
- 空白字符不影响程序语义，但应遵循统一的代码风格
- 好的注释应解释 "为什么"，而非重复代码已经表达的 "怎么做"
