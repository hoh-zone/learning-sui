# 项目规划与架构设计

本节介绍如何从零开始规划一个基于 Sui 的全栈去中心化应用（dApp）。我们将从需求分析出发，完成技术选型、目录结构设计和开发流程规划，为后续的 Move 合约开发与前端集成打下基础。

## 需求分析

在开始编码之前，明确项目需求是最重要的一步。以 Hero NFT 游戏为例：

### 用户故事

- 作为用户，我可以连接钱包到应用
- 作为用户，我可以创建一个英雄（Hero）并装备武器（Weapon）
- 作为用户，我可以查看自己拥有的英雄列表
- 作为用户，我可以查看最近被铸造的所有英雄

### 功能拆解

| 功能模块 | 链上（Move） | 链下（前端/SDK） |
|---------|------------|--------------|
| 英雄铸造 | `new_hero` 函数 | 交易构造 + 签名 |
| 武器铸造 | `new_weapon` 函数 | 交易构造 + 签名 |
| 装备管理 | `equip_weapon` / `unequip_weapon` | UI 交互 + PTB 调用 |
| 英雄列表 | `HeroRegistry` 共享对象 | RPC 查询 + 渲染 |
| 我的英雄 | — | `getOwnedObjects` 过滤 |

## 技术选型

### 技术栈概览

```
┌──────────────────────────────────────────────────┐
│                  全栈 DApp 架构                     │
├──────────────────────────────────────────────────┤
│                                                    │
│  智能合约层    Sui Move                             │
│  集成测试层    TypeScript + @mysten/sui SDK         │
│  前端 UI 层   React + @mysten/dapp-kit             │
│  钱包连接层    Slush Wallet / Suiet / Sui Wallet   │
│                                                    │
└──────────────────────────────────────────────────┘
```

### 核心依赖

| 层 | 技术 | 用途 |
|---|------|-----|
| 合约 | Sui Move | 链上逻辑、对象模型 |
| SDK | `@mysten/sui` | 交易构造、RPC 调用、BCS 编码 |
| 前端框架 | React + Vite | UI 渲染、路由管理 |
| dApp 工具包 | `@mysten/dapp-kit` | 钱包连接、hooks、查询 |
| 脚手架 | `@mysten/create-dapp` | 快速初始化项目 |

### 为什么选择 Sui？

- **对象所有权模型**：NFT 天然适合 Sui 的所有权语义
- **并行执行**：独立的 owned object 交易可并行处理
- **PTB（可编程交易块）**：一笔交易内完成铸造+装备的原子操作
- **Move 类型安全**：编译期保证资源安全

## 目录结构设计

```
my-dapp/
├── move/                          # Move 合约
│   └── hero/
│       ├── Move.toml              # 包配置
│       ├── sources/
│       │   └── hero.move          # 核心合约
│       └── tests/
│           └── hero_tests.move    # 单元测试
├── typescript/                    # TypeScript 集成
│   ├── src/
│   │   ├── helpers/               # 交易构造辅助函数
│   │   │   ├── mintHero.ts
│   │   │   └── mintWeapon.ts
│   │   └── tests/
│   │       └── e2e.test.ts        # 端到端测试
│   ├── package.json
│   └── tsconfig.json
├── app/                           # React 前端
│   ├── src/
│   │   ├── components/
│   │   │   ├── HeroesList.tsx     # 英雄列表组件
│   │   │   ├── HeroCard.tsx       # 英雄卡片组件
│   │   │   ├── CreateHeroForm.tsx # 创建英雄表单
│   │   │   └── OwnedObjects.tsx   # 我的英雄
│   │   ├── App.tsx
│   │   └── main.tsx
│   └── package.json
└── README.md
```

## 开发流程

### 推荐的开发顺序

```
1. 设计数据模型（Move 结构体）
      │
      ▼
2. 实现核心合约逻辑
      │
      ▼
3. 编写 Move 单元测试
      │
      ▼
4. 发布到 localnet/testnet
      │
      ▼
5. 编写 TypeScript 集成辅助函数
      │
      ▼
6. 编写端到端测试
      │
      ▼
7. 搭建 React 前端
      │
      ▼
8. 集成钱包 + 调用合约
      │
      ▼
9. 测试 + 部署
```

### Move.toml 配置示例

```toml
[package]
name = "hero"
edition = "2024"

[addresses]
hero = "0x0"
```

### 初始化前端项目

```bash
cd app
npm create @mysten/dapp
# 选择模板，填写项目名称
cd <app-name>
pnpm install
pnpm run dev
```

## 数据模型设计原则

设计 Move 结构体时需要考虑的关键问题：

### 1. Owned vs Shared

| 类型 | 适用场景 | 示例 |
|------|---------|-----|
| Owned Object | 单一用户拥有，不需要并发访问 | Hero、Weapon |
| Shared Object | 全局状态，需要多方读写 | HeroRegistry |

### 2. 能力（Abilities）选择

```move
// key + store：可转让的 NFT
public struct Hero has key, store {
    id: UID,
    name: String,
    stamina: u64,
    weapon: Option<Weapon>,
}

// key + store：能力凭证（Cap 后缀）
public struct AdminCap has key, store {
    id: UID,
}

// copy + drop：事件
public struct HeroCreated has copy, drop {
    hero_id: ID,
    creator: address,
}
```

### 3. 注册表模式

使用共享对象追踪全局状态：

```move
public struct HeroRegistry has key {
    id: UID,
    ids: vector<ID>,
    counter: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(HeroRegistry {
        id: object::new(ctx),
        ids: vector[],
        counter: 0,
    });
}
```

## 小结

项目规划是全栈 dApp 开发的第一步。关键要点：

- 从用户故事出发，明确链上/链下的职责划分
- 采用 Move 合约 → TypeScript SDK → React 前端的三层架构
- 合理组织目录结构，保持模块清晰
- 先设计数据模型，再实现逻辑——Move 的类型系统会帮你在编译期发现问题
- 遵循 "合约优先" 的开发顺序，确保链上逻辑正确后再构建前端
