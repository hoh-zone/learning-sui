# 构建 NFT 市场

本节将所有 Kiosk 相关知识整合，设计一个完整的 NFT 市场。我们将从合约设计到前端集成思路，展示如何构建一个支持上架、购买和版税收取的去中心化 NFT 市场。

## 市场架构

基于 Kiosk 标准的市场架构：

```
┌────────────────────────────────────────────┐
│                 前端 dApp                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ 浏览市场  │  │ 上架 NFT │  │ 购买 NFT │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │             │             │        │
├───────┼─────────────┼─────────────┼────────┤
│       │        TypeScript SDK     │        │
│       │        KioskClient        │        │
├───────┼─────────────┼─────────────┼────────┤
│       ▼             ▼             ▼        │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  │
│  │ 索引器   │  │ 卖家     │  │ 买家     │  │
│  │ 查询     │  │ Kiosk    │  │ Kiosk    │  │
│  └─────────┘  └──────────┘  └──────────┘  │
│                     │                      │
│              TransferPolicy                │
│          (版税 + 锁定 + 个人Kiosk)          │
└────────────────────────────────────────────┘
```

## 合约设计

### NFT 定义

```move
module marketplace::sword;

use std::string::String;
use sui::display;
use sui::package;

public struct Sword has key, store {
    id: UID,
    name: String,
    damage: u64,
    special_effects: vector<String>,
}

public struct SWORD() has drop;

fun init(otw: SWORD, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    // 设置 Display
    let mut d = display::new<Sword>(&publisher, ctx);
    d.add(b"name".to_string(), b"{name}".to_string());
    d.add(
        b"image_url".to_string(),
        b"https://mygame.com/swords/{name}.png".to_string(),
    );
    d.add(
        b"description".to_string(),
        b"A sword with {damage} damage".to_string(),
    );
    d.update_version();

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(d, ctx.sender());
}

public fun mint(
    name: String,
    damage: u64,
    special_effects: vector<String>,
    ctx: &mut TxContext,
): Sword {
    Sword {
        id: object::new(ctx),
        name,
        damage,
        special_effects,
    }
}

public fun name(self: &Sword): &String { &self.name }
public fun damage(self: &Sword): u64 { self.damage }
```

### TransferPolicy 配置

Sui Framework 只提供 `transfer_policy::add_rule` 等原语，不包含现成的 `sui::royalty_rule` 或 `sui::kiosk_lock_rule`。版税等规则需要自行实现（或依赖 [Kiosk 生态包](https://github.com/MystenLabs/apps/tree/testnet/kiosk)）。下面示例在包内实现一个简单的版税规则并创建 Policy：

```move
// 包内自定义版税规则（基于 transfer_policy::add_rule）
module marketplace::royalty_rule;

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

```move
module marketplace::policy_setup;

use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap};
use sui::package::Publisher;
use marketplace::sword::Sword;
use marketplace::royalty_rule;

public fun create_policy_with_royalty(
    publisher: &Publisher,
    royalty_bps: u16,
    _min_royalty: u64,
    ctx: &mut TxContext,
) {
    let (mut policy, cap) = transfer_policy::new<Sword>(publisher, ctx);

    royalty_rule::add(&mut policy, &cap, royalty_bps);

    transfer::public_share_object(policy);
    transfer::public_transfer(cap, ctx.sender());
}
```

## 前端集成

### 初始化 KioskClient

```typescript
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { KioskClient, Network } from "@mysten/kiosk";

const suiClient = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});

const kioskClient = new KioskClient({
  client: suiClient,
  network: Network.TESTNET,
});
```

### 创建 Kiosk

```typescript
import { KioskTransaction } from "@mysten/kiosk";
import { Transaction } from "@mysten/sui/transactions";

async function createUserKiosk(signer: Keypair) {
  const tx = new Transaction();
  const kioskTx = new KioskTransaction({
    transaction: tx,
    kioskClient,
  });

  kioskTx.create();
  kioskTx.finalize();

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await suiClient.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

### 上架 NFT

```typescript
async function listNFT(
  signer: Keypair,
  kioskCap: KioskOwnerCap,
  swordId: string,
  price: bigint,
) {
  const tx = new Transaction();
  const kioskTx = new KioskTransaction({
    transaction: tx,
    kioskClient,
    kioskCap,
  });

  kioskTx.list({
    itemType: `${PACKAGE_ID}::sword::Sword`,
    itemId: swordId,
    price,
  });

  kioskTx.finalize();

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await suiClient.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

### 购买 NFT

```typescript
async function purchaseNFT(
  signer: Keypair,
  buyerKioskCap: KioskOwnerCap,
  swordId: string,
  sellerKioskId: string,
  price: bigint,
) {
  const tx = new Transaction();
  const kioskTx = new KioskTransaction({
    transaction: tx,
    kioskClient,
    kioskCap: buyerKioskCap,
  });

  await kioskTx.purchase({
    itemType: `${PACKAGE_ID}::sword::Sword`,
    itemId: swordId,
    price,
    sellerKiosk: sellerKioskId,
  });

  kioskTx.finalize();

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await suiClient.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

### 查询上架 NFT

```typescript
async function getListedItems(kioskId: string) {
  const { items } = await kioskClient.getKiosk({
    id: kioskId,
    options: {
      withListingPrices: true,
      withKioskFields: true,
    },
  });

  return items
    .filter((item) => item.listing !== undefined)
    .map((item) => ({
      id: item.objectId,
      type: item.type,
      price: item.listing?.price,
    }));
}
```

### 提取收益

```typescript
async function withdrawProfits(signer: Keypair, kioskCap: KioskOwnerCap) {
  const tx = new Transaction();
  const kioskTx = new KioskTransaction({
    transaction: tx,
    kioskClient,
    kioskCap,
  });

  kioskTx.withdraw(tx.object(kioskCap.kioskId));
  kioskTx.finalize();

  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(result.FailedTransaction.status.error?.message ?? 'Transaction failed');
  }
  await suiClient.waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
```

## 市场功能清单

一个完整的 NFT 市场通常包含：

| 功能 | 合约层 | 前端层 |
| --- | --- | --- |
| 铸造 NFT | Move mint 函数 | Mint 表单页面 |
| 创建 Kiosk | `kiosk::new` | 用户注册时自动创建 |
| 上架 | `kiosk::place_and_list` | 价格设定表单 |
| 购买 | `kiosk::purchase` + Policy 满足 | 购买按钮 + 钱包签名 |
| 下架 | `kiosk::delist` | 管理面板 |
| 提取收益 | `kiosk::withdraw` | 收益提取按钮 |
| 浏览 | 索引器 + RPC | 列表页 + 详情页 |
| 版税 | TransferPolicy | 自动收取 |

## 小结

- 基于 Kiosk 的 NFT 市场是去中心化的——每个用户拥有自己的商店
- 合约层负责 NFT 定义、Display、TransferPolicy 配置
- 前端通过 TypeScript SDK 的 `KioskClient` 和 `KioskTransaction` 交互
- TransferPolicy 的规则（版税、锁定等）自动在购买过程中执行
- SDK 提供了自动解析 Policy 并生成满足逻辑的能力，简化开发
