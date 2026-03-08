# 与合约交互

合约发布到链上后，我们需要通过交易来调用它的函数。Sui CLI 提供了强大的可编程交易块（Programmable Transaction Blocks，PTB）功能，可以在一笔交易中组合多个操作。本节将通过与上一节发布的 TodoList 合约交互，深入学习 PTB 的使用方法。

## 准备环境变量

首先，设置我们需要用到的环境变量：

```bash
# 替换为你上一节发布时获得的 PackageID
export PACKAGE_ID=0x<your-package-id>

# 获取当前活跃地址
export MY_ADDRESS=$(sui client active-address)

# 验证设置
echo "Package ID: $PACKAGE_ID"
echo "My Address: $MY_ADDRESS"
```

## 理解可编程交易块（PTB）

PTB 是 Sui 交易系统的核心概念。与传统区块链每次交易只能调用一个函数不同，Sui 的 PTB 允许你在**一笔交易中执行多个命令**，每个命令可以使用前面命令的结果。

PTB 的关键特性：

- **原子性**：所有命令要么全部成功，要么全部回滚
- **可组合性**：后续命令可以使用前面命令的返回值
- **高效性**：多个操作合并为一笔交易，减少 Gas 消耗
- **灵活性**：支持调用函数、转移对象、分割/合并 Coin 等

## 创建 TodoList 对象

让我们创建一个新的 TodoList 对象：

```bash
sui client ptb \
    --assign sender @$MY_ADDRESS \
    --move-call $PACKAGE_ID::todo_list::new \
    --assign list \
    --transfer-objects "[list]" sender
```

让我们逐行解析这个命令：

| 参数 | 说明 |
|------|------|
| `--assign sender @$MY_ADDRESS` | 将地址赋值给变量 `sender` |
| `--move-call $PACKAGE_ID::todo_list::new` | 调用 `new` 函数创建 TodoList |
| `--assign list` | 将上一个命令的返回值赋给变量 `list` |
| `--transfer-objects "[list]" sender` | 将 `list` 对象转移给 `sender` |

> **注意**：`new` 函数虽然需要 `&mut TxContext` 参数，但 CLI 会自动传入，无需手动指定。

交易成功后，输出中会包含创建的对象 ID。记录下这个 ID：

```bash
# 从输出中找到 Created Objects 的 ID
export LIST_ID=0x<created-object-id>
```

## 查看对象

### 基本查看

```bash
sui client object $LIST_ID
```

输出示例：

```
╭───────────────┬──────────────────────────────────────────────╮
│ objectId      │ 0x1234...                                    │
│ version       │ 1                                            │
│ digest        │ abc123...                                    │
│ objType       │ 0x<pkg>::todo_list::TodoList                 │
│ owner         │ AddressOwner(0x7d20...)                      │
│ content       │ { id: 0x1234..., items: [] }                 │
╰───────────────┴──────────────────────────────────────────────╯
```

可以看到 `items` 字段为空数组，这是我们刚创建的空 TodoList。

### JSON 格式查看

```bash
sui client object $LIST_ID --json
```

JSON 格式更适合程序解析，包含更详细的类型信息和字段值。

## 添加待办事项

使用 `add` 函数向列表中添加项目：

```bash
sui client ptb \
    --move-call $PACKAGE_ID::todo_list::add \
        @$LIST_ID \
        "'学习 Move 语言'"
```

这里直接传入了两个参数：

- `@$LIST_ID`：TodoList 对象的引用（`@` 前缀表示对象 ID）
- `"'学习 Move 语言'"`：要添加的字符串内容

> **提示**：字符串参数需要用单引号包裹，外层再用双引号，即 `"'内容'"`。

再添加几个事项：

```bash
sui client ptb \
    --move-call $PACKAGE_ID::todo_list::add \
        @$LIST_ID \
        "'编写智能合约'"

sui client ptb \
    --move-call $PACKAGE_ID::todo_list::add \
        @$LIST_ID \
        "'部署到主网'"
```

## 在一笔交易中执行多个操作

PTB 的强大之处在于可以在一笔交易中组合多个命令。让我们在一次交易中添加多个待办事项：

```bash
sui client ptb \
    --move-call $PACKAGE_ID::todo_list::add \
        @$LIST_ID \
        "'阅读 Sui 文档'" \
    --move-call $PACKAGE_ID::todo_list::add \
        @$LIST_ID \
        "'参与社区讨论'"
```

这样做不仅更高效（只需一笔 Gas 费），而且保证了原子性：要么两个事项都添加成功，要么都不添加。

## 创建对象并立即使用

下面展示一个更复杂的 PTB 示例——创建 TodoList 并立即添加事项：

```bash
sui client ptb \
    --assign sender @$MY_ADDRESS \
    --move-call $PACKAGE_ID::todo_list::new \
    --assign new_list \
    --move-call $PACKAGE_ID::todo_list::add new_list "'第一个任务'" \
    --move-call $PACKAGE_ID::todo_list::add new_list "'第二个任务'" \
    --transfer-objects "[new_list]" sender
```

这个交易包含了四个命令：

1. 调用 `new` 创建 TodoList
2. 调用 `add` 添加第一个事项（使用步骤 1 的返回值）
3. 调用 `add` 添加第二个事项
4. 将 TodoList 转移给自己

## 删除待办事项

```bash
# 删除索引为 0 的事项（第一个）
sui client ptb \
    --move-call $PACKAGE_ID::todo_list::remove \
        @$LIST_ID \
        0
```

## 查询拥有的对象

查看当前地址下的所有对象：

```bash
sui client objects
```

输出会列出你拥有的所有对象，包括 SUI Coin、TodoList、UpgradeCap 等：

```
╭───────────────────────────────────────────────────────────────╮
│ ╭────────────┬──────────────────────────────────────────────╮ │
│ │ objectId   │ 0x1234...                                   │ │
│ │ version    │ 5                                           │ │
│ │ digest     │ abc...                                      │ │
│ │ objectType │ 0x<pkg>::todo_list::TodoList                │ │
│ ╰────────────┴──────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────╮ │
│ │ objectId   │ 0x5678...                                   │ │
│ │ version    │ 1                                           │ │
│ │ digest     │ def...                                      │ │
│ │ objectType │ 0x2::coin::Coin<0x2::sui::SUI>             │ │
│ ╰────────────┴──────────────────────────────────────────────╯ │
╰───────────────────────────────────────────────────────────────╯
```

## 查看交易历史

你可以通过区块浏览器查看某个地址或对象的所有交易历史：

```bash
# 查看特定交易详情
sui client transaction-block <transaction-digest> --json
```

## PTB 命令速查

以下是 `sui client ptb` 支持的常用操作：

| 操作 | 语法 | 说明 |
|------|------|------|
| 调用 Move 函数 | `--move-call pkg::mod::fun args...` | 调用链上函数 |
| 赋值变量 | `--assign name value` | 将值赋给变量 |
| 转移对象 | `--transfer-objects "[obj]" recipient` | 转移对象给接收者 |
| 分割 Coin | `--split-coins coin "[amount]"` | 从 Coin 中分出指定金额 |
| 合并 Coin | `--merge-coins target "[source]"` | 将多个 Coin 合并为一个 |
| 设置 Gas 预算（可选） | `--gas-budget amount` | 覆盖自动估算的最大 Gas；通常可省略 |

## 交互流程总结

```bash
# 完整的交互流程

# 1. 设置环境变量
export PACKAGE_ID=0x...
export MY_ADDRESS=$(sui client active-address)

# 2. 创建对象
sui client ptb \
    --assign sender @$MY_ADDRESS \
    --move-call $PACKAGE_ID::todo_list::new \
    --assign list \
    --transfer-objects "[list]" sender

# 3. 记录对象 ID
export LIST_ID=0x...

# 4. 调用函数修改对象
sui client ptb \
    --move-call $PACKAGE_ID::todo_list::add @$LIST_ID "'新任务'"

# 5. 查看对象状态
sui client object $LIST_ID

# 6. 查看所有对象
sui client objects
```

## 小结

本节我们学习了如何通过 Sui CLI 的 PTB 命令与链上合约交互。核心要点包括：使用 `sui client ptb --move-call` 调用合约函数、使用 `--assign` 捕获返回值、使用 `--transfer-objects` 转移对象。PTB 最强大的特性是**可组合性**——你可以在一笔交易中串联多个命令，后续命令可以使用前面命令的结果，而整个过程是原子的。这种设计让 Sui 上的交易既灵活又高效。至此，你已经掌握了 Move 开发的完整流程：编写 → 测试 → 发布 → 交互。接下来我们将深入学习 Move 语言的核心概念。
