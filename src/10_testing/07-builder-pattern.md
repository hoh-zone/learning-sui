# Builder 模式测试

Builder 模式用于以灵活、可读的方式构造具有多个参数的复杂对象。它通过方法调用逐步积累配置，在调用 `build()` 时产生最终对象。这一模式在测试中尤为有用——你经常需要创建仅有细微差异的对象，同时保持大多数字段使用合理的默认值。

> Builder 模式在发布代码中可能因中间结构体和多次函数调用而增加 Gas 成本。此模式最适合测试场景，其中可读性和可维护性比 Gas 消耗更重要。

## 定义 Builder

Builder 结构体镜像目标对象的字段，但使用 `Option` 类型包装。典型的 Builder 提供：

- `new()` 创建空 Builder
- Setter 方法配置各字段并返回 Builder 用于链式调用
- `build()` 使用默认值填充未设置的字段，构造最终对象

```move
module book::user;

public struct User has copy, drop {
    name: String,
    balance: u64,
    is_active: bool,
    level: u8,
}
```

对应的 Builder：

```move
#[test_only]
module book::user_builder;

use book::user::User;

public struct UserBuilder has copy, drop {
    name: Option<String>,
    balance: Option<u64>,
    is_active: Option<bool>,
    level: Option<u8>,
}

public fun new(): UserBuilder {
    UserBuilder {
        name: option::none(),
        balance: option::none(),
        is_active: option::none(),
        level: option::none(),
    }
}

public fun name(mut self: UserBuilder, name: String): UserBuilder {
    self.name = option::some(name);
    self
}

public fun balance(mut self: UserBuilder, balance: u64): UserBuilder {
    self.balance = option::some(balance);
    self
}

public fun is_active(mut self: UserBuilder, is_active: bool): UserBuilder {
    self.is_active = option::some(is_active);
    self
}

public fun level(mut self: UserBuilder, level: u8): UserBuilder {
    self.level = option::some(level);
    self
}

public fun build(self: UserBuilder): User {
    User {
        name: self.name.destroy_or!(b"default".to_string()),
        balance: self.balance.destroy_or!(0),
        is_active: self.is_active.destroy_or!(true),
        level: self.level.destroy_or!(1),
    }
}
```

## 使用示例

### 没有 Builder 时

每个测试必须指定所有字段，即使只有一个字段与测试相关：

```move
#[test]
fun inactive_user_without_builder() {
    let user = User {
        name: b"Alice".to_string(),
        balance: 0,
        is_active: false,  // 只关心这个字段
        level: 1,
    };
    assert!(!user.is_active);
}
```

### 使用 Builder 后

测试变得聚焦且自文档化：

```move
#[test]
fun inactive_user_with_builder() {
    let user = user_builder::new()
        .is_active(false)
        .build();
    assert!(!user.is_active);
}

#[test]
fun high_level_user() {
    let user = user_builder::new()
        .name(b"Hero".to_string())
        .level(99)
        .build();
    assert_eq!(user.level, 99);
}
```

每个测试清楚地展示了哪个字段是关键的。向 `User` 添加新字段时只需更新 Builder 的 `build()` 函数添加默认值——现有测试无需修改。

## 方法链

流畅 Builder 语法的关键是方法链。每个 setter 方法通过值取得 `mut self` 的所有权，修改后返回修改过的 Builder：

```move
public fun is_active(mut self: UserBuilder, is_active: bool): UserBuilder {
    self.is_active = option::some(is_active);
    self
}
```

链式调用的每个方法消耗前一个 Builder 并返回新的 Builder，最终 `build()` 消耗 Builder 产生目标对象：

```move
let user = user_builder::new()
    .name(b"Alice".to_string())
    .balance(1000)
    .is_active(true)
    .build();
```

## 系统包中的使用

Sui Framework 和 Sui System 包广泛使用 Builder 模式进行测试：

### ValidatorBuilder

```move
use sui_system::validator_builder;

#[test]
fun validator_operations() {
    let validator = validator_builder::preset()
        .name("My Validator")
        .gas_price(1000)
        .commission_rate(500) // 5%
        .initial_stake(100_000_000)
        .build(ctx);
    // 测试验证器操作...
}
```

### TxContextBuilder

```move
use sui::test_scenario as ts;

#[test]
fun epoch_dependent_logic() {
    let mut test = ts::begin(@0x1);
    let ctx = test
        .ctx_builder()
        .set_epoch(100)
        .set_epoch_timestamp(1000000)
        .build();
    // 测试依赖 epoch 的逻辑...
    test.end();
}
```

## 小结

- Builder 模式通过 setter 方法积累配置，通过 `build()` 产生最终对象
- 使用 `Option` 字段使配置可选，在 `build()` 中提供合理默认值
- 方法链（`fun method(mut self, ...): Self`）创建流畅的 API
- Builder 减少测试样板代码，将测试与目标结构体的变更隔离
- 此模式最适合用于测试工具，可读性比 Gas 成本更重要的场景
