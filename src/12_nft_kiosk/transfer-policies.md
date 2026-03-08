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

## 内置规则

Sui Framework 提供了几种常用的内置规则：

### 版税规则（Royalty Rule）

每次交易自动收取版税：

```typescript
import { percentageToBasisPoints } from "@mysten/kiosk";
import { RoyaltyRule } from "@mysten/kiosk/rules";

// 在 TransferPolicy 上添加版税规则
RoyaltyRule.add(tx, {
  policy: policyId,
  policyCap: policyCapId,
  percentageBps: percentageToBasisPoints(5), // 5% 版税
  minAmount: 1_000_000, // 最低版税
});
```

在 Move 中：

```move
use sui::royalty_rule;

public fun add_royalty(
    policy: &mut TransferPolicy<Sword>,
    cap: &TransferPolicyCap<Sword>,
) {
    // 添加 5% 版税规则，最低 100 MIST
    royalty_rule::add(policy, cap, 500, 100);
}
```

购买时满足版税规则：

```move
use sui::royalty_rule;

public fun purchase_with_royalty(
    kiosk: &mut Kiosk,
    item_id: ID,
    payment: Coin<SUI>,
    policy: &mut TransferPolicy<Sword>,
    ctx: &mut TxContext,
) {
    let (item, mut request) = kiosk::purchase<Sword>(kiosk, item_id, payment);

    // 支付版税
    let royalty_payment = coin::mint_for_testing<SUI>(
        royalty_rule::fee_amount(&request, 500, 100), ctx,
    );
    royalty_rule::pay(policy, &mut request, royalty_payment);

    transfer_policy::confirm_request(policy, request);
    transfer::public_transfer(item, ctx.sender());
}
```

### 锁定规则（Kiosk Lock Rule）

要求买家将 NFT 锁定在自己的 Kiosk 中，不能直接取出：

```typescript
import { KioskLockRule } from "@mysten/kiosk/rules";

KioskLockRule.add(tx, {
  policy: policyId,
  policyCap: policyCapId,
});
```

```move
use sui::kiosk_lock_rule;

// 添加锁定规则
kiosk_lock_rule::add(policy, cap);
```

满足锁定规则：

```move
// 购买后将 NFT 锁入买家的 Kiosk
let (item, mut request) = kiosk::purchase<Sword>(seller_kiosk, item_id, payment);
kiosk::lock(buyer_kiosk, buyer_cap, policy, item);
kiosk_lock_rule::prove(&mut request, buyer_kiosk);
```

### 个人 Kiosk 规则（Personal Kiosk Rule）

要求买家使用个人 Kiosk（不可转让 KioskOwnerCap 的 Kiosk）：

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

可以同时添加多个规则，所有规则都必须满足：

```move
use sui::royalty_rule;
use sui::kiosk_lock_rule;
use sui::personal_kiosk_rule;

public fun setup_strict_policy(
    policy: &mut TransferPolicy<Sword>,
    cap: &TransferPolicyCap<Sword>,
) {
    // 5% 版税
    royalty_rule::add(policy, cap, 500, 100);
    // 必须锁定在 Kiosk 中
    kiosk_lock_rule::add(policy, cap);
    // 必须使用个人 Kiosk
    personal_kiosk_rule::add(policy, cap);
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
- 内置规则包括版税（Royalty）、锁定（Lock）、个人 Kiosk 等
- 多个规则可组合使用，所有规则都必须满足后转移才能完成
- 可创建自定义规则实现特定业务逻辑
- TypeScript SDK 的 KioskClient 可自动解析 Policy 规则并生成满足逻辑
