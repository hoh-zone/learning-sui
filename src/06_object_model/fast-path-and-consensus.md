# 快速路径与共识

Sui 区块链的一个核心创新在于其**双轨执行模型**：针对不同类型的对象，Sui 采用不同的交易处理路径。涉及地址所有和不可变对象的交易可以绕过共识，通过"快速路径"直接执行；而涉及共享对象的交易则需要经过共识排序。这种设计使 Sui 在保持安全性的同时，实现了极高的交易吞吐量和极低的延迟。

本章将深入探讨快速路径和共识路径的工作原理、对象类型与执行路径的对应关系，以及如何利用这一机制优化应用性能。

## 区块链的并发挑战

### 传统区块链的瓶颈

在比特币和以太坊等传统区块链中，所有交易都需要**全局排序**。即使两个交易操作的是完全不同的数据，它们也必须被排成一个线性序列来执行。这就像一家银行只有一个柜台——即使客户要办理的业务完全无关，也必须排队等候。

这种模型的问题是明显的：

- **吞吐量受限**：所有交易串行执行，系统吞吐量取决于单线程处理速度
- **延迟较高**：即使是简单交易也要等待共识完成
- **资源浪费**：大量算力用于对无关交易进行排序

### Sui 的创新：基于对象的并发

Sui 的关键洞察是：**不是所有交易都需要全局排序**。如果两个交易操作的是不同的对象，且这些对象各自只有一个所有者，那么这两个交易之间没有冲突，可以**并行执行**。

这就像银行开设了多个柜台——不同客户办理不同业务时可以同时进行，只有涉及同一账户的操作才需要排队。

## 快速路径（Fast Path）

### 工作原理

当一个交易**只涉及地址所有对象和/或不可变对象**时，Sui 会通过快速路径执行它：

1. 交易被提交给一组验证者
2. 每个验证者**独立检查**交易的有效性（签名、对象所有权、版本等）
3. 验证者直接签署交易结果
4. 当收集到足够多的签名（2/3+ 权重）时，交易即完成
5. **不需要验证者之间相互通信达成共识**

这个过程非常快——只需要一到两轮网络通信。

### 为什么可以跳过共识？

关键原因是**所有权的排他性**：

- 地址所有对象只能被其所有者使用
- 一个所有者在同一时刻只能提交一个使用该对象的交易（通过版本号保证）
- 因此不存在两个交易同时修改同一个地址所有对象的可能性

不可变对象更简单——它们永远不会被修改，所以无论多少交易同时读取它们都不会产生冲突。

### 快速路径的性能特征

- **延迟**：通常在 400-600 毫秒内完成（亚秒级）
- **吞吐量**：理论上可以无限扩展（不同对象的交易完全并行）
- **费用**：更低的 gas 费用（不需要共识开销）

## 共识路径（Consensus Path）

### 工作原理

当交易涉及**至少一个共享对象**时，需要通过共识路径执行：

1. 交易被提交给验证者
2. 验证者将交易输入**共识协议**（Sui 使用 Mysticeti 等高性能共识算法）
3. 共识协议对涉及同一共享对象的交易进行**全局排序**
4. 排序后的交易按顺序执行
5. 执行结果被最终确认

### 为什么共享对象需要共识？

共享对象可以被任何人修改。如果两个交易同时尝试修改同一个共享对象：

- 交易 A：将计数器从 10 增加到 11
- 交易 B：将计数器从 10 增加到 11

没有排序的话，两个交易都会读到 10 并写入 11，导致一次增量被"丢失"。共识确保这两个交易被排成 A → B 或 B → A 的顺序执行。

### 共识路径的性能特征

- **延迟**：通常在 2-3 秒内完成
- **吞吐量**：受共识协议性能和共享对象竞争程度影响
- **费用**：相对较高的 gas 费用

## 代码示例：两种路径对比

```move
module examples::fast_path_demo;

/// Address-owned object: uses FAST PATH (no consensus needed)
public struct PersonalNote has key {
    id: UID,
    content: vector<u8>,
}

/// Shared object: requires CONSENSUS
public struct Bulletin has key {
    id: UID,
    messages: vector<vector<u8>>,
}

public fun write_note(content: vector<u8>, ctx: &mut TxContext) {
    let note = PersonalNote {
        id: object::new(ctx),
        content,
    };
    transfer::transfer(note, ctx.sender());
}

public fun create_bulletin(ctx: &mut TxContext) {
    let bulletin = Bulletin {
        id: object::new(ctx),
        messages: vector::empty(),
    };
    transfer::share_object(bulletin);
}

public fun post_message(bulletin: &mut Bulletin, msg: vector<u8>) {
    vector::push_back(&mut bulletin.messages, msg);
}
```

### 执行路径分析

| 操作 | 使用的对象 | 执行路径 | 预期延迟 |
|------|----------|---------|---------|
| `write_note` | 无输入对象（创建新对象） | 快速路径 | ~500ms |
| 修改已有的 `PersonalNote` | 地址所有对象 | 快速路径 | ~500ms |
| `post_message` | 共享的 `Bulletin` | 共识路径 | ~2-3s |
| 读取 `Bulletin` 的 `messages` | 共享的 `Bulletin`（只读） | 共识路径 | ~2-3s |

注意：即使只是**读取**共享对象（使用 `&T`），交易仍然走共识路径。这是因为 Sui 需要确保读取到的是共享对象的最新状态。

## 对象类型与执行路径的映射

### 地址所有对象 → 快速路径

地址所有对象的交易始终走快速路径。这是 Sui 中性能最优的对象类型。

### 不可变对象 → 快速路径

不可变对象永远不会被修改，因此也走快速路径。而且不可变对象可以被**无限数量的交易同时使用**，是最优的只读数据存储方式。

### 共享对象 → 共识路径

共享对象的交易必须走共识路径。这是最慢但功能最强大的执行路径。

### 被包装对象 → 继承父对象

被包装（wrapped）的对象不在全局存储中独立存在，它们的执行路径由**父对象的所有权类型**决定：

- 如果父对象是地址所有的 → 快速路径
- 如果父对象是共享的 → 共识路径

```move
module examples::inherited_path;

use std::string::String;

public struct Weapon has store {
    name: String,
    damage: u64,
}

/// 地址所有的角色 → 对武器的操作走快速路径
public struct OwnedCharacter has key {
    id: UID,
    weapon: Option<Weapon>,
}

/// 共享的 NPC → 对武器的操作走共识路径
public struct SharedNPC has key {
    id: UID,
    weapon: Option<Weapon>,
}

public fun equip_owned(character: &mut OwnedCharacter, weapon: Weapon) {
    option::fill(&mut character.weapon, weapon);
}

public fun equip_shared(npc: &mut SharedNPC, weapon: Weapon) {
    option::fill(&mut npc.weapon, weapon);
}
```

在这个例子中，`equip_owned` 走快速路径（因为 `OwnedCharacter` 是地址所有的），而 `equip_shared` 走共识路径（因为 `SharedNPC` 是共享的）。同样的 `Weapon` 数据操作，因为父对象类型不同，执行路径也不同。

## 混合交易

一个交易可以同时涉及多种类型的对象。在这种情况下：

- **只要有一个共享对象，整个交易就走共识路径**
- 只有**全部**输入对象都是地址所有或不可变的，交易才走快速路径

```move
module examples::mixed_transaction;

public struct OwnedToken has key, store {
    id: UID,
    value: u64,
}

public struct SharedPool has key {
    id: UID,
    total: u64,
}

/// 这个交易同时涉及地址所有对象和共享对象
/// 因此走共识路径
public fun deposit(
    token: OwnedToken,
    pool: &mut SharedPool,
) {
    pool.total = pool.total + token.value;
    let OwnedToken { id, value: _ } = token;
    id.delete();
}
```

`deposit` 函数接收一个地址所有的 `OwnedToken` 和一个共享的 `SharedPool`。由于涉及共享对象，整个交易走共识路径。

## 性能优化策略

理解快速路径和共识路径后，我们可以有针对性地优化应用性能。

### 策略一：最大化使用地址所有对象

将尽可能多的数据存储为地址所有对象，最小化共享对象的使用：

```move
module examples::perf_optimization;

/// 较差设计：所有余额存在一个共享对象中
public struct SharedLedger has key {
    id: UID,
    balances: vector<u64>,
    owners: vector<address>,
}

/// 较好设计：每个用户有自己的余额对象
public struct PersonalBalance has key {
    id: UID,
    balance: u64,
}

/// 用户间转账时才使用共享对象协调
public struct TransferRequest has key {
    id: UID,
    from: address,
    to: address,
    amount: u64,
}
```

### 策略二：利用不可变对象缓存只读数据

将不会变化的数据冻结为不可变对象，享受快速路径的性能：

```move
module examples::cache_pattern;

use std::string::String;

/// 将价格表冻结为不可变对象
public struct PriceTable has key {
    id: UID,
    prices: vector<u64>,
    symbols: vector<String>,
    updated_at: u64,
}

public fun create_price_table(
    prices: vector<u64>,
    symbols: vector<String>,
    timestamp: u64,
    ctx: &mut TxContext,
) {
    let table = PriceTable {
        id: object::new(ctx),
        prices,
        symbols,
        updated_at: timestamp,
    };
    transfer::freeze_object(table);
}

/// 任何人都可以高效地读取价格，走快速路径
public fun price_at(table: &PriceTable, index: u64): u64 {
    *vector::borrow(&table.prices, index)
}
```

### 策略三：延迟共享

对象不需要在创建时就共享。可以先作为地址所有对象进行初始化配置，准备就绪后再共享：

```move
module examples::lazy_sharing;

const ENotConfigured: u64 = 0;

public struct GameRoom has key {
    id: UID,
    name: vector<u8>,
    max_players: u64,
    is_configured: bool,
}

/// 步骤1：创建房间（地址所有，走快速路径）
public fun create_room(
    name: vector<u8>,
    ctx: &mut TxContext,
): GameRoom {
    GameRoom {
        id: object::new(ctx),
        name,
        max_players: 0,
        is_configured: false,
    }
}

/// 步骤2：配置房间（仍是地址所有，走快速路径）
public fun configure(room: &mut GameRoom, max_players: u64) {
    room.max_players = max_players;
    room.is_configured = true;
}

/// 步骤3：配置完成后共享（之后走共识路径）
public fun open_room(room: GameRoom) {
    assert!(room.is_configured, ENotConfigured);
    transfer::share_object(room);
}
```

这种模式将配置阶段（可能需要多次修改）保持在快速路径上，只在最终需要多方访问时才切换到共识路径。

## 执行路径的选择决策树

在设计应用时，可以按照以下决策树来选择对象的所有权类型：

```
该数据是否需要被多方修改？
├── 否 → 该数据创建后是否需要修改？
│   ├── 否 → 使用不可变对象（快速路径，最优）
│   └── 是 → 使用地址所有对象（快速路径）
└── 是 → 使用共享对象（共识路径，必要时）
```

## 实际性能数据

以下是 Sui 主网上不同执行路径的典型性能数据（供参考）：

| 指标 | 快速路径 | 共识路径 |
|------|---------|---------|
| 最终确认延迟 | 400-600ms | 2-3s |
| 吞吐量 | 极高（并行） | 受共识限制 |
| Gas 费用 | 较低 | 较高 |
| 并发能力 | 无冲突交易完全并行 | 同一对象的交易串行 |

## 小结

Sui 的双轨执行模型是其高性能的核心秘密。关键要点回顾：

- **快速路径**：涉及地址所有对象和不可变对象的交易跳过共识，直接执行，延迟极低。
- **共识路径**：涉及共享对象的交易需要共识排序，延迟较高但保证了数据一致性。
- **混合交易**：只要包含一个共享对象，整个交易就走共识路径。
- **继承规则**：被包装对象继承父对象的执行路径。
- **性能优化**：最大化使用地址所有和不可变对象，最小化共享对象的使用。
- **延迟共享**：先以地址所有对象进行初始化，准备就绪后再共享。

理解并善用快速路径与共识路径的区别，是构建高性能 Sui 应用的关键。在大多数应用中，80-90% 的交易都可以设计为走快速路径，只有在真正需要多方交互时才使用共享对象。
