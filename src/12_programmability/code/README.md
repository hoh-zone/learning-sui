# 第十二章 · 示例代码（高级可编程性）

与 [§12.1](01-sui-framework.md) 及全章各节对照：`programmability_lab` 集中演示 **事件**、**`init` 一次**、以及 **Clock 在 PTB 中的组合方式**（链下伪代码）。

## `programmability_lab/`

| 文件 | 对应节 | 说明 |
|------|--------|------|
| `sources/events.move` | [§12.4](../04-events.md) | `CounterEvent`（含 `tick`）与 `emit_tick` |
| `sources/lab_init.move` | [§12.3](../03-module-initializer.md) | 发布时向部署者发放 `LabAdminCap`（`init` 仅一次） |
| `ptb_clock_hint.md` | [§12.5](../05-epoch-and-time.md) | `Clock` + `moveCall` 的 PTB 伪代码（TypeScript 思路） |

```bash
cd programmability_lab
sui move build
sui move test
```

动态字段、Table、`Balance` 等更大示例分散在本书其它章配套包中；全章**阅读路线**见 [章索引 · 建议阅读路线](../00-index.md)。
