# 扩展外部模块测试

当测试依赖外部包的代码时，你经常需要为这些包定义的类型创建测试数据。然而许多库不提供测试工具函数，导致你无法构造测试所需的对象。模块扩展（Module Extensions）通过允许你向外部模块添加仅测试函数来解决这个问题。

## 问题背景

假设你的应用使用 Pyth Network 的价格预言机。代码依赖 Pyth 包中的 `PriceInfoObject` 来获取资产价格：

```move
module app::trading;

use pyth::price_info::PriceInfoObject;

public fun execute_trade(price_info: &PriceInfoObject, amount: u64): u64 {
    let price = get_price(price_info);
    amount * price / 1_000_000
}
```

要测试 `execute_trade`，你需要一个 `PriceInfoObject`。但 Pyth 的 Sui 实现没有提供 `create_price_info_for_testing` 函数——获取 `PriceInfoObject` 的唯一方式是通过实际的预言机更新，这在单元测试中不可行。

## 什么是扩展？

扩展允许你向现有模块（甚至外部包中的模块）添加函数。扩展的函数可以访问模块的私有类型，并能创建、读取或修改它们：

```move
#[test_only]
extend module pyth::price_info;

// 现在可以定义有权访问 pyth::price_info
// 私有类型和函数的函数
```

扩展的特性：

- **仅可添加**：只能添加新声明，不能修改或删除已有项
- **局部于你的包**：不影响下游依赖或原始包
- **需要模式属性**：最常用 `#[test_only]` 用于测试
- **强大**：可完全访问被扩展模块的内部，如同代码直接写在该模块中

## 解决方案

创建一个扩展文件为 `PriceInfoObject` 添加测试辅助函数：

```move
// tests/extensions/pyth_price_info_ext.move
#[test_only]
extend module pyth::price_info;

public fun new_price_info_object_for_testing(
    price_info: PriceInfo,
    ctx: &mut TxContext,
): PriceInfoObject {
    PriceInfoObject {
        id: object::new(ctx),
        price_info,
    }
}
```

现在可以编写正确的单元测试：

```move
#[test_only]
module app::trading_tests;

use app::trading;
use pyth::price_info;
use std::unit_test::assert_eq;
use sui::test_utils::destroy;

#[test]
fun execute_trade_with_price() {
    let mut ctx = tx_context::dummy();

    let price_info = price_info::new_price_info_object_for_testing(
        /* ... */
        &mut ctx,
    );

    let result = trading::execute_trade(&price_info, 1000);
    assert_eq!(result, 50_000);

    destroy(price_info);
}
```

## 项目结构

建议将扩展放在专用文件夹中：

```
my_project/
├── sources/
│   └── trading.move
├── tests/
│   ├── extensions/
│   │   └── pyth_price_info_ext.move
│   └── trading_tests.move
└── Move.toml
```

## 扩展自己的模块

扩展不限于外部包——也可以扩展自己包中的模块。这对于添加测试辅助函数而不在生产代码中塞满 `#[test_only]` 函数很有用：

```move
#[test_only]
extend module app::trading;

public fun get_internal_value(/* ... */): u64 {
    // 访问私有字段用于测试
}

#[test]
fun test_internal_invariant() {
    // 测试可以和辅助函数共存于扩展中
}
```

## 其他用例

- **创建和销毁具有私有字段的对象**：当依赖不暴露类型构造器时
- **通过公共访问器暴露内部状态**：需要在测试中验证内部不变量时
- **模拟行为**：需要模拟正常难以达到的特定状态时
- **测试错误条件**：需要创建无效状态来测试错误处理时

## 限制

- **需要模式属性**：扩展必须有如 `#[test_only]` 的模式属性
- **仅可添加**：只能添加新声明，不能修改、覆盖或遮蔽已有项
- **仅根包有效**：只有根包中定义的扩展会被应用；依赖中的扩展会被忽略
- **Edition 兼容**：扩展代码受目标模块的 edition 特性约束
- **Edition 要求**：扩展需要 `2024.alpha` 或更高版本

## 小结

- 模块扩展允许向外部模块添加 `#[test_only]` 函数，解决无法构造外部类型测试数据的问题
- 使用 `extend module` 关键字，扩展可访问目标模块的所有私有内容
- 扩展是仅添加的、局部于包的，且需要模式属性
- 建议在 `tests/extensions/` 目录中组织扩展文件
- 也可用于扩展自己的模块，保持生产代码整洁
