# 拥有对象、共享对象与排序

历史上文档曾用「快速路径 / Fast Path」描述仅涉及**地址所有**或**不可变**对象时的执行方式；**当前协议实现已演进**，本书不再使用该术语，也**不展开**具体共识算法。开发时只需掌握：**共享对象**需要网络对「谁先到、谁后到」形成**全局顺序**；**仅涉及地址所有 / 不可变对象**的交易彼此更容易并行、交互模式更简单。

## 传统链的瓶颈与 Sui 的对象并行

在全部交易都必须**全局串行排序**的模型里，无关操作也要排队。Sui 以**对象**为粒度管理状态：若两笔交易触及的对象集合**无冲突**，就有机会**并行执行**——这是高性能的重要来源之一。

## 为什么共享对象更「重」

共享对象可被任意发送者在交易中引用。若两笔交易都要**修改**同一个共享对象，网络必须先约定顺序（先执行谁），否则会出现「两个增量都基于旧值」等一致性问题。因此，**涉及至少一个共享对象**的交易，必须经过**验证者之间的排序与一致性协议**才能完成；具体机制以[官方文档](https://docs.sui.io/concepts/sui-architecture)为准。

> **注意**：即便只**读取**共享对象（`&T`），交易仍可能因「需与写入同一共享状态的其他交易协调」而比纯拥有对象场景更重——以运行时与网络为准。

## 地址所有与不可变对象：更简单的交互面

**地址所有**对象在同一时刻只能被其所有者用于一笔进行中的修改（由对象版本约束）。**不可变**对象内容不变，任意方只读时不会产生「谁先写」的冲突。因此这类对象**不涉及多方对同一可变共享状态的争用**，合约设计与用户体验通常更直接——但**不要**将其理解为「固定延迟 ×× ms」或「跳过共识」等过时表述。

**被包装**对象的路径随**父对象**而定：父为地址所有则随父参与交易；父为共享则与共享对象一并排序。

## 代码示例：拥有 vs 共享

```move
module examples::ownership_demo;

/// 地址所有：典型个人资产
public struct PersonalNote has key {
    id: UID,
    content: vector<u8>,
}

/// 共享：多人写入的公告板
public struct Bulletin has key {
    id: UID,
    messages: vector<vector<u8>>,
}

public fun write_note(content: vector<u8>, ctx: &mut TxContext) {
    let note = PersonalNote {
        id: object::new(ctx),
        content,
    };
    transfer::transfer(note, ctx.sender());
}

public fun create_bulletin(ctx: &mut TxContext) {
    let bulletin = Bulletin {
        id: object::new(ctx),
        messages: vector::empty(),
    };
    transfer::share_object(bulletin);
}

public fun post_message(bulletin: &mut Bulletin, msg: vector<u8>) {
    vector::push_back(&mut bulletin.messages, msg);
}
```

| 操作 | 对象类型 | 设计要点 |
|------|----------|----------|
| `write_note` / 修改自己的 `PersonalNote` | 地址所有 | 单方修改，不涉及共享状态争用 |
| `post_message` / 读共享 `Bulletin` | 共享 | 需全局排序与一致性；多读多写都要与链上当前版本协调 |

### 混合输入

一笔交易里**只要出现至少一个共享对象**，整笔交易就要与共享对象的排序规则一起处理（与「仅拥有对象」的交互复杂度不同）。

```move
module examples::mixed_transaction;

public struct OwnedToken has key, store {
    id: UID,
    value: u64,
}

public struct SharedPool has key {
    id: UID,
    total: u64,
}

public fun deposit(
    token: OwnedToken,
    pool: &mut SharedPool,
) {
    pool.total = pool.total + token.value;
    let OwnedToken { id, value: _ } = token;
    id.delete();
}
```

## 设计取舍（性能与可组合性）

- **多用地址所有 / 不可变**：个人余额、NFT、配置在单方名下完成时，优先建模为拥有对象，减少不必要的共享热点。
- **该共享时再共享**：可先创建为地址所有，完成初始化后再 `share_object`，避免过早暴露全局争用。
- **共享对象适合**：DEX 池、全局计数器、多人协作状态等**必须多方写同一链上字**的场景。

## 小结

- 不再使用「快速路径」作为机制名；以**对象是否共享、是否多方争用同一可变状态**来理解成本与并行度。
- **共享对象**需要网络级**全局排序**；细节以官方文档与当前主网行为为准。
- **仅拥有 / 不可变**场景通常更易并行、合约更直观，但**不**承诺固定延迟数字。
- **混合交易**含共享对象时，整体随共享对象走「需排序」的一侧。
