# 第十一章 · 实战练习

## 实战一：事件里加字段

1. 进入 `src/11_programmability/code/programmability_lab/`。
2. 在事件 struct 中增加一个字段（如 `sender: address` 或 `tick: u8`），同步修改 `emit` 调用处。
3. `sui move build`（及测试若存在）。
4. **验收**：编译通过；能说明为何事件类型需要 `copy + drop`。

## 实战二：`init` 与一次性逻辑

1. 参考 `src/12_patterns/code/patterns_lab/` 中的 `fun init`（第十一与十二章交界，可对照阅读）。
2. 在 `programmability_lab` 或副本包中，为模块添加 `init`，只做**一件**事（如发一个 `AdminCap` 给部署者）。
3. **验收**：`sui move test` 或本地构建通过；能解释 `init` 何时运行一次。

## 实战三：Clock 只读调用（链下组合）

1. 阅读第十一章「Epoch 与时间」与 `src/21_advanced_topics/code/advanced_lab/sources/clock_probe.move`。
2. 写一段 **PTB 伪代码**（不必上链）：传入共享 `Clock`，调用 `timestamp_ms` 读时间，再 `moveCall` 你的业务函数。
3. **验收**：步骤顺序合理（Clock 作为共享对象传入）。
