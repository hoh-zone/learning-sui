# 第六章 · Move 语法进阶

本章在语法基础之上，介绍标准库与常用集合类型、枚举与模式匹配、方法语法、宏函数，以及所有权与引用，帮助你写出结构清晰、可维护的 Move 模块；**最后一节**集中整理 **Move 2024 Edition** 与清单约定，供系统对照与迁移旧代码。

## 本章内容

| 节 | 主题 | 核心知识点 |
|---|------|-----------|
| 6.1 | 标准库概览 | Move 标准库常用模块与使用方式 |
| 6.2 | Vector | 向量操作、下标语法、遍历、常用方法 |
| 6.3 | Option | None / Some、安全取值与模式匹配 |
| 6.4 | String | UTF-8 与 ASCII、字符串操作 |
| 6.5 | 枚举 | enum 定义、带数据变体、能力、实例化与限制 |
| 6.6 | 模式匹配 | match 表达式、穷尽性、通配符、解构变体数据 |
| 6.7 | 结构体方法 | 方法语法、self 参数、链式调用 |
| 6.8 | 宏函数（导读） | 最短上手；系统篇见 **[第 7 章](../11_move_macros/00-index.md)**（全书目录中位于第 10 章之后） |
| 6.9 | 所有权与作用域 | 所有权转移、变量生命周期 |
| 6.10 | 引用（& 与 &mut） | &T / &mut T、借用规则与使用场景 |
| 6.11 | Move 2024 Edition 与语法对照 | `edition`、Framework `rev`、新旧语法与迁移工具 |

## 节与正文、示例代码

| 节 | 正文 | 配套 `code/`（可 `sui move build`） |
|----|------|--------------------------------------|
| 6.1 | [标准库概览](01-standard-library.md) | `code/01-standard-library/` |
| 6.2 | [Vector](02-vector.md) | `code/02-vector/` |
| 6.3 | [Option](03-option.md) | `code/03-option/` |
| 6.4 | [String](04-string.md) | `code/04-string/` |
| 6.5 | [枚举](05-enum.md) | `code/05-enum/` |
| 6.6 | [模式匹配](06-pattern-matching.md) | `code/06-pattern-matching/` |
| 6.7 | [结构体方法](07-struct-methods.md) | `code/07-struct-methods/` |
| 6.8 | [宏函数（导读）](08-macros.md) | `code/08-macros/`；详解见 [`../11_move_macros/`](../11_move_macros/00-index.md) |
| 6.9 | [所有权与作用域](09-ownership-and-scope.md) | `code/09-ownership-and-scope/` |
| 6.10 | [引用](10-references.md) | `code/10-references/` |
| 6.11 | [Move 2024 Edition 与语法对照](11-move-2024.md) | （对照篇，沿用全书各章 `code/`） |

## 学习目标

读完本章后，你将能够：

- 熟练使用标准库中的 Vector、Option、String 等类型
- 用枚举与模式匹配表达多分支逻辑与错误处理
- 用结构体方法和宏函数组织与复用代码
- 理解所有权与引用，写出正确且高效的 Move 代码
- 能解释 `Move.toml` 中 `edition` / `rev` 的约定，并对照 Move 2024 与旧版语法差异（§6.11）

## 本章实战练习

每章 **1～3 个**动手任务见 **[hands-on.md](hands-on.md)**（目录中亦列为「本章实战练习」）。
