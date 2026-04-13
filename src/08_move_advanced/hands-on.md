# 第八章 · 实战练习

## 实战一：泛型约束小改

1. 进入 `src/08_move_advanced/code/01-generics-basics/`。
2. 为现有泛型函数增加一条**能力约束**（如 `copy`、`drop`）并新增一个调用示例类型。
3. `sui move build`。
4. **验收**：故意去掉约束时出现编译错误，加回后恢复通过（可保留注释说明）。

## 实战二：`type_name` 调试输出

1. 使用 `src/08_move_advanced/code/04-type-reflection/`。
2. 增加一个 `public fun`，对**两个**不同 struct 调用 `type_name::with_defining_ids` 或本章正文等价 API，比较输出差异。
3. **验收**：能在测试中或注释里记录两次输出的不同点。

## 实战三：编译模式测试跑通

1. 进入 `src/08_move_advanced/code/05-compilation-modes/`。
2. 执行 `sui move test`，阅读 `tests/modes_tests.move` 与 `sources/lib.move` 的分工。
3. **验收**：全部测试通过；能说明 `#[test]` 与 `#[test_only]` 模块的边界。
