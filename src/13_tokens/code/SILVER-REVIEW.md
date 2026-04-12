# 第十三章实战 · `silver.move` 自查（对接第十八章清单）

| 项 | 结论（请自行勾选） |
|----|-------------------|
| `mint` / `entry` 可见性与调用路径 | 仅持有 `TreasuryCap` 可铸币；`mint_to_sender` 暴露为 `entry` 需在 PTB 中传入可变 Treasury 对象 |
| 溢出 | `amount` 为 `u64`，`coin::mint` 内部行为以 Framework 为准；大额业务应链下校验 |
| 错误与 `abort` | `init` 依赖 OTW 与 `coin_registry`；失败时在客户端查看 **Clever Errors**（`#[error]` 常量的人类可读消息） |
