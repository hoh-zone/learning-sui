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
    "move.lint": true
}
```

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

Move Analyzer 是 Move 语言服务器的核心组件。在安装 Sui CLI 后，它通常已包含在内。你可以验证：

```bash
# 检查 move-analyzer 是否可用
sui move analyzer --version
```

如果 VSCode 无法找到 Move Analyzer，可能需要手动指定路径。在 VSCode 设置中搜索 "move" 并设置 `Move: Sui Path` 为 `sui` 二进制文件的完整路径：

```bash
# 查找 sui 的安装位置
which sui
```

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

本节介绍了多种编辑器的 Move 开发环境配置，其中 VSCode + Mysten Labs 官方 Move 扩展是目前最推荐的方案。关键要确保以下三个功能正常工作：**实时错误检查**（通过 Move Analyzer）、**代码格式化**（通过 Move Formatter）和**语法高亮**（通过 Move Syntax）。配合集成终端和自动化任务，你将拥有一个流畅的 Move 开发体验。下一节我们将配置钱包并获取测试币，为部署合约做准备。
