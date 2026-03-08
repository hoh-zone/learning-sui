# 对象间转移

Sui 的 **Transfer to Object (TTO)** 机制允许将对象转移给另一个对象（而不仅仅是地址）。结合 `Receiving` 类型和 `receive` 函数，这一机制为 Sui 带来了强大的对象组合能力，实现了"对象邮箱"、账户抽象等高级模式。

## 为什么需要对象间转移

在传统的对象模型中，对象只能被转移给地址（即账户）。但在很多实际场景中，我们希望对象能够"持有"其他对象：

- **邮箱系统**：用户的邮箱对象接收信件对象。
- **库存管理**：角色对象接收装备对象。
- **账户抽象**：智能合约对象代替地址持有资产。
- **多签钱包**：钱包对象接收待批准的交易对象。

Sui 的 TTO 机制正是为此而设计的。

## 基本概念

### 转移到对象

任何对象都可以作为"接收方"，就像地址一样。每个对象都有一个唯一的 `UID`，其底层是一个 `address`——因此可以用这个地址作为 `transfer` 的目标：

```move
// 将 letter 转移给一个对象（使用对象的地址）
transfer::public_transfer(letter, object_address);
```

被转移到某个对象的子对象，不会直接成为父对象的字段——它们存在于一个逻辑上的"邮箱"中，需要通过 `receive` 操作来提取。

### Receiving 类型

`Receiving<T>` 是 `sui::transfer` 模块中定义的一个特殊类型，它代表"有一个类型为 `T` 的对象正在等待被接收"：

```move
// sui::transfer 模块中的定义（简化）
public struct Receiving<phantom T: key> has drop {
    id: ID,
    version: u64,
}
```

`Receiving<T>` 的特点：

- 拥有 `drop` 能力——如果不接收，可以安全忽略。
- 包含 `phantom T`——不实际存储 `T`，只做类型标记。
- 在交易中由 Sui 运行时自动构造——不能由用户代码创建。
- 包含对象的 `ID` 和 `version`，用于验证接收操作。

## receive 与 public_receive

与 `transfer` 类似，`receive` 也分为内部版本和公开版本：

| 函数 | 要求 | 限制 |
|------|------|------|
| `transfer::receive<T>` | `T: key` | 只能在定义 `T` 的模块中调用 |
| `transfer::public_receive<T>` | `T: key + store` | 可在任何模块中调用 |

### 函数签名

```move
public fun receive<T: key>(
    parent: &mut UID,
    to_receive: Receiving<T>,
): T;

public fun public_receive<T: key + store>(
    parent: &mut UID,
    to_receive: Receiving<T>,
): T;
```

注意 `parent` 参数是 `&mut UID`——需要父对象的 `UID` 的可变引用。这意味着只有能获取父对象可变引用的代码才能提取子对象，提供了访问控制。

## 邮箱模式：完整示例

```move
module examples::post_office;

use std::string::String;

public struct PostBox has key {
    id: UID,
    owner: address,
}

public struct Letter has key, store {
    id: UID,
    content: String,
    from: address,
}

public fun create_postbox(ctx: &mut TxContext): PostBox {
    PostBox {
        id: object::new(ctx),
        owner: ctx.sender(),
    }
}

/// 发送信件到某人的邮箱
public fun send_letter(
    postbox_id: address,
    content: String,
    ctx: &mut TxContext,
) {
    let letter = Letter {
        id: object::new(ctx),
        content,
        from: ctx.sender(),
    };
    // 将信件转移到邮箱对象的地址
    transfer::public_transfer(letter, postbox_id);
}

/// 从邮箱中接收信件
public fun receive_letter(
    postbox: &mut PostBox,
    letter: transfer::Receiving<Letter>,
): Letter {
    transfer::public_receive(&mut postbox.id, letter)
}
```

### 执行流程

1. Alice 创建一个 `PostBox` 对象。
2. Bob 调用 `send_letter`，将 `Letter` 转移到 `PostBox` 的地址。
3. `Letter` 进入 `PostBox` 的"邮箱"（不是字段，是链上的关联关系）。
4. Alice 调用 `receive_letter`，传入 `PostBox` 的可变引用和 `Receiving<Letter>`。
5. Sui 运行时验证 `Letter` 确实在 `PostBox` 的邮箱中，然后返回 `Letter`。

## 内部接收约束

对于只有 `key` 的类型，`receive` 只能在定义该类型的模块中调用：

```move
module examples::restricted_mail;

use std::string::String;

/// 只有 key——接收受限
public struct SecretDocument has key {
    id: UID,
    classified_content: String,
}

public struct SecureBox has key {
    id: UID,
}

/// 只有本模块能接收 SecretDocument
public fun receive_secret(
    box_obj: &mut SecureBox,
    doc: transfer::Receiving<SecretDocument>,
): SecretDocument {
    transfer::receive(&mut box_obj.id, doc)
}

/// 可以在接收时添加自定义逻辑
public fun receive_and_verify(
    box_obj: &mut SecureBox,
    doc: transfer::Receiving<SecretDocument>,
    ctx: &TxContext,
): SecretDocument {
    let document = transfer::receive(&mut box_obj.id, doc);
    assert!(ctx.sender() == @examples, 0);
    document
}
```

外部模块尝试接收 `SecretDocument` 会失败：

```move
// 在另一个模块中——错误！
public fun try_receive(
    box_obj: &mut examples::restricted_mail::SecureBox,
    doc: transfer::Receiving<SecretDocument>,
) {
    // transfer::receive 只能在定义 SecretDocument 的模块中调用
    let _doc = transfer::receive(&mut box_obj.id, doc); // 验证器拒绝
}
```

## 对象钱包模式

TTO 机制可以实现一个对象级别的"钱包"，用于接收和管理各种资产：

```move
module examples::object_wallet;

use std::string::String;
use sui::coin::Coin;
use sui::sui::SUI;

public struct Wallet has key {
    id: UID,
    name: String,
}

public fun create_wallet(name: String, ctx: &mut TxContext) {
    let wallet = Wallet {
        id: object::new(ctx),
        name,
    };
    transfer::transfer(wallet, ctx.sender());
}

/// 向钱包发送 SUI
public fun deposit(
    wallet_address: address,
    coin: Coin<SUI>,
) {
    transfer::public_transfer(coin, wallet_address);
}

/// 从钱包提取 SUI
public fun withdraw(
    wallet: &mut Wallet,
    coin_to_receive: transfer::Receiving<Coin<SUI>>,
    recipient: address,
) {
    let coin = transfer::public_receive(&mut wallet.id, coin_to_receive);
    transfer::public_transfer(coin, recipient);
}

/// 查询钱包地址（用于存入）
public fun wallet_address(wallet: &Wallet): address {
    object::id(wallet).to_address()
}
```

## 多层接收模式

TTO 可以嵌套使用——对象 A 收到了对象 B，对象 B 又收到了对象 C：

```move
module examples::nested_receive;

use std::string::String;

public struct Warehouse has key {
    id: UID,
    name: String,
}

public struct Crate has key, store {
    id: UID,
    label: String,
}

public struct Package has key, store {
    id: UID,
    item: String,
}

/// 将包裹发送到箱子
public fun send_to_crate(
    crate_addr: address,
    item: String,
    ctx: &mut TxContext,
) {
    let package = Package {
        id: object::new(ctx),
        item,
    };
    transfer::public_transfer(package, crate_addr);
}

/// 将箱子发送到仓库
public fun send_to_warehouse(
    warehouse_addr: address,
    label: String,
    ctx: &mut TxContext,
) {
    let crate_obj = Crate {
        id: object::new(ctx),
        label,
    };
    transfer::public_transfer(crate_obj, warehouse_addr);
}

/// 从仓库接收箱子
public fun receive_crate(
    warehouse: &mut Warehouse,
    crate_ticket: transfer::Receiving<Crate>,
): Crate {
    transfer::public_receive(&mut warehouse.id, crate_ticket)
}

/// 从箱子接收包裹
public fun receive_package(
    crate_obj: &mut Crate,
    package_ticket: transfer::Receiving<Package>,
): Package {
    transfer::public_receive(&mut crate_obj.id, package_ticket)
}
```

## TTO 的使用场景

| 场景 | 描述 |
|------|------|
| 邮箱系统 | 用户对象接收消息对象 |
| 账户抽象 | 智能合约对象代替地址管理资产 |
| 多签钱包 | 钱包对象接收待审批的提案 |
| 游戏库存 | 角色对象接收战利品和装备 |
| DAO 治理 | DAO 对象接收提案和投票 |
| 托管服务 | 托管对象接收双方存入的资产 |

## TTO 与包装（Wrapping）的区别

将对象存储在另一个对象中有两种方式，它们有本质区别：

| 特性 | 包装（Wrapping） | TTO（Receiving） |
|------|-----------------|-----------------|
| 存储方式 | 作为父对象的字段 | 在父对象的"邮箱"中 |
| 链上可见性 | 子对象变为不可见 | 子对象保持可见 |
| 添加时机 | 创建时或通过 `&mut` | 任何时候通过 `transfer` |
| 提取方式 | 解构父对象 | 通过 `receive` |
| 类型限制 | 子类型需要 `store` | 子类型需要 `key`（+ `store` 用于 `public_receive`） |
| 动态性 | 静态——编译时确定 | 动态——运行时接收 |

## 小结

- Transfer to Object (TTO) 允许将对象转移给另一个对象，而不仅仅是地址。
- `Receiving<T>` 类型代表一个等待被接收的对象，由 Sui 运行时在交易中自动构造。
- `receive` 和 `public_receive` 用于从父对象的"邮箱"中提取子对象，遵循与 `transfer` 相同的内部/公开限制。
- 接收操作需要父对象的 `&mut UID`，提供了天然的访问控制——只有能获取父对象可变引用的代码才能提取子对象。
- TTO 机制实现了对象级别的资产管理，适用于邮箱系统、账户抽象、多签钱包等高级场景。
- TTO 与包装（Wrapping）是互补的两种对象组合方式——TTO 更动态灵活，Wrapping 更静态紧凑。
