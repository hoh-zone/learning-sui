# 第二章 · 开发环境搭建

本章将指导你从零搭建完整的 Sui Move 开发环境，包括 CLI 工具、IDE 配置、钱包创建和网络连接。**Move 2024 Edition 的完整语法对照与 `Move.toml` 约定**集中在[第六章 §6.11](../06_move_intermediate/11-move-2024.md)，避免入门阶段信息过载；前三章只需跟示例能 **`sui move build`** 即可。

## 本章内容

| 节 | 主题 | 你将学到 |
|---|------|---------|
| 2.1 | 安装 Sui CLI 与 Suiup | 用 Suiup 安装/切换 `sui`；备选 Homebrew、预编译包、源码编译；版本与诊断 |
| 2.2 | IDE 与编辑器配置 | VS Code 插件、Move Analyzer、代码补全 |
| 2.3 | 创建钱包与获取测试币 | CLI 钱包管理、网络切换、水龙头领币 |

## 学习目标

读完本章后，你将能够：

- 安装 **Suiup** 与 **Sui CLI**，在本地运行 `sui` / `suiup` 并查看版本（必要时切换 testnet/devnet 构建）
- 在 VS Code 中获得 Move 代码的语法高亮和错误提示
- 拥有一个 devnet/testnet 钱包并持有测试 SUI

## 本章实战练习

每章 **1～3 个**动手任务见 **[hands-on.md](hands-on.md)**（目录中亦列为「本章实战练习」）。
