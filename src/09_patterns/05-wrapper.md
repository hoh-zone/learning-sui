# Wrapper 模式

Wrapper（包装器）模式是一种通过创建新类型来包装已有类型，从而**扩展或限制**其行为的设计模式。在 Move 中，Wrapper 模式广泛用于构建自定义数据结构、控制对象访问权限以及实现类型安全的接口封装。

本章将介绍 Wrapper 模式的基本原理、常见实现方式，以及在对象系统中的高级应用。

## 什么是 Wrapper 模式

Wrapper 模式的核心思想很简单：**创建一个新的结构体，其中包含一个已有类型的字段**。通过控制对外暴露的接口，可以：

- **限制行为**：隐藏底层类型的某些操作（如只允许栈操作，不允许随机访问）
- **扩展行为**：在底层类型的基础上添加新功能（如添加权限检查、日志记录）
- **改变语义**：赋予底层类型新的含义（如将 `vector` 包装为 `Stack`）

### 基本结构

```move
/// 典型的 Wrapper 结构
public struct Wrapper<T> has store {
    inner: T,
}
```

### 标准访问器

Wrapper 通常提供三种标准访问器：

| 函数 | 签名 | 用途 |
|------|------|------|
| `inner()` | `&Wrapper<T> -> &T` | 只读访问内部值 |
| `inner_mut()` | `&mut Wrapper<T> -> &mut T` | 可变访问内部值 |
| `into_inner()` | `Wrapper<T> -> T` | 解包，消耗 Wrapper |

## 限制行为：Stack 示例

将 `vector` 包装为 `Stack`，只暴露后进先出（LIFO）操作：

```move
module examples::wrapper;

/// Stack - 包装 vector 以限制操作
public struct Stack<T> has store {
    inner: vector<T>,
}

public fun new<T>(): Stack<T> {
    Stack { inner: vector::empty() }
}

public fun push<T>(stack: &mut Stack<T>, item: T) {
    vector::push_back(&mut stack.inner, item);
}

public fun pop<T>(stack: &mut Stack<T>): T {
    vector::pop_back(&mut stack.inner)
}

public fun peek<T>(stack: &Stack<T>): &T {
    let len = vector::length(&stack.inner);
    vector::borrow(&stack.inner, len - 1)
}

public fun is_empty<T>(stack: &Stack<T>): bool {
    vector::is_empty(&stack.inner)
}

public fun size<T>(stack: &Stack<T>): u64 {
    vector::length(&stack.inner)
}

/// 只读访问底层 vector
public fun inner<T>(stack: &Stack<T>): &vector<T> {
    &stack.inner
}

/// 销毁 Wrapper，返回底层 vector
public fun into_inner<T>(stack: Stack<T>): vector<T> {
    let Stack { inner } = stack;
    inner
}
```

通过这种包装：

- ✅ 允许 `push`、`pop`、`peek` 操作
- ❌ 禁止随机访问（`vector::borrow`）
- ❌ 禁止在中间插入或删除元素
- 如果需要底层 `vector`，必须显式调用 `into_inner()` 解包

## 扩展行为：带边界检查的数组

```move
module examples::bounded_vec;

/// 有最大长度限制的 vector
public struct BoundedVec<T> has store {
    inner: vector<T>,
    max_size: u64,
}

public fun new<T>(max_size: u64): BoundedVec<T> {
    BoundedVec {
        inner: vector::empty(),
        max_size,
    }
}

public fun push<T>(bv: &mut BoundedVec<T>, item: T) {
    assert!(vector::length(&bv.inner) < bv.max_size, 0);
    vector::push_back(&mut bv.inner, item);
}

public fun pop<T>(bv: &mut BoundedVec<T>): T {
    vector::pop_back(&mut bv.inner)
}

public fun get<T>(bv: &BoundedVec<T>, index: u64): &T {
    vector::borrow(&bv.inner, index)
}

public fun length<T>(bv: &BoundedVec<T>): u64 {
    vector::length(&bv.inner)
}

public fun max_size<T>(bv: &BoundedVec<T>): u64 {
    bv.max_size
}

public fun is_full<T>(bv: &BoundedVec<T>): bool {
    vector::length(&bv.inner) >= bv.max_size
}
```

`BoundedVec` 在 `vector` 的基础上增加了最大长度限制，每次 `push` 时自动检查是否超出容量。

## 不可变包装器

通过不提供可变访问器，可以创建不可变的数据结构：

```move
module examples::immutable_vec;

/// 一旦创建就不可修改的 vector
public struct ImmutableVec<T: store> has store {
    inner: vector<T>,
}

/// 从 vector 创建，之后不可修改
public fun from_vec<T: store>(v: vector<T>): ImmutableVec<T> {
    ImmutableVec { inner: v }
}

/// 只读访问
public fun get<T: store>(iv: &ImmutableVec<T>, index: u64): &T {
    vector::borrow(&iv.inner, index)
}

public fun length<T: store>(iv: &ImmutableVec<T>): u64 {
    vector::length(&iv.inner)
}

public fun contains<T: store>(iv: &ImmutableVec<T>, item: &T): bool
where T: copy {
    vector::contains(&iv.inner, item)
}

/// 解包获取底层 vector（消耗 ImmutableVec）
public fun into_inner<T: store>(iv: ImmutableVec<T>): vector<T> {
    let ImmutableVec { inner } = iv;
    inner
}
```

注意这里**没有**提供 `inner_mut()` 或任何修改方法，确保了创建后的不可变性。

## 包装对象

Wrapper 模式在对象层面同样强大。通过将一个对象包装在另一个对象中，可以实现权限控制、时间锁等功能。

### 时间锁包装器

```move
module examples::guarded;

use std::string::String;

/// 将任意可存储类型包装为带时间锁的对象
public struct Locked<T: store> has key {
    id: UID,
    content: T,
    unlock_epoch: u64,
}

public fun lock<T: store>(
    content: T,
    unlock_epoch: u64,
    ctx: &mut TxContext,
) {
    let locked = Locked {
        id: object::new(ctx),
        content,
        unlock_epoch,
    };
    transfer::transfer(locked, ctx.sender());
}

public fun unlock<T: store>(
    locked: Locked<T>,
    ctx: &TxContext,
): T {
    assert!(ctx.epoch() >= locked.unlock_epoch, 0);
    let Locked { id, content, unlock_epoch: _ } = locked;
    id.delete();
    content
}
```

这个包装器可以锁定任意类型，直到指定的 epoch 才能解锁。

### 权限包装器

```move
module examples::permission_wrapper;

use std::string::String;

/// 包装对象，添加权限控制
public struct Protected<T: store> has key {
    id: UID,
    content: T,
    authorized_users: vector<address>,
}

public fun protect<T: store>(
    content: T,
    authorized_users: vector<address>,
    ctx: &mut TxContext,
) {
    let protected = Protected {
        id: object::new(ctx),
        content,
        authorized_users,
    };
    transfer::share_object(protected);
}

const ENotAuthorized: u64 = 0;

/// 只有授权用户才能访问
public fun access<T: store>(
    protected: &Protected<T>,
    ctx: &TxContext,
): &T {
    assert!(
        vector::contains(&protected.authorized_users, &ctx.sender()),
        ENotAuthorized,
    );
    &protected.content
}

/// 只有授权用户才能修改
public fun access_mut<T: store>(
    protected: &mut Protected<T>,
    ctx: &TxContext,
): &mut T {
    assert!(
        vector::contains(&protected.authorized_users, &ctx.sender()),
        ENotAuthorized,
    );
    &mut protected.content
}

/// 添加授权用户（需要已是授权用户）
public fun add_user<T: store>(
    protected: &mut Protected<T>,
    new_user: address,
    ctx: &TxContext,
) {
    assert!(
        vector::contains(&protected.authorized_users, &ctx.sender()),
        ENotAuthorized,
    );
    vector::push_back(&mut protected.authorized_users, new_user);
}
```

## Wrapper 与 Wrapped Object

在 Sui 的对象模型中，当一个对象被包装到另一个对象内部时，它就变成了**被包装对象**（Wrapped Object）。被包装的对象在链上是不可直接访问的，只有通过外层对象才能操作它。

```move
module examples::nft_bundle;

use std::string::String;

public struct NFT has key, store {
    id: UID,
    name: String,
}

/// 将多个 NFT 捆绑为一个对象
public struct Bundle has key {
    id: UID,
    nfts: vector<NFT>,
    label: String,
}

public fun create_bundle(
    nfts: vector<NFT>,
    label: String,
    ctx: &mut TxContext,
) {
    let bundle = Bundle {
        id: object::new(ctx),
        nfts,
        label,
    };
    transfer::transfer(bundle, ctx.sender());
}

/// 解开捆绑包，归还所有 NFT
public fun unbundle(
    bundle: Bundle,
    ctx: &TxContext,
) {
    let Bundle { id, mut nfts, label: _ } = bundle;
    id.delete();
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, ctx.sender());
    };
    vector::destroy_empty(nfts);
}
```

## 设计原则

### 何时使用 Wrapper

| 场景 | 示例 |
|------|------|
| 限制底层类型的操作 | `Stack`、`ImmutableVec` |
| 添加额外约束 | `BoundedVec`、`Locked` |
| 组合多个类型 | `Bundle`、`Protected` |
| 改变语义 | 将 `u64` 包装为 `Percentage`（百分比） |

### 设计建议

1. **最小接口原则**：只暴露必要的操作，隐藏不需要的底层功能
2. **提供逃生舱**：通常应提供 `into_inner()` 方法，允许在需要时解包
3. **考虑能力传递**：Wrapper 的能力应该合理反映其用途
4. **文档化限制**：清晰说明 Wrapper 与底层类型的行为差异

## 小结

Wrapper 模式通过将已有类型包装在新类型中，实现了行为的扩展和限制。在数据结构层面，它可以创建 Stack、BoundedVec 等受限集合；在对象层面，它可以实现时间锁、权限控制等高级功能。Wrapper 模式的精髓在于**通过接口控制来改变类型的行为**，同时保持底层数据的完整性。在设计 Move 模块时，合理使用 Wrapper 模式可以显著提高代码的安全性和可维护性。
