# 游戏内代币实战

本节将所学的代币知识应用于实际游戏场景，涵盖忠诚积分、游戏货币和代币兑换等常见模式。我们将设计一个完整的游戏经济系统，展示如何在 Move 中实现各种代币用例。

## 忠诚积分系统

忠诚积分是闭环代币的经典应用——积分只能通过特定操作获取，只能在指定商店消费：

```move
module game::loyalty_points;

use sui::coin;
use sui::token::{Self, Token, ActionRequest, TokenPolicy, TokenPolicyCap};

public struct LOYALTY_POINTS() has drop;

public struct ShopOwnerRule() has drop;

public struct ShopConfig has store {
    shop_owner: address,
}

fun init(otw: LOYALTY_POINTS, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency(
        otw, 0, b"LP", b"Loyalty Points",
        b"Earn points, redeem rewards", option::none(), ctx,
    );

    let (mut policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

    // spend 操作需要 ShopOwnerRule 验证
    token::add_rule_for_action<LOYALTY_POINTS, ShopOwnerRule>(
        &mut policy, &policy_cap, token::spend_action(), ctx,
    );

    // 配置规则
    token::add_rule_config(
        ShopOwnerRule(), &mut policy, &policy_cap,
        ShopConfig { shop_owner: ctx.sender() }, ctx,
    );

    token::share_policy(policy);
    transfer::public_transfer(policy_cap, ctx.sender());
    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_freeze_object(metadata);
}

/// 玩家完成任务后获得积分
public fun reward_player(
    treasury_cap: &mut coin::TreasuryCap<LOYALTY_POINTS>,
    amount: u64,
    player: address,
    ctx: &mut TxContext,
) {
    let token = token::mint(treasury_cap, amount, ctx);
    let request = token::transfer(token, player, ctx);
    token::confirm_with_treasury_cap(treasury_cap, request, ctx);
}

/// 消费积分兑换奖励
public fun spend_points(
    token: Token<LOYALTY_POINTS>,
    policy: &TokenPolicy<LOYALTY_POINTS>,
    ctx: &mut TxContext,
) {
    let mut request = token::spend(token, ctx);
    // 验证消费规则
    let config: &ShopConfig = token::rule_config(ShopOwnerRule(), policy);
    assert!(ctx.sender() == config.shop_owner || true); // 示例：任何人都可消费
    token::add_approval(ShopOwnerRule(), &mut request, ctx);
    token::confirm_request(policy, request, ctx);
}
```

## 游戏货币（双币系统）

许多游戏采用双币系统——一种免费获取的软币和一种需要购买的硬币：

```move
module game::currencies;

use sui::coin::{Self, Coin, TreasuryCap};

/// 软币：通过游戏获取，可自由转移
public struct GOLD() has drop;

/// 硬币：通过充值获取（固定供应或可控铸造）
public struct GEM() has drop;

/// 游戏商店
public struct GameShop has key {
    id: UID,
    gold_treasury: TreasuryCap<GOLD>,
    gold_per_quest: u64,
    gem_to_gold_rate: u64,
}

/// 初始化游戏货币
public fun init_gold(otw: GOLD, ctx: &mut TxContext): TreasuryCap<GOLD> {
    let (treasury_cap, metadata) = coin::create_currency<GOLD>(
        otw, 0, b"GOLD", b"Gold",
        b"In-game currency earned by playing",
        option::none(), ctx,
    );
    transfer::public_freeze_object(metadata);
    treasury_cap
}

/// 完成任务获得金币
public fun complete_quest(
    shop: &mut GameShop,
    player: address,
    ctx: &mut TxContext,
) {
    let reward = coin::mint(
        &mut shop.gold_treasury, shop.gold_per_quest, ctx,
    );
    transfer::public_transfer(reward, player);
}

/// 用宝石兑换金币
public fun exchange_gem_for_gold(
    shop: &mut GameShop,
    gem: Coin<GEM>,
    ctx: &mut TxContext,
): Coin<GOLD> {
    let gem_amount = gem.value();
    let gold_amount = gem_amount * shop.gem_to_gold_rate;

    // 销毁宝石（需要 GEM 的 TreasuryCap）
    // 铸造对应的金币
    let gold = coin::mint(
        &mut shop.gold_treasury, gold_amount, ctx,
    );

    transfer::public_transfer(gem, @0x0); // 简化处理
    gold
}
```

## 代币兑换市场

实现一个简单的代币兑换合约：

```move
module game::exchange;

use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};

public struct Exchange<phantom CoinA, phantom CoinB> has key {
    id: UID,
    reserve_a: Balance<CoinA>,
    reserve_b: Balance<CoinB>,
    rate_a_to_b: u64,  // 1 A = rate 个 B（以最小单位计）
    rate_b_to_a: u64,
}

const EInsufficientReserve: u64 = 1;

/// 创建兑换池
public fun create_exchange<CoinA, CoinB>(
    initial_a: Coin<CoinA>,
    initial_b: Coin<CoinB>,
    rate_a_to_b: u64,
    rate_b_to_a: u64,
    ctx: &mut TxContext,
) {
    let exchange = Exchange<CoinA, CoinB> {
        id: object::new(ctx),
        reserve_a: initial_a.into_balance(),
        reserve_b: initial_b.into_balance(),
        rate_a_to_b,
        rate_b_to_a,
    };
    transfer::share_object(exchange);
}

/// 用 A 换 B
public fun swap_a_for_b<CoinA, CoinB>(
    exchange: &mut Exchange<CoinA, CoinB>,
    coin_a: Coin<CoinA>,
    ctx: &mut TxContext,
): Coin<CoinB> {
    let amount_a = coin_a.value();
    let amount_b = amount_a * exchange.rate_a_to_b;

    assert!(exchange.reserve_b.value() >= amount_b, EInsufficientReserve);

    // 存入 A
    exchange.reserve_a.join(coin_a.into_balance());

    // 取出 B
    let balance_b = exchange.reserve_b.split(amount_b);
    balance_b.into_coin(ctx)
}

/// 用 B 换 A
public fun swap_b_for_a<CoinA, CoinB>(
    exchange: &mut Exchange<CoinA, CoinB>,
    coin_b: Coin<CoinB>,
    ctx: &mut TxContext,
): Coin<CoinA> {
    let amount_b = coin_b.value();
    let amount_a = amount_b * exchange.rate_b_to_a;

    assert!(exchange.reserve_a.value() >= amount_a, EInsufficientReserve);

    exchange.reserve_b.join(coin_b.into_balance());

    let balance_a = exchange.reserve_a.split(amount_a);
    balance_a.into_coin(ctx)
}
```

## 奖励分发模式

按比例分发代币奖励的常见模式：

```move
module game::rewards;

use sui::coin::{Self, Coin, TreasuryCap};

public struct RewardPool<phantom T> has key {
    id: UID,
    treasury: TreasuryCap<T>,
    reward_per_action: u64,
    total_distributed: u64,
    max_distribution: u64,
}

const EPoolExhausted: u64 = 1;

public fun claim_reward<T>(
    pool: &mut RewardPool<T>,
    player: address,
    ctx: &mut TxContext,
) {
    assert!(
        pool.total_distributed + pool.reward_per_action <= pool.max_distribution,
        EPoolExhausted,
    );

    let reward = coin::mint(
        &mut pool.treasury, pool.reward_per_action, ctx,
    );
    pool.total_distributed = pool.total_distributed + pool.reward_per_action;
    transfer::public_transfer(reward, player);
}

public fun remaining_rewards<T>(pool: &RewardPool<T>): u64 {
    pool.max_distribution - pool.total_distributed
}
```

## 测试游戏代币

```move
#[test]
fun loyalty_reward_and_spend() {
    use sui::test_scenario;
    use sui::token::{Token, TokenPolicy};

    let shop_owner = @0xSHOP;
    let player = @0xPLAYER;
    let mut scenario = test_scenario::begin(shop_owner);

    // 初始化忠诚积分
    init(LOYALTY_POINTS(), scenario.ctx());

    // 奖励玩家
    scenario.next_tx(shop_owner);
    {
        let mut tcap = scenario.take_from_sender<coin::TreasuryCap<LOYALTY_POINTS>>();
        reward_player(&mut tcap, 100, player, scenario.ctx());
        scenario.return_to_sender(tcap);
    };

    // 玩家消费积分
    scenario.next_tx(player);
    {
        let token = scenario.take_from_sender<Token<LOYALTY_POINTS>>();
        let policy = scenario.take_shared<TokenPolicy<LOYALTY_POINTS>>();
        spend_points(token, &policy, scenario.ctx());
        test_scenario::return_shared(policy);
    };

    scenario.end();
}
```

## 小结

- 忠诚积分适合使用闭环代币（Token），限制获取和消费渠道
- 双币系统（软币 + 硬币）是游戏经济的常见模式，软币用 Coin 实现，硬币可用固定供应
- 代币兑换可通过 Balance 管理储备池实现简单的定价机制
- 奖励分发模式需要控制总分发量，防止通胀
- 根据场景选择 Coin（自由转移）或 Token（受限操作），或两者结合
