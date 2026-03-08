# 灵魂绑定 NFT

灵魂绑定代币（Soulbound Token, SBT）是不可转移的 NFT，一旦铸造给某个地址就永久绑定。在 Sui 上，这通过去掉 `store` ability 来实现——没有 `store` 的对象无法通过 `transfer::public_transfer` 转移，只能通过模块自定义的函数操作。本节将介绍如何设计和实现灵魂绑定 NFT。

## 设计原理

在 Sui 中，ability 组合决定了对象的行为：

| Ability | 含义 |
| --- | --- |
| `key` | 对象可以存在于链上 |
| `store` | 可被 `public_transfer` 自由转移 |
| `key` 但无 `store` | 只能通过定义模块内的 `transfer::transfer` 转移 |

灵魂绑定 NFT 只有 `key` 而没有 `store`，因此：

- 无法通过标准的 `transfer::public_transfer` 转移
- 无法放入 Kiosk 交易
- 只能通过模块定义的专用函数操作

## 基本实现

### 成就证书

```move
module game::achievement;

use std::string::String;

/// 没有 store ability——不可转移
public struct Achievement has key {
    id: UID,
    name: String,
    description: String,
    earned_by: address,
    earned_at: u64,
}

/// 只有游戏合约可以铸造成就
public fun mint_achievement(
    name: String,
    description: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let achievement = Achievement {
        id: object::new(ctx),
        name,
        description,
        earned_by: recipient,
        earned_at: ctx.epoch_timestamp_ms(),
    };

    // 使用 transfer::transfer（非 public_transfer）
    // 只有定义模块可以调用
    transfer::transfer(achievement, recipient);
}

public fun name(self: &Achievement): &String { &self.name }
public fun description(self: &Achievement): &String { &self.description }
public fun earned_by(self: &Achievement): address { self.earned_by }
```

### 身份凭证

```move
module identity::credential;

use std::string::String;

public struct Credential has key {
    id: UID,
    holder: address,
    credential_type: String,
    issuer: address,
    issued_at: u64,
    expires_at: Option<u64>,
}

const ENotIssuer: u64 = 1;
const EAlreadyExpired: u64 = 2;

public struct IssuerCap has key, store {
    id: UID,
    issuer_name: String,
}

/// 颁发凭证
public fun issue(
    issuer_cap: &IssuerCap,
    credential_type: String,
    holder: address,
    expires_at: Option<u64>,
    ctx: &mut TxContext,
) {
    let credential = Credential {
        id: object::new(ctx),
        holder,
        credential_type,
        issuer: object::id_address(issuer_cap),
        issued_at: ctx.epoch_timestamp_ms(),
        expires_at,
    };

    transfer::transfer(credential, holder);
}

/// 吊销凭证（需要持有者配合）
public fun revoke(credential: Credential) {
    let Credential { id, .. } = credential;
    object::delete(id);
}

/// 验证凭证是否有效
public fun is_valid(
    credential: &Credential,
    current_time: u64,
): bool {
    match (credential.expires_at) {
        option::some(expiry) => current_time < expiry,
        option::none() => true,
    }
}
```

## 带 Display 的灵魂绑定 NFT

即使 NFT 不可转移，仍可设置 Display 用于展示：

```move
module game::badge;

use std::string::String;
use sui::display;
use sui::package;

public struct Badge has key {
    id: UID,
    title: String,
    tier: u8,  // 1=铜, 2=银, 3=金
    image_url: String,
}

public struct BADGE() has drop;

fun init(otw: BADGE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut d = display::new<Badge>(&publisher, ctx);
    d.add(b"name".to_string(), b"{title}".to_string());
    d.add(b"image_url".to_string(), b"{image_url}".to_string());
    d.add(
        b"description".to_string(),
        b"Soulbound badge - Tier {tier}".to_string(),
    );
    d.update_version();

    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(d, ctx.sender());
}

public fun award_badge(
    title: String,
    tier: u8,
    image_url: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let badge = Badge {
        id: object::new(ctx),
        title,
        tier,
        image_url,
    };
    transfer::transfer(badge, recipient);
}
```

## 可销毁但不可转移

有时需要允许持有者放弃 SBT（比如注销账号），但不允许转移：

```move
module game::membership;

use std::string::String;

public struct Membership has key {
    id: UID,
    member_name: String,
    level: u64,
    join_date: u64,
}

/// 铸造会员卡
public fun join(
    member_name: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(Membership {
        id: object::new(ctx),
        member_name,
        level: 1,
        join_date: ctx.epoch_timestamp_ms(),
    }, recipient);
}

/// 升级会员等级
public fun level_up(membership: &mut Membership) {
    membership.level = membership.level + 1;
}

/// 持有者可以选择销毁（退出）
public fun resign(membership: Membership) {
    let Membership { id, .. } = membership;
    object::delete(id);
}
```

## 灵魂绑定 NFT 的使用场景

### 1. 游戏成就系统

```move
// 首杀成就
award_badge(
    b"First Blood".to_string(),
    1,
    b"https://game.com/badges/first-blood.png".to_string(),
    player,
    ctx,
);
```

### 2. 教育证书

```move
// 课程完成证书
issue(
    &issuer_cap,
    b"Move Developer Certificate".to_string(),
    graduate,
    option::none(), // 永不过期
    ctx,
);
```

### 3. DAO 投票权

```move
public struct VotingPower has key {
    id: UID,
    dao_id: ID,
    weight: u64,
}

// 投票权不可转移，防止投票权买卖
public fun grant_voting_power(
    dao_id: ID,
    weight: u64,
    member: address,
    ctx: &mut TxContext,
) {
    transfer::transfer(VotingPower {
        id: object::new(ctx),
        dao_id,
        weight,
    }, member);
}
```

## 测试灵魂绑定 NFT

```move
#[test]
fun achievement_is_soulbound() {
    use std::unit_test::assert_eq;
    use sui::test_scenario;

    let issuer = @0xISSUER;
    let player = @0xPLAYER;
    let mut scenario = test_scenario::begin(issuer);

    // 铸造成就给玩家
    mint_achievement(
        b"Dragon Slayer".to_string(),
        b"Defeated the final dragon".to_string(),
        player,
        scenario.ctx(),
    );

    // 玩家可以查看自己的成就
    scenario.next_tx(player);
    {
        let achievement = scenario.take_from_sender<Achievement>();
        assert_eq!(achievement.earned_by(), player);
        // 不能 public_transfer——编译器会阻止
        // transfer::public_transfer(achievement, @0xOTHER); // 编译错误！
        scenario.return_to_sender(achievement);
    };

    scenario.end();
}
```

## 小结

- 灵魂绑定 NFT 通过去掉 `store` ability 实现不可转移性
- 只有定义模块可以使用 `transfer::transfer` 转移，外部无法调用 `public_transfer`
- 仍可设置 Display 用于钱包和浏览器展示
- 常见场景包括成就、证书、会员、投票权等
- 可以设计为可销毁（持有者可选择放弃）但不可转移的模式
