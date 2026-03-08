# 常见漏洞模式

本节分析 Move 合约开发中常见的安全漏洞模式，包括权限泄露、对象混淆、整数溢出、存储膨胀等。了解这些漏洞模式可以帮助你在编码阶段就避免它们。

## 权限泄露

### 未绑定的 Capability

最常见的权限漏洞是 Capability 没有绑定到特定的共享对象：

```move
// 漏洞：任何 SatchelCap 都能操控任何 SharedSatchel
public struct SatchelCap has key, store {
    id: UID,
}

public fun remove_scroll(
    self: &mut SharedSatchel,
    _cap: &SatchelCap, // 没有验证 cap 属于 self
    scroll_id: ID,
): Scroll {
    // 直接操作，无权限验证...
}
```

**修复**：在 Capability 中存储关联对象的 ID：

```move
public struct SatchelCap has key, store {
    id: UID,
    satchel_id: ID,
}

public fun remove_scroll(
    self: &mut SharedSatchel,
    cap: &SatchelCap,
    scroll_id: ID,
): Scroll {
    assert!(cap.satchel_id == object::id(self), ENotYourSatchel);
    // ...
}
```

### 过度暴露的 Capability

```move
// 漏洞：AdminCap 有 store 能力，可以被自由转让
public struct AdminCap has key, store {
    id: UID,
}

// 更安全：去掉 store，只允许定义模块内转让
public struct AdminCap has key {
    id: UID,
}
```

## 对象混淆

### Hot Potato 跨对象攻击

不绑定的 Hot Potato 可以被用来在不同对象间移动资产：

```move
// 漏洞：Borrow 没有绑定到特定 Satchel
public struct Borrow() {}

// 攻击场景：
// 1. 从 satchel_a 借出 scroll（获得 Borrow）
// 2. 将 scroll 归还到 satchel_b（使用同一个 Borrow）
// 3. scroll 被移动到了攻击者控制的 satchel
```

**修复**：

```move
public struct Borrow {
    satchel_id: ID,
    scroll_id: ID,
}

public fun return_scroll(
    self: &mut SharedSatchel,
    scroll: Scroll,
    borrow: Borrow,
) {
    let Borrow { satchel_id, scroll_id } = borrow;
    assert!(satchel_id == object::id(self), EInvalidReturn);
    assert!(scroll_id == object::id(&scroll), EWrongScroll);
    self.scrolls.push_back(scroll);
}
```

### 类型混淆

```move
// 潜在漏洞：使用泛型时未限制类型参数
public fun withdraw<T: key + store>(
    vault: &mut Vault,
    id: ID,
): T {
    df::remove(&mut vault.id, id)
}

// 攻击者可能用错误的类型 T 调用，导致意外行为
// 修复：使用 Phantom 类型或验证类型
```

## 重放攻击

### 签名重放

```move
// 漏洞：同一个签名可以被多次使用
public fun mint(
    sig: vector<u8>,
    health: u64,
    stamina: u64,
    ctx: &mut TxContext,
): bool {
    let msg = /* 构造消息 */;
    let digest = hash::blake2b256(&msg);
    if (!ed25519::ed25519_verify(&sig, &BE_PUBLIC_KEY, &digest)) {
        return false
    };
    // 铸造...但同样的 sig 可以再次使用！
    true
}
```

**修复**：加入递增的 counter 或 nonce：

```move
public fun mint(
    sig: vector<u8>,
    counter: &mut Counter,
    health: u64,
    stamina: u64,
    ctx: &mut TxContext,
): bool {
    let mut msg = b"Mint Hero;counter=".to_string();
    msg.append(counter.value.to_string());
    // ... 其他消息内容

    let digest = hash::blake2b256(&msg.into_bytes());
    if (!ed25519::ed25519_verify(&sig, &BE_PUBLIC_KEY, &digest)) {
        return false
    };

    counter.value = counter.value + 1; // 递增，使旧签名失效
    // 铸造...
    true
}
```

## 整数溢出

### 算术溢出

Move 默认不检查算术溢出。在 u64 范围内，大数值相加可能会回绕：

```move
// 潜在漏洞：如果 amount 非常大
public fun add_balance(account: &mut Account, amount: u64) {
    account.balance = account.balance + amount;
    // 如果溢出，balance 可能变成一个很小的值
}
```

**修复**：

```move
const EOverflow: u64 = 100;

public fun add_balance(account: &mut Account, amount: u64) {
    let new_balance = account.balance + amount;
    assert!(new_balance >= account.balance, EOverflow);
    account.balance = new_balance;
}
```

### 除零错误

```move
// 漏洞：divisor 可能为 0
public fun calculate_share(total: u64, divisor: u64): u64 {
    total / divisor // 如果 divisor == 0 会 panic
}

// 修复
const EDivisionByZero: u64 = 101;

public fun calculate_share(total: u64, divisor: u64): u64 {
    assert!(divisor > 0, EDivisionByZero);
    total / divisor
}
```

## 存储膨胀

### Vector 无限增长

```move
// 漏洞：vector 无限增长最终会超过对象大小限制
public struct Registry has key {
    id: UID,
    items: vector<ID>, // 当超过约 31,000 个 ID 时会超过 256KB 限制
}

public fun register(reg: &mut Registry, id: ID) {
    reg.items.push_back(id); // 无限制添加
}
```

**修复**：使用 `Table` 替代 `vector`：

```move
use sui::table::Table;

public struct Registry has key {
    id: UID,
    items: Table<u64, ID>, // 动态字段不计入对象大小
    counter: u64,
}

public fun register(reg: &mut Registry, id: ID) {
    reg.items.add(reg.counter, id);
    reg.counter = reg.counter + 1;
}
```

### 存储回收遗漏

使用 Table 时，`drop` 只销毁表结构，不回收条目的存储空间：

```move
// 漏洞：丢失存储回收
public fun destroy(armory: Armory) {
    let Armory { id, swords } = armory;
    swords.drop(); // 只删表，条目变成"孤儿"，存储费无法回收
    id.delete();
}

// 修复：先清空表条目
public fun destroy_entries(
    armory: &mut Armory,
    start: u64,
    end: u64,
) {
    let mut i = start;
    while (i < end) {
        let _sword: Sword = armory.swords.remove(i);
        let Sword { id, .. } = _sword;
        id.delete(); // 回收存储
        i = i + 1;
    };
}

public fun destroy(armory: Armory) {
    let Armory { id, swords } = armory;
    swords.destroy_empty(); // 确保表已清空
    id.delete();
}
```

## 版本跳过攻击

```move
// 漏洞：升级后不使用版本检查
public fun perform_action(state: &mut AppState) {
    // 没有版本检查！旧包的函数仍然可以调用
}

// 修复
public fun perform_action(state: &mut AppState) {
    assert!(state.version == VERSION, EInvalidPackageVersion);
    // ...
}
```

## 漏洞检查清单

| 漏洞类型 | 检查方法 |
|---------|---------|
| 权限泄露 | Capability 是否绑定到特定对象？ |
| 对象混淆 | Hot Potato 是否包含对象 ID？ |
| 重放攻击 | 签名消息是否包含 nonce/counter？ |
| 整数溢出 | 大数值运算是否有边界检查？ |
| 存储膨胀 | 是否使用 Table 替代无界 vector？ |
| 版本跳过 | 共享对象操作是否有版本检查？ |
| 除零错误 | 除法操作前是否验证分母？ |
| 过度暴露 | Capability 是否需要 `store` 能力？ |

## 小结

- 权限泄露是最常见的漏洞：始终将 Capability 绑定到特定对象
- Hot Potato 必须包含来源对象的 ID，防止跨对象操作
- 签名验证必须包含 nonce/counter 防止重放
- 注意整数溢出和除零错误，添加适当的断言
- 使用 `Table` 替代无界 `vector`，避免存储膨胀
- 正确回收 Table 条目的存储空间
- 所有操作共享对象的函数都应包含版本检查
