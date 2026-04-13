# 宏函数（导读）

宏函数（`macro fun`）在**编译期**展开，调用写为 `name!(...)`，可接收 **lambda** 参数，用于表达「遍历向量」「处理 `Option`」等重复模式。第六章此处只保留**最短上手**；**系统讲解**（为什么需要宏、编译期管线、展开语义、标准库向量/Option 宏、`assert!` 与 BCS 相关宏、排错与选型）见 **[第十一章 · Move 宏函数详解](../11_move_macros/00-index.md)**（目录上位于第十章之后）。

## 最小示例

```move
macro fun add($a: u64, $b: u64): u64 { $a + $b }

public fun three(): u64 { add!(1u64, 2u64) }
```

标准库中优先使用 `vector` 的 `do!`、`fold!`、`tabulate!` 等，以及 `option` 的 `do!`、`destroy_or!`，详见第十一章各节。

## 配套代码

本章配套仍为 **`code/08-macros/`**（`sui move build`）。与第十一章示例 **`../11_move_macros/code/macro_lab/`** 可对照阅读。
