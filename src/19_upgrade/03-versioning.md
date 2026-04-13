# 版本化共享对象

升级包后，旧版本的包仍然存在于链上——任何人都可以继续通过旧包地址调用函数。如果不做限制，用户会选择对自己有利的版本（比如 XP 更多的旧版训练函数），破坏系统设计。版本化共享对象模式通过在对象和函数中嵌入版本检查来解决这个问题。

本节介绍三种版本化模式：**包级版本化**、**对象级版本化**和**混合版本化**。

## 模式一：包级版本化

包级版本化是最基础也最常用的模式。核心思想：创建一个全局共享的 `Version` 对象，所有入口函数都通过它进行版本检查。

### Version 管理器

```move
module my_protocol::version_manager;

const EInvalidPackageVersion: u64 = 0;
const EProtocolPaused: u64 = 1;
const EVersionMismatch: u64 = 2;

/// 包级版本常量
/// V1 中值为 1，V2 升级后改为 2
const CURRENT_VERSION: u64 = 1;

/// 全局版本对象（共享）
public struct Version has key {
    id: UID,
    version: u64,
    is_paused: bool,
}

/// 发布时创建 Version 对象
fun init(ctx: &mut TxContext) {
    transfer::share_object(Version {
        id: object::new(ctx),
        version: CURRENT_VERSION,
        is_paused: false,
    });
}

/// 核心检查：包的编译时版本 == 链上对象版本
public fun assert_is_valid(self: &Version) {
    assert!(!self.is_paused, EProtocolPaused);
    assert!(self.version == CURRENT_VERSION, EInvalidPackageVersion);
}

/// 暂停协议（升级前调用）
public fun pause(self: &mut Version) {
    self.is_paused = true;
}

/// 恢复协议（升级后调用）
public fun unpause(self: &mut Version) {
    self.is_paused = false;
}

/// 迁移：将版本更新为当前包版本
public fun migrate(self: &mut Version) {
    self.version = CURRENT_VERSION;
}
```

### 在业务函数中使用

每个入口函数都接收 `&Version` 参数并调用检查：

```move
module my_protocol::calculator;

use my_protocol::version_manager::Version;

/// 所有业务函数都需要版本检查
public fun sum_numbers(version: &Version, a: u64, b: u64): u64 {
    version.assert_is_valid();
    a + b
}

public fun multiply_numbers(version: &Version, a: u64, b: u64): u64 {
    version.assert_is_valid();
    a * b
}
```

### 升级流程

```
1. pause()             ← 暂停协议，阻止所有操作
2. sui client upgrade  ← 发布新包（CURRENT_VERSION = 2）
3. migrate()           ← 更新 Version 对象的版本号
4. unpause()           ← 恢复协议
```

暂停机制的好处：防止升级过程中（migrate 之前）旧包代码继续执行，确保状态一致性。

### V2 中的变化

升级时只需修改 `CURRENT_VERSION` 常量：

```move
// V2 中
const CURRENT_VERSION: u64 = 2; // ← 从 1 改为 2
```

升级后的效果：

```
V1 包（CURRENT_VERSION=1）+ Version 对象（version=2）
→ 1 != 2 → assert_is_valid() 失败 → 旧包不可用 ✓

V2 包（CURRENT_VERSION=2）+ Version 对象（version=2）
→ 2 == 2 → assert_is_valid() 成功 → 新包正常工作 ✓
```

### 优缺点

| 优点 | 缺点 |
|------|------|
| 实现简单，一个 Version 对象管理整个包 | 所有函数都需要传入 `&Version` 参数 |
| 迁移原子化，一次 `migrate()` 切换所有函数 | 不支持按对象粒度控制版本 |
| 支持暂停/恢复机制 | 共享对象需全局协调，通常比纯拥有对象更重 |

## 模式二：对象级版本化

对象级版本化将版本信息嵌入到**每个共享对象**中，而不是使用全局 Version 对象。适用于有多个独立共享对象、需要逐个迁移的场景。

### 示例：流动性池和注册表

```move
module my_protocol::pool;

use my_protocol::version_check;

public struct SharedPool<phantom T0, phantom T1> has key {
    id: UID,
    version: u64,         // 每个池有自己的版本
    balance_t0: u64,
    balance_t1: u64,
    is_active: bool,
}

/// 创建池（版本 = 当前包版本）
public fun create_pool<T0, T1>(ctx: &mut TxContext) {
    transfer::share_object(SharedPool<T0, T1> {
        id: object::new(ctx),
        version: version_check::current_version(),
        balance_t0: 0,
        balance_t1: 0,
        is_active: true,
    });
}

/// 存款到池（检查池的版本）
public fun deposit<T0, T1>(
    pool: &mut SharedPool<T0, T1>,
    amount_t0: u64,
    amount_t1: u64,
) {
    version_check::assert_pool_version(pool.version);
    assert!(pool.is_active, 0);

    pool.balance_t0 = pool.balance_t0 + amount_t0;
    pool.balance_t1 = pool.balance_t1 + amount_t1;
}

/// 迁移单个池
public fun migrate_pool<T0, T1>(pool: &mut SharedPool<T0, T1>) {
    pool.version = version_check::current_version();
}
```

```move
module my_protocol::registry;

use my_protocol::version_check;

public struct SharedRegistry has key {
    id: UID,
    version: u64,
    pool_count: u64,
}

public fun register_pool(
    registry: &mut SharedRegistry,
    pool_id: ID,
) {
    version_check::assert_registry_version(registry.version);
    registry.pool_count = registry.pool_count + 1;
}

public fun migrate_registry(registry: &mut SharedRegistry) {
    registry.version = version_check::current_version();
}
```

### 版本检查模块

```move
module my_protocol::version_check;

const ENotSupportedObjectVersion: u64 = 0;

const CURRENT_VERSION: u64 = 1;

public fun current_version(): u64 {
    CURRENT_VERSION
}

public fun assert_pool_version(object_version: u64) {
    assert!(object_version == CURRENT_VERSION, ENotSupportedObjectVersion);
}

public fun assert_registry_version(object_version: u64) {
    assert!(object_version == CURRENT_VERSION, ENotSupportedObjectVersion);
}
```

### 逐对象迁移

对象级版本化的核心优势：可以**逐个迁移**共享对象，而不是一刀切。

```bash
# 升级包后，逐个迁移

# 先迁移注册表
sui client call --package 0xV2 --module registry --function migrate_registry \
  --args 0xREGISTRY

# 再迁移各个池（可以分批，甚至跨多笔交易）
sui client call --package 0xV2 --module pool --function migrate_pool \
  --type-args 0x2::sui::SUI 0xUSDC::usdc::USDC \
  --args 0xPOOL_SUI_USDC
```

### 优缺点

| 优点 | 缺点 |
|------|------|
| 逐对象迁移，不影响其他对象 | 每个对象都需要 version 字段 |
| 不需要全局 Version 对象 | 迁移过程可能较长（多个对象） |
| 函数签名不需要额外的 Version 参数 | 无法一次性切换所有对象 |

## 模式三：混合版本化

混合版本化结合了**包级**和**对象级**两种模式。入口函数同时检查全局 Version 和对象自身的版本——适用于有复杂权限和多层状态管理的协议。

### 示例

```move
module my_protocol::mixed;

use my_protocol::version_manager::Version;
use my_protocol::pool::SharedPool;
use my_protocol::registry::SharedRegistry;

/// 管理员操作：同时检查包版本和对象版本
public fun set_pool_in_registry(
    version: &Version,
    registry: &mut SharedRegistry,
    pool_id: ID,
    is_active: bool,
) {
    version.assert_is_valid();
    version.assert_versions_match(registry.version());
    // 业务逻辑...
}

/// 用户操作：同时检查包版本和池版本
public fun withdraw_from_pool<T0, T1>(
    version: &Version,
    pool: &mut SharedPool<T0, T1>,
    amount: u64,
) {
    version.assert_is_valid();
    version.assert_versions_match(pool.version());
    // 提款逻辑...
}
```

### 版本管理器扩展

```move
module my_protocol::version_manager;

/// 检查对象版本是否与全局版本匹配
public fun assert_versions_match(self: &Version, object_version: u64) {
    assert!(self.version == object_version, EVersionMismatch);
}
```

### 升级流程

```
1. version.pause()                    ← 暂停全局
2. sui client upgrade                 ← 发布新包
3. version.migrate()                  ← 更新全局版本
4. pool.migrate_pool()                ← 逐个迁移池
5. registry.migrate_registry()        ← 迁移注册表
6. version.unpause()                  ← 恢复服务
```

### 何时使用混合模式

| 场景 | 推荐模式 |
|------|---------|
| 简单合约，1-2 个共享对象 | 包级版本化 |
| 多个独立共享对象（如多个池） | 对象级版本化 |
| DeFi 协议，有管理员+用户操作 | 混合版本化 |

## 小结

- **包级版本化**：一个 Version 对象管理全包，实现简单，适合大多数场景
- **对象级版本化**：每个对象独立管理版本，支持逐对象迁移
- **混合版本化**：结合两者，适合复杂协议
- 版本化将**发布**与**激活**解耦，提供受控的迁移窗口
- 暂停/恢复机制可以保护迁移过程中的状态一致性
