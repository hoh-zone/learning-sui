# MVR — Move 包注册中心

MVR（Move Registry）是 Sui 生态的包注册中心，为 Move 包提供人类可读的命名系统。它的作用类似于 NPM 等包注册中心，让开发者可以用 `@org/package` 的形式引用链上包，而不必记忆 64 位的十六进制地址。

## 为什么需要 MVR

在没有 MVR 之前，引用一个 Sui 链上包需要这样写：

```toml
[dependencies]
SomePackage = { git = "https://github.com/org/repo.git", subdir = "packages/some", rev = "abc123" }
```

这带来了几个问题：

| 问题 | 说明 |
|------|------|
| **地址不可读** | `0xbb97fa5af2504cc944a8df78dcb5c8b72c3673ca4ba8e4969a98188bf745ee54` 毫无语义 |
| **版本管理困难** | 包升级后地址会变，依赖方需要手动更新 |
| **网络差异** | testnet 和 mainnet 的地址不同，需要分别维护 |
| **PTB 硬编码** | 可编程交易块中必须硬编码包地址 |

MVR 通过链上名称注册表解决了这些问题：

```toml
[dependencies]
demo = { r.mvr = "@mvr/demo" }
```

## 安装 MVR CLI

### 方式一：通过 Suiup 安装（推荐）

```bash
suiup install mvr
```

### 方式二：通过 Cargo 安装

```bash
cargo install --locked --git https://github.com/mystenlabs/mvr --branch release mvr
```

### 方式三：下载预编译二进制

| 操作系统 | 架构 | 下载链接 |
|----------|------|---------|
| macOS | Apple Silicon | [mvr-macos-arm64](https://github.com/mystenlabs/mvr/releases/latest/download/mvr-macos-arm64) |
| macOS | Intel | [mvr-macos-x86_64](https://github.com/mystenlabs/mvr/releases/latest/download/mvr-macos-x86_64) |
| Linux | x86_64 | [mvr-ubuntu-x86_64](https://github.com/mystenlabs/mvr/releases/latest/download/mvr-ubuntu-x86_64) |
| Linux | ARM64 | [mvr-ubuntu-aarch64](https://github.com/mystenlabs/mvr/releases/latest/download/mvr-ubuntu-aarch64) |
| Windows | x86_64 | [mvr-windows-x86_64.exe](https://github.com/mystenlabs/mvr/releases/latest/download/mvr-windows-x86_64.exe) |

下载后重命名并添加执行权限：

```bash
mv mvr-macos-arm64 mvr
chmod +x mvr
sudo mv mvr /usr/local/bin/
```

### 前置要求

- **Sui CLI ≥ 1.63**，且已加入 PATH
- 如果 Sui CLI 不在默认路径，设置环境变量：`export SUI_BINARY_PATH=/path/to/sui`

### 验证安装

```bash
mvr --version
```

## 核心概念

### 名称格式

MVR 的名称由三部分组成：

```
@组织名/包名[/版本号]
```

| 组成部分 | 规则 | 示例 |
|---------|------|------|
| 组织名 | 小写字母、数字、连字符，最长 64 字符 | `@mvr`, `@myorg` |
| 包名 | 小写字母、数字、连字符，最长 64 字符 | `demo`, `my-package` |
| 版本号 | 可选，整数 | `/1`, `/2` |

示例：

```
@mvr/demo          # 最新版本
@mvr/core           # MVR 核心包
@pkg/qwer/1         # 指定版本 1
```

### 名称与 SuiNS 的关系

MVR 的组织名称基于 [SuiNS](https://suins.io/)（Sui Name Service）。要注册一个 MVR 包名，你需要：

1. 拥有一个 SuiNS 域名（如 `myorg.sui`）
2. 用该域名注册 MVR 应用名称
3. 将包信息绑定到名称上

### 链上架构

```
┌─────────────────────────────────────────────┐
│  MoveRegistry（共享对象）                     │
│  ┌───────────────────────────────────────┐  │
│  │  Table<Name, AppRecord>               │  │
│  │                                       │  │
│  │  @mvr/demo  ──→  AppRecord {         │  │
│  │                    networks: {        │  │
│  │                      mainnet: AppInfo │  │
│  │                      testnet: AppInfo │  │
│  │                    }                  │  │
│  │                    package_info: ID   │  │
│  │                  }                    │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

核心类型：

- **MoveRegistry** — 全局注册表，存储所有名称到应用记录的映射
- **AppRecord** — 应用记录，包含各网络的包信息
- **AppCap** — 应用管理权限，持有者可以更新应用信息
- **PackageInfo** — 包的元数据（git 仓库、版本、Display 信息）

## 使用 MVR 管理依赖

### 添加依赖

确保当前 Sui CLI 已连接到正确的网络：

```bash
# 查看当前网络
sui client active-env

# 切换网络
sui client switch --env mainnet
sui client switch --env testnet
```

然后使用 `mvr add` 添加依赖：

```bash
mvr add @mvr/demo
```

该命令会自动修改你的 `Move.toml`，添加：

```toml
[dependencies]
demo = { r.mvr = "@mvr/demo" }
```

### 本地/不支持的网络

如果你使用本地网络或自定义网络，设置回退网络：

```bash
MVR_FALLBACK_NETWORK=mainnet mvr add @mvr/demo
```

### 指定版本

```toml
[dependencies]
my_pkg = { r.mvr = "@org/package" }       # 最新版本
my_pkg = { r.mvr = "@org/package/1" }     # 指定版本 1
my_pkg = { r.mvr = "@org/package/2" }     # 指定版本 2
```

### 构建项目

添加 MVR 依赖后，正常构建即可。Sui CLI 会自动调用 MVR 解析依赖：

```bash
sui move build
```

构建过程中，MVR CLI 作为依赖解析器被调用：

1. Sui CLI 检测到 `r.mvr` 依赖
2. 调用 `mvr --resolve-deps` 解析名称
3. MVR 通过 API 查询链上注册信息
4. 下载并缓存对应的包
5. 返回本地路径给 Sui CLI

## 查询与搜索

### 解析名称

查看一个 MVR 名称对应的包信息：

```bash
# 默认使用当前网络
mvr resolve @mvr/demo

# 指定网络
mvr resolve @mvr/demo --network mainnet
mvr resolve @mvr/demo --network testnet
```

输出包含包的地址、版本、git 仓库等信息。

### 搜索包

```bash
# 按名称搜索
mvr search demo

# 搜索某个组织的所有包
mvr search @myorg/

# 限制结果数量
mvr search demo --limit 5

# 分页查询
mvr search demo --cursor <cursor_value>
```

### JSON 输出

所有命令都支持 JSON 格式输出，方便脚本处理：

```bash
mvr resolve @mvr/demo --json
mvr search demo --json
```

## 在 PTB 中使用 MVR

MVR 的一大优势是可以在可编程交易块（PTB）中使用名称代替地址。这样当包升级后，PTB 会自动使用最新版本，无需修改代码。

### TypeScript SDK 集成

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Transaction } from "@mysten/sui/transactions";
import { MVRPlugin } from "@mysten/mvr-plugin";

const client = new SuiGrpcClient({
  network: "mainnet",
  baseUrl: "https://fullnode.mainnet.sui.io:443",
});

const tx = new Transaction();

// 使用 MVR 名称代替地址
tx.moveCall({
  target: `@mvr/demo::demo::hello`,
  arguments: [],
});

// MVR 插件会在执行前自动解析名称
const plugin = new MVRPlugin(client);
await plugin.resolve(tx);
```

### CLI PTB 集成

```bash
sui client ptb \
  --move-call @mvr/demo::demo::hello \
```

## 发布你的包到 MVR

### 步骤概览

```
1. 拥有 SuiNS 域名
       ↓
2. 注册应用名称
       ↓
3. 发布 Move 包到链上
       ↓
4. 创建 PackageInfo
       ↓
5. 绑定名称到 PackageInfo
       ↓
6. 设置网络信息
```

### 1. 获取 SuiNS 域名

前往 [suins.io](https://suins.io) 注册一个域名，如 `myorg.sui`。

### 2. 在 MVR 注册应用

前往 [moveregistry.com](https://www.moveregistry.com) 使用 SuiNS 域名注册应用名称。

### 3. 发布包并绑定

发布你的 Move 包后，通过 MVR Web 界面或 API 将包地址绑定到注册的名称上。

### 4. 设置 Git 信息

设置包的 git 仓库地址和相关元数据，让其他开发者可以查看源码：

```
仓库: https://github.com/myorg/my-package
子目录: packages/core
标签: v1.0.0
```

## API 端点

MVR 提供 REST API，供 CLI 和第三方工具使用：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v1/names` | GET | 搜索名称（分页） |
| `/v1/names/{name}` | GET | 获取包信息 |
| `/v1/resolution/{name}` | GET | 解析名称到包地址 |
| `/v1/resolution/bulk` | POST | 批量解析 |
| `/v1/reverse-resolution/{package_id}` | GET | 反向解析（地址→名称） |
| `/v1/reverse-resolution/bulk` | POST | 批量反向解析 |
| `/v1/type-resolution/{type_name}` | GET | 解析类型名称 |
| `/v1/struct-definition/{type_name}` | GET | 获取结构体定义 |
| `/v1/package-address/{id}/dependencies` | GET | 查询依赖 |
| `/v1/package-address/{id}/dependents` | GET | 查询被依赖 |
| `/health` | GET | 健康检查 |

API 基础地址：

- Mainnet: `https://mainnet.mvr.mystenlabs.com`
- Testnet: `https://testnet.mvr.mystenlabs.com`

使用示例：

```bash
# 解析名称
curl https://mainnet.mvr.mystenlabs.com/v1/resolution/@mvr/demo

# 反向解析
curl https://mainnet.mvr.mystenlabs.com/v1/reverse-resolution/0xabc...

# 搜索
curl "https://mainnet.mvr.mystenlabs.com/v1/names?query=demo&limit=10"
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `SUI_BINARY_PATH` | Sui CLI 路径（默认使用 PATH 中的 `sui`） |
| `MVR_FALLBACK_NETWORK` | 回退网络（`mainnet` 或 `testnet`），用于本地/不支持的网络 |

## 常用命令速查

```bash
# 安装
suiup install mvr                         # 通过 suiup 安装

# 依赖管理
mvr add @org/package                      # 添加依赖到 Move.toml
mvr add @org/package/1                    # 添加指定版本

# 查询
mvr resolve @org/package                  # 解析名称
mvr resolve @org/package --network mainnet  # 指定网络解析
mvr search demo                           # 搜索包
mvr search @org/ --limit 20              # 搜索组织下的包

# 构建
sui move build                            # 自动解析 MVR 依赖

# 网络切换
sui client switch --env mainnet           # MVR 跟随 Sui CLI 网络
sui client switch --env testnet
```

## 实战示例：使用 MVR 依赖构建项目

### 创建项目

```bash
sui move new my_defi_app
cd my_defi_app
```

### 添加 MVR 依赖

```bash
# 确保在正确的网络
sui client switch --env mainnet

# 添加依赖
mvr add @mvr/core
```

### Move.toml

```toml
[package]
name = "my_defi_app"
edition = "2024"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
mvr_core = { r.mvr = "@mvr/core" }

[addresses]
my_defi_app = "0x0"
```

### 编写代码

```move
module my_defi_app::app;

// MVR 依赖会被自动解析
// 可以直接使用 @mvr/core 中的类型和函数

public struct MyApp has key {
    id: UID,
    name: vector<u8>,
}

fun init(ctx: &mut TxContext) {
    let app = MyApp {
        id: object::new(ctx),
        name: b"My DeFi App",
    };
    transfer::transfer(app, ctx.sender());
}
```

### 构建与测试

```bash
sui move build    # MVR 自动解析依赖
sui move test     # 运行测试
```

## 小结

MVR 是 Sui 生态中包管理的基础设施，它为 Move 开发带来了现代化的依赖管理体验：

- **人类可读**：`@org/package` 取代冗长的十六进制地址
- **自动解析**：构建时自动解析 MVR 名称，无需手动管理地址
- **网络感知**：同一名称在不同网络自动解析到对应的包
- **版本管理**：支持版本号，包升级后依赖方可以平滑迁移
- **PTB 集成**：在可编程交易块中使用名称，始终调用最新版本
- **生态互通**：通过注册中心发现和复用社区包

随着 Sui 生态的成长，MVR 将成为 Move 开发者日常工作流中不可或缺的一环，建议尽早在项目中采用 MVR 管理依赖。
