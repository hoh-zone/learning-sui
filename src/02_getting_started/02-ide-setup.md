# IDE 开发环境配置

一个良好的 IDE 配置可以显著提升 Move 开发效率。通过语言服务器的支持，你可以获得代码补全、实时错误检查、跳转定义等功能，避免许多低级错误。本节将详细介绍如何配置主流编辑器来支持 Move 开发。

## Visual Studio Code（推荐）

VSCode 是目前 Move 开发体验最好的编辑器，拥有最完善的插件生态。

### 安装 Move 扩展

#### Move（Mysten Labs 官方扩展）

这是 Sui Move 开发的核心扩展，由 Mysten Labs 官方维护，提供：

- **Move Analyzer 语言服务器**：实时语法和类型检查
- **代码补全**：智能提示函数、类型、模块名等
- **跳转定义**：`Cmd/Ctrl + 点击` 跳转到符号定义
- **悬停文档**：鼠标悬停显示类型信息和文档
- **错误诊断**：编译错误实时显示在编辑器中

安装步骤：

1. 打开 VSCode
2. 按 `Cmd+Shift+X`（macOS）或 `Ctrl+Shift+X`（Windows/Linux）打开扩展面板
3. 搜索 "Move" 并安装由 **Mysten Labs** 发布的扩展

> **注意**：市场上有多个名为 "Move" 的扩展，请确认发布者是 **Mysten Labs**，而非其他第三方。

#### Move Formatter

基于 `prettier-plugin-move` 的代码格式化扩展，帮助你保持代码风格一致：

1. 在扩展面板搜索 "Move Formatter" 并安装
2. 在 VSCode 设置中将 Move 文件的默认格式化工具设为此扩展

在 VSCode 的 `settings.json` 中添加：

```json
{
    "[move]": {
        "editor.defaultFormatter": "mysten.prettier-move",
        "editor.formatOnSave": true
    }
}
```

#### Move Syntax

提供增强的 Move 语法高亮支持，让代码更易阅读。在扩展面板搜索 "Move Syntax" 并安装即可。

### VSCode 推荐配置

以下是一份针对 Move 开发优化的 VSCode 配置：

```json
{
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.rulers": [100],
    "editor.wordWrap": "off",
    "[move]": {
        "editor.defaultFormatter": "mysten.prettier-move",
        "editor.formatOnSave": true,
        "editor.tabSize": 4
    },
    "files.associations": {
        "Move.toml": "toml"
    }
}
```

### 工作区设置

对于多包项目，建议创建 `.vscode/settings.json` 进行工作区级别配置：

```json
{
    "move.sui.path": "/usr/local/bin/sui",
    "move.server.path": "/path/to/move-analyzer",
    "move.lint": true
}
```

其中 `move.server.path` 仅在扩展找不到 `move-analyzer` 时需要填写；`move.sui.path` 仅在 `sui` 不在默认 `PATH` 上时需要填写。

## 其他编辑器

### IntelliJ IDEA

JetBrains 系列 IDE 用户可以使用 Move Language Plugin：

1. 打开 `Settings/Preferences → Plugins → Marketplace`
2. 搜索 "Move Language"，安装由 **MoveFuns** 发布的插件
3. 重启 IDE

该插件提供：

- Move 语法高亮
- 基本代码补全
- 项目结构识别
- Move.toml 文件支持

> **提示**：IntelliJ 的 Move 插件功能不如 VSCode 扩展完善，但对于习惯 JetBrains 生态的开发者来说仍是不错的选择。

### Emacs

Emacs 用户可以使用 `move-mode`：

```bash
# 通过 MELPA 安装
M-x package-install RET move-mode RET
```

或在 Emacs 配置文件中添加：

```elisp
(use-package move-mode
  :ensure t
  :mode "\\.move\\'"
  :hook (move-mode . (lambda ()
                       (setq tab-width 4)
                       (setq indent-tabs-mode nil))))
```

### Zed

Zed 编辑器通过其扩展系统提供 Move 支持：

1. 打开 Zed
2. 通过命令面板 `Cmd+Shift+P` 搜索 "Extensions"
3. 搜索并安装 Move 语言扩展

### GitHub Codespaces

如果你不想配置本地环境，GitHub Codespaces 是一个很好的选择：

1. 在 Sui 相关仓库中点击 "Code → Codespaces → New codespace"
2. Codespaces 会自动配置开发环境
3. 在线上 VSCode 中安装上述推荐的 Move 扩展

## 配置 Move Analyzer

**`move-analyzer` 是独立的语言服务器程序**：在系统里表现为单独的 **`move-analyzer` 可执行文件**，由 Mysten 的 Move VSCode 扩展通过 LSP 调用。它**不是** `sui` CLI 的子命令——没有 `sui move analyzer` 这类用法；**构建与测试**仍由 **`sui move build` / `sui move test`** 完成，与语言服务器是两回事。

### 安装（推荐：suiup）

与[第二章 §2.1 · 安装 Sui CLI 与 Suiup](01-install-sui.md)一致，**推荐用 suiup 安装** `move-analyzer`，便于与 `sui`、`mvr` 等统一版本管理：

```bash
suiup install move-analyzer
```

安装完成后（若 shell 已按 suiup 说明加载 `PATH`），可在终端验证：

```bash
which move-analyzer
move-analyzer --version
```

若找不到命令，执行 `suiup which` 查看各工具的安装路径，把对应 `bin` 目录加入 `PATH`，或直接在 VSCode 里为扩展指定二进制路径（见下）。

### VSCode 中的两项路径（勿混淆）

扩展里常见两个设置，含义不同：

| 设置（用户可在设置 UI 中搜索） | 指向谁 | 用途 |
|-------------------------------|--------|------|
| **`move.sui.path`**（Move: Sui Path） | **`sui` 可执行文件** | 扩展内执行构建、测试、trace 等，调用的是 `sui move …` |
| **`move.server.path`**（Move: Analyzer Path） | **`move-analyzer` 可执行文件** | 语法检查、跳转定义、悬停类型等 LSP 能力 |

默认情况下，扩展会在 **`~/.sui/bin`**（Windows 为 `C:\Users\<用户>\.sui\bin`）查找 **`move-analyzer`**。通过 suiup 安装时若二进制不在该目录，请将 **`move.server.path`** 设为 `which move-analyzer` 输出的完整路径，并重启 VSCode。

```bash
which sui
which move-analyzer
```

> **备选**：也可依赖扩展安装时下载的平台 `move-analyzer`，或按 [Sui 文档 · Move IDE](https://docs.sui.io/references/ide/move) 使用 `cargo install … sui-move-lsp` 等方式；无论何种来源，扩展都是通过 **`move.server.path`**（或默认目录）定位 **`move-analyzer`**，与 **`sui` 的路径无关**。

## 开发工作流

一个高效的 Move 开发工作流通常包括以下步骤：

### 编辑 - 检查 - 构建 - 测试循环

```bash
# 1. 编辑代码（在 IDE 中进行，实时错误检查）

# 2. 构建项目
sui move build

# 3. 运行测试
sui move test

# 4. 运行特定测试
sui move test test_function_name

# 5. 查看测试覆盖
sui move test --coverage
```

### 集成终端

建议在 VSCode 中使用集成终端（`Ctrl + ~`），这样你可以在同一个窗口中编辑代码和运行命令。你可以设置常用命令的快捷方式：

```json
// .vscode/tasks.json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Move Build",
            "type": "shell",
            "command": "sui move build",
            "group": "build",
            "problemMatcher": []
        },
        {
            "label": "Move Test",
            "type": "shell",
            "command": "sui move test",
            "group": "test",
            "problemMatcher": []
        }
    ]
}
```

配置完成后，你可以通过 `Cmd+Shift+B`（macOS）或 `Ctrl+Shift+B`（Windows/Linux）快速运行构建任务。

## 小结

本节介绍了多种编辑器的 Move 开发环境配置，其中 VSCode + Mysten Labs 官方 Move 扩展是目前最推荐的方案。关键要确保以下三个功能正常工作：**实时错误检查**（通过独立可执行文件 **`move-analyzer`**，推荐 **`suiup install move-analyzer`**）、**代码格式化**（通过 Move Formatter）和**语法高亮**（通过 Move Syntax）；并分清 **`move.server.path`（move-analyzer）** 与 **`move.sui.path`（sui CLI）**。配合集成终端和自动化任务，你将拥有一个流畅的 Move 开发体验。下一节我们将配置钱包并获取测试币，为部署合约做准备。
