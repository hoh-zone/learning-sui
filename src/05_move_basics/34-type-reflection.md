# 类型反射

Move 提供有限的运行时类型反射能力，主要通过 `std::type_name` 模块实现。类型反射允许在运行时获取类型的名称、模块信息和包地址等元数据，常用于在集合中存储类型信息、实现类型分发逻辑或调试。虽然反射能力有限，但在很多场景下已经足够实用。

## type_name 模块

### 获取类型名称

`type_name::get<T>()` 函数返回一个 `TypeName` 结构体，包含类型 `T` 的元数据信息：

```move
module book::reflection_basic;

use std::type_name;

public struct MyType has drop {}

#[test]
fun get_type_name() {
    let my_type_name = type_name::get<MyType>();
    let u64_type_name = type_name::get<u64>();
    let bool_type_name = type_name::get<bool>();

    // 不同类型的 TypeName 不相等
    assert!(u64_type_name != bool_type_name);

    let _ = my_type_name;
}
```

### 类型名称字符串

通过 `into_string()` 方法可以将 `TypeName` 转换为 ASCII 字符串，获取完整的类型名称：

```move
module book::reflection_string;

use std::type_name;
use std::ascii::String;

public struct Token has drop {}

#[test]
fun type_string() {
    let type_name = type_name::get<Token>();
    let name_str: String = type_name.into_string();

    // name_str 包含完整的类型路径，如 "0x...::reflection_string::Token"
    let _ = name_str;
}
```

## TypeName 方法

### 提取模块和地址信息

`TypeName` 提供了多个方法来提取类型的各部分信息：

```move
module book::reflection_example;

use std::type_name;
use std::ascii::String;

public struct MyType has drop {}

#[test]
fun type_reflection() {
    let type_name = type_name::get<MyType>();

    // 获取完整的类型名称字符串
    let name_str: String = type_name.into_string();

    // 获取模块名称
    let module_name = type_name.get_module();

    // 获取包地址
    let address = type_name.get_address();

    // 类型比较
    let u64_name = type_name::get<u64>();
    let bool_name = type_name::get<bool>();
    assert!(u64_name != bool_name);

    let _ = name_str;
    let _ = module_name;
    let _ = address;
}
```

### 原始类型的判断

`is_primitive()` 方法可以判断一个类型是否为原始类型（如 `u8`、`u64`、`bool`、`address` 等）：

```move
module book::reflection_primitive;

use std::type_name;

public struct CustomType has drop {}

#[test]
fun is_primitive() {
    let u64_name = type_name::get<u64>();
    let bool_name = type_name::get<bool>();
    let custom_name = type_name::get<CustomType>();

    assert!(u64_name.is_primitive());
    assert!(bool_name.is_primitive());
    assert!(!custom_name.is_primitive());
}
```

## Defining ID 与 Original ID

### 两种包标识

Move 在类型反射中区分两种包标识：

- **Original ID**（原始 ID）：类型首次发布时所在的包地址
- **Defining ID**（定义 ID）：引入该类型的包地址（在包升级后可能不同）

当包没有被升级时，两者相同。当包经过升级后，新版本的包地址与原始包地址不同，这时两个 ID 的区别就显现出来了：

```move
module book::reflection_ids;

use std::type_name;

public struct VersionedType has drop {}

#[test]
fun type_ids() {
    // get 方法使用 defining ID
    let with_defining = type_name::get<VersionedType>();

    // get_with_original_ids 使用 original ID
    let with_original = type_name::get_with_original_ids<VersionedType>();

    // 未升级时两者相同
    let _ = with_defining;
    let _ = with_original;
}
```

## 实际应用场景

### 在集合中存储类型信息

类型反射常用于在动态字段或表中以类型作为键：

```move
module book::reflection_usage;

use std::type_name::{Self, TypeName};
use std::ascii::String;

public struct TypeRegistry has drop {
    registered: vector<TypeName>,
}

public fun new_registry(): TypeRegistry {
    TypeRegistry { registered: vector[] }
}

public fun register<T>(registry: &mut TypeRegistry) {
    let type_name = type_name::get<T>();
    registry.registered.push_back(type_name);
}

public fun is_registered<T>(registry: &TypeRegistry): bool {
    let type_name = type_name::get<T>();
    let mut i = 0;
    while (i < registry.registered.length()) {
        if (registry.registered[i] == type_name) {
            return true
        };
        i = i + 1;
    };
    false
}

public struct TokenA has drop {}
public struct TokenB has drop {}
public struct TokenC has drop {}

#[test]
fun registry() {
    let mut registry = new_registry();

    register<TokenA>(&mut registry);
    register<TokenB>(&mut registry);

    assert!(is_registered<TokenA>(&registry));
    assert!(is_registered<TokenB>(&registry));
    assert!(!is_registered<TokenC>(&registry));
}
```

### 类型信息调试

在开发和测试阶段，类型反射可以帮助调试泛型代码：

```move
module book::reflection_debug;

use std::type_name;
use std::ascii::String;

public fun type_info<T>(): String {
    let type_name = type_name::get<T>();
    type_name.into_string()
}

#[test]
fun debug_info() {
    let u64_info = type_info<u64>();
    let bool_info = type_info<bool>();

    // 可以在测试中打印或断言类型信息
    assert!(u64_info != bool_info);
}
```

## 小结

Move 通过 `std::type_name` 模块提供有限但实用的运行时类型反射能力。`type_name::get<T>()` 返回 `TypeName` 结构体，可以获取类型的完整名称、模块名、包地址等元数据。`is_primitive()` 用于判断是否为原始类型。Move 还区分 Defining ID 和 Original ID 来处理包升级后的类型标识问题。类型反射在动态集合的类型键、类型注册表和调试等场景中非常有用。
