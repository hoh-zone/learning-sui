# 转移限制

Sui Move 的对象系统内置了一套精巧的**转移权限控制**机制。通过 `key` 和 `store` 能力的组合，开发者可以精确控制谁能转移、冻结或共享一个对象。这一机制是实现灵魂绑定代币（SBT）、权限凭证和受控资产等模式的基础。

## 默认行为：转移受限

在 Sui 中，存储操作（`transfer`、`freeze_object`、`share_object`）默认是**受限的**——只有定义该类型的模块才能调用这些操作。

这意味着当你创建一个只有 `key` 的对象时，外部模块无法对它执行任何存储操作：

```move
module examples::transfer_a;

/// key only —— 转移受限，只有本模块能转移
public struct SoulboundNFT has key {
    id: UID,
    name: vector<u8>,
}

/// key + store —— 公开转移，任何人都可以转移
public struct TradableNFT has key, store {
    id: UID,
    name: vector<u8>,
}

public fun mint_soulbound(name: vector<u8>, to: address, ctx: &mut TxContext) {
    let nft = SoulboundNFT { id: object::new(ctx), name };
    transfer::transfer(nft, to);
}

public fun mint_tradable(name: vector<u8>, to: address, ctx: &mut TxContext) {
    let nft = TradableNFT { id: object::new(ctx), name };
    transfer::public_transfer(nft, to);
}
```

## Sui 验证器的强制约束

转移限制不是靠编程约定实现的——它由 **Sui 字节码验证器（Sui Verifier）** 在**发布时**强制执行。

### 验证规则

当验证器检查一个模块时，它会扫描所有对 `transfer::transfer`、`transfer::freeze_object`、`transfer::share_object` 的调用，并检查：

> **被操作的类型 `T` 是否在当前模块中定义？**

如果不是，验证器直接拒绝发布。这是字节码级别的检查，无法通过任何编程技巧绕过。

同类「类型须由当前模块定义」的约束也适用于其他 Sui 标准 API，例如 `sui::event::emit<T>`：泛型参数 `T` 必须由调用方所在模块定义，否则验证器会报错。其目的与转移限制一致：保证关键操作的类型由可信模块控制。

### 跨模块示例

```move
module examples::transfer_b;

use examples::transfer_a::{TradableNFT};

/// 合法：TradableNFT 有 `store`，可以使用 public_transfer
public fun transfer_tradable(nft: TradableNFT, to: address) {
    transfer::public_transfer(nft, to);
}
```

如果尝试对 `SoulboundNFT` 做同样的操作：

```move
module examples::transfer_c;

use examples::transfer_a::{SoulboundNFT};

/// 非法！SoulboundNFT 只有 key，不能在外部模块使用 transfer
public fun try_transfer(nft: SoulboundNFT, to: address) {
    transfer::transfer(nft, to);         // 验证器拒绝！
}

/// 也不行！SoulboundNFT 没有 store，不能使用 public_transfer
public fun try_public_transfer(nft: SoulboundNFT, to: address) {
    transfer::public_transfer(nft, to);  // 编译错误！
}
```

## public_* 函数放宽限制

`transfer` 模块的 `public_*` 系列函数通过要求 `store` 能力来放宽限制：

```move
// 内部版本：T: key —— 只能在定义 T 的模块中调用
public fun transfer<T: key>(obj: T, recipient: address);

// 公开版本：T: key + store —— 可在任何模块调用
public fun public_transfer<T: key + store>(obj: T, recipient: address);
```

`store` 能力在这里充当了一个**显式的许可标记**——模块作者通过给类型添加 `store`，明确声明"我允许外部模块操作这个类型的存储"。

## key-only vs key+store 对比

| 特性 | key only | key + store |
|------|----------|-------------|
| 是否为对象 | 是 | 是 |
| 模块内转移 | `transfer::transfer` | `transfer::transfer` 或 `public_transfer` |
| 外部模块转移 | 不可能 | `transfer::public_transfer` |
| 模块内冻结 | `transfer::freeze_object` | 两者皆可 |
| 外部模块冻结 | 不可能 | `transfer::public_freeze_object` |
| 模块内共享 | `transfer::share_object` | 两者皆可 |
| 外部模块共享 | 不可能 | `transfer::public_share_object` |
| 可包装（Wrap） | 不可以 | 可以 |
| 自定义转移逻辑 | 支持 | 难以强制执行 |
| 用例 | 权限控制、SBT | NFT、代币、可交易资产 |

## 添加 store 的影响

决定是否给对象添加 `store` 是一个**灵活性 vs 控制权**的权衡。

### 添加 store 意味着

1. **自由流通**：持有者可以自由转移对象，不受模块约束。
2. **可组合**：其他模块可以将你的对象包装（wrap）在它们的对象中。
3. **失去控制**：你无法阻止转移、不能收取转移费用、不能实施黑名单。
4. **PTB 友好**：用户可以在可编程交易块（PTB）中直接操作。

### 不添加 store 意味着

1. **模块控制**：所有转移必须通过你的模块函数，你可以添加任意业务逻辑。
2. **不可组合**：其他模块无法包装或自由操作你的对象。
3. **可实现**：收费转移、冷却期、白名单、审批流程等。
4. **PTB 受限**：用户必须调用你提供的函数来操作对象。

## 灵魂绑定代币模式

灵魂绑定代币（Soulbound Token, SBT）是"key without store"的经典应用：

```move
module examples::soulbound;

use std::string::String;

/// 灵魂绑定徽章——不可转让
public struct Badge has key {
    id: UID,
    title: String,
    description: String,
    issued_to: address,
    issued_at: u64,
}

/// 只有本模块能颁发徽章
public fun issue(
    title: String,
    description: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let badge = Badge {
        id: object::new(ctx),
        title,
        description,
        issued_to: recipient,
        issued_at: ctx.epoch(),
    };
    transfer::transfer(badge, recipient);
}

/// 持有者可以选择销毁自己的徽章
public fun burn(badge: Badge) {
    let Badge {
        id,
        title: _,
        description: _,
        issued_to: _,
        issued_at: _,
    } = badge;
    id.delete();
}
```

由于 `Badge` 只有 `key`：

- 持有者**无法转让**给其他人（`transfer::public_transfer` 不可用，`transfer::transfer` 只能在本模块调用）。
- 徽章永远绑定在最初的接收者身上。
- 只有通过模块提供的 `burn` 函数才能销毁。

## 受控转移模式

利用 key-only 限制，可以实现自定义的转移逻辑：

```move
module examples::controlled_transfer;

use std::string::String;

const EMaxTransfersReached: u64 = 0;

public struct Ticket has key {
    id: UID,
    event_name: String,
    transfer_count: u64,
    max_transfers: u64,
}

/// 铸造门票
public fun mint(
    event_name: String,
    max_transfers: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let ticket = Ticket {
        id: object::new(ctx),
        event_name,
        transfer_count: 0,
        max_transfers,
    };
    transfer::transfer(ticket, recipient);
}

/// 受控转移——带有转移次数限制
public fun controlled_transfer(
    mut ticket: Ticket,
    to: address,
) {
    assert!(
        ticket.transfer_count < ticket.max_transfers,
        EMaxTransfersReached,
    );

    ticket.transfer_count = ticket.transfer_count + 1;
    transfer::transfer(ticket, to);
}
```

在这个例子中，门票只能通过 `controlled_transfer` 函数转移，并且有最大转移次数限制。如果 `Ticket` 有 `store`，持有者就可以绕过这个限制直接用 `public_transfer` 转移。

## 自定义策略模式

通过 `key` only，开发者可以实现更复杂的策略：

```move
module examples::policy_transfer;

use std::string::String;
use sui::coin::Coin;
use sui::sui::SUI;

public struct PremiumAsset has key {
    id: UID,
    name: String,
    value: u64,
}

public struct TransferPolicy has key {
    id: UID,
    fee_bps: u64,        // 转移费率（基点）
    fee_recipient: address,
}

/// 创建转移策略（共享对象）
public fun create_policy(
    fee_bps: u64,
    fee_recipient: address,
    ctx: &mut TxContext,
) {
    let policy = TransferPolicy {
        id: object::new(ctx),
        fee_bps,
        fee_recipient,
    };
    transfer::share_object(policy);
}

/// 需要缴费的转移
public fun transfer_with_fee(
    asset: PremiumAsset,
    policy: &TransferPolicy,
    mut payment: Coin<SUI>,
    to: address,
    ctx: &mut TxContext,
) {
    let fee_amount = (asset.value * policy.fee_bps) / 10000;
    let fee = payment.split(fee_amount, ctx);

    transfer::public_transfer(fee, policy.fee_recipient);
    transfer::public_transfer(payment, ctx.sender());
    transfer::transfer(asset, to);
}
```

## 小结

- Sui 的存储操作默认受限于定义类型的模块，这由 Sui 字节码验证器在发布时强制执行。
- `public_*` 函数通过要求 `store` 能力来放宽限制，允许外部模块操作对象。
- `key only` 提供最大的控制权，适合权限凭证、灵魂绑定代币、受控转移等场景。
- `key + store` 提供最大的灵活性，适合 NFT、代币等需要自由流通的资产。
- 是否添加 `store` 是 Sui 对象设计中最重要的决策——它决定了谁能控制对象的生命周期。
- 利用 key-only 限制，开发者可以实现收费转移、次数限制、审批流程等自定义策略。
