# 第十五章 · 客户端与 PTB

本章讲解如何从客户端与 Sui 链交互，包括 SDK 的使用、可编程交易块（PTB）的构造、链上数据的读取以及钱包集成。

## 本章内容

| 节 | 主题 | 你将学到 |
|---|------|---------|
| 13.1 | Sui Client SDK 概览 | TypeScript / Rust SDK、dApp Kit |
| 13.2 | 可编程交易块（PTB） | 概念、命令类型、链式操作 |
| 13.3 | 读取链上对象 | getObject、multiGetObjects |
| 13.4 | 动态字段查询 | getDynamicFields、getDynamicFieldObject |
| 13.5 | 分页读取 | cursor 分页、批量查询 |
| 13.6 | 交易提交与 Gas 管理 | 签名执行、Gas Budget、赞助交易 |
| 13.7 | 钱包集成 | Wallet Standard、dApp Kit 组件 |

## 学习目标

读完本章后，你将能够：

- 使用 TypeScript SDK 读写 Sui 链上数据
- 构造复杂的可编程交易块（PTB）
- 在 React 应用中集成 Sui 钱包
