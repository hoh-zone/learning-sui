# 小结与选型

## 核心要点

| 概念 | 一句话 |
|------|--------|
| 何时展开 | 编译 `sui move build` 时 |
| 如何定义 | `macro fun`，`$` 参数， `name!(...)` 调用 |
| 与 `fun` 区别 | 实参为**片段代入**，不是先求值再传 |
| Lambda | 仅宏参数可用 `\|...\| -> R` |
| 标准库 | `vector` / `option` 宏优先于手写循环 |

## 选型建议

1. **遍历、折叠、重复 n 次**：优先 `vector` 宏与 `u8::do!` 等。
2. **处理 `Option` 分支**：优先 `option::do!` / `destroy_or!`。
3. **断言**：`assert!` + `#[error]` 常量（Move 2024 可读错误）。
4. **自定义重复模式**：考虑 `macro fun`，但保持宏体简短、可读。

## 后续阅读

- 泛型与能力：[第八章 §8.1–8.2](../08_move_advanced/01-generics-basics.md)、[§8.2](../08_move_advanced/02-type-parameters-and-constraints.md)
- 方法语法与 `use fun`：[第六章 §6.7](../06_move_intermediate/07-struct-methods.md)
- BCS 与 `peel_*!`：[第十一章 · BCS](../11_programmability/12-bcs.md)
