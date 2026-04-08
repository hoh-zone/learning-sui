# 事件系统

事件（Events）是 Sui Move 中合约与链下世界通信的桥梁。通过事件，智能合约可以向链下应用程序、索引器和用户界面发送通知，告知链上发生了什么。事件不会存储在链上状态中，但会被 Sui 全节点记录并提供查询接口，是构建响应式 DApp 的重要基础。

## 事件基础

### 核心概念

事件系统由 `sui::event` 模块提供，其核心是一个简单的函数：

```move
public native fun emit<T: copy + drop>(event: T);
```

当合约调用 `event::emit()` 时，Sui 运行时会捕获该事件数据，并将其附加到交易的执行结果中。链下应用可以通过 Sui JSON-RPC API 订阅和查询这些事件。

### 事件类型要求

用作事件的结构体必须满足以下条件：

| 要求 | 说明 |
|------|------|
| `copy` 能力 | 事件值需要被复制 |
| `drop` 能力 | 事件值在 emit 后被丢弃 |
| 模块内部定义 | 事件类型必须在调用 `emit` 的模块内定义 |

注意：事件类型**不能**使用从其他模块导入的类型作为事件 emit。你只能 emit 当前模块中定义的结构体。该要求来自 Sui 验证器的**内部约束**规则，原理与更多示例见[内部约束](../07_using_objects/05-internal-constraint.md)。

### 事件的元数据

每个 emit 的事件会自动附带以下元数据信息（由 Sui 运行时添加，无需开发者处理）：

- **发送者地址**：触发事件的交易发送者
- **包 ID**：发出事件的包地址
- **模块名**：发出事件的模块
- **事件类型**：事件结构体的完全限定类型名
- **时间戳**：交易执行的时间

## 定义和发出事件

### 基本用法

```move
module examples::marketplace_events;

use std::string::String;

/// 商品上架事件
public struct ItemListed has copy, drop {
    item_id: ID,
    price: u64,
    seller: address,
}

/// 商品售出事件
public struct ItemSold has copy, drop {
    item_id: ID,
    price: u64,
    seller: address,
    buyer: address,
}

/// 取消上架事件
public struct ListingCancelled has copy, drop {
    item_id: ID,
    seller: address,
}

public struct Item has key, store {
    id: UID,
    name: String,
}

public fun list_item(item: &Item, price: u64, ctx: &TxContext) {
    sui::event::emit(ItemListed {
        item_id: object::id(item),
        price,
        seller: ctx.sender(),
    });
}

public fun buy_item(
    item: &Item,
    price: u64,
    seller: address,
    ctx: &TxContext,
) {
    sui::event::emit(ItemSold {
        item_id: object::id(item),
        price,
        seller,
        buyer: ctx.sender(),
    });
}

public fun cancel_listing(item: &Item, ctx: &TxContext) {
    sui::event::emit(ListingCancelled {
        item_id: object::id(item),
        seller: ctx.sender(),
    });
}
```

### 导入方式

你可以选择完整路径或导入 `emit` 函数：

```move
module examples::event_import;

// 方式一：使用完整路径
// sui::event::emit(MyEvent { ... });

// 方式二：导入模块
use sui::event;

public struct Transfer has copy, drop {
    from: address,
    to: address,
    amount: u64,
}

public fun do_transfer(from: address, to: address, amount: u64) {
    // 使用模块前缀
    event::emit(Transfer { from, to, amount });
}
```

## 事件设计最佳实践

### 命名规范

事件类型名称应该使用**过去分词**或**动作名词**，清晰表达发生了什么：

```move
module examples::event_naming;

// 好的命名——清晰表达了发生的动作
public struct TokenMinted has copy, drop {
    token_id: ID,
    recipient: address,
    amount: u64,
}

public struct PoolCreated has copy, drop {
    pool_id: ID,
    creator: address,
    initial_liquidity: u64,
}

public struct VoteSubmitted has copy, drop {
    proposal_id: ID,
    voter: address,
    vote: bool,
}
```

### 包含足够的信息

事件应该包含链下应用需要的所有关键信息，避免链下应用还需要额外查询链上状态：

```move
module examples::rich_events;

use std::string::String;

public struct NFTMinted has copy, drop {
    nft_id: ID,
    collection_id: ID,
    name: String,
    creator: address,
    serial_number: u64,
    total_supply: u64,
    timestamp_ms: u64,
}

public struct AuctionCompleted has copy, drop {
    auction_id: ID,
    item_id: ID,
    winner: address,
    winning_bid: u64,
    total_bids: u64,
    duration_epochs: u64,
}
```

### 为不同操作定义不同事件

不要试图用一个通用事件覆盖所有场景，而是为每种操作定义专门的事件类型。这让链下消费者可以精确订阅感兴趣的事件。

```move
module examples::defi_events;

public struct LiquidityAdded has copy, drop {
    pool_id: ID,
    provider: address,
    amount_a: u64,
    amount_b: u64,
    lp_tokens_minted: u64,
}

public struct LiquidityRemoved has copy, drop {
    pool_id: ID,
    provider: address,
    amount_a: u64,
    amount_b: u64,
    lp_tokens_burned: u64,
}

public struct SwapExecuted has copy, drop {
    pool_id: ID,
    trader: address,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
}
```

## 完整示例：带事件的投票系统

```move
module examples::voting;

use std::string::String;
use sui::event;

// ========== 事件定义 ==========

public struct ProposalCreated has copy, drop {
    proposal_id: ID,
    title: String,
    creator: address,
    end_epoch: u64,
}

public struct VoteCast has copy, drop {
    proposal_id: ID,
    voter: address,
    in_favor: bool,
}

public struct ProposalFinalized has copy, drop {
    proposal_id: ID,
    approved: bool,
    yes_votes: u64,
    no_votes: u64,
}

// ========== 常量 ==========

const EAlreadyFinalized: u64 = 0;
const EVotingEnded: u64 = 1;

// ========== 数据结构 ==========

public struct Proposal has key {
    id: UID,
    title: String,
    creator: address,
    yes_votes: u64,
    no_votes: u64,
    end_epoch: u64,
    finalized: bool,
}

public struct VoterCap has key {
    id: UID,
}

// ========== 函数 ==========

public fun create_proposal(
    title: String,
    duration_epochs: u64,
    ctx: &mut TxContext,
) {
    let proposal = Proposal {
        id: object::new(ctx),
        title,
        creator: ctx.sender(),
        yes_votes: 0,
        no_votes: 0,
        end_epoch: ctx.epoch() + duration_epochs,
        finalized: false,
    };

    event::emit(ProposalCreated {
        proposal_id: object::id(&proposal),
        title: proposal.title,
        creator: proposal.creator,
        end_epoch: proposal.end_epoch,
    });

    transfer::share_object(proposal);
}

public fun vote(proposal: &mut Proposal, in_favor: bool, ctx: &TxContext) {
    assert!(!proposal.finalized, EAlreadyFinalized);
    assert!(ctx.epoch() <= proposal.end_epoch, EVotingEnded);

    if (in_favor) {
        proposal.yes_votes = proposal.yes_votes + 1;
    } else {
        proposal.no_votes = proposal.no_votes + 1;
    };

    event::emit(VoteCast {
        proposal_id: object::id(proposal),
        voter: ctx.sender(),
        in_favor,
    });
}

public fun finalize(proposal: &mut Proposal, ctx: &TxContext) {
    assert!(!proposal.finalized, EAlreadyFinalized);
    assert!(ctx.epoch() > proposal.end_epoch, EVotingEnded);

    proposal.finalized = true;
    let approved = proposal.yes_votes > proposal.no_votes;

    event::emit(ProposalFinalized {
        proposal_id: object::id(proposal),
        approved,
        yes_votes: proposal.yes_votes,
        no_votes: proposal.no_votes,
    });
}
```

## 链下事件订阅

虽然链下订阅的代码不是 Move 合约的一部分，但了解消费端如何工作有助于你设计更好的事件。Sui 提供了以下方式来获取事件：

1. **JSON-RPC API**：使用 `suix_queryEvents` 方法按事件类型、发送者、交易哈希等条件查询历史事件
2. **WebSocket 订阅**：使用 `suix_subscribeEvent` 方法实时订阅新事件
3. **索引器**：通过第三方索引服务（如 Sui Indexer）聚合和查询事件

查询事件的典型 RPC 调用示例（JSON-RPC）：

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "suix_queryEvents",
    "params": [
        {
            "MoveEventType": "0xPACKAGE_ID::marketplace_events::ItemSold"
        },
        null,
        10,
        false
    ]
}
```

## 小结

事件是 Sui Move 合约与链下世界沟通的标准机制。事件类型必须具有 `copy` 和 `drop` 能力，且只能在定义它的模块中通过 `sui::event::emit()` 发出。事件数据不存储在链上状态中，但由全节点记录，可通过 JSON-RPC API 查询和订阅。设计事件时应遵循以下原则：为每种操作定义专门的事件类型、包含足够的上下文信息、使用清晰的命名。良好的事件设计能极大简化链下应用的开发，是构建完整 DApp 体验不可或缺的一环。
