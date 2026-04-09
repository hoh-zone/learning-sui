# 编码规范

本附录总结 Move on Sui 的编码规范和最佳实践，涵盖命名、文件组织、代码风格和常见反模式。遵循这些规范可以提高代码可读性和可维护性。

## 包配置

### 使用正确的 Edition

```toml
[package]
name = "my_package"
edition = "2024"
```

### 隐式框架依赖

从 Sui 1.45 起，不再需要显式声明框架依赖：

```toml
# 现代写法
[dependencies]
# Sui, MoveStdlib, SuiSystem 自动导入

# 旧写法（不再需要）
# [dependencies]
# Sui = { ... }
```

### 命名地址加前缀

```toml
# 不推荐：通用名称容易冲突
[addresses]
math = "0x0"

# 推荐：项目前缀
[addresses]
my_protocol_math = "0x0"
```

## 模块结构

### 使用模块标签

```move
// 不推荐：旧风格，增加缩进
module my_package::my_module {
    public struct A {}
}

// 推荐：模块标签
module my_package::my_module;

public struct A {}
```

### Import 规范

```move
// 不推荐：单独的 Self 导入
use my_package::my_module::{Self};

// 推荐
use my_package::my_module;

// 同时需要模块和成员时
use my_package::other::{Self, OtherMember};

// 不推荐：分开写
use my_package::my_module;
use my_package::my_module::OtherMember;

// 推荐：合并
use my_package::my_module::{Self, OtherMember};
```

## 命名规范

### 常量命名

```move
// 错误常量：EPascalCase
const ENotAuthorized: u64 = 0;
const EInsufficientBalance: u64 = 1;

// 普通常量：ALL_CAPS
const MAX_SUPPLY: u64 = 10000;
const MY_CONSTANT: vector<u8> = b"my const";
```

### 结构体命名

```move
// Capability 类型加 Cap 后缀
public struct AdminCap has key, store {
    id: UID,
}

// 不要加 Potato 后缀
// 不推荐
public struct PromisePotato {}
// 推荐
public struct Promise {}

// 事件使用过去时
// 不推荐
public struct RegisterUser has copy, drop { user: address }
// 推荐
public struct UserRegistered has copy, drop { user: address }

// 动态字段键使用位置结构体 + Key 后缀
public struct DynamicFieldKey() has copy, drop, store;
```

## 函数设计

### 不要使用 public entry

```move
// 不推荐：entry 对 public 函数不必要
entry fun do_something() { /* ... */ }
// 或：public fun do_something() { /* ... */ } 供 PTB 组合调用

// 推荐：public 函数已经可以在交易中调用
public fun do_something(): T { /* ... */ }
```

### 可组合设计

```move
// 不推荐：不可组合，难以测试
public fun mint_and_transfer(ctx: &mut TxContext) {
    transfer::transfer(mint(ctx), ctx.sender());
}

// 推荐：可组合
public fun mint(ctx: &mut TxContext): NFT { /* ... */ }

// 可以使用 entry 做不可组合的便捷函数
entry fun mint_and_keep(ctx: &mut TxContext) { /* ... */ }
```

### 参数顺序

```move
// 不推荐：参数顺序混乱
public fun call_app(
    value: u8,
    app: &mut App,
    is_smth: bool,
    cap: &AppCap,
    clock: &Clock,
    ctx: &mut TxContext,
) { /* ... */ }

// 推荐：对象优先，Capability 其次，值参数随后，Clock 和 ctx 最后
public fun call_app(
    app: &mut App,
    cap: &AppCap,
    value: u8,
    is_smth: bool,
    clock: &Clock,
    ctx: &mut TxContext,
) { /* ... */ }
```

### 访问器命名

```move
// 不推荐：不必要的 get_ 前缀
public fun get_name(u: &User): String { /* ... */ }

// 推荐：getter 以字段名命名，无 get_ 前缀
public fun name(u: &User): String { /* ... */ }

// 可变引用加 _mut 后缀
public fun details_mut(u: &mut User): &mut Details { /* ... */ }
```

## 现代语法

### 字符串

```move
// 不推荐
use std::string::utf8;
let str = utf8(b"hello");

// 推荐
let str = b"hello".to_string();
let ascii = b"hello".to_ascii_string();
```

### UID 和上下文

```move
// 不推荐
object::delete(id);
tx_context::sender(ctx);

// 推荐
id.delete();
ctx.sender();
```

### Vector

```move
// 不推荐
let mut v = vector::empty();
vector::push_back(&mut v, 10);
let first = vector::borrow(&v, 0);
assert!(vector::length(&v) == 1);

// 推荐
let mut v = vector[10];
let first = v[0];
assert!(v.length() == 1);
```

### Coin 操作

```move
// 不推荐
let paid = coin::split(&mut payment, amount, ctx);
let balance = coin::into_balance(paid);

// 推荐
let balance = payment.split(amount, ctx).into_balance();

// 更好（不创建临时 coin）
let balance = payment.balance_mut().split(amount);
```

## 宏的使用

### Option 宏

```move
// 不推荐
if (opt.is_some()) {
    let inner = opt.destroy_some();
    call_function(inner);
};

// 推荐
opt.do!(|value| call_function(value));

// 带默认值
let value = opt.destroy_or!(default_value);
let value = opt.destroy_or!(abort ECannotBeEmpty);
```

### 循环宏

```move
// 不推荐
let mut i = 0;
while (i < 32) {
    do_action();
    i = i + 1;
};

// 推荐
32u8.do!(|_| do_action());

// 生成 vector
vector::tabulate!(32, |i| i);

// 遍历 vector
vec.do_ref!(|e| call_function(e));

// 销毁 vector 并对每个元素操作
vec.destroy!(|e| call(e));

// 折叠
let sum = source.fold!(0, |acc, v| acc + v);

// 过滤
let filtered = source.filter!(|e| e > 10);
```

### 解构

```move
// 不推荐
let MyStruct { id, field_1: _, field_2: _, field_3: _ } = value;
id.delete();

// 推荐
let MyStruct { id, .. } = value;
id.delete();
```

## 测试规范

### 合并测试属性

```move
// 不推荐：属性分两行
#[test]
#[expected_failure]
fun value_passes_check() { abort }

// 推荐：合并属性，测试函数不加 test_ 前缀
#[test, expected_failure]
fun value_passes_check() { abort }
```

### 简化测试上下文

```move
// 不推荐：不必要地使用 TestScenario
let mut test = test_scenario::begin(@0);
let nft = app::mint(test.ctx());
app::destroy(nft);
test.end();

// 推荐：使用 dummy context
let ctx = &mut tx_context::dummy();
app::mint(ctx).destroy();
```

### 使用 assert_eq!

```move
// 不推荐：assert! 不显示期望值与实际值
assert!(result == b"expected_value", 0);

// 推荐：assert_eq! 失败时打印两侧值（需 use std::unit_test::assert_eq）
assert_eq!(result, expected_value);
```

### 使用 test_utils::destroy

```move
// 不推荐：自定义 destroy_for_testing
nft.destroy_for_testing();

// 推荐：使用框架 test_utils::destroy
use sui::test_utils::destroy;
destroy(nft);
```

### 测试命名

```move
// 不推荐：测试函数不需要 test_ 前缀
#[test]
fun test_this_feature() { /* ... */ }

// 推荐：#[test] 已表达测试意图
#[test]
fun this_feature_works() { /* ... */ }
```

## 注释规范

```move
// 使用 /// 编写文档注释
/// 创建新的英雄 NFT
public fun mint(ctx: &mut TxContext): Hero { /* ... */ }

// 使用 // 解释复杂逻辑
// 当值小于 10 时可能下溢，需要添加 assert
let value = external_call(value, ctx);
```

## 小结

- 使用 Move 2024 Edition 和模块标签语法
- 错误常量用 `EPascalCase`，普通常量用 `ALL_CAPS`
- 函数设计遵循可组合原则，优先返回对象
- 参数顺序：对象 → Capability → 值参数 → Clock → ctx
- 积极使用现代语法：方法调用、宏、vector 字面量
- 测试中使用 `assert_eq!`、`destroy`、`tx_context::dummy()`
- 使用 Move Formatter 保持代码格式一致
