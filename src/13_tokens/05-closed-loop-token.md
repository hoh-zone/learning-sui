# 闭环代币

Sui 的闭环代币（Closed-Loop Token）系统提供了比 Coin 更精细的控制能力。与 Coin 允许自由转移不同，Token 的每个操作都需要通过 `TokenPolicy` 的规则验证。这使得它非常适合游戏内货币、忠诚积分、有条件转移等场景。

## Token 与 Coin 的区别

| 特性 | Coin | Token |
| --- | --- | --- |
| 转移 | 自由转移（有 `store`） | 需要通过 Policy 批准 |
| Ability | `key, store` | `key`（无 `store`） |
| 使用方式 | 标准转账 | 通过 ActionRequest 请求操作 |
| 适用场景 | 通用代币、DeFi | 积分、游戏货币、有限制的代币 |

## 核心概念

### TokenPolicy

`TokenPolicy` 是控制 Token 操作的策略对象。每个操作（transfer、spend、to_coin 等）可以配置不同的规则：

```move
use sui::token::{Self, TokenPolicy, TokenPolicyCap};
```

### ActionRequest

每次对 Token 的操作都会生成一个 `ActionRequest`，需要满足 Policy 中的所有规则后才能被确认：

```move
// 转移 Token 生成 ActionRequest
let request = token::transfer(my_token, recipient, ctx);

// 通过规则验证
my_rule::prove(&mut request, &policy, ctx);

// 确认请求
token::confirm_request(&policy, request, ctx);
```

### Rule

规则（Rule）是附加到 TokenPolicy 上的验证逻辑。每个规则是一个 witness 类型，可以有自己的配置：

```move
public struct CrownCouncilRule() has drop;

public struct Config has store {
    members: VecSet<address>,
}
```

## 创建闭环代币

以 King Credits（国王信用）为例——一种只有皇家议会成员才能转移的代币：

```move
module king_credits::king_credits;

use std::string;
use sui::coin;
use sui::coin_registry;
use sui::token;
use king_credits::crown_council_rule::{Self, CrownCouncilRule};

public struct KING_CREDITS() has drop;

fun init(otw: KING_CREDITS, ctx: &mut TxContext) {
    let (initializer, treasury_cap) = coin_registry::new_currency_with_otw<KING_CREDITS>(
        otw, 9,
        string::utf8(b"KING_CREDITS"),
        string::utf8(b"King's Credits"),
        string::utf8(b"Awarded to citizens for heroic actions."),
        string::utf8(b"https://example.com/icon"),
        ctx,
    );
    let metadata_cap = coin_registry::finalize(initializer, ctx);
    transfer::public_transfer(metadata_cap, ctx.sender());

    // 创建 Token Policy
    let (mut policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

    // 允许 transfer 操作，但需要 CrownCouncilRule 验证
    token::add_rule_for_action<KING_CREDITS, CrownCouncilRule>(
        &mut policy,
        &policy_cap,
        token::transfer_action(),
        ctx,
    );

    // 设置规则配置（初始议会成员）
    crown_council_rule::add_rule_config(
        &mut policy,
        &policy_cap,
        vector[ctx.sender()],
        ctx,
    );

    // 共享 Policy，转移 PolicyCap 和 TreasuryCap
    token::share_policy(policy);
    transfer::public_transfer(policy_cap, ctx.sender());
    transfer::public_transfer(treasury_cap, ctx.sender());
}
```

## 实现自定义规则

```move
module king_credits::crown_council_rule;

use sui::token::{Self, ActionRequest, TokenPolicy, TokenPolicyCap};
use sui::vec_set::{Self, VecSet};

const EMaxCouncilMembers: u64 = 0;
const ENotACouncilMember: u64 = 1;
const MAX_CROWN_COUNCIL_MEMBERS: u64 = 100;

public struct CrownCouncilRule() has drop;

public struct Config has store {
    members: VecSet<address>,
}

/// 初始化规则配置
public fun add_rule_config<T>(
    policy: &mut TokenPolicy<T>,
    cap: &TokenPolicyCap<T>,
    initial_members: vector<address>,
    ctx: &mut TxContext,
) {
    assert!(initial_members.length() <= MAX_CROWN_COUNCIL_MEMBERS, EMaxCouncilMembers);
    let members = vec_set::from_keys(initial_members);
    token::add_rule_config(CrownCouncilRule(), policy, cap, Config { members }, ctx);
}

/// 添加议会成员
public fun add_council_member<T>(
    policy: &mut TokenPolicy<T>,
    cap: &TokenPolicyCap<T>,
    member_addr: address,
) {
    let config: &mut Config = token::rule_config_mut(CrownCouncilRule(), policy, cap);
    config.members.insert(member_addr);
}

/// 移除议会成员
public fun remove_council_member<T>(
    policy: &mut TokenPolicy<T>,
    cap: &TokenPolicyCap<T>,
    member_addr: address,
) {
    let config: &mut Config = token::rule_config_mut(CrownCouncilRule(), policy, cap);
    config.members.remove(&member_addr);
}

/// 验证请求发送者是否为议会成员
public fun prove<T>(
    request: &mut ActionRequest<T>,
    policy: &TokenPolicy<T>,
    ctx: &mut TxContext,
) {
    let config: &Config = token::rule_config(CrownCouncilRule(), policy);
    assert!(config.members.contains(&ctx.sender()), ENotACouncilMember);
    token::add_approval(CrownCouncilRule(), request, ctx);
}
```

## Token 操作流程

### 铸造

```move
let token = token::mint(&mut treasury_cap, 100_000, ctx);
let request = token::transfer(token, recipient, ctx);
// 使用 treasury_cap 确认（绕过规则）
token::confirm_with_treasury_cap(&mut treasury_cap, request, ctx);
```

### 转移（需要规则验证）

```move
let token = scenario.take_from_sender<Token<KING_CREDITS>>();
let mut request = token::transfer(token, recipient, ctx);

// 证明满足 CrownCouncilRule
crown_council_rule::prove(&mut request, &policy, ctx);

// 确认请求
token::confirm_request(&policy, request, ctx);
```

### 消费（Spend）

```move
let mut request = token::spend(token, ctx);
// 验证规则...
token::confirm_request(&policy, request, ctx);
```

## 完整测试

```move
#[test]
fun transfer() {
    use sui::test_scenario;
    use sui::token::{Token, TokenPolicy, TokenPolicyCap};
    use sui::coin::TreasuryCap;

    let publisher = @0x11111;
    let council_member = @0x22222;
    let recipient = @0x33333;

    let mut scenario = test_scenario::begin(publisher);

    // 初始化
    init(KING_CREDITS(), scenario.ctx());

    // 添加议会成员
    scenario.next_tx(publisher);
    {
        let policy_cap = scenario.take_from_sender<TokenPolicyCap<KING_CREDITS>>();
        let mut policy = scenario.take_shared<TokenPolicy<KING_CREDITS>>();
        crown_council_rule::add_council_member(
            &mut policy, &policy_cap, council_member,
        );
        test_scenario::return_shared(policy);
        scenario.return_to_sender(policy_cap);
    };

    // 铸造给议会成员
    scenario.next_tx(publisher);
    {
        let mut tcap = scenario.take_from_sender<TreasuryCap<KING_CREDITS>>();
        let token = token::mint(&mut tcap, 100_000_000_000_000, scenario.ctx());
        let request = token::transfer(token, council_member, scenario.ctx());
        token::confirm_with_treasury_cap(&mut tcap, request, scenario.ctx());
        scenario.return_to_sender(tcap);
    };

    // 议会成员转移给接收者
    scenario.next_tx(council_member);
    {
        let policy = scenario.take_shared<TokenPolicy<KING_CREDITS>>();
        let token = scenario.take_from_sender<Token<KING_CREDITS>>();
        let mut request = token::transfer(token, recipient, scenario.ctx());
        crown_council_rule::prove(&mut request, &policy, scenario.ctx());
        token::confirm_request(&policy, request, scenario.ctx());
        test_scenario::return_shared(policy);
    };

    scenario.end();
}
```

## 小结

- 闭环代币（Token）与 Coin 不同，每个操作都需要通过 `TokenPolicy` 规则验证
- Token 没有 `store` ability，无法自由转移，必须通过 ActionRequest 机制
- 自定义 Rule 可以实现任意验证逻辑（成员检查、时间锁、数量限制等）
- `confirm_with_treasury_cap` 可以绕过规则直接确认请求（用于铸造初始分配）
- 闭环代币适用于积分系统、游戏货币、有条件转移等需要精细控制的场景
