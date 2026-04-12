# 第七章 · 实战练习

## 实战一：编译宏示例包

1. 进入 `src/07_move_macros/code/macro_lab/`。
2. 执行 `sui move build`。
3. 打开 `sources/demo.move`，对照 [§7.3–7.6](03-macro-definition.md) 理解 `add!`、`fold!`、`do_ref!` 等调用。

**验收**：编译无错误；能向同伴口述「宏在编译期展开、链上无宏」。

## 实战二：把一段手写循环改成宏

1. 在 `demo.move` 的 `#[test]` 中新增一个手写 `while` 遍历 `vector`，求元素之和。
2. 将同一逻辑改写为 `fold!`（或 `do_ref!` + 累加变量）。
3. 对比两种写法的行数与可读性。

**验收**：两种写法结果一致；能说明为何宏版本更不易漏改下标。

## 实战三：Option 宏

1. 构造 `option::some(42u64)` 与 `option::none()`。
2. 对 `some` 用 `option::do!` 执行一次加倍；对 `none` 用 `destroy_or!(0)` 得到默认值。

**验收**：理解 `destroy_or!` 会**消费** `Option`。
