# Transfer 函数参考

本附录汇总 `sui::transfer` 模块中所有转移函数的签名、用途和权限要求。

## 函数总览

| 函数 | 公共变体 | 最终状态 | 权限 |
|------|---------|---------|------|
| `transfer` | `public_transfer` | 地址所有 | 完全权限 |
| `share_object` | `public_share_object` | 共享 | 引用、可变引用、删除 |
| `freeze_object` | `public_freeze_object` | 冻结 | 仅不可变引用 |
| `party_transfer` | `public_party_transfer` | Party | 取决于 Party 设置 |

## 对象状态说明

| 状态 | 描述 |
|------|------|
| 地址所有（Address Owned） | 对象可以被一个地址（或对象）完全访问 |
| 共享（Shared） | 对象可以被任何人引用和删除 |
| 冻结（Frozen） | 对象只能通过不可变引用访问 |
| Party | 取决于 Party 设置 |

## 详细函数签名

### transfer / public_transfer

将对象转移到指定地址，使其成为地址所有的对象。

```move
// 模块内部使用（不需要 store 能力）
public fun transfer<T: key>(obj: T, recipient: address);

// 公共使用（需要 store 能力）
public fun public_transfer<T: key + store>(obj: T, recipient: address);
```

**使用示例**：

```move
module my_package::example;

// key only 的类型只能在定义模块内 transfer
public struct AdminCap has key {
    id: UID,
}

// key + store 的类型可以从任何地方 public_transfer
public struct NFT has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    // 模块内使用 transfer
    transfer::transfer(AdminCap {
        id: object::new(ctx),
    }, ctx.sender());
}

public fun mint(ctx: &mut TxContext): NFT {
    NFT { id: object::new(ctx) }
    // 调用者可以使用 public_transfer 转移
}
```

### share_object / public_share_object

将对象变为共享对象，任何人都可以访问。

```move
// 模块内部使用
public fun share_object<T: key>(obj: T);

// 公共使用（需要 store）
public fun public_share_object<T: key + store>(obj: T);
```

**使用示例**：

```move
public struct Registry has key {
    id: UID,
    items: vector<ID>,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(Registry {
        id: object::new(ctx),
        items: vector[],
    });
}
```

**注意**：共享后不可逆——对象永远保持共享状态。

### freeze_object / public_freeze_object

将对象冻结为不可变对象。

```move
// 模块内部使用
public fun freeze_object<T: key>(obj: T);

// 公共使用（需要 store）
public fun public_freeze_object<T: key + store>(obj: T);
```

**使用示例**：

```move
public struct Config has key, store {
    id: UID,
    max_supply: u64,
    name: String,
}

public fun freeze_config(config: Config) {
    transfer::public_freeze_object(config);
    // 此后 config 只能通过 &Config 访问
}
```

### receive

从"父"对象中接收一个发送给它的"子"对象。

```move
public fun receive<T: key>(parent: &mut UID, to_receive: Receiving<T>): T;

public fun public_receive<T: key + store>(parent: &mut UID, to_receive: Receiving<T>): T;
```

**使用示例**：

```move
public struct Wallet has key {
    id: UID,
}

public fun accept_nft(
    wallet: &mut Wallet,
    nft_receiving: Receiving<NFT>,
): NFT {
    transfer::public_receive(&mut wallet.id, nft_receiving)
}
```

## 选择指南

### 何时使用 transfer vs public_transfer

```move
// 使用 transfer：希望限制转移权限在模块内
public struct SoulboundNFT has key {
    id: UID,
    // 没有 store 能力，外部无法调用 public_transfer
}

// 使用 public_transfer：允许自由转让
public struct TradableNFT has key, store {
    id: UID,
    // 有 store 能力，任何模块都可以调用 public_transfer
}
```

### 决策流程图

```
创建对象后要做什么？
    │
    ├── 转给特定地址 ──────────── transfer / public_transfer
    │
    ├── 所有人都能访问和修改 ──── share_object / public_share_object
    │
    ├── 永远不再修改 ──────────── freeze_object / public_freeze_object
    │
    └── 发送给另一个对象 ──────── transfer（收件人为对象地址）
                                  └── 使用 receive 接收
```

### store 能力的影响

| 有无 store | transfer | public_transfer | 被包装 | 动态字段 |
|-----------|----------|-----------------|--------|---------|
| 无 store | ✓ 模块内 | ✗ | ✗ | ✗ |
| 有 store | ✓ | ✓ 任何地方 | ✓ | ✓ |

## 常见模式

### 铸造并转让

```move
public fun mint_and_transfer(
    name: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let nft = NFT {
        id: object::new(ctx),
        name,
    };
    transfer::public_transfer(nft, recipient);
}
```

### 可组合铸造（推荐）

```move
// 返回对象，让 PTB 决定如何处理
public fun mint(name: String, ctx: &mut TxContext): NFT {
    NFT {
        id: object::new(ctx),
        name,
    }
}

// PTB 中：
// const [nft] = tx.moveCall({ target: '...::mint', ... });
// tx.transferObjects([nft], recipient);
```

## 小结

- `transfer` 系列函数控制对象的最终状态：地址所有、共享或冻结
- `public_*` 变体需要对象有 `store` 能力，允许从任何模块调用
- 非 `public_*` 变体只能在定义该类型的模块内调用
- 共享和冻结操作不可逆
- 推荐可组合设计：函数返回对象，让调用者（PTB）决定后续操作
