# 第十章 · 示例代码（高级可编程性）

## `programmability_lab/`

- **`events.move`**：`CounterEvent`（含 `tick` 字段）与 `emit_tick`。
- **`lab_init.move`**：发布时向部署者发放 `LabAdminCap`（`init` 一次）。
- **`ptb_clock_hint.md`**：Clock + `moveCall` 的 PTB 伪代码（TypeScript）。

```bash
cd programmability_lab
sui move build
sui move test
```
