# 包（Package）

在 Move 语言中，包（Package）是代码组织的基本单位。每个包在发布到 Sui 区块链后，都会被分配一个唯一的链上地址作为标识。理解包的结构和工作机制，是编写和部署 Move 智能合约的第一步。

## 包的目录结构

使用 Sui CLI 创建一个新包：

```bash
sui move new my_package
```

生成的标准目录结构如下：

```
my_package/
├── Move.toml
├── sources/
│   └── my_module.move
└── tests/
    └── my_module_tests.move
```

各目录和文件的作用：

| 路径 | 说明 |
|------|------|
| `Move.toml` | 包的清单文件，声明包名、依赖、地址别名等 |
| `sources/` | 存放所有 Move 源代码（`.move` 文件） |
| `tests/` | 存放测试代码 |
| `examples/` | 可选目录，存放示例代码（不会被编译到主包中） |

## 包与模块的关系

一个包可以包含多个模块（Module），每个模块又包含函数、类型（结构体）和常量。它们的层次关系可以这样理解：

```
package 0x...
    module a
        struct A1
        fun hello_world()
    module b
        struct B1
        fun hello_package()
```

在代码层面，每个 `.move` 文件通常定义一个模块：

```move
// sources/cafe.move
module my_package::cafe;

public struct Coffee has drop {
    strength: u8,
}

public fun brew(strength: u8): Coffee {
    Coffee { strength }
}
```

```move
// sources/bakery.move
module my_package::bakery;

public struct Bread has drop {
    flavor: vector<u8>,
}

public fun bake(flavor: vector<u8>): Bread {
    Bread { flavor }
}
```

上面的两个模块 `cafe` 和 `bakery` 同属于 `my_package` 这一个包。发布后，它们共享同一个链上地址。

## 包的发布与不可变性

使用以下命令将包发布到 Sui 网络：

```bash
sui client publish
```

发布后，包具有以下特性：

- **唯一地址**：每个已发布的包都有一个唯一的链上地址（如 `0xabc123...`），后续所有对该包中模块和函数的调用都通过此地址进行。
- **不可变性**：已发布的包是不可变对象（Immutable Object），任何人（包括发布者）都无法修改或删除它。这保证了链上合约代码的透明性和可审计性。

### 在代码中引用已发布的包

其他包可以通过地址引用已发布的模块：

```move
module other_package::user;

use 0xabc123::cafe;

public fun drink() {
    let _coffee = cafe::brew(10);
}
```

## 包的升级与 UpgradeCap

虽然已发布的包不可变，但 Sui 提供了**包升级**机制，允许开发者发布一个新版本的包来替代旧版。

### UpgradeCap

当一个包首次发布时，发布者会收到一个 `UpgradeCap` 对象。持有此对象即拥有升级该包的权限：

```bash
sui client upgrade
```

升级时需注意以下兼容性规则：

| 升级策略 | 允许的变更 |
|----------|-----------|
| `compatible` | 可以添加新函数和新模块，不能删除或修改已有的公共函数签名 |
| `additive` | 只能添加新模块，不能修改现有模块 |
| `dep_only` | 只能更改依赖项 |

### 放弃升级权限

如果希望让包彻底不可变（无法再升级），可以销毁 `UpgradeCap`：

```move
module my_package::config;

use sui::package;

public fun make_immutable(cap: package::UpgradeCap) {
    package::make_immutable(cap);
}
```

调用此函数后，包将永远无法再被升级。

## 包的命名规范

- 包名使用 `snake_case`，如 `my_defi_app`
- 模块名同样使用 `snake_case`，如 `liquidity_pool`
- 包名在 `Move.toml` 的 `[package]` 段中声明，同时作为 `[addresses]` 中的命名地址使用

```toml
[package]
name = "my_defi_app"

[addresses]
my_defi_app = "0x0"
```

## 小结

包是 Move 项目的顶层组织单位。一个包由 `Move.toml` 清单文件和 `sources/` 目录中的模块组成。发布到链上后，包获得唯一地址并变为不可变。通过 `UpgradeCap` 机制，开发者可以在保持兼容性的前提下发布新版本。理解包的结构和生命周期，是构建 Sui 应用的基础。
