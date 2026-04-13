# 标准库：Option、`assert!` 与其它宏

## Option：`do!` 与 `destroy_or!`

- **`option::do!(opt, |x| …)`**：当 `opt` 为 `some` 时执行 lambda，传入内部值；常用于取代「`is_some` + `destroy_some` + 分支」的冗长写法。
- **`opt.destroy_or!(default)`**：消耗 `opt`，为 `some` 则返回值，为 `none` 则使用默认值（默认值须已存在）。
- **`opt.destroy_or!(abort E)`**：为 `none` 时以错误码 `E` 中止（`E` 为 `u64` 错误常量）。

与 [第六章 §6.3](../06_move_intermediate/03-option.md) 的 API 配合阅读，宏侧更强调**消费 `Option` 时的控制流**。

## 内建 `assert!`

`assert!(cond, code)` 是语言内建宏：条件为假时以 `code` 中止。**错误行号**指向**调用 `assert!` 的源码位置**，便于定位（与宏展开映射一致的设计目标）。详见 [第五章 §5.19](../05_move_basics/19-assert-and-abort.md)。

## BCS：`peel_vec!` / `peel_option!`

在 [`sui::bcs`](../../12_programmability/12-bcs.md) 中，对向量或 `Option` 的解码常配合 **`peel_vec!`、`peel_option!`** 等宏，在解码器闭包中组合 `peel_*` 调用。它们同样是**编译期展开**，减少手写样板代码。详细步骤见第十二章 BCS 一节。

## 测试辅助

`#[test_only]` 模块中常用 `assert!`；`std::unit_test` 等模块还提供断言与调试辅助（见[测试章](../../14_testing/03-test-utilities.md)）。这些与业务宏无强耦合，但同属「减少重复」的宏工具箱。

## 小结

把 **Option 宏**当作控制流压缩写法，把 **`assert!`** 当作带行号映射的检查点，把 **BCS 宏**当作解码样板生成器；需要细节时跳到对应章节即可。
