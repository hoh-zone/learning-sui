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

## 与本书其它章的衔接

按全书侧边栏顺序，**第八章**、**第九～十章**在本章之前；**第十二章**（Framework 等）起在本章之后。

- 泛型与能力：[第八章 §8.1–8.2](../08_move_advanced/01-generics-basics.md)、[§8.2](../08_move_advanced/02-type-parameters-and-constraints.md)
- 方法语法与 `use fun`：[第六章 §6.7](../06_move_intermediate/07-struct-methods.md)
- 对象模型与使用对象：[第九～十章索引](../09_object_model/00-index.md)
- 宏函数导读：[第六章 §6.8](../06_move_intermediate/08-macros.md)
- 后续：**BCS** 与 `peel_*!`：[第十二章 §12.12](../12_programmability/12-bcs.md)
