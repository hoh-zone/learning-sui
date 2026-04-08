# Party 对象

Party 对象是 Sui 的一种**混合所有权**类型：像地址所有对象一样有**单一所有者**，又像共享对象一样由**共识做版本管理**。它适合「需要共识版本、又希望保留单方所有权」或「同一对象上多笔交易并行排队」的场景。

参考：[Sui 官方文档 - Party Objects](https://docs.sui.io/concepts/object-ownership/party)、[sui::party 模块](https://docs.sui.io/references/framework/sui/party)。

## 核心特征

| 特性 | 说明 |
|------|------|
| **所有权** | 归属于一个 **Party**（由 `sui::party::Party` 描述），Party 内可配置多个地址及各自权限 |
| **版本化** | 与共享对象一样经**共识**出块并产生版本，便于多笔交易对同一对象排队（pipeline） |
| **转移方式** | 使用 `transfer::party_transfer` 或 `transfer::public_party_transfer`，将对象「转给」一个 Party |
| **后续转换** | 可再转为地址所有、不可变、或作为动态对象字段；**不能**在创建后变为共享对象 |

与**地址所有**对比：地址所有对象同一时刻只能参与一笔未完成交易；Party 对象可以有多笔 in-flight 交易同时排队，由共识排序后依次执行。

与**共享对象**对比：共享对象任何人都可访问；Party 对象只有 Party 内被授权的主体能访问，访问权限由 Party 的权限配置决定。

## Party 类型与权限

Party 描述「谁对该对象有什么权限」。权限在 `sui::party` 中定义为位掩码：

| 常量 | 值 | 含义 |
|------|---|------|
| `READ` | 1 | 可将对象作为**不可变**输入参与交易（发送时校验） |
| `WRITE` | 2 | 可**修改**对象，但不能改所有者或删除（执行结束时校验） |
| `DELETE` | 4 | 可**删除**对象，不能做其他修改（执行结束时校验） |
| `TRANSFER` | 8 | 可**变更对象所有者**，不能做其他修改（执行结束时校验） |
| `NO_PERMISSIONS` | 0 | 无权限 |
| `ALL_PERMISSIONS` | 15 | 读 + 写 + 删除 + 转移 |

Party 内部可维护「成员 → 权限」的映射；若交易发送方在成员表中，则使用该成员的权限，否则使用默认权限。常用构造方式：

- **`party::single_owner(owner: address): Party`**  
  创建一个「单所有者」Party：仅该 `owner` 拥有全部权限，无其他成员、无默认权限。大多数「把对象交给一个地址，但用共识版本」的场景可用此方式。

## 创建 Party 对象

将对象转为 Party 所有权，使用 `sui::transfer` 中的：

```move
// 模块内使用（不要求对象有 store）
public fun party_transfer<T: key>(obj: T, party: sui::party::Party);

// 公共使用（对象需 key + store）
public fun public_party_transfer<T: key + store>(obj: T, party: sui::party::Party);
```

- 若类型有 **store**，可从任意模块调用 **public_party_transfer**。
- 若类型无 store、且需支持「转给 Party」，则需在定义该类型的模块内使用 **party_transfer**，或通过[自定义转移策略](https://docs.sui.io/guides/developer/objects/transfers/custom-rules.md)控制。

**示例**：铸造一个 NFT 并转为单所有者 Party 对象

```move
use sui::party;
use sui::transfer;

public fun mint_and_party_transfer(
    nft: NFT,
    owner: address,
) {
    let p = party::single_owner(owner);
    transfer::public_party_transfer(nft, p);
}
```

## 何时使用 Party 对象

适合使用 Party 对象的典型情况：

1. **需要共识版本、但仍是单方资产**  
   例如：需要与共享对象或其它 Party 对象在同一交易中交互，希望由共识排序、版本一致，又不想把对象设为「任何人可访问」的共享。

2. **同一对象上多笔交易并行排队（pipeline）**  
   地址所有对象同一时刻只能被一笔交易使用；Party 对象可被多笔 in-flight 交易同时引用，由验证人按共识结果依次执行，有利于高并发场景。

3. **与其它 Party/共享对象一起使用**  
   若对象主要和 Party 或共享对象配合使用，转为 Party 对象不会带来额外共识成本（因为同属共识路径），却能得到单方所有权和权限控制。

**注意**：

- Party 对象**创建后不能再变为共享**；可转为地址所有、不可变或放入动态对象字段。
- **Coin 可以是 Party 对象**，但作为 Party 的 Coin **不能直接用于支付 gas**；若要用其支付 gas，需先转回地址所有。

## 在交易中使用 Party 对象

在 PTB 中，Party 对象与共享对象一样作为**交易输入**传入：按对象 ID（及必要时的版本）指定即可。验证人会检查**交易发送方**是否有权访问该 Party 对象（即是否在该 Party 的成员中且具备相应权限）。若在执行前该 Party 对象的所有者因其它冲突交易已变更，验证人可能在执行时中止交易。

通过「transfer to object」机制接收对象时，若**接收方是对象 ID**（即对象作为「父」接收子对象），则**不支持**以「该对象 ID 为所有者的 Party 对象」作为接收目标；Party 对象的所有者若为**账户地址**则不受此限（按官方文档当前约定）。

## 与其它所有权类型的对比

| 维度 | 地址所有 | 共享 | Party |
|------|----------|------|--------|
| 所有者 | 单一地址 | 无 | 单一 Party（可多成员+权限） |
| 版本化 | 无共识版本 | 共识版本 | 共识版本 |
| 多笔 in-flight 交易 | ❌ | ✅ | ✅ |
| 创建后能否变共享 | ✅（可 share_object） | — | ❌ |
| 典型用法 | 钱包资产、Cap | 市场、池子 | 需共识版本的单方资产、pipeline |

## 小结

- **Party 对象** = 单一 Party 所有 + 共识版本化，通过 **party_transfer / public_party_transfer** 创建，通过 **sui::party::Party**（如 **single_owner**）指定所有者与权限。
- 适合「要共识版本、又要单方控制」或「同一对象多笔交易排队」的场景；**不能**在创建后再改为共享对象。
- 使用前请查阅本书 [Transfer 函数参考](../appendix/03-transfer-functions.md) 中的 `party_transfer` / `public_party_transfer` 说明，以及 [sui::party](https://docs.sui.io/references/framework/sui/party) 的权限常量与 `single_owner` 等 API。
