# 测试基础

Move 编译器内置了测试框架——测试用 Move 编写，与源代码并存。你只需为函数添加 `#[test]` 注解，编译器就会自动发现并执行它们。测试中的 VM 执行环境与生产环境一致，确保代码语义完全相同。本节将带你掌握编写和运行测试的基本方法。

## 什么是测试？

测试是带有 `#[test]` 属性的函数。测试函数不能接收参数，也不应返回值。当测试函数意外中止（abort）时，测试即为失败。

```move
module book::my_module;

#[test_only]
use std::unit_test::assert_eq;

#[test]
fun addition() {
    assert_eq!(2 + 2, 4);
}

#[test]
fun that_aborts() {
    abort // 此测试会失败——意外的 abort
}

#[test, expected_failure]
fun expected_abort() {
    abort // 此测试会通过——abort 在预期之中
}
```

## 运行测试

使用 `sui move test` 命令运行测试。编译器会在 _测试模式_ 下构建包并执行所有发现的测试。

```bash
sui move test
```

输出示例：

```
Running Move unit tests
[ PASS    ] book::my_module::addition
[ FAIL    ] book::my_module::that_aborts
[ PASS    ] book::my_module::expected_abort
Test result: FAILED. Total tests: 3; passed: 2; failed: 1
```

### 过滤测试

可以通过提供过滤字符串来运行特定测试，只有完全限定名中包含该字符串的测试才会执行：

```bash
# 运行名称中含 "addition" 的测试
sui move test addition

# 运行特定模块的所有测试
sui move test my_module

# 运行特定测试
sui move test book::my_module::addition
```

## 期望失败（Expected Failure）

使用 `#[expected_failure]` 测试代码在特定条件下是否会中止。只有函数 abort 时测试才通过；若正常完成则测试失败。

### 基本用法

```move
#[test, expected_failure]
fun division_by_zero() {
    let _ = 1 / 0; // 中止——测试通过
}
```

### 指定中止码

通过指定期望的 abort code 确保函数因正确的原因失败：

```move
module book::errors;

const EInvalidInput: u64 = 1;
const ENotFound: u64 = 2;

public fun validate(x: u64) {
    assert!(x > 0, EInvalidInput);
}

#[test, expected_failure(abort_code = EInvalidInput)]
fun validate_zero_fails() {
    validate(0); // 以 EInvalidInput 中止——测试通过
}

#[test, expected_failure(abort_code = ENotFound)]
fun wrong_error_code() {
    validate(0); // 以 EInvalidInput 中止而非 ENotFound——测试失败
}
```

### 指定中止位置

使用 `location` 指定 abort 应发生在哪个模块中：

```move
#[test, expected_failure(abort_code = EInvalidInput, location = book::errors)]
fun abort_location() {
    validate(0);
}

#[test, expected_failure(abort_code = 1, location = Self)]
fun abort_in_self() {
    abort 1
}
```

## 仅测试代码（Test-Only Code）

标记为 `#[test_only]` 的代码只在测试模式下编译，适用于测试工具函数、辅助导入等不应出现在生产代码中的内容。

### 仅测试导入

```move
#[test_only]
use std::unit_test::assert_eq;

#[test]
fun with_assert_eq() {
    assert_eq!(2 + 2, 4);
}
```

### 仅测试函数

```move
#[test_only]
fun setup_test_data(): vector<u64> {
    vector[1, 2, 3, 4, 5]
}

#[test]
fun sum() {
    let data = setup_test_data();
    let mut sum = 0;
    data.do!(|x| sum = sum + x);
    assert_eq!(sum, 15);
}
```

### 仅测试常量与模块

```move
#[test_only]
const TEST_ADDRESS: address = @0xCAFE;

#[test_only]
module book::test_helpers;
public fun create_test_scenario(): u64 { 42 }
```

## 常用 CLI 选项

| 选项 | 描述 |
| --- | --- |
| `<filter>` | 只运行匹配过滤字符串的测试 |
| `--coverage` | 收集覆盖率信息 |
| `--trace` | 生成 LCOV 追踪数据 |
| `--statistics` | 显示 Gas 消耗统计 |
| `--threads <n>` | 并行测试线程数 |
| `--rand-num-iters <n>` | 随机测试的迭代次数 |
| `--seed <n>` | 可复现的随机种子 |

## 测试失败输出

当测试失败时，输出会包含测试名称、FAIL 状态、abort code、失败位置和调用栈：

```
┌── test_that_failed ──────
│ error[E11001]: test failure
│    ┌─ ./sources/module.move:15:9
│    │
│ 15 │         assert!(balance == 100);
│    │         ^^^^^^^^^^^^^^^^^^^^^^^ Test was not expected to error, but it
│    │         aborted with code 1 originating in the module 0x0::module
│
└──────────────────
```

## 小结

- 使用 `#[test]` 标注测试函数，`sui move test` 运行所有测试
- `#[expected_failure]` 用于验证代码是否正确地 abort，可指定 abort code 和 location
- `#[test_only]` 标记仅在测试模式下编译的代码，适合放置辅助函数和导入
- 通过过滤字符串可精确运行特定测试，CLI 提供覆盖率、统计等丰富选项
