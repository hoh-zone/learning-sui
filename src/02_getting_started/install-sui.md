# 安装 Sui CLI

Sui CLI 是开发 Move 智能合约和与 Sui 网络交互的核心工具。它集成了项目创建、编译、测试、部署和链上交互等全套功能，是每位 Sui 开发者的必备工具。本节将介绍多种安装方式，并帮助你完成环境验证。

## 安装方式

### 使用 suiup 安装（推荐）

`suiup` 是 Sui 官方提供的版本管理工具，类似于 Rust 的 `rustup`。它可以方便地安装、切换和管理不同版本的 Sui CLI。

```bash
# 安装 suiup
curl -fsSL https://sui.io/suiup.sh | bash

# 使用 suiup 安装最新稳定版 Sui CLI
suiup install sui
```

安装完成后，`sui` 命令将自动添加到你的 `PATH` 中。如果终端提示找不到命令，请重新打开终端或执行 `source ~/.bashrc`（或 `source ~/.zshrc`）。

### 使用 Homebrew 安装（macOS）

macOS 用户可以通过 Homebrew 快速安装：

```bash
brew install sui
```

### 使用 Chocolatey 安装（Windows）

Windows 用户可以通过 Chocolatey 包管理器安装：

```bash
choco install sui
```

### 下载预编译二进制文件

你也可以直接从 GitHub Releases 页面下载对应平台的预编译二进制文件：

1. 访问 [Sui Releases](https://github.com/MystenLabs/sui/releases)
2. 选择目标版本，下载对应操作系统的压缩包
3. 解压后将 `sui` 二进制文件移动到系统 `PATH` 目录下

```bash
# macOS / Linux 示例
tar -xzf sui-<version>-<platform>.tgz
sudo mv sui /usr/local/bin/
```

### 从源码编译安装

如果你需要最新的开发版本，或者想要自定义编译选项，可以通过 Cargo 从源码编译：

```bash
# 前提：已安装 Rust 工具链
# 安装 mainnet 分支版本
cargo install --git https://github.com/MystenLabs/sui.git sui --branch mainnet

# 安装 testnet 分支版本
cargo install --git https://github.com/MystenLabs/sui.git sui --branch testnet
```

> **注意**：从源码编译需要较长时间（通常 10-30 分钟），且需要足够的磁盘空间和内存。建议至少预留 2GB 内存和 10GB 磁盘空间。

## 验证安装

安装完成后，运行以下命令验证：

```bash
sui client --version
```

你应该看到类似如下的输出：

```bash
sui 1.45.2-abc1234
```

你还可以查看所有可用命令：

```bash
sui --help
```

## 使用 suiup 管理版本

在实际开发中，你可能需要在不同网络环境之间切换。例如，testnet 和 mainnet 可能运行着不同版本的 Sui 协议。`suiup` 可以帮助你轻松管理多个版本。

```bash
# 查看当前安装的版本
suiup show

# 安装特定网络对应的版本
suiup install sui --network testnet
suiup install sui --network mainnet

# 切换到 testnet 版本
suiup use --network testnet

# 切换到 mainnet 版本
suiup use --network mainnet
```

> **最佳实践**：在部署合约到特定网络前，确保你使用的 Sui CLI 版本与目标网络的协议版本兼容。使用 `suiup` 切换到对应版本可以避免兼容性问题。

## 常见问题排查

### 命令找不到

如果安装后终端提示 `command not found: sui`：

```bash
# 检查安装路径
which sui

# 如果使用 suiup，确保 PATH 包含 ~/.sui/bin
echo $PATH | tr ':' '\n' | grep sui

# 手动添加到 PATH（添加到 ~/.zshrc 或 ~/.bashrc）
export PATH="$HOME/.sui/bin:$PATH"
source ~/.zshrc
```

### 依赖缺失（源码编译）

从源码编译时可能遇到依赖问题：

```bash
# macOS：安装 Xcode 命令行工具
xcode-select --install

# Ubuntu/Debian：安装必要依赖
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev pkg-config cmake clang
```

### 版本不匹配

如果遇到与网络版本不兼容的错误：

```bash
# 查看当前版本
sui client --version

# 检查网络协议版本
sui client envs

# 使用 suiup 切换到匹配版本
suiup install sui --network <target-network>
suiup use --network <target-network>
```

### 权限问题

在 Linux/macOS 上可能遇到权限问题：

```bash
# 确保二进制文件有执行权限
chmod +x /usr/local/bin/sui

# 如果安装到系统目录需要 sudo
sudo mv sui /usr/local/bin/
```

## 小结

本节介绍了五种安装 Sui CLI 的方式：suiup（推荐）、Homebrew、Chocolatey、预编译二进制和源码编译。推荐使用 `suiup`，因为它不仅安装简便，还提供了版本管理功能，方便你在不同网络环境间切换。安装完成后，请务必通过 `sui client --version` 验证安装是否成功。下一节我们将配置 IDE 开发环境，为编写 Move 代码做好准备。
