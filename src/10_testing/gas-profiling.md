# Gas 分析

理解 Gas 消耗有助于优化 Move 代码并估算交易成本。Move 测试框架提供了内置工具来测量测试执行期间的 Gas 使用量，此外还有 `sui analyze-trace` 工具用于更深入的分析。

> `-s` 显示的统计数据仅反映**计算单元**，不包括存储成本。编译器计算单元不直接映射到实际的链上 Gas 费用，它们展示的是相对计算复杂度，适合在不同实现之间比较。要获取实际 Gas 成本，请发布到测试网并测量真实交易。

## 简单测量：测试统计

使用 `-s` 或 `--statistics` 标志查看每个测试的执行时间和 Gas 消耗：

```bash
sui move test -s
```

输出示例：

```
Test Statistics:

┌──────────────────────────────────────────┬────────────┬───────────────────┐
│               Test Name                  │    Time    │     Gas Used      │
├──────────────────────────────────────────┼────────────┼───────────────────┤
│ book::my_module::test_simple_operation   │   0.003    │         1         │
├──────────────────────────────────────────┼────────────┼───────────────────┤
│ book::my_module::test_complex_operation  │   0.011    │        59         │
├──────────────────────────────────────────┼────────────┼───────────────────┤
│ book::my_module::test_with_objects       │   0.008    │        25         │
└──────────────────────────────────────────┴────────────┴───────────────────┘
```

### CSV 输出

导入到电子表格或用于程序化分析：

```bash
sui move test -s csv
```

```
test_name,time_ns,gas_used
book::my_module::test_simple_operation,3381750,1
book::my_module::test_complex_operation,8454125,59
book::my_module::test_with_objects,3905625,25
```

## Gas 限制

使用 `-i` 或 `--gas-limit` 设置测试的最大 Gas 预算，超出限制的测试会超时：

```bash
sui move test -i 50
```

```
[ PASS    ] book::my_module::test_simple_operation
[ TIMEOUT ] book::my_module::test_complex_operation
[ PASS    ] book::my_module::test_with_objects
```

适用场景：

- **识别昂贵操作**：发现消耗意外大量 Gas 的测试
- **强制 Gas 预算**：确保关键路径保持在可接受的限制内
- **测试 Gas 耗尽**：验证代码正确处理 Gas 不足的情况

## 比较不同实现

使用统计数据比较不同实现的 Gas 消耗：

```move
module book::comparison;

use std::unit_test::assert_eq;

public fun sum_loop(n: u64): u64 {
    let mut sum = 0;
    n.do!(|i| sum = sum + i);
    sum
}

public fun sum_formula(n: u64): u64 {
    n * (n - 1) / 2
}

#[test]
fun sum_loop_100() {
    let result = sum_loop(100);
    assert_eq!(result, 4950);
}

#[test]
fun sum_formula_100() {
    let result = sum_formula(100);
    assert_eq!(result, 4950);
}
```

运行统计分析揭示差异：

```bash
sui move test -s comparison
```

```
┌────────────────────────────────────┬────────────┬───────────┐
│           Test Name                │    Time    │  Gas Used │
├────────────────────────────────────┼────────────┼───────────┤
│ book::comparison::sum_loop_100     │   0.005    │    201    │
├────────────────────────────────────┼────────────┼───────────┤
│ book::comparison::sum_formula_100  │   0.002    │      3    │
└────────────────────────────────────┴────────────┴───────────┘
```

数学公式比循环节省了约 66 倍的计算量！

## 追踪分析（Trace Analysis）

对于更深入的性能分析，可以生成执行追踪并用 speedscope 可视化。

### 步骤 1：生成追踪

```bash
sui move test --trace
```

追踪文件写入包构建目录下的 `traces/` 文件夹。

### 步骤 2：生成 Gas 概况

```bash
sui analyze-trace -p traces/<TRACE_FILE> gas-profile
```

输出 `gas_profile_<TRACE_FILE>.json` 文件。

### 步骤 3：使用 Speedscope 可视化

```bash
npm install -g speedscope
speedscope gas_profile_<TRACE_FILE>.json
```

Speedscope 提供三种视图：

- **Time Order**：按调用顺序从左到右展示调用栈，条形宽度对应 Gas 消耗
- **Left Heavy**：将重复调用分组，按总 Gas 消耗排序——适合找到最昂贵的代码路径
- **Sandwich**：列出每个函数的 Gas 消耗，含 **Total**（包括被调用函数）和 **Self**（仅函数本身）

## Gas 优化策略

基于分析结果的常见优化方向：

1. **用数学公式替代循环**：如上例所示
2. **减少对象创建**：每个 `object::new` 都有成本
3. **选择高效数据结构**：`VecMap` 适合小集合，`Table` 适合大集合
4. **避免不必要的拷贝**：使用引用而非值传递
5. **批量操作**：将多个小操作合并为少量大操作

## 小结

- 使用 `sui move test -s` 获取每个测试的 Gas 消耗统计
- `--gas-limit` 可设置 Gas 上限，识别昂贵操作
- Gas 统计适合比较不同实现的计算效率
- `sui analyze-trace` 配合 speedscope 提供函数级的 Gas 消耗火焰图
- 注意：编译器 Gas 单元与实际链上费用不同，适合做相对比较
