# entry 与 public 函数

Move 函数有多种可见性级别，控制可被谁调用。**入口函数（entry）** 是 Sui 交易的直接入口，可从客户端发起；**公共函数（public）** 可被任意模块调用。

## 四种可见性

| 修饰符 | 可调用范围 |
|--------|------------|
| （无 / 私有） | 仅本模块内部 |
| `public` | 任意模块 |
| `public(package)` | 同一包内模块 |
| `entry` | 仅可从交易直接调用，不可被其他 Move 模块调用 |

```move
module book::function_example;

// 私有函数 — 仅模块内部
fun add(a: u64, b: u64): u64 {
    a + b
}

// 公共函数 — 任何模块都可调用
public fun multiply(a: u64, b: u64): u64 {
    a * b
}

// 包内可见
public(package) fun internal_multiply(a: u64, b: u64): u64 {
    a * b
}
```

## entry 函数

`entry` 函数是 Sui 交易的入口点，可以直接从客户端发起的交易中被调用，但不能从其他 Move 模块中调用。参数类型通常限于基础类型、对象和 `&mut TxContext`：

```move
module book::entry_example;

public struct Counter has key {
    id: UID,
    value: u64,
}

entry fun create_counter(ctx: &mut TxContext) {
    let counter = Counter {
        id: object::new(ctx),
        value: 0,
    };
    transfer::transfer(counter, ctx.sender());
}

entry fun increment(counter: &mut Counter) {
    counter.value = counter.value + 1;
}
```

## 调用其他模块的函数

通过 `模块名::函数名()` 调用其他模块的公共函数，需先用 `use` 导入：

```move
module book::caller_example;

use book::function_example;

fun call_public() {
    let result = function_example::multiply(3, 4);
    assert!(result == 12);
}
```

## 小结

- **可见性**：私有、`public`、`public(package)`、`entry`
- **entry**：交易入口，仅可从交易调用，不能从其他模块调用
- **调用方式**：`模块名::函数名()`，需先 `use` 导入
