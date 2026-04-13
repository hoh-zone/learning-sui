# 第十四章 · 实战练习

## 实战一：testing_lab 全绿 + 新用例

1. 进入 `src/14_testing/code/testing_lab/`。
2. `sui move test`，确认 `test_double_pure` 与 `test_shared_counter_scenario` 通过。
3. 新增第三个 `#[test]`：测试 `double(0)` 或 `Counter` 连续 `bump` 两次后的值。
4. **验收**：测试总数 ≥ 3 且全通过。

## 实战二：故意失败再修复

1. 暂时改坏 `demo::double` 或断言条件，观察 `sui move test` 的失败输出。
2. 用本章「好的测试」标准，给失败信息写一条**改进测试消息**的建议（如增加 `assert!` 第二个参数）。
3. 恢复原代码。
4. **验收**：记录一次「红→绿」过程。

## 实战三：跨模块 `#[test_only]`

1. 阅读 `src/09_object_model/code/object_lab/tests/` 与 `testing_lab/tests/` 的模块声明差异。
2. 列出测试模块允许访问 `public(package)` 的条件（结合本章「扩展外部模块」若有）。
3. **验收**：简短问答笔记。
