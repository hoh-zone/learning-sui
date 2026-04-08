# Suiup — Sui 生态工具链管理器

Suiup 是 Mysten Labs 官方推出的 Sui 生态 CLI 安装与版本管理工具。通过 suiup，你可以一键安装、升级和切换 Sui CLI 及其他生态工具，无需手动下载二进制文件或从源码编译。

## 为什么使用 Suiup

在没有 suiup 之前，安装 Sui CLI 通常需要：

- 安装 Rust 工具链
- 从源码编译 `sui`（耗时较长）
- 手动管理不同网络版本的切换

suiup 解决了这些痛点：

| 功能 | 说明 |
|------|------|
| **一键安装** | 自动下载对应平台的预编译二进制 |
| **版本管理** | 同时安装多个版本，自由切换 |
| **网络对齐** | 直接安装 testnet / devnet / mainnet 对应版本 |
| **生态覆盖** | 不止 sui，还管理 walrus、mvr、move-analyzer 等 |
| **自动更新** | 一条命令升级到最新版本 |

## 安装 Suiup

### macOS / Linux（推荐方式）

打开终端，运行以下命令：

```bash
curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh
```

安装脚本会自动：
1. 检测操作系统（macOS / Linux）和 CPU 架构（x86_64 / ARM64）
2. 下载对应的 suiup 二进制文件
3. 安装到 `~/.local/bin/` 目录

安装完成后，重启终端或执行：

```bash
source ~/.bashrc  # bash 用户
source ~/.zshrc   # zsh 用户（macOS 默认）
```

验证安装：

```bash
suiup --version
```

### 自定义安装路径

如果你想安装到其他目录：

```bash
SUIUP_INSTALL_DIR=/opt/suiup curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh
```

### 通过 Cargo 安装

如果你已经安装了 Rust 工具链，也可以通过 Cargo 安装：

```bash
cargo install --git https://github.com/MystenLabs/suiup.git --locked
```

### Windows

1. 从 [GitHub Releases](https://github.com/MystenLabs/suiup/releases) 下载最新的 `suiup-Windows-msvc-x86_64.zip`
2. 解压后将 `suiup.exe` 放到 PATH 目录中

### 支持的平台

| 操作系统 | 架构 | 支持状态 |
|----------|------|---------|
| macOS | x86_64 (Intel) | ✅ 完全支持 |
| macOS | ARM64 (Apple Silicon) | ✅ 完全支持 |
| Linux | x86_64 | ✅ 完全支持 |
| Linux | ARM64 | ✅ 完全支持 |
| Windows | x86_64 | ✅ 完全支持 |
| Windows | ARM64 | ⚠️ 有限支持 |

## 安装 Sui CLI

suiup 安装成功后，用它来安装 Sui CLI：

```bash
# 安装最新 testnet 版本（默认）
suiup install sui

# 安装特定网络版本
suiup install sui@testnet
suiup install sui@devnet
suiup install sui@mainnet

# 安装特定版本号
suiup install sui@testnet-1.40.1
suiup install sui@1.44.2

# 跳过确认提示（CI 环境常用）
suiup install sui -y
```

安装完成后验证：

```bash
sui --version
sui client --version
```

### 安装 Debug 版本

如果你需要使用 `sui move test --coverage`（测试覆盖率），需要安装 debug 版本：

```bash
suiup install sui --debug
```

### 从源码编译安装（Nightly）

如果你需要最新开发分支的功能（需要 Rust 工具链）：

```bash
# 默认从 main 分支编译
suiup install sui --nightly

# 指定分支
suiup install sui --nightly releases/sui-v1.45.0-release
```

## 可安装的工具

suiup 不仅管理 Sui CLI，还支持整个 Sui 生态的工具链：

```bash
suiup list
```

| 工具 | 说明 | 安装命令 |
|------|------|---------|
| `sui` | Sui CLI（核心工具） | `suiup install sui` |
| `sui-node` | Sui 全节点 | `suiup install sui-node` |
| `move-analyzer` | Move 语言分析器（IDE 插件后端） | `suiup install move-analyzer` |
| `mvr` | Move Registry CLI | `suiup install mvr` |
| `walrus` | Walrus 去中心化存储 CLI | `suiup install walrus` |
| `site-builder` | Walrus Sites 静态站点构建器 | `suiup install site-builder` |
| `ledger-signer` | Ledger 硬件钱包签名工具 | `suiup install ledger-signer` |
| `yubikey-signer` | YubiKey 签名工具 | `suiup install yubikey-signer` |

### 推荐的开发环境安装

对于 Move 开发者，建议至少安装以下工具：

```bash
suiup install sui@testnet
suiup install move-analyzer
suiup install mvr
```

## 版本管理与切换

suiup 的核心优势在于可以同时管理多个版本。

### 查看已安装的版本

```bash
suiup show
```

输出示例：

```
sui:
  testnet-1.44.2 (default)
  devnet-1.45.0
  mainnet-1.43.1
move-analyzer:
  mainnet-2024.1.1 (default)
mvr:
  0.0.8 (default)
```

### 切换默认版本

当你同时安装了多个版本，可以随时切换：

```bash
# 切换 sui 到 devnet 版本
suiup default set sui@devnet

# 切换到特定版本
suiup default set sui@testnet-1.40.0

# 切换 debug 版本为默认
suiup default set sui@testnet-1.44.2 --debug
```

也可以使用 `switch` 命令快速切换：

```bash
suiup switch sui@testnet
suiup switch sui@devnet
suiup switch sui@mainnet
```

### 查看当前默认版本

```bash
suiup default get
```

### 查看工具的安装路径

```bash
suiup which
```

## 升级工具

### 升级已安装的工具

```bash
# 升级 sui 到对应网络的最新版本
suiup update sui

# 升级特定网络的 sui
suiup update sui@testnet
suiup update sui@devnet

# 跳过确认
suiup update sui -y

# 升级其他工具
suiup update walrus
suiup update mvr
```

### 升级 Suiup 自身

```bash
suiup self update
```

## 环境诊断

如果遇到问题，使用 `doctor` 命令进行环境检查：

```bash
suiup doctor
```

该命令会检查：
- PATH 配置是否正确
- 已安装的二进制文件是否完整
- GitHub API 是否可访问
- 配置文件是否正常

## 缓存清理

suiup 会缓存下载的安装包，可以定期清理：

```bash
# 清理 30 天前的缓存（默认）
suiup cleanup

# 清理 7 天前的缓存
suiup cleanup --days 7

# 清理所有缓存
suiup cleanup --all

# 预览会清理什么（不实际删除）
suiup cleanup --dry-run
```

## 卸载

### 卸载已安装的工具

```bash
suiup remove sui
suiup remove walrus
```

> **注意：** `remove` 命令目前可能不太稳定，建议手动删除对应的二进制文件。

### 卸载 Suiup 自身

```bash
suiup self uninstall
```

## CI / CD 集成

在 CI 环境中使用 suiup，推荐设置 GitHub Token 以避免 API 速率限制：

```bash
GITHUB_TOKEN=your_token suiup install sui -y
```

GitHub Actions 示例：

```yaml
name: Build and Test
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install suiup
        run: curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh

      - name: Install Sui
        run: suiup install sui@testnet -y
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Test
        run: |
          sui move build
          sui move test
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `SUIUP_INSTALL_DIR` | 自定义 suiup 安装目录 |
| `SUIUP_DEFAULT_BIN_DIR` | 自定义默认二进制文件目录 |
| `GITHUB_TOKEN` | GitHub API Token（提高速率限制） |
| `SUIUP_DISABLE_UPDATE_WARNINGS` | 禁用 suiup 更新提醒 |

## 常用命令速查

```bash
# 安装
suiup install sui@testnet          # 安装 Sui（testnet）
suiup install sui@devnet           # 安装 Sui（devnet）
suiup install move-analyzer        # 安装 Move 语言分析器

# 查看
suiup show                         # 查看所有已安装的工具和版本
suiup list                         # 查看所有可安装的工具
suiup which                        # 查看默认二进制路径
suiup default get                  # 查看当前默认版本

# 版本切换
suiup switch sui@testnet           # 切换到 testnet 版本
suiup default set sui@devnet       # 设置 devnet 为默认

# 升级
suiup update sui                   # 升级 Sui
suiup self update                  # 升级 suiup 自身

# 维护
suiup doctor                       # 环境诊断
suiup cleanup                      # 清理缓存
```

## 小结

suiup 是 Sui 开发者的必备工具，它让工具链管理变得简单高效：

- **安装简单**：一行命令安装 suiup，再一行命令安装 sui
- **版本管理**：轻松在 testnet / devnet / mainnet 之间切换
- **生态覆盖**：统一管理 sui、walrus、mvr、move-analyzer 等所有生态工具
- **持续更新**：一条命令完成升级，始终保持最新版本

建议所有 Sui 开发者使用 suiup 作为工具链管理的标准方式，取代手动安装和源码编译。
