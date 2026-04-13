# 第十二章 · 实战练习

以下任务与 [章索引 · 建议阅读路线](00-index.md) 中的阶段 A～E 对应，可按兴趣选做。

## 实战一：事件里加字段（阶段 B）

1. 进入 `src/12_programmability/code/programmability_lab/`。
2. 在事件 struct 中增加一个字段（如 `sender: address` 或 `tick: u8`），同步修改 `emit` 调用处。
3. `sui move build`（及测试若存在）。
4. **验收**：编译通过；能说明为何事件类型需要 `copy + drop`，并对照 [§12.1](01-sui-framework.md) 中 `event` 在框架中的位置。

## 实战二：`init` 与一次性逻辑（阶段 A）

1. 参考 `src/13_patterns/code/patterns_lab/` 中的 `fun init`（第十一与十二章交界，可对照阅读）。
2. 在 `programmability_lab` 或副本包中，为模块添加 `init`，只做**一件**事（如发一个 `AdminCap` 给部署者）。
3. **验收**：`sui move test` 或本地构建通过；能解释 `init` 何时运行一次、升级时为何不再次运行。

## 实战三：Clock 只读调用（阶段 C）

1. 阅读 [§12.5 · Epoch 与时间](05-epoch-and-time.md) 与 `src/22_advanced_topics/code/advanced_lab/sources/clock_probe.move`（若仓库中有）。
2. 写一段 **PTB 伪代码**（不必上链）：传入共享 `Clock`，调用 `timestamp_ms` 读时间，再 `moveCall` 你的业务函数。
3. **验收**：步骤顺序合理（`Clock` 作为共享对象传入）；能区分 `ctx.epoch()` 与 `Clock::timestamp_ms` 的精度差异。

## 实战四：VecMap 与 Table 二选一（阶段 D）

1. 设计一个「地址 → 积分」映射：条目数可能从几十增长到上万。
2. 分别说明：若用 **`VecMap`** 会有什么问题；若用 **`Table`** 优势在哪（对照 [§12.1](01-sui-framework.md) 集合表与 [§12.6](06-collections.md)、[§12.10](10-dynamic-collections.md)）。
3. **验收**：书面回答即可，无需长代码。

## 实战五：框架地图自测（全章）

1. 打开 [§12.1](01-sui-framework.md)，遮住「集合选型」表，在纸上默写 `VecMap` / `Table` / `ObjectTable` / `Bag` 四类在「键同质、值是否对象、数据住哪」上的区别。
2. **验收**：能口述无误后再回到表格核对。
