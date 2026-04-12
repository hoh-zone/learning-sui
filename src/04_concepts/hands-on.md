# 第四章 · 实战练习

## 实战一：从 Move.toml 追到链上地址

1. 打开 `src/04_concepts/code/concepts_demo/Move.toml`，查看 `[addresses]` 与 `[package]`。
2. 将该包 `sui move build` 通过后，若已发布，用 Explorer 查看**命名地址**与链上 `Package ID` 的对应关系。
3. **验收**：能口头解释「清单里的 named address」与「发布后的 0x… package」不是同一概念、但如何关联。

## 实战二：读一个 Coin 对象的字段

1. 在测试网任选自己钱包中的 **SUI coin 对象 ID**（`0x2::sui::SUI`）。
2. 使用 `sui client object <ID> --json`（或 Explorer）查看 `digest`、`version`、`owner`。
3. **验收**：写出该对象作为交易输入时，为什么需要 **object ref**（id + version + digest）。

## 实战三：干跑一笔简单 PTB（概念）

1. 阅读本章「交易」一节，列出 PTB 中三个你能在文档里找到的元素（例如：命令列表、gas、发送者）。
2. 不必须上链：写出你打算用 PTB 完成的**一件小事**（如：转 NFT、调 `entry`）。
3. **验收**：3～5 条 bullet，说明你的 PTB 里会有哪些命令类型（`MoveCall`、`TransferObjects` 等）。
