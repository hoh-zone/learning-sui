# 安全最佳实践

本节总结 Move 合约开发中的安全最佳实践，涵盖权限管理、输入验证和对象安全三大方面。这些实践来源于 Sui 生态的真实项目经验和常见安全审计发现。

## 权限管理

### Capability 模式

使用 Capability 对象控制特权操作：

```move
module admin_action::admin_cap;

use sui::package;

public struct ADMIN_CAP() has drop;

/// 持有此凭证才能执行管理操作
public struct AdminCap has key, store {
    id: UID,
}

public struct Hero has key {
    id: UID,
    health: u64,
    stamina: u64,
}

fun init(otw: ADMIN_CAP, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
    transfer::public_transfer(AdminCap {
        id: object::new(ctx),
    }, ctx.sender());
}

/// 只有持有 AdminCap 的地址才能铸造
public fun mint(
    _cap: &AdminCap, // Capability 作为权限证明
    health: u64,
    stamina: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(Hero {
        id: object::new(ctx),
        health,
        stamina,
    }, recipient);
}
```

### ACL（访问控制列表）模式

使用共享对象维护授权地址列表：

```move
module admin_action::acl;

const ENotAdmin: u64 = 0;

public struct AccessControlList has key {
    id: UID,
    admins: vector<address>,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(AccessControlList {
        id: object::new(ctx),
        admins: vector[ctx.sender()],
    });
}

public fun mint(
    acl: &AccessControlList,
    health: u64,
    stamina: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(acl.admins.contains(&ctx.sender()), ENotAdmin);
    // ... 铸造逻辑
}

public fun add_admin(
    acl: &mut AccessControlList,
    _cap: &AdminCap,
    new_admin: address,
) {
    acl.admins.push_back(new_admin);
}
```

### 签名验证模式

使用 Ed25519 签名进行链下授权：

```move
module admin_action::signature;

use sui::{ed25519, hash};

const BE_PUBLIC_KEY: vector<u8> = x"...your_public_key...";

public struct Counter has key {
    id: UID,
    value: u64,
}

#[allow(implicit_const_copy)]
public fun mint(
    sig: vector<u8>,
    counter: &mut Counter,
    health: u64,
    stamina: u64,
    ctx: &mut TxContext,
): bool {
    // 将 counter 值包含在签名消息中，防止重放攻击
    let mut msg = b"Mint Hero for: 0x".to_string();
    msg.append(ctx.sender().to_string());
    msg.append_utf8(b";health=");
    msg.append(health.to_string());
    msg.append_utf8(b";counter=");
    msg.append(counter.value.to_string());

    let bytes = msg.into_bytes();
    let digest = hash::blake2b256(&bytes);

    if (!ed25519::ed25519_verify(&sig, &BE_PUBLIC_KEY, &digest)) {
        return false
    };

    // 递增 counter 防止重放
    counter.value = counter.value + 1;

    transfer::transfer(Hero {
        id: object::new(ctx),
        health,
        stamina,
    }, ctx.sender());
    true
}
```

## 对象引用安全

### Referent ID 问题

Capability 必须与它控制的共享对象绑定，否则一个 Capability 可以操控任意共享对象：

```move
// 不安全：SatchelCap 可以操控任何 SharedSatchel
public struct SatchelCap has key, store {
    id: UID,
}

// 安全：SatchelCap 绑定到特定的 SharedSatchel
public struct SatchelCap has key, store {
    id: UID,
    satchel_id: ID, // 绑定到特定共享对象
}

public fun add_scroll(
    self: &mut SharedSatchel,
    cap: &SatchelCap,
    scroll: Scroll,
) {
    // 验证 cap 属于这个 satchel
    assert!(cap.satchel_id == object::id(self), ENotYourSatchel);
    self.scrolls.push_back(scroll);
}
```

### Hot Potato 安全

Borrow 类型的 Hot Potato 也需要绑定到特定对象，防止跨对象借用：

```move
/// 不安全的 Borrow
public struct Borrow()

/// 安全的 Borrow：绑定到特定的 SharedSatchel
public struct Borrow {
    satchel_id: ID,
}

public fun borrow_scroll(
    self: &mut SharedSatchel,
    scroll_id: ID,
): (Scroll, Borrow) {
    let idx = self.scrolls.find_index!(|s| object::id(s) == scroll_id);
    assert!(idx.is_some(), ENoScrollWithThisID);
    (
        self.scrolls.remove(idx.extract()),
        Borrow { satchel_id: object::id(self) },
    )
}

public fun return_scroll(
    self: &mut SharedSatchel,
    scroll: Scroll,
    borrow: Borrow,
) {
    assert!(borrow.satchel_id == object::id(self), EInvalidReturn);
    self.scrolls.push_back(scroll);
    let Borrow { satchel_id: _ } = borrow;
}
```

## 输入验证

### 全面的参数检查

```move
const EInvalidName: u64 = 1;
const EInvalidStamina: u64 = 2;
const EInvalidAttack: u64 = 3;
const MAX_STAMINA: u64 = 1000;
const MAX_ATTACK: u64 = 500;

public fun create_hero(
    name: String,
    stamina: u64,
    attack: u64,
    ctx: &mut TxContext,
): Hero {
    assert!(name.length() > 0 && name.length() <= 32, EInvalidName);
    assert!(stamina > 0 && stamina <= MAX_STAMINA, EInvalidStamina);
    assert!(attack <= MAX_ATTACK, EInvalidAttack);

    Hero {
        id: object::new(ctx),
        name,
        stamina,
        weapon: option::none(),
    }
}
```

### 整数溢出保护

```move
const EOverflow: u64 = 10;

public fun safe_add(a: u64, b: u64): u64 {
    let result = a + b;
    assert!(result >= a, EOverflow); // 检查溢出
    result
}

public fun add_xp(hero: &mut Hero, amount: u64) {
    hero.xp = safe_add(hero.xp, amount);
}
```

## 协议限制

了解 Sui 的协议限制对于安全设计至关重要：

| 限制 | 值 | 影响 |
|------|---|------|
| `max_num_new_move_object_ids` | 2048 | 每笔交易最多创建的新对象数 |
| `max_move_object_size` | 256,000 bytes | 单个对象最大大小 |
| `object_runtime_max_num_cached_objects` | 1000 | 单笔交易最多访问的动态字段数 |
| `max_num_event_emit` | 1024 | 每笔交易最多发出的事件数 |

### 批量操作

```move
/// 批量铸造：分批处理以遵守协议限制
public fun mint_swords_batch(
    armory: &mut Armory,
    n_swords: u64,
    attack: u64,
    ctx: &mut TxContext,
) {
    // 每批最多 1000 个（尊重缓存限制）
    let batch_size = if (n_swords > 1000) { 1000 } else { n_swords };
    batch_size.do!(|_| {
        let sword = Sword {
            id: object::new(ctx),
            attack,
        };
        table::add(&mut armory.swords, armory.index, sword);
        armory.index = armory.index + 1;
    });
}
```

## 安全检查清单

### 发布前必查

- [ ] 所有特权操作都有 Capability 或 ACL 保护
- [ ] Capability 与其控制的共享对象绑定（Referent ID）
- [ ] Hot Potato 绑定到特定对象
- [ ] 所有用户输入都经过验证
- [ ] 整数运算检查溢出
- [ ] 共享对象有版本控制
- [ ] 错误码唯一且有描述性
- [ ] 遵守协议限制（对象大小、数量等）
- [ ] 敏感操作有重放攻击防护
- [ ] `public` 函数签名已确认稳定

## 小结

- 使用 Capability 模式、ACL 模式或签名验证模式管理权限
- Capability 必须通过 Referent ID 绑定到它控制的共享对象
- Hot Potato 应绑定到特定对象，防止跨对象操作
- 全面验证用户输入：范围检查、长度检查、溢出保护
- 了解并遵守 Sui 协议限制
- 使用签名 + Counter 防止重放攻击
- 发布前完成安全检查清单
