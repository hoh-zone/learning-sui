# 第五章 · 实战练习

## 实战一：跟踪一节一包 — 从编译到改代码

1. 任选一节目录，例如 `src/05_move_basics/code/04-integers/`。
2. 在对应 `sources/*.move` 中**新增**一个 `public fun`，做简单整数运算（注意溢出与类型）。
3. 执行 `sui move build`。
4. **验收**：编译通过；你能在模块中定位到自己的新函数。

## 实战二：断言与错误路径

1. 打开 `src/05_move_basics/code/18-assert-and-abort/`。
2. 故意引入一个会触发 `assert!` 失败的条件，运行 `sui move test` 或写最小 `#[test]` 观察失败信息。
3. 再改回合理条件，使测试/构建恢复通过。
4. **验收**：保留或记录一条「失败时 Move VM 的报错样式」，便于以后对照 Clever Errors / 错误码。

## 实战三：`entry` 与脚本调用

1. 使用 `src/05_move_basics/code/20-entry-and-public/`，阅读其中的 `entry` 函数。
2. 将该包发布到测试网后，用 `sui client call` 或 TypeScript `Transaction` 构造一笔**只调该 entry** 的交易（参数按函数签名填）。
3. **验收**：链上交易成功；你能从 Effects 里看到被调用的函数名。
