# 链上随机数

## 导读

本节对应 [§12.1](01-sui-framework.md) 中的 **`sui::random`**：**`Random` 共享对象（`0x8`）** 提供协议级随机性，与 [§12.5](05-epoch-and-time.md) 的 **`Clock@0x6`** 一样属于**系统共享对象**，但用途完全不同——勿用时间戳或 epoch 代替随机数。

- **前置**：[§12.5](05-epoch-and-time.md)（系统对象传入交易的习惯）、[§12.2](02-transaction-context.md)  
- **后续**：[第十八章 · 安全](../20_security/00-index.md)（随机数误用与博弈场景）  

---

安全的随机数生成是区块链上最具挑战性的问题之一。传统方法（如使用区块哈希或时间戳）容易被验证者操纵，存在严重的安全隐患。Sui 通过内置的 `Random` 共享对象和 `RandomGenerator` 机制，提供了一套经过密码学验证的链上随机数生成方案。本章将详细介绍如何在 Move 合约中安全地使用随机数。

## Random 共享对象

### 系统预置对象

Sui 在创世时预置了一个 `Random` 共享对象，地址固定为 `0x8`。该对象由系统维护，每个 epoch 更新随机种子。所有需要随机数的交易都通过引用这个对象来获取随机性。

```move
// Random 对象的地址常量
// 0x0000000000000000000000000000000000000000000000000000000000000008
```

### 安全保证

Sui 的随机数机制提供以下安全保证：

1. **不可预测性**：在交易执行之前，没有人（包括验证者）能预测将生成的随机数
2. **不可偏倚性**：任何单一参与者无法影响随机数的分布
3. **确定性重放**：给定相同的交易和种子，随机数生成过程可以确定性重放（用于共识验证）

## RandomGenerator — 随机数生成器

### 创建生成器

每次需要随机数时，首先从 `Random` 对象创建一个 `RandomGenerator`：

```move
use sui::random::{Self, Random, RandomGenerator};

entry fun my_random_function(random: &Random, ctx: &mut TxContext) {
    let mut generator = random::new_generator(random, ctx);
    // 使用 generator 生成随机数...
}
```

`RandomGenerator` 绑定到当前交易上下文，确保同一交易中的多次随机数生成是独立且不可预测的。

### 生成整数随机数

`RandomGenerator` 提供了丰富的整数随机数生成函数：

```move
// 全范围随机数
let val_u8: u8 = random::generate_u8(&mut generator);
let val_u16: u16 = random::generate_u16(&mut generator);
let val_u32: u32 = random::generate_u32(&mut generator);
let val_u64: u64 = random::generate_u64(&mut generator);
let val_u128: u128 = random::generate_u128(&mut generator);
let val_u256: u256 = random::generate_u256(&mut generator);

// 范围内随机数（包含两端）
let in_range: u8 = random::generate_u8_in_range(&mut generator, 1, 100);
let in_range: u64 = random::generate_u64_in_range(&mut generator, 0, 999);
```

### 生成随机字节

```move
// 生成指定长度的随机字节向量
let random_bytes: vector<u8> = random::generate_bytes(&mut generator, 32);
```

### 随机打乱向量

```move
// 原地随机打乱向量元素顺序（Fisher-Yates 洗牌算法）
let mut items = vector[1, 2, 3, 4, 5];
random::shuffle(&mut generator, &mut items);
```

### 生成布尔值

```move
let coin_flip: bool = random::generate_bool(&mut generator);
```

## 安全要求：entry 函数

### 为什么必须使用 entry 函数

使用随机数的函数**必须声明为 `entry`** 而不是 `public`。这是 Sui 随机数安全模型的关键约束。

```move
// 正确：使用 entry
entry fun draw_winner(random: &Random, ctx: &mut TxContext) { ... }

// 危险：使用 public 会带来安全风险
public fun draw_winner(random: &Random, ctx: &mut TxContext) { ... }
```

原因分析：

如果使用随机数的函数是 `public` 的，攻击者可以在 PTB（Programmable Transaction Block）中组合调用：

1. 调用随机函数获取结果
2. 检查结果是否满足条件
3. 如果不满足，使整个交易中止（abort）

这样攻击者可以无成本地反复尝试，直到获得有利的随机结果。将函数声明为 `entry` 可以防止这种组合攻击，因为 `entry` 函数只能作为交易的入口点，不能被其他函数调用。

## 完整示例：抽奖系统

```move
module examples::lottery;

use sui::random::{Self, Random, RandomGenerator};

public struct Lottery has key {
    id: UID,
    participants: vector<address>,
    winner: Option<address>,
}

public fun create(ctx: &mut TxContext) {
    let lottery = Lottery {
        id: object::new(ctx),
        participants: vector::empty(),
        winner: option::none(),
    };
    transfer::share_object(lottery);
}

public fun join(lottery: &mut Lottery, ctx: &TxContext) {
    vector::push_back(&mut lottery.participants, ctx.sender());
}

/// Must be `entry` not `public` for randomness security
entry fun draw_winner(
    lottery: &mut Lottery,
    random: &Random,
    ctx: &mut TxContext,
) {
    assert!(vector::length(&lottery.participants) > 0, 0);
    let mut generator = random::new_generator(random, ctx);
    let len = vector::length(&lottery.participants);
    let idx = random::generate_u64_in_range(&mut generator, 0, len - 1);
    let winner = *vector::borrow(&lottery.participants, idx);
    lottery.winner = option::some(winner);
}
```

### 关键设计要点

1. `draw_winner` 声明为 `entry` 而非 `public`，防止组合攻击
2. `Random` 以不可变引用 `&Random` 传入，它是共享对象
3. 使用 `generate_u64_in_range` 在参与者索引范围内生成随机索引
4. 随机数在交易执行时才确定，任何人无法提前预测结果

## 完整示例：掷骰子

```move
module examples::dice;

use sui::random::{Self, Random};
use sui::event;

public struct DiceRolled has copy, drop {
    value: u8,
    player: address,
}

entry fun roll_dice(random: &Random, ctx: &mut TxContext) {
    let mut generator = random::new_generator(random, ctx);
    let value = random::generate_u8_in_range(&mut generator, 1, 6);
    event::emit(DiceRolled {
        value,
        player: ctx.sender(),
    });
}
```

这个示例展示了最简单的随机数使用场景。注意事项：

- 函数声明为 `entry`，确保安全性
- 使用 `generate_u8_in_range(1, 6)` 生成 1-6 的随机数（两端包含）
- 通过事件（Event）广播掷骰子的结果，方便链下应用监听

## 进阶示例：随机 NFT 属性

```move
module examples::random_nft;

use sui::random::{Self, Random};
use std::string::String;

public struct Monster has key, store {
    id: UID,
    name: String,
    attack: u64,
    defense: u64,
    speed: u64,
    rarity: u8,
}

entry fun mint_random_monster(
    name: String,
    random: &Random,
    ctx: &mut TxContext,
) {
    let mut gen = random::new_generator(random, ctx);

    let attack = random::generate_u64_in_range(&mut gen, 10, 100);
    let defense = random::generate_u64_in_range(&mut gen, 10, 100);
    let speed = random::generate_u64_in_range(&mut gen, 10, 100);

    // 稀有度：1-100 的随机数，越高越稀有
    let rarity_roll = random::generate_u8_in_range(&mut gen, 1, 100);
    let rarity = if (rarity_roll <= 50) {
        1 // 普通 (50%)
    } else if (rarity_roll <= 80) {
        2 // 稀有 (30%)
    } else if (rarity_roll <= 95) {
        3 // 史诗 (15%)
    } else {
        4 // 传说 (5%)
    };

    let monster = Monster {
        id: object::new(ctx),
        name,
        attack,
        defense,
        speed,
        rarity,
    };
    transfer::transfer(monster, ctx.sender());
}
```

## 常见陷阱与最佳实践

### 陷阱 1：在 public 函数中使用随机数

永远不要在 `public` 函数中使用 `Random`。攻击者可以利用 PTB 组合调用进行选择性中止攻击。

### 陷阱 2：先生成随机数再根据结果做可中止操作

```move
// 危险模式
entry fun bad_pattern(random: &Random, ctx: &mut TxContext) {
    let mut gen = random::new_generator(random, ctx);
    let result = random::generate_u64(&mut gen);
    // 不要在获取随机数后执行可能失败的外部调用
    // 因为这可能被利用来选择性中止交易
}
```

### 陷阱 3：重复使用 Generator

同一个 `RandomGenerator` 可以安全地生成多个随机数——每次调用都会更新内部状态。不需要为每个随机数创建新的生成器。

### 最佳实践

1. 使用随机数的函数始终声明为 `entry`
2. 在同一函数中只创建一个 `RandomGenerator`，多次使用即可
3. 随机数生成应当是函数中的最后一步操作之一，避免后续操作导致交易中止
4. 使用事件广播随机结果，方便链下应用获取

## 小结

Sui 的链上随机数机制提供了密码学安全的随机性保证，核心要点包括：

- **Random 对象**：系统预置的共享对象（地址 `0x8`），是所有随机数的来源
- **RandomGenerator**：通过 `random::new_generator(random, ctx)` 创建，绑定到当前交易
- **丰富的生成函数**：支持 `u8` 到 `u256` 的全范围和指定范围随机数，以及随机字节和向量打乱
- **安全约束**：使用随机数的函数必须声明为 `entry` 而非 `public`，防止 PTB 组合攻击
- **公平性保证**：随机种子在交易执行前不可知，任何参与者（包括验证者）无法预测或操纵结果
- 在实际应用中，随机数广泛用于抽奖、游戏、NFT 属性生成等需要公平随机性的场景
