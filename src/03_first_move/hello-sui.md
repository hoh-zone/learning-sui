# 部署合约到 Sui 网络

编写和测试 Move 代码只是第一步，真正激动人心的是将合约部署到 Sui 网络上并让它运行起来。本节将通过一个 TodoList 合约示例，完整演示从编写到发布的全过程，并深入解读发布交易的每一个细节。

## 准备工作

在部署之前，确保你已完成以下准备（详见[钱包与测试币](../02_getting_started/wallet-and-faucet.md)章节）：

```bash
# 1. 确认当前网络为 devnet 或 testnet
sui client envs

# 2. 切换到 devnet（如果需要）
sui client switch --env devnet

# 3. 确认有足够的测试币
sui client balance

# 4. 如果余额不足，获取测试币
sui client faucet
```

## 编写 TodoList 合约

创建一个新项目：

```bash
sui move new todo_list
cd todo_list
```

编辑 `sources/todo_list.move`：

```move
module todo_list::todo_list;

use std::string::String;

/// 一个简单的待办事项列表
public struct TodoList has key, store {
    id: UID,
    items: vector<String>,
}

/// 创建一个新的待办事项列表
public fun new(ctx: &mut TxContext): TodoList {
    TodoList {
        id: object::new(ctx),
        items: vector[],
    }
}

/// 添加一个待办事项
public fun add(list: &mut TodoList, item: String) {
    list.items.push_back(item);
}

/// 删除指定位置的待办事项，返回被删除的内容
public fun remove(list: &mut TodoList, index: u64): String {
    list.items.remove(index)
}

/// 获取待办事项数量
public fun length(list: &TodoList): u64 {
    list.items.length()
}
```

让我们解析这个合约的关键要素：

### 结构体定义

```move
public struct TodoList has key, store {
    id: UID,
    items: vector<String>,
}
```

- `has key`：表示该结构体是一个 Sui 对象，拥有全局唯一的 `id`
- `has store`：表示该对象可以被存储在其他对象中，也可以被转移
- `id: UID`：每个 Sui 对象必须有的唯一标识符字段
- `items: vector<String>`：使用向量存储待办事项列表

### 对象创建

```move
public fun new(ctx: &mut TxContext): TodoList {
    TodoList {
        id: object::new(ctx),
        items: vector[],
    }
}
```

- `ctx: &mut TxContext`：交易上下文，用于生成唯一 ID
- `object::new(ctx)`：创建新的 `UID`
- `vector[]`：Move 2024 的空向量字面量语法

### 构建项目

```bash
sui move build
```

确保编译通过没有错误。

## 发布合约

使用以下命令将合约发布到链上：

```bash
sui client publish --gas-budget 100000000
```

`--gas-budget` 指定本次交易愿意支付的最大 Gas 费用（单位为 MIST）。100000000 MIST = 0.1 SUI，对于发布操作来说通常足够。

## 解读发布交易输出

发布成功后，CLI 会输出大量信息。让我们逐部分解读。

### Transaction Digest

```
Transaction Digest: 5JxQpNBk4r5F2UaGRe4Vb9DF7hLZqijU3aTvN8H7kQ2W
```

交易摘要（Digest）是交易的唯一标识符，可以在区块浏览器中查看交易详情。

### Transaction Data

```
╭──────────────────────────────────────────────────────────╮
│ Transaction Data                                         │
├──────────────────────────────────────────────────────────┤
│ Sender: 0x7d20dcdb...                                    │
│ Gas Budget: 100000000 MIST                               │
│ Commands:                                                │
│   Publish:                                               │
│     - Package: todo_list                                 │
│   TransferObjects:                                       │
│     - UpgradeCap → Sender                                │
╰──────────────────────────────────────────────────────────╯
```

- **Sender**：发布者的地址
- **Commands**：交易包含两个命令
  - **Publish**：发布 `todo_list` 包
  - **TransferObjects**：将 `UpgradeCap`（升级能力）转移给发布者

### Transaction Effects

```
╭──────────────────────────────────────────────────────────╮
│ Transaction Effects                                      │
├──────────────────────────────────────────────────────────┤
│ Status: Success                                          │
│ Created Objects:                                         │
│   - Package:    0xabc123...                              │
│   - UpgradeCap: 0xdef456...                              │
│ Gas Cost Summary:                                        │
│   Storage Cost:  8976000 MIST                            │
│   Computation Cost: 1000000 MIST                         │
│   Total Gas Cost: 9976000 MIST                           │
│   Storage Rebate: 978120 MIST                            │
╰──────────────────────────────────────────────────────────╯
```

- **Status: Success**：交易执行成功
- **Created Objects**：创建了两个对象
  - **Package**：发布的包，包含你的 Move 模块
  - **UpgradeCap**：升级能力对象，后续升级包时需要用到
- **Gas Cost**：Gas 费用明细

### Object Changes

```
╭──────────────────────────────────────────────────────────╮
│ Object Changes                                           │
├──────────────────────────────────────────────────────────┤
│ Published Objects:                                       │
│   PackageID: 0xabc123def456...                           │
│   Modules: todo_list                                     │
╰──────────────────────────────────────────────────────────╯
```

**PackageID** 是你的合约在链上的唯一标识，后续调用合约函数时需要用到它。

> **重要**：请记录下你的 PackageID，后续章节将需要使用它。

## 使用 JSON 格式输出

添加 `--json` 标志可以获取 JSON 格式的输出，方便程序化解析：

```bash
sui client publish --gas-budget 100000000 --json
```

JSON 输出更适合脚本自动化处理，你可以用 `jq` 提取关键信息：

```bash
# 发布并提取 PackageID
sui client publish --gas-budget 100000000 --json | jq -r '.objectChanges[] | select(.type == "published") | .packageId'
```

## 理解 UpgradeCap

`UpgradeCap`（升级能力）是 Sui 包管理的核心机制：

- 每次发布包时自动生成并转移给发布者
- 持有 `UpgradeCap` 的人可以升级对应的包
- 如果你销毁或转移 `UpgradeCap`，就放弃了升级权限
- 这是 Sui 上实现**不可变性保证**的一种方式

```bash
# 查看 UpgradeCap 对象
sui client object <upgrade-cap-id>
```

> **安全提示**：如果你想让包变成不可变的（无法升级），可以在发布后销毁 `UpgradeCap`。但请谨慎操作，一旦销毁便无法撤回。

## 在区块浏览器上查看

你可以在 Sui 区块浏览器上查看已发布的包：

- **Devnet**：`https://suiscan.xyz/devnet/object/<PackageID>`
- **Testnet**：`https://suiscan.xyz/testnet/object/<PackageID>`

在浏览器中你可以看到：

- 包的所有模块
- 每个模块的公开函数
- 结构体定义
- 历史交易

## 完整发布流程总结

```bash
# 1. 创建项目
sui move new todo_list && cd todo_list

# 2. 编写合约代码（编辑 sources/todo_list.move）

# 3. 构建
sui move build

# 4. 测试
sui move test

# 5. 确保有测试币
sui client faucet

# 6. 发布
sui client publish --gas-budget 100000000

# 7. 记录 PackageID
export PACKAGE_ID=0x<your-package-id>
```

## 小结

本节我们完成了一个 TodoList 合约的编写和链上发布。关键步骤包括：使用 `sui client publish` 发布包、理解交易输出中的 Digest、Effects、Created Objects 等信息。发布后我们获得了两个重要的对象——**Package**（包含合约代码）和 **UpgradeCap**（升级能力）。记录好 PackageID，下一节我们将学习如何通过 CLI 与已发布的合约进行交互。
