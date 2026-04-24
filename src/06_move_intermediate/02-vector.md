# 向量（Vector）

向量（Vector）是 Move 语言中唯一的原生集合类型，用于存储同一类型的有序元素序列。它类似于其他语言中的动态数组或列表，可以在运行时添加、删除和访问元素。向量是 Move 中最基础、最常用的数据结构，几乎所有复杂的数据组织都建立在它之上。

## 创建向量

### 字面量语法

Move 提供了简洁的字面量语法来创建向量：

```move
module book::vector_create;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun create() {
    let empty: vector<u64> = vector[];     // 空向量，需要类型标注
    let nums = vector[1u64, 2, 3];         // 带初始元素的向量
    let bools = vector[true, false, true]; // 布尔向量
    let bytes = vector[0u8, 1, 2, 255];   // 字节向量

    assert_eq!(empty.length(), 0);
    assert_eq!(nums.length(), 3);
    assert_eq!(bools.length(), 3);
    assert_eq!(bytes.length(), 4);
}
```

### 泛型类型

向量的类型表示为 `vector<T>`，其中 `T` 可以是任何合法的 Move 类型：

```move
module book::vector_types;

use std::string::String;

public struct Item has copy, drop {
    name: String,
    value: u64,
}

#[test]
fun vector_types() {
    let _strings: vector<String> = vector[];
    let _nested: vector<vector<u64>> = vector[];    // 向量的向量
    let _items: vector<Item> = vector[];             // 结构体向量
    let _options: vector<Option<u64>> = vector[];    // Option 向量
}
```

## 基本操作

向量内置于语言中，无需导入即可使用。以下是最常用的操作方法：

### 添加与移除元素

```move
module book::vector_ops;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun push_pop() {
    let mut v = vector<u64>[];

    // 尾部添加元素
    v.push_back(10);
    v.push_back(20);
    v.push_back(30);
    assert_eq!(v.length(), 3);

    // 尾部移除元素（返回被移除的值）
    let last = v.pop_back();
    assert_eq!(last, 30);
    assert_eq!(v.length(), 2);

    // 在指定位置移除元素
    let removed = v.remove(0);  // 移除第一个元素
    assert_eq!(removed, 10);
    assert_eq!(v.length(), 1);
}
```

### 访问元素

```move
module book::vector_access;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun access() {
    let v = vector[10u64, 20, 30, 40];

    // 索引访问（语法糖，等价于 *vector::borrow(&v, 0)）
    assert_eq!(v[0], 10);
    assert_eq!(v[3], 40);

    // 通过 borrow 获取不可变引用
    let first: &u64 = &v[0];
    assert_eq!(*first, 10);
}
```

### 修改元素

```move
module book::vector_modify;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun modify() {
    let mut v = vector[10u64, 20, 30];

    // 通过 borrow_mut 获取可变引用
    let first = &mut v[1];
    *first = 200;
    assert_eq!(v[1], 200);
}
```

### 下标语法

`v[i]` 是 Move 的**下标语法**：编译器会将其转换为对 `vector::borrow`（只读）或 `vector::borrow_mut`（可写）的调用。标准库中的 `vector` 通过 `#[syntax(index)]` 标记了 `borrow` 与 `borrow_mut`，因此支持 `v[i]` 和 `&v[i]`、`&mut v[i]`。

自定义类型也可以为“索引访问”定义类似语法：在同一模块中为类型定义带有 `#[syntax(index)]` 的 `public fun borrow(...)` 和 `public fun borrow_mut(...)`，第一个参数为 `&Self` / `&mut Self`，返回 `&T` / `&mut T`，即可对该类型的值使用 `obj[index_expr]` 形式的读写。详见语言参考中的 Index Syntax。

## 查询操作

```move
module book::vector_query;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun query() {
    let v = vector[10u64, 20, 30, 40, 50];

    // 长度
    assert_eq!(v.length(), 5);

    // 是否为空
    assert!(!v.is_empty());
    assert!(vector<u64>[].is_empty());

    // 是否包含某个元素
    assert!(v.contains(&30));
    assert!(!v.contains(&99));
}
```

## 排列操作

```move
module book::vector_arrange;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun arrange() {
    let mut v = vector[1u64, 2, 3, 4, 5];

    // 交换两个位置的元素
    v.swap(0, 4);
    assert_eq!(v[0], 5);
    assert_eq!(v[4], 1);

    // swap_remove：将指定位置元素与最后一个交换，然后 pop_back
    // 比 remove 更高效（O(1)），但不保持顺序
    let mut v2 = vector[10u64, 20, 30, 40];
    let removed = v2.swap_remove(1);  // 移除索引 1 的元素 (20)
    assert_eq!(removed, 20);
    // v2 现在是 [10, 40, 30]（40 被换到了索引 1）

    // 反转向量
    let mut v3 = vector[1u64, 2, 3];
    v3.reverse();
    assert!(v3 == vector[3u64, 2, 1]);
}
```

## 遍历向量

### while 循环遍历

Move 中遍历向量最常见的方式是使用 `while` 循环配合索引：

```move
module book::vector_iterate;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun while_loop() {
    let v = vector[10u64, 20, 30, 40, 50];

    let mut i = 0;
    let mut sum = 0u64;
    while (i < v.length()) {
        sum = sum + v[i];
        i = i + 1;
    };

    assert_eq!(sum, 150);
}
```

### 消耗式遍历

如果不再需要向量，可以使用 `pop_back` 逐个取出元素：

```move
module book::vector_consume;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun consume() {
    let mut v = vector[1u64, 2, 3];
    let mut sum = 0u64;

    while (!v.is_empty()) {
        sum = sum + v.pop_back();
    };

    assert_eq!(sum, 6);
    assert!(v.is_empty());
    v.destroy_empty(); // 显式销毁空向量
}
```

## 销毁向量

### destroy_empty

对于元素类型没有 `drop` 能力的向量，必须在向量为空后使用 `destroy_empty` 显式销毁：

```move
module book::vector_destroy;

public struct NoDrop { value: u64 }

fun consume(_item: NoDrop) {
    let NoDrop { value: _ } = _item;
}

#[test]
fun destroy() {
    let mut v = vector[NoDrop { value: 1 }, NoDrop { value: 2 }];

    // 必须逐个取出并消耗元素
    consume(v.pop_back());
    consume(v.pop_back());

    // 向量为空后才能销毁
    v.destroy_empty();
}
```

如果元素类型有 `drop` 能力，向量在作用域结束时会自动销毁，无需手动处理。

## 向量的向量

Move 支持嵌套向量，即向量的元素本身也是向量：

```move
module book::nested_vector;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun nested() {
    let mut matrix: vector<vector<u64>> = vector[];

    matrix.push_back(vector[1, 2, 3]);
    matrix.push_back(vector[4, 5, 6]);
    matrix.push_back(vector[7, 8, 9]);

    assert_eq!(matrix.length(), 3);
    assert_eq!(matrix[0][0], 1);
    assert_eq!(matrix[1][1], 5);
    assert_eq!(matrix[2][2], 9);
}
```

## 结构体向量

向量可以存储自定义结构体，这在实际开发中非常常见：

```move
module book::struct_vector;

use std::string::String;

public struct Player has copy, drop {
    name: String,
    score: u64,
}

public fun top_scorer(players: &vector<Player>): String {
    assert!(!players.is_empty());

    let mut best_idx = 0;
    let mut i = 1;
    while (i < players.length()) {
        if (players[i].score > players[best_idx].score) {
            best_idx = i;
        };
        i = i + 1;
    };

    players[best_idx].name
}

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun struct_vector() {
    let players = vector[
        Player { name: b"Alice".to_string(), score: 100 },
        Player { name: b"Bob".to_string(), score: 250 },
        Player { name: b"Charlie".to_string(), score: 180 },
    ];

    let top = top_scorer(&players);
    assert_eq!(top, b"Bob".to_string());
}
```

## 完整示例

下面的例子综合展示了向量的常用操作：

```move
module book::vector_example;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun vector_example() {
    let mut v = vector[10u64, 20, 30];

    // 添加元素
    v.push_back(40);
    assert_eq!(v.length(), 4);

    // 访问元素
    assert_eq!(v[0], 10);
    assert_eq!(v[3], 40);

    // 移除最后一个元素
    let last = v.pop_back();
    assert_eq!(last, 40);

    // 按索引移除
    let removed = v.remove(1); // 移除 20
    assert_eq!(removed, 20);

    // 查询
    assert!(v.contains(&10));
    assert!(!v.contains(&20));

    // 遍历求和
    let mut i = 0;
    let mut sum = 0u64;
    while (i < v.length()) {
        sum = sum + v[i];
        i = i + 1;
    };

    assert_eq!(sum, 40); // 10 + 30
}
```

## 小结

向量是 Move 中最基础也是最重要的集合类型。本节核心要点：

- **创建**：使用 `vector[]` 字面量语法，类型为 `vector<T>`
- **添加/移除**：`push_back` 尾部添加，`pop_back` 尾部移除，`remove` 按索引移除
- **访问**：通过 `v[i]` 索引访问，`borrow` 获取引用，`borrow_mut` 获取可变引用
- **查询**：`length()`、`is_empty()`、`contains()` 检查向量状态
- **排列**：`swap` 交换、`swap_remove` 高效删除、`reverse` 反转
- **遍历**：使用 `while` 循环配合索引进行遍历
- **销毁**：元素有 `drop` 时自动销毁，否则需要清空后调用 `destroy_empty`
- **嵌套**：支持 `vector<vector<T>>` 等嵌套结构
