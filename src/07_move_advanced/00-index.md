# 第七章 · Move 语法高级

本章介绍泛型与类型反射，涉及类型参数、能力约束以及运行时类型信息，是编写可复用、类型安全的 Move 库与框架的必备内容。

## 本章内容

| 节 | 主题 | 核心知识点 |
|---|------|-----------|
| 7.1 | 泛型基础 | 泛型函数与泛型结构体、类型参数、多类型参数 |
| 7.2 | 类型参数与能力约束 | 能力约束、幻影类型参数、泛型与对象 |
| 7.3 | 类型反射 | type_name 模块、运行时类型信息与使用场景 |
| 7.4 | 编译模式（Modes） | #[mode(name)]、--mode 构建、不可发布代码 |
| 7.5 | 下标语法（Index Syntax） | #[syntax(index)]、自定义类型的索引访问与规则 |

## 节与正文、示例代码

| 节 | 正文 | 配套 `code/` |
|----|------|----------------|
| 7.1 | [泛型基础](01-generics-basics.md) | `code/01-generics-basics/` |
| 7.2 | [类型参数与能力约束](02-type-parameters-and-constraints.md) | `code/02-type-parameters-and-constraints/` |
| 7.3 | [类型反射](03-type-reflection.md) | `code/03-type-reflection/` |
| 7.4 | [编译模式（Modes）](04-compilation-modes.md) | `code/04-compilation-modes/` |
| 7.5 | [下标语法](05-index-syntax.md) | `code/05-index-syntax/` |

## 学习目标

读完本章后，你将能够：

- 编写泛型函数与泛型结构体，并正确施加能力约束
- 理解 phantom 类型参数的作用与用法
- 在需要时使用类型反射获取运行时类型信息
- 使用编译模式控制调试/测试等不可发布代码的编入与发布安全
- 为自定义类型定义下标语法（#[syntax(index)]）并遵守只读/可写成对规则

## 本章实战练习

每章 **1～3 个**动手任务见 **[hands-on.md](hands-on.md)**（目录中亦列为「本章实战练习」）。
