# Sui Dev Skills — AI 辅助开发技能包

Sui Dev Skills 是 Mysten Labs 维护的一套 **Claude 技能包（Skills）**，用于在 Claude Code 或兼容的 AI 编程助手中规范 Sui 开发行为。每个技能是一份 `SKILL.md` 文档，描述了对应技术栈的约定、最佳实践和常见坑，AI 在编写或审查代码时会自动参考这些规则，从而产出更符合 Sui 生态习惯的代码。

本节介绍 Sui Dev Skills 的安装方式、三个子技能的内容与适用场景，以及如何在本项目中组合使用。

## 什么是 Sui Dev Skills

在 Sui 开发中，AI 容易犯一些典型错误，例如：

- **Move**：使用 Aptos Move 的 `signer`、`move_to`，或旧版 Sui 的 `public(friend)`、无 `public` 的结构体
- **TypeScript**：使用已废弃的 `@mysten/sui.js`、`TransactionBlock`，或忘记检查交易执行结果
- **前端**：使用已废弃的 `@mysten/dapp-kit` 三 Provider 结构，或未在查询前 `waitForTransaction`

Sui Dev Skills 通过结构化文档（SKILL.md）明确「应该怎么做」和「不要怎么做」，让 AI 在写 Move、TS SDK 或前端代码时遵循同一套约定，减少上述问题。

### 三个子技能

| 技能 | 路径 | 适用场景 | 主要内容 |
|------|------|----------|----------|
| **sui-move** | `sui-move/SKILL.md` | 编写、审查、调试或部署 Sui Move 代码；配置 Move.toml；写 Move 测试 | Move 2024 语法、包结构、对象能力、Capability 模式、事件、PTB 可调用的 entry、测试约定 |
| **sui-ts-sdk** | `sui-ts-sdk/SKILL.md` | 用 TypeScript/JavaScript 与 Sui 链交互（脚本、CLI、服务端或前端的交易构建层） | `@mysten/sui`、PTB 构建（Transaction、moveCall、splitCoins、coinWithBalance）、SuiGrpcClient、签名与执行、链上查询 |
| **sui-frontend** | `sui-frontend/SKILL.md` | 构建浏览器端 Sui dApp（React 或 Vue/原生 JS/Svelte + dApp Kit） | `@mysten/dapp-kit-react` / `dapp-kit-core`、钱包连接、React hooks、Web Components、nanostores、链上查询与缓存失效 |

**路由建议：**

- 只写 Move 合约 → 加载 **sui-move**
- 只写后端脚本或 CLI → 加载 **sui-ts-sdk**
- 只写前端页面（含钱包、查询、发交易）→ 加载 **sui-frontend** + **sui-ts-sdk**
- 全栈（合约 + 前端 + 脚本）→ 三个都加载

## 安装

### 方式一：全局安装（推荐）

技能放在 Claude Code 的全局技能目录，对所有项目生效：

```bash
git clone https://github.com/MystenLabs/sui-dev-skills ~/.claude/skills/sui-dev-skills
```

Claude Code 会自动发现 `~/.claude/skills/` 下的技能，并根据当前编辑的文件和任务类型选择合适的技能激活。

### 方式二：项目内安装（可提交到仓库）

把技能克隆到项目内的 `.claude/skills/`，方便团队统一使用：

```bash
mkdir -p .claude/skills
git clone https://github.com/MystenLabs/sui-dev-skills .claude/skills/sui-dev-skills
```

将 `.claude/skills/sui-dev-skills` 提交到 Git 后，任何人用 Claude Code 打开该项目都会自动应用这些技能。

### 方式三：在 CLAUDE.md 中显式引用

若使用 Cursor、Claude Code 等支持 `CLAUDE.md` 的编辑器，可以在项目根目录的 `CLAUDE.md` 中固定引用要用的技能，确保每次对话都会加载：

```markdown
# My Sui Dapp

@.claude/skills/sui-dev-skills/sui-move/SKILL.md
@.claude/skills/sui-dev-skills/sui-ts-sdk/SKILL.md
@.claude/skills/sui-dev-skills/sui-frontend/SKILL.md
```

全局安装时路径可能是：

```markdown
@~/sui-dev-skills/sui-move/SKILL.md
@~/sui-dev-skills/sui-ts-sdk/SKILL.md
@~/sui-dev-skills/sui-frontend/SKILL.md
```

这样 AI 在动手写代码前就会先读取这些技能文档，按其中的约定生成或修改代码。

## 各技能要点速览

### sui-move

- **包与模块**：`edition = "2024"`（与本书正文一致），Sui 1.45+ 不显式写框架依赖，命名地址带项目前缀
- **语法**：单行 `module pkg::mod;`，`public struct`，`let mut`，方法语法，枚举与 `match`
- **对象**：带 `key` 的结构体必须有 `id: UID`，只用 `transfer`/`share_object`/`freeze_object` 的非 `public_` 版本在定义该类型的模块内调用
- **可见性**：用 `public(package)` 替代 `public(friend)`，不要写 `public entry`
- **命名**：Capability 后缀 `Cap`，事件过去式，错误常量 `EPascalCase`
- **测试**：不写 `test_` 前缀，用 `assert_eq!`、`tx_context::dummy()`、`sui::test_utils::destroy`

详细规则见仓库内 `sui-move/SKILL.md`。

### sui-ts-sdk

- **包与客户端**：使用 `@mysten/sui`，新代码优先 `SuiGrpcClient`，不再用 `SuiClient`/`getFullnodeUrl`
- **交易**：使用 `Transaction`（不是 `TransactionBlock`），`tx.pure.u64()` 等类型化纯参数，`tx.object(id)` 由 SDK 解析版本
- **命令**：`splitCoins`、`mergeCoins`、`transferObjects`、`moveCall`、`coinWithBalance`（非 SUI 时需 `setSender`）
- **执行**：始终检查 `result.$kind === 'FailedTransaction'`，执行后用 `client.waitForTransaction()` 再查链上状态
- **赞助交易**：用 `coinWithBalance` 而非 `tx.gas` 做支付，避免占用赞助方 gas

详细规则见仓库内 `sui-ts-sdk/SKILL.md`。

### sui-frontend

- **包**：新项目用 `@mysten/dapp-kit-react`（React）或 `@mysten/dapp-kit-core`（Vue/原生等），不再用旧的 `@mysten/dapp-kit`
- **配置**：`createDAppKit` + `DAppKitProvider`，`createClient` 传入 `SuiGrpcClient`
- **React**：`useCurrentAccount`、`useCurrentClient`、`useDAppKit().signAndExecuteTransaction`，链上数据用 `useCurrentClient` + `@tanstack/react-query`，查询加 `enabled: !!account`
- **非 React**：nanostores 的 `$connection`、`$currentClient` 等，Web Components 如 `mysten-dapp-kit-connect-button`
- **交易后**：先 `waitForTransaction`，再 `queryClient.invalidateQueries`，避免读到未索引数据

详细规则见仓库内 `sui-frontend/SKILL.md`。

## 典型使用流程

1. **安装**：按上面任选一种方式安装 Sui Dev Skills（推荐项目内克隆并提交）。
2. **按任务选技能**：只写合约就依赖 sui-move；只写脚本就依赖 sui-ts-sdk；写 dApp 就同时依赖 sui-frontend + sui-ts-sdk；全栈则三个都引用。
3. **在 CLAUDE.md 中固定技能**（可选）：把用到的 `SKILL.md` 路径写在 `CLAUDE.md` 里，保证每次对话都会加载。
4. **正常写需求**：像平时一样描述需求或贴代码，AI 会结合技能里的约定生成或修改代码，并避免技能中列出的反模式。

## 运行 Evals（可选）

仓库中每个子技能都带有 `evals/evals.json`，用于在 Claude Code 中通过 skill-creator 跑自动化评测，验证技能是否能让 AI 产出符合预期的代码。若你只关心「在日常开发里用好这些技能」，可以跳过 evals；若需要验证或贡献技能，可参考仓库根目录 README 中的 “Running evals” 说明。

## 小结

- Sui Dev Skills 是一套供 AI 参考的 Sui 开发规范，包含 **sui-move**、**sui-ts-sdk**、**sui-frontend** 三个子技能。
- 安装方式：全局克隆到 `~/.claude/skills/`，或项目内克隆到 `.claude/skills/sui-dev-skills`，或在 `CLAUDE.md` 中直接引用对应 `SKILL.md`。
- 按任务选择加载的技能：只合约 → sui-move；只脚本 → sui-ts-sdk；只前端 → sui-frontend + sui-ts-sdk；全栈 → 三个都加载。
- 使用后，AI 会更稳定地遵循 Move 2024、TS SDK v2 和 dApp Kit 的推荐写法，并避免常见错误（如错误包名、旧 API、未检查交易结果、查询未索引数据等）。
