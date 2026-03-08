# 模块（Module）

模块（Module）是 Move 语言中代码组织的基本单元，用于将相关的类型定义、函数和常量组织在一起。模块为代码提供了命名空间隔离，所有成员默认是私有的，只有显式标记为 `public` 的成员才能被外部访问。理解模块的声明方式和组织规范是学习 Move 语言的第一步。

## 模块声明语法

每个 Move 源文件通常包含一个模块声明。模块声明的基本语法如下：

```move
module package_address::module_name;
```

其中 `package_address` 是包地址（可以是字面地址或命名地址），`module_name` 是模块名称。

### 2024 标签语法与传统语法

在 Move 2024 版本中，推荐使用上面的标签语法（label syntax），以分号结尾，模块体中的代码直接写在文件中，无需大括号包裹。

传统语法（pre-2024）使用大括号包裹模块体：

```move
module book::my_module {
    // 模块内容全部在大括号内
    public fun hello(): u64 { 42 }
}
```

本书统一使用 2024 标签语法。

## 命名规范

Move 模块遵循 **snake_case**（蛇形命名法）规范，即全部小写字母，单词之间以下划线分隔：

- `my_module` ✅
- `token_swap` ✅
- `MyModule` ❌
- `tokenSwap` ❌

通常建议 **一个文件只包含一个模块**，文件名与模块名保持一致。例如模块 `my_module` 对应文件 `my_module.move`。

## 模块成员

一个模块可以包含以下成员：

- **结构体（Struct）**：自定义数据类型
- **函数（Function）**：可执行的逻辑单元
- **常量（Constant）**：编译时确定的不可变值
- **导入（Use）**：引用其他模块的成员

```move
module book::my_module;

use std::string::String;

const MAX_SIZE: u64 = 100;

public struct Item has key, store {
    id: UID,
    name: String,
}

public fun create_item(name: String, ctx: &mut TxContext): Item {
    Item {
        id: object::new(ctx),
        name,
    }
}
```

上面的示例展示了一个完整的模块，包含了导入、常量、结构体和函数。

## 地址与命名地址

模块必须属于一个地址。地址可以是字面地址或命名地址。

### 字面地址

字面地址是一个十六进制值，例如 `0x0`、`0x1`、`0x2`：

```move
module 0x1::math;
```

### 命名地址

命名地址是在 `Move.toml` 配置文件中定义的别名，更加可读且便于管理：

```toml
# Move.toml
[addresses]
book = "0x0"
std = "0x1"
sui = "0x2"
```

使用命名地址声明模块：

```move
module book::my_module;
```

编译时，`book` 会被替换为 `Move.toml` 中定义的实际地址 `0x0`。命名地址的好处是在发布合约后只需修改 `Move.toml` 中的地址，而不需要修改源代码。

## 访问控制

模块中的所有成员默认是 **私有的**，即只能在定义它们的模块内部访问：

```move
module book::access_control;

// 私有函数，只能在本模块内调用
fun internal_logic(): u64 {
    42
}

// 公开函数，可以被其他模块调用
public fun value(): u64 {
    internal_logic()
}

// 仅供 package 内其他模块调用
public(package) fun package_only(): u64 {
    100
}
```

Move 提供了三种可见性级别：

| 可见性 | 关键字 | 访问范围 |
|--------|--------|----------|
| 私有 | （无修饰符） | 仅模块内部 |
| 公开 | `public` | 任何模块 |
| 包级别 | `public(package)` | 同一个包内的模块 |

## 小结

模块是 Move 语言的代码组织基石。本节的核心要点包括：

- 模块使用 `module address::name;` 语法声明，推荐使用 2024 标签语法
- 模块名遵循 snake_case 命名规范，一个文件对应一个模块
- 模块可以包含结构体、函数、常量和导入
- 地址可以是字面地址或 `Move.toml` 中定义的命名地址
- 所有模块成员默认私有，需要显式标记 `public` 或 `public(package)` 来暴露
