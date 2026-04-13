# 第十九章实战 · 观测指标备忘

可在 Prometheus 中关注（名称以实际 `sui-node` 导出为准）：

- `sui_tx_execution_latency` —— 交易执行延迟分布，用于 SLA 与回归对比。
- `sui_checkpoint_sequence_number` 或等价 **最高 checkpoint** 指标 —— 与索引器游标比对，发现同步滞后。

Grafana：将上述指标做成面板并设阈值告警，便于运维先于用户发现问题。
