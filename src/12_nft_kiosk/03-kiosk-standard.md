# Kiosk 标准

Kiosk 是 Sui 的去中心化商业基础设施，为 NFT 交易提供了标准化的上架、购买和转移机制。每个用户可以拥有自己的 Kiosk（类似于虚拟商店），在其中展示和出售 NFT。本节将介绍 Kiosk 的核心概念和操作流程。

## Kiosk 概念

Kiosk 是一个共享对象，扮演用户的个人商店角色：

- **持有者**通过 `KioskOwnerCap` 管理自己的 Kiosk
- NFT 可以**放置**（place）到 Kiosk 中
- 放置的 NFT 可以**上架**（list）出售
- 买家可以**购买**（purchase）上架的 NFT
- 所有转移受 **TransferPolicy** 约束

```
  卖家                     买家
   │                       │
   ├─ 创建 Kiosk           │
   ├─ 放置 NFT             │
   ├─ 上架（设定价格）      │
   │                       ├─ 浏览 Kiosk
   │                       ├─ 购买 NFT
   │                       ├─ 满足 TransferPolicy
   │                       └─ 获得 NFT
   └─ 提取收益
```

## 创建 Kiosk

```move
use sui::kiosk;

// 创建 Kiosk 和 KioskOwnerCap
let (mut kiosk, kiosk_cap) = kiosk::new(ctx);

// 共享 Kiosk，转移 Cap
transfer::public_share_object(kiosk);
transfer::public_transfer(kiosk_cap, ctx.sender());
```

使用 TypeScript SDK：

```typescript
import { KioskClient, KioskTransaction } from "@mysten/kiosk";

const tx = new Transaction();
const kioskTx = new KioskTransaction({ transaction: tx, kioskClient });

kioskTx.create();
kioskTx.finalize();

const result = await client.signAndExecuteTransaction({ transaction: tx, signer: keypair });
if (result.$kind === 'FailedTransaction') {
  throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
}
await client.waitForTransaction({ digest: result.Transaction.digest });
```

## 放置和上架

### 放置 NFT

将 NFT 放入 Kiosk（不出售）：

```move
use sui::kiosk;

public fun place_in_kiosk<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    item: T,
) {
    kiosk::place(kiosk, cap, item);
}
```

### 上架出售

设定价格后上架：

```move
public fun list_in_kiosk<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    item_id: ID,
    price: u64,
) {
    kiosk::list<T>(kiosk, cap, item_id, price);
}
```

### 放置并上架（一步完成）

```move
public fun place_and_list<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    item: T,
    price: u64,
) {
    kiosk::place_and_list(kiosk, cap, item, price);
}
```

TypeScript 版本：

```typescript
const kioskTx = new KioskTransaction({
  transaction: tx,
  kioskClient,
  kioskCap: myKioskCap,
});

kioskTx.placeAndList({
  itemType: `${PACKAGE_ID}::sword::Sword`,
  item: swordId,
  price: 1_000_000_000n, // 1 SUI
});

kioskTx.finalize();
```

## 购买

买家从 Kiosk 购买 NFT：

```move
use sui::kiosk;
use sui::coin::Coin;
use sui::sui::SUI;
use sui::transfer_policy::TransferPolicy;

public fun purchase_from_kiosk<T: key + store>(
    kiosk: &mut Kiosk,
    item_id: ID,
    payment: Coin<SUI>,
    policy: &TransferPolicy<T>,
    ctx: &mut TxContext,
) {
    let (item, mut request) = kiosk::purchase<T>(kiosk, item_id, payment);

    // 满足 TransferPolicy 的规则
    // （如果 Policy 为空则无需额外操作）

    // 确认转移
    transfer_policy::confirm_request(policy, request);

    // 转移给买家
    transfer::public_transfer(item, ctx.sender());
}
```

TypeScript 版本：

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

kioskTx.finalize();
```

## 下架和取回

### 下架

取消出售但保留在 Kiosk 中：

```move
kiosk::delist<Sword>(kiosk, cap, item_id);
```

### 取回

从 Kiosk 中取回 NFT：

```move
let item = kiosk::take<Sword>(kiosk, cap, item_id);
```

## 提取收益

卖家从 Kiosk 中提取销售收益：

```move
let profits = kiosk::withdraw(kiosk, cap, option::none(), ctx);
// option::none() 表示提取全部，也可指定金额
transfer::public_transfer(profits, ctx.sender());
```

## TransferPolicy

每种 NFT 类型需要一个 `TransferPolicy` 来定义转移规则。没有 Policy 的类型无法通过 Kiosk 交易。

### 创建空 Policy

```move
use sui::transfer_policy;
use sui::package;

fun create_policy<T>(publisher: &package::Publisher, ctx: &mut TxContext) {
    let (policy, policy_cap) = transfer_policy::new<T>(publisher, ctx);
    transfer::public_share_object(policy);
    transfer::public_transfer(policy_cap, ctx.sender());
}
```

空的 Policy 意味着无需额外条件即可完成转移。

## 完整交易流程示例

```move
#[test]
fun kiosk_trading() {
    use sui::test_scenario;
    use sui::kiosk;
    use sui::transfer_policy;
    use sui::sui::SUI;
    use sui::coin;

    let seller = @0xSELLER;
    let buyer = @0xBUYER;
    let mut scenario = test_scenario::begin(seller);

    // 卖家创建 Kiosk 并上架 Sword
    {
        let (mut kiosk, cap) = kiosk::new(scenario.ctx());
        let sword = new_sword(b"Flame Sword".to_string(), 50, vector[], scenario.ctx());
        let sword_id = object::id(&sword);
        kiosk::place_and_list(&mut kiosk, &cap, sword, 1_000_000_000);
        transfer::public_share_object(kiosk);
        transfer::public_transfer(cap, seller);
    };

    // 创建 TransferPolicy
    scenario.next_tx(seller);
    // ... 使用 Publisher 创建 Policy

    // 买家购买
    scenario.next_tx(buyer);
    {
        let mut kiosk = scenario.take_shared<kiosk::Kiosk>();
        let payment = coin::mint_for_testing<SUI>(1_000_000_000, scenario.ctx());
        // ... 购买逻辑
        test_scenario::return_shared(kiosk);
    };

    scenario.end();
}
```

## 小结

- Kiosk 是 Sui 的去中心化商店标准，每个用户可拥有自己的 Kiosk
- 操作流程：创建 Kiosk → 放置 NFT → 上架定价 → 买家购买 → 满足 Policy → 转移
- `KioskOwnerCap` 是管理权凭证，持有者可放置、上架、下架、提取收益
- `TransferPolicy` 定义 NFT 转移规则，是 Kiosk 交易的必要组件
- TypeScript SDK 的 `KioskClient` 和 `KioskTransaction` 提供了便捷的客户端操作
