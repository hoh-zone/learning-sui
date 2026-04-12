# 第八章 · 实战练习

## 实战一：共享 Counter 场景测通

1. 进入 `src/08_object_model/code/object_lab/`。
2. 执行 `sui move test`，读懂 `tests/counter_tests.move` 中 `test_scenario` 的流程。
3. **验收**：测试全绿；能口述「哪一事务创建了对象、哪一事务修改了共享对象」。

## 实战二：自己加一次 `bump`

1. 在同一包中，为 `Counter` 增加一个 `public fun reset(self: &mut Counter)`（置 0）或 `double(self: &mut Counter)`。
2. 更新或新增测试，覆盖新逻辑。
3. **验收**：`sui move test` 通过。

## 实战三：链上对照（可选）

1. 将 `object_lab` 发布到测试网，创建共享 `Counter` 对象。
2. 用 Explorer 查看该共享对象的 `version` 在多次调用前后的变化。
3. **验收**：记录至少两次交易 digest 与对象 version。
