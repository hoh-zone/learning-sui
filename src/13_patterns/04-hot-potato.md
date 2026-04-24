# Hot Potato 模式

Hot Potato（烫手山芋）模式是 Move 中一种独特而强大的设计模式。其核心是一个**没有任何能力（abilities）的结构体**——它不能被存储、不能被复制、不能被丢弃。就像一个真正的烫手山芋，一旦创建就必须被"消耗"掉，否则交易会失败。

这种模式可以在没有回调机制的情况下**强制执行特定的工作流程**，是 Move 类型系统最精妙的应用之一。

## 什么是 Hot Potato

在 Move 中，结构体可以拥有四种能力：`copy`、`drop`、`store`、`key`。一个没有任何能力的结构体具有以下特性：

| 操作 | 是否允许 | 原因 |
|------|---------|------|
| 复制 | ❌ | 没有 `copy` |
| 丢弃 | ❌ | 没有 `drop` |
| 存储到对象中 | ❌ | 没有 `store` |
| 作为对象存在 | ❌ | 没有 `key` |
| 转移给其他地址 | ❌ | 没有 `key` |

唯一的处理方式是**在同一个交易中通过解构（destructure）来消耗它**。这意味着必须调用某个接受该类型并解构它的函数。

```move
/// Hot Potato - 没有任何能力！
public struct Receipt {
    amount: u64,
}

/// 创建 Hot Potato
public fun create_receipt(amount: u64): Receipt {
    Receipt { amount }
}

/// 消耗 Hot Potato - 唯一的"出路"
public fun consume_receipt(receipt: Receipt): u64 {
    let Receipt { amount } = receipt;
    amount
}
```

## 为什么叫"烫手山芋"

想象你拿到一个滚烫的山芋：

1. **不能拿着不动**（不能 drop）——交易结束时如果还持有，交易失败
2. **不能放进口袋**（不能 store）——无法存储在任何对象中
3. **不能递给别人**（不能 transfer）——没有 key，不能作为独立对象转移
4. **必须处理掉**（必须解构）——唯一的解决方案

这就强制了调用者必须在同一个交易中完成整个工作流程。

## 闪电贷示例

闪电贷（Flash Loan）是 Hot Potato 模式最经典的应用场景。借款人必须在同一交易中借款并还款，否则交易会回滚：

```move
module examples::flash_loan;

use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::sui::SUI;

/// Hot Potato! 没有任何能力 - 必须被消耗
public struct FlashLoanReceipt {
    amount: u64,
    fee: u64,
}

public struct LendingPool has key {
    id: UID,
    balance: Balance<SUI>,
    fee_percent: u64,
}

public fun create_pool(ctx: &mut TxContext) {
    let pool = LendingPool {
        id: object::new(ctx),
        balance: balance::zero(),
        fee_percent: 1,
    };
    transfer::share_object(pool);
}

public fun deposit(pool: &mut LendingPool, coin: Coin<SUI>) {
    pool.balance.join(coin.into_balance());
}

/// 借款 - 返回资金和一个 Hot Potato 收据
public fun borrow(
    pool: &mut LendingPool,
    amount: u64,
    ctx: &mut TxContext,
): (Coin<SUI>, FlashLoanReceipt) {
    let coins = pool.balance.split(amount).into_coin(ctx);
    let receipt = FlashLoanReceipt {
        amount,
        fee: amount * pool.fee_percent / 100,
    };
    (coins, receipt)
}

const EInsufficientRepay: u64 = 0;

/// 还款 - 消耗 Hot Potato
public fun repay(
    pool: &mut LendingPool,
    payment: Coin<SUI>,
    receipt: FlashLoanReceipt,
) {
    let FlashLoanReceipt { amount, fee } = receipt;
    let repay_amount = amount + fee;
    assert!(payment.value() >= repay_amount, EInsufficientRepay);
    pool.balance.join(payment.into_balance());
}
```

调用流程必须是：

```
borrow() → [使用资金做其他操作] → repay()
```

如果调用者只调用 `borrow()` 不调用 `repay()`，交易会失败，因为 `FlashLoanReceipt` 无法被丢弃。资金安全得到了类型系统的保证。

## 借用与归还模式

另一个常见场景是确保借出的资源一定会被归还：

```move
module examples::lending;

use std::string::String;

public struct Item has key, store {
    id: UID,
    name: String,
}

/// Hot Potato - 借用凭证
public struct BorrowReceipt {
    item_id: ID,
    borrower: address,
}

public struct Vault has key {
    id: UID,
    items: vector<Item>,
}

/// 从保险柜借出物品，返回物品和凭证
public fun borrow_item(
    vault: &mut Vault,
    index: u64,
    ctx: &TxContext,
): (Item, BorrowReceipt) {
    let item = vault.items.remove(index);
    let receipt = BorrowReceipt {
        item_id: object::id(&item),
        borrower: ctx.sender(),
    };
    (item, receipt)
}

const EItemMismatch: u64 = 0;

/// 归还物品，消耗凭证
public fun return_item(
    vault: &mut Vault,
    item: Item,
    receipt: BorrowReceipt,
) {
    let BorrowReceipt { item_id, borrower: _ } = receipt;
    assert!(object::id(&item) == item_id, EItemMismatch);
    vault.items.push_back(item);
}
```

## 多步骤工作流

Hot Potato 可以用来强制执行多步骤的工作流程，确保每一步都不会被跳过：

```move
module examples::phone_shop;

use sui::coin::Coin;
use sui::sui::SUI;

/// 手机
public struct Phone has key, store {
    id: UID,
    model: std::string::String,
}

/// Hot Potato：排队号
public struct QueueTicket {
    customer: address,
}

/// Hot Potato：验货凭证
public struct InspectionSlip {
    customer: address,
    phone_id: ID,
}

/// 第一步：排队取号
public fun take_queue_number(ctx: &TxContext): QueueTicket {
    QueueTicket { customer: ctx.sender() }
}

/// 第二步：选购手机（消耗排队号，产生验货凭证）
public fun select_phone(
    ticket: QueueTicket,
    phone: &Phone,
): InspectionSlip {
    let QueueTicket { customer } = ticket;
    InspectionSlip {
        customer,
        phone_id: object::id(phone),
    }
}

const EPhoneMismatch: u64 = 0;

/// 第三步：付款取货（消耗验货凭证）
public fun pay_and_collect(
    slip: InspectionSlip,
    phone: Phone,
    mut payment: Coin<SUI>,
    shop_owner: address,
    ctx: &mut TxContext,
) {
    let InspectionSlip { customer, phone_id } = slip;
    assert!(object::id(&phone) == phone_id, EPhoneMismatch);

    let price = payment.split(1000, ctx);
    transfer::public_transfer(price, shop_owner);
    transfer::public_transfer(payment, customer);
    transfer::public_transfer(phone, customer);
}
```

这个例子强制了购买流程的三个步骤必须按顺序执行：

1. `take_queue_number()` → 得到 `QueueTicket`
2. `select_phone()` → 消耗 `QueueTicket`，得到 `InspectionSlip`
3. `pay_and_collect()` → 消耗 `InspectionSlip`

跳过任何步骤都会导致 Hot Potato 无法被消耗，交易失败。

## 可变路径执行

Hot Potato 还可以支持多种不同的消耗路径，实现灵活的工作流：

```move
module examples::multi_path;

public struct Obligation {
    value: u64,
}

public fun create_obligation(value: u64): Obligation {
    Obligation { value }
}

/// 路径 A：全额偿还
public fun fulfill_full(obligation: Obligation) {
    let Obligation { value: _ } = obligation;
}

const EInvalidPartial: u64 = 0;

/// 路径 B：部分偿还 + 新义务
public fun fulfill_partial(
    obligation: Obligation,
    partial_amount: u64,
): Obligation {
    let Obligation { value } = obligation;
    assert!(partial_amount < value, EInvalidPartial);
    Obligation { value: value - partial_amount }
}

/// 路径 C：由管理员豁免
public fun waive(
    _admin: &examples::capability::AdminCap,
    obligation: Obligation,
) {
    let Obligation { value: _ } = obligation;
}
```

## 设计要点

### 1. 确保有消耗路径

每个 Hot Potato 都必须至少有一个公开的消耗函数，否则调用者永远无法完成交易：

```move
/// ❌ 错误：没有公开的消耗函数
public struct Trap { value: u64 }

public fun create_trap(): Trap {
    Trap { value: 0 }
    // 调用者拿到 Trap 后无法处理！
}

// 消耗函数只在模块内部，外部无法调用
fun consume_trap(trap: Trap) {
    let Trap { value: _ } = trap;
}
```

### 2. 验证一致性

在消耗函数中验证 Hot Potato 携带的数据与实际操作一致：

```move
public fun repay(receipt: Receipt, payment: Coin<SUI>) {
    let Receipt { amount } = receipt;
    // ✅ 验证还款金额
    assert!(payment.value() >= amount, 0);
}
```

### 3. 携带必要信息

Hot Potato 可以携带字段来传递创建时的上下文信息到消耗时：

```move
public struct ActionReceipt {
    expected_result: u64,
    deadline_epoch: u64,
    initiator: address,
}
```

## 小结

Hot Potato 模式利用 Move 类型系统中"无能力结构体必须被解构"的规则，在没有回调机制的情况下实现了强制工作流程执行。它就像一个必须被传递和处理的"烫手山芋"，确保了借贷必须归还、流程必须完成、义务必须履行。这是 Move 语言独有的设计模式，在闪电贷、借用归还、多步骤流程等场景中有着不可替代的作用。
