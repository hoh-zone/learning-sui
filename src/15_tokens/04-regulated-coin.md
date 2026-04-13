# 受监管代币

在某些场景下，代币发行方需要限制特定地址的代币使用——例如合规要求、制裁名单或反洗钱。Sui 通过 `DenyCap` 和 `DenyList` 机制提供了原生的受监管代币支持。本节将介绍如何创建和管理受监管代币。

## 受监管代币 vs 普通代币

普通代币使用 **`coin_registry::new_currency_with_otw` + `finalize`** 创建。受监管代币在创建时使用 **`coin_registry::make_regulated`**（`coin::create_regulated_currency_v2` 已废弃），额外得到 **`DenyCapV2<T>`**，允许发行方将特定地址加入黑名单。

## 创建受监管代币

```move
module regulated::rusd;

use std::string;
use sui::coin_registry;
use sui::deny_list::DenyList;

public struct RUSD() has drop;

fun init(otw: RUSD, ctx: &mut TxContext) {
    let (mut initializer, treasury_cap) = coin_registry::new_currency_with_otw<RUSD>(
        otw, 6,
        string::utf8(b"RUSD"),
        string::utf8(b"Regulated USD"),
        string::utf8(b"A regulated stablecoin"),
        string::utf8(b""),
        ctx,
    );
    let deny_cap = coin_registry::make_regulated(&mut initializer, true, ctx); // allow_global_pause
    let metadata_cap = coin_registry::finalize(initializer, ctx);

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_transfer(deny_cap, ctx.sender());
    transfer::public_transfer(metadata_cap, ctx.sender());
}
```

### 新 API 返回值说明

| 对象 | 说明 |
| --- | --- |
| `TreasuryCap<T>` | 铸造权凭证 |
| `DenyCapV2<T>` | 黑名单与全局暂停管理权凭证 |
| `MetadataCap<T>` | 代币元数据更新权（链上元数据在 `Currency<T>` 中） |

## DenyCap 与黑名单管理

`DenyCap` 的持有者可以将地址添加到黑名单或从黑名单中移除：

```move
use sui::deny_list::DenyList;
use sui::coin;

/// 将地址加入黑名单
public fun deny_address(
    deny_list: &mut DenyList,
    deny_cap: &mut coin::DenyCapV2<RUSD>,
    addr: address,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_add(deny_list, deny_cap, addr, ctx);
}

/// 将地址从黑名单移除
public fun undeny_address(
    deny_list: &mut DenyList,
    deny_cap: &mut coin::DenyCapV2<RUSD>,
    addr: address,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_remove(deny_list, deny_cap, addr, ctx);
}

/// 检查地址是否在黑名单中
public fun is_denied(
    deny_list: &DenyList,
    addr: address,
): bool {
    coin::deny_list_v2_contains_current_epoch<RUSD>(deny_list, addr)
}
```

## 全局暂停

使用 **`coin_registry::make_regulated`** 时将 `allow_global_pause` 设为 `true`，即可启用全局暂停，暂停所有该代币的转移：

```move
/// 全局暂停代币转移
public fun global_pause(
    deny_list: &mut DenyList,
    deny_cap: &mut coin::DenyCapV2<RUSD>,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_enable_global_pause(deny_list, deny_cap, ctx);
}

/// 恢复代币转移
public fun global_unpause(
    deny_list: &mut DenyList,
    deny_cap: &mut coin::DenyCapV2<RUSD>,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_disable_global_pause(deny_list, deny_cap, ctx);
}
```

## DenyList 系统对象

`DenyList` 是 Sui 的系统对象，在创世时创建。它是一个共享对象，用于存储所有受监管代币的黑名单信息。在交易中作为 `&mut DenyList` 参数传入。

## 合规代币设计模式

### 多签管理

将 **`DenyCapV2`** 放入多签钱包管理，而非单一地址：

```move
use std::string;
use sui::coin_registry;

fun init(otw: RUSD, ctx: &mut TxContext) {
    let (mut initializer, treasury_cap) = coin_registry::new_currency_with_otw<RUSD>(
        otw, 6,
        string::utf8(b"RUSD"),
        string::utf8(b"Regulated USD"),
        string::utf8(b"Compliant stablecoin"),
        string::utf8(b""),
        ctx,
    );
    let deny_cap = coin_registry::make_regulated(&mut initializer, true, ctx);
    let metadata_cap = coin_registry::finalize(initializer, ctx);

    let multisig_addr = @0xMULTISIG;
    transfer::public_transfer(treasury_cap, multisig_addr);
    transfer::public_transfer(deny_cap, multisig_addr);
    transfer::public_transfer(metadata_cap, multisig_addr);
}
```

### 分权管理

铸造权和黑名单权分开管理：

```move
use std::string;
use sui::coin_registry;

fun init(otw: RUSD, ctx: &mut TxContext) {
    let (mut initializer, treasury_cap) = coin_registry::new_currency_with_otw<RUSD>(
        otw, 6,
        string::utf8(b"RUSD"),
        string::utf8(b"Regulated USD"),
        string::utf8(b"Compliant stablecoin"),
        string::utf8(b""),
        ctx,
    );
    let deny_cap = coin_registry::make_regulated(&mut initializer, true, ctx);
    let metadata_cap = coin_registry::finalize(initializer, ctx);

    let minter = @0xMINTER;
    let compliance_officer = @0xCOMPLIANCE;

    transfer::public_transfer(treasury_cap, minter);
    transfer::public_transfer(deny_cap, compliance_officer);
    transfer::public_transfer(metadata_cap, compliance_officer);
}
```

## 测试受监管代币

```move
#[test]
fun deny_and_undeny() {
    use sui::test_scenario;
    use sui::deny_list;

    let admin = @0xAD;
    let blocked_user = @0xBAD;
    let mut scenario = test_scenario::begin(admin);

    // 创建系统对象（包括 DenyList）
    scenario.create_system_objects();

    init(RUSD(), scenario.ctx());
    scenario.next_tx(admin);

    // 获取 DenyCap 和 DenyList
    {
        let mut deny_cap = scenario.take_from_sender<coin::DenyCapV2<RUSD>>();
        let mut deny_list = scenario.take_shared<DenyList>();

        // 加入黑名单
        coin::deny_list_v2_add(
            &mut deny_list, &mut deny_cap, blocked_user, scenario.ctx(),
        );

        test_scenario::return_shared(deny_list);
        scenario.return_to_sender(deny_cap);
    };

    scenario.end();
}
```

## 小结

- 受监管代币使用 **`coin_registry::new_currency_with_otw` + `make_regulated` + `finalize`** 创建，额外返回 **`DenyCapV2`**（`coin::create_regulated_currency_v2` 已废弃）
- **`DenyCapV2`** 允许将地址加入/移出黑名单，被黑名单的地址无法接收或发送该代币
- **`DenyList`** 是系统共享对象，存储所有受监管代币的黑名单数据
- 支持全局暂停功能，可一键暂停所有代币转移
- 合规场景中建议使用多签或分权管理铸造权和黑名单权
