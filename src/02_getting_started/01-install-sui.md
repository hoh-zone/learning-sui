# 安装 Sui CLI 与 Suiup

**Sui CLI** 是开发 Move 合约、编译测试、部署并与链交互的核心工具。**Suiup** 是 Mysten Labs 提供的 **Sui 生态工具链安装与版本管理器**（类似其他语言的版本管理工具）：一键安装预编译 **`sui`**，并可在 testnet / devnet / mainnet 等版本间切换，通常 **无需** 自行从源码编译。

本节将 **先介绍推荐路径（安装 suiup → 再安装 `sui`）**，再列出 Homebrew、预编译包、源码等 **备选方式**，最后说明 **版本管理、诊断与常见问题**。

---

## 为何需要 Sui CLI

Sui CLI 集成了项目创建、**`sui move build` / `test`**、部署、客户端与环境切换等能力，是后续各章的默认命令行入口。

---

## 推荐：先安装 Suiup，再安装 Sui

### 为何优先用 Suiup

在广泛使用 suiup 之前，安装 `sui` 往往需要本地 Rust 工具链并从源码编译（耗时长）。Suiup 提供：

| 能力 | 说明 |
|------|------|
| **预编译二进制** | 按平台下载，免去本地编译 |
| **多版本并存** | 同时安装多个 `sui` 版本并切换默认 |
| **与网络对齐** | 可安装 `testnet` / `devnet` / `mainnet` 对应构建 |
| **生态工具** | 同一套命令管理 `move-analyzer`、`mvr`、`walrus` 等 |

### 安装 Suiup

**macOS / Linux（常用）**：在终端执行：

```bash
curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh
```

脚本会检测系统与架构，并将 `suiup` 安装到 **`~/.local/bin/`**（若使用自定义路径，见下文）。安装后 **重启终端**，或执行：

```bash
source ~/.bashrc   # bash
source ~/.zshrc    # zsh（macOS 常见）
```

验证：

```bash
suiup --version
```

**自定义安装目录**：

```bash
SUIUP_INSTALL_DIR=/opt/suiup curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh
```

**已安装 Rust 时** 也可用 Cargo：

```bash
cargo install --git https://github.com/MystenLabs/suiup.git --locked
```

**Windows**：从 [suiup Releases](https://github.com/MystenLabs/suiup/releases) 下载 `suiup-Windows-msvc-x86_64.zip`，解压后将 `suiup.exe` 加入 **PATH**。

### 用 Suiup 安装 Sui CLI

```bash
# 安装最新 testnet 构建（默认常用）
suiup install sui

# 按网络安装
suiup install sui@testnet
suiup install sui@devnet
suiup install sui@mainnet

# 指定版本号（示例）
suiup install sui@testnet-1.40.1
suiup install sui@1.44.2

# CI 等非交互场景可跳过确认
suiup install sui -y
```

安装完成后验证：

```bash
sui --version
sui client --version
```

**测试覆盖率**（`sui move test --coverage`）需要 **debug** 构建时：

```bash
suiup install sui --debug
```

**需要跟踪最新开发分支**（需本地 Rust）时：

```bash
suiup install sui --nightly
# 或指定分支，例如：
# suiup install sui --nightly releases/sui-v1.45.0-release
```

> **提示**：官方也提供一键安装脚本的短链入口（若文档有更新，以 [docs.sui.io](https://docs.sui.io) 当前说明为准）。本书示例以 **`suiup` 命令** 为主。

---

## 其他安装方式（备选）

若你暂时不想使用 Suiup，可选用下列方式之一安装 **`sui`**；**版本管理**仍建议后续改用 Suiup，以免多网络切换时手工换二进制。

### Homebrew（macOS）

```bash
brew install sui
```

### Chocolatey（Windows）

```bash
choco install sui
```

### 预编译二进制

1. 打开 [Sui Releases](https://github.com/MystenLabs/sui/releases)  
2. 选择版本，下载对应平台的压缩包  
3. 解压后将 `sui` 放到 **`PATH`** 中的目录  

```bash
# macOS / Linux 示例
tar -xzf sui-<version>-<platform>.tgz
sudo mv sui /usr/local/bin/
```

### 从源码编译（Cargo）

需要较长时间与足够磁盘/内存：

```bash
cargo install --git https://github.com/MystenLabs/sui.git sui --branch testnet
# 或 --branch mainnet 等
```

---

## 使用 Suiup 管理版本与默认 CLI

同时安装多版本时，常用命令：

```bash
suiup show                    # 已安装版本与默认项
suiup switch sui@testnet      # 快速切换
suiup default set sui@devnet    # 设置默认
suiup default get
suiup which                   # 当前默认二进制路径
```

升级与自检：

```bash
suiup update sui
suiup update sui@testnet
suiup self update             # 升级 suiup 自身
suiup doctor                  # 环境诊断（PATH、二进制完整性等）
```

缓存与卸载：

```bash
suiup cleanup                 # 清理下载缓存（可加 --days、--all、--dry-run）
suiup remove sui              # 卸载某工具（具体行为以当前 CLI 为准）
suiup self uninstall          # 卸载 suiup
```

**CI 提示**：可向环境注入 **`GITHUB_TOKEN`** 以降低 GitHub API 限流概率；示例见 suiup 文档或本书仓库历史中的 GitHub Actions 片段。

---

## 生态工具（可选，与 IDE 联动）

除 `sui` 外，开发时常一并安装：

```bash
suiup list
suiup install move-analyzer
suiup install mvr
```

与 [§2.2 · IDE 配置](02-ide-setup.md) 中的 **Move Analyzer** 一致：**推荐用 suiup 安装 `move-analyzer`**，便于与 `sui` 版本统一管理。

---

## 常见问题

### 找不到 `sui` 或 `suiup`

- 确认 **`~/.local/bin`**（或你的安装目录）已在 **`PATH`** 中。  
- 执行 `suiup which` 查看期望路径；必要时在 `~/.zshrc` / `~/.bashrc` 中追加 `export PATH="$HOME/.local/bin:$PATH"`。

### 与目标网络协议版本不匹配

部署或调用前，用 **`suiup install sui@<对应网络>`** 与 **`suiup switch`** 对齐；并用 **`sui client envs`** 查看当前客户端环境。

### 源码编译失败

安装 Xcode 命令行工具（macOS）或 `build-essential`、`libssl-dev` 等（Linux）；预留足够磁盘与内存。

### 权限问题

确保二进制有执行权限；安装到系统目录时可能需要 `sudo`。

---

## 小结

- **推荐路径**：安装 **Suiup** → **`suiup install sui`**（可按网络/版本细化）→ **`sui --version`** 验收。  
- **备选**：Homebrew、Chocolatey、预编译包、**Cargo 源码编译**。  
- **长期维护**：用 **`suiup show` / `switch` / `update` / `doctor`** 管理版本与排障；需要 IDE 时再装 **`move-analyzer`**（见下一节）。

下一节配置 **IDE 与 Move Analyzer**，便于编写与调试 Move 代码。
