# 自定义转移策略

TransferPolicy 是 Kiosk 系统中控制 NFT 转移行为的核心机制。通过附加不同的规则（Rule），你可以实现版税收取、锁定要求、个人 Kiosk 限制等高级功能。本节将介绍如何创建和配置 TransferPolicy 及其规则。

## TransferPolicy 概述

当买家从 Kiosk 购买 NFT 时，会生成一个 `TransferRequest`。这个请求必须满足 TransferPolicy 中所有已添加的规则后才能被确认，NFT 才能完成转移。

```
购买 NFT → 生成 TransferRequest → 满足所有 Rule → confirm_request → NFT 转移完成
```

## 创建 TransferPolicy

创建 Policy 需要 `Publisher` 对象证明你是该 NFT 类型的发布者：

```move
use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap};
use sui::package::Publisher;

fun create_transfer_policy<T>(
    publisher: &Publisher,
    ctx: &mut TxContext,
) {
    let (policy, policy_cap) = transfer_policy::new<T>(publisher, ctx);
    transfer::public_share_object(policy);
    transfer::public_transfer(policy_cap, ctx.sender());
}
```

## 规则机制说明

Sui Framework 只提供 TransferPolicy 原语（`add_rule`、`get_rule`、`add_receipt`、`add_to_balance` 等），**不提供**现成的 `sui::royalty_rule`、`sui::kiosk_lock_rule` 等模块。版税、锁定、个人 Kiosk 等规则需要：

- 在 Move 中自行基于 `transfer_policy::add_rule` 实现，或  
- 使用生态包（如 [MystenLabs Kiosk 包](https://github.com/MystenLabs/apps/tree/main/kiosk)）中提供的规则。

下面以「版税规则」为例说明如何在 Move 中实现并满足规则；TS SDK 的用法仍可与 Kiosk 包或自定义规则配合使用。

### 版税规则（Royalty Rule）示例

每次交易按比例收取版税。前端可使用 `@mysten/kiosk` 的 `RoyaltyRule`（依赖 Kiosk 包）与已有 Policy 交互；在 Move 中需自行实现规则逻辑。

在 Move 中（自定义规则，仅用 framework）：

```move
// 自定义 Rule 与 Config，使用 transfer_policy::add_rule
module game::royalty_rule;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::transfer_policy::{Self as policy, TransferPolicy, TransferPolicyCap, TransferRequest};

const MAX_BP: u16 = 10_000;

public struct Rule has drop {}
public struct Config has store, drop { amount_bp: u16 }

public fun add<T: key + store>(
    policy: &mut TransferPolicy<T>,
    cap: &TransferPolicyCap<T>,
    amount_bp: u16,
) {
    assert!(amount_bp <= MAX_BP, 0);
    policy::add_rule(Rule {}, policy, cap, Config { amount_bp })
}

public fun pay<T: key + store>(
    policy: &mut TransferPolicy<T>,
    request: &mut TransferRequest<T>,
    payment: &mut Coin<SUI>,
    ctx: &mut TxContext,
) {
    let paid = policy::paid(request);
    let config = policy::get_rule(Rule {}, policy);
    let amount = ((paid as u128) * (config.amount_bp as u128) / (MAX_BP as u128)) as u64;
    assert!(coin::value(payment) >= amount, 1);
    let fee = coin::split(payment, amount, ctx);
    policy::add_to_balance(Rule {}, policy, fee);
    policy::add_receipt(Rule {}, request)
}
```

添加 5% 版税并创建 Policy 后，购买时需先调用该规则的 `pay` 再 `confirm_request`：

```move
// 购买时：先 pay 版税，再 confirm
let (item, mut request) = kiosk::purchase<Sword>(kiosk, item_id, payment);
royalty_rule::pay(policy, &mut request, &mut royalty_payment, ctx);
transfer_policy::confirm_request(policy, request);
transfer::public_transfer(item, ctx.sender());
```

### 锁定规则（Kiosk Lock Rule）

要求买家将 NFT 锁定在自己的 Kiosk 中，不能直接取出。锁定规则的实现不在 Sui Framework 内，而是由 [Kiosk 包](https://github.com/MystenLabs/apps/tree/main/kiosk) 提供（如 `kiosk::kiosk_lock_rule`）。

前端可用 TypeScript 添加规则：

```typescript
import { KioskLockRule } from "@mysten/kiosk/rules";

KioskLockRule.add(tx, {
  policy: policyId,
  policyCap: policyCapId,
});
```

若在 Move 中依赖 Kiosk 包，则添加与满足规则的方式类似：

```move
// 依赖 Kiosk 包时
use kiosk::kiosk_lock_rule;

kiosk_lock_rule::add(policy, cap);

// 购买后锁入买家 Kiosk 并证明
let (item, mut request) = kiosk::purchase<Sword>(seller_kiosk, item_id, payment);
kiosk::lock(buyer_kiosk, buyer_cap, policy, item);
kiosk_lock_rule::prove(&mut request, buyer_kiosk);
```

### 个人 Kiosk 规则（Personal Kiosk Rule）

要求买家使用个人 Kiosk（不可转让 KioskOwnerCap 的 Kiosk）。该规则同样由 Kiosk 生态包提供，Framework 中无对应模块。

```typescript
import { PersonalKioskRule } from "@mysten/kiosk/rules";

PersonalKioskRule.add(tx, {
  policy: policyId,
  policyCap: policyCapId,
});
```

创建个人 Kiosk：

```typescript
const kioskTx = new KioskTransaction({
  transaction: tx,
  kioskClient,
});

kioskTx.createPersonal();
kioskTx.finalize();
```

## 组合多个规则

可以同时添加多个规则，所有规则都必须满足。版税类规则可在本包内用 `transfer_policy::add_rule` 实现；锁定、个人 Kiosk 等需依赖 Kiosk 包：

```move
// 假设本包有 game::royalty_rule，并依赖 Kiosk 包
use game::royalty_rule;
use kiosk::kiosk_lock_rule;
use kiosk::personal_kiosk_rule;

public fun setup_strict_policy(
    policy: &mut TransferPolicy<Sword>,
    cap: &TransferPolicyCap<Sword>,
) {
    royalty_rule::add(policy, cap, 500);      // 5% 版税（自定义规则）
    kiosk_lock_rule::add(policy, cap);       // 必须锁定在 Kiosk（Kiosk 包）
    personal_kiosk_rule::add(policy, cap);   // 必须使用个人 Kiosk（Kiosk 包）
}
```

购买时满足所有规则：

```typescript
const kioskTx = new KioskTransaction({
  transaction: tx,
  kioskClient,
  kioskCap: buyerKioskCap,
});

await kioskTx.purchase({
  itemType: `${PACKAGE_ID}::sword::Sword`,
  itemId: swordId,
  price: 1_000_000_000n,
  sellerKiosk: sellerKioskId,
});

// SDK 会自动解析 Policy 中的规则并生成对应的满足逻辑
kioskTx.finalize();
```

## 自定义规则

除了内置规则，你还可以创建自定义规则：

```move
module game::level_rule;

use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap, TransferRequest};

public struct LevelRule() has drop;

public struct Config has store, drop {
    min_level: u64,
}

/// 添加等级要求规则
public fun add<T>(
    policy: &mut TransferPolicy<T>,
    cap: &TransferPolicyCap<T>,
    min_level: u64,
) {
    transfer_policy::add_rule(LevelRule(), policy, cap, Config { min_level });
}

/// 验证买家等级
public fun prove<T>(
    request: &mut TransferRequest<T>,
    player_level: u64,
    policy: &TransferPolicy<T>,
) {
    let config: &Config = transfer_policy::get_rule(LevelRule(), policy);
    assert!(player_level >= config.min_level);
    transfer_policy::add_receipt(LevelRule(), request);
}
```

## 提取版税收益

Policy 持有者可提取收集的版税：

```move
let profits = transfer_policy::withdraw(
    policy,
    cap,
    option::none(), // none 表示全部提取
    ctx,
);
transfer::public_transfer(profits, ctx.sender());
```

## 小结

- TransferPolicy 控制 NFT 通过 Kiosk 交易时的转移行为
- Framework 只提供 `add_rule` / `get_rule` / `add_receipt` 等原语，无现成「内置」版税/锁定/个人 Kiosk 模块；版税等需自行实现或使用 [Kiosk 包](https://github.com/MystenLabs/apps/tree/main/kiosk) 中的规则
- 多个规则可组合使用，所有规则都必须满足后转移才能完成
- 可创建自定义规则实现特定业务逻辑
- TypeScript SDK 的 KioskClient 可自动解析 Policy 规则并生成满足逻辑
