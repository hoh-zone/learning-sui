# 覆盖率报告

代码覆盖率是衡量测试期间代码哪些部分被执行的指标。它帮助识别未测试的代码路径，确保你的测试是全面的。`sui move test` 的 `--coverage` 标志用于生成覆盖率数据，`sui move coverage` 提供分析工具。

## 运行带覆盖率的测试

```bash
sui move test --coverage
```

这会运行所有测试并收集覆盖率信息。覆盖率数据存储在 `build` 目录中。

## 覆盖率摘要

`sui move coverage summary` 显示所有模块的覆盖率概览：

```bash
sui move coverage summary
```

输出示例：

```
+-------------------------+
| Move Coverage Summary   |
+-------------------------+
Module 0x0::my_module
>>> % Module coverage: 85.71
Module 0x0::another_module
>>> % Module coverage: 100.00
Module 0x0::untested_module
>>> % Module coverage: 0.00
+-------------------------+
| % Move Coverage: 62.50  |
+-------------------------+
```

### 按函数查看

```bash
sui move coverage summary --summarize-functions
```

### CSV 格式输出

```bash
sui move coverage summary --csv
```

## 源代码覆盖率

查看特定模块哪些行被执行：

```bash
sui move coverage source --module <MODULE_NAME>
```

这会显示带有覆盖率注解的源代码，指出哪些行被覆盖（在测试中执行过），哪些未被覆盖。

## LCOV 格式

对于与外部工具和 CI/CD 流水线集成，可以生成 LCOV 格式报告。

### 生成 LCOV 报告

首先运行带 `--trace` 标志的测试：

```bash
sui move test --coverage --trace
```

然后生成 LCOV 报告：

```bash
sui move coverage lcov
```

这会在当前目录创建 `lcov.info` 文件。

### 生成 HTML 报告

使用 `genhtml` 从 LCOV 文件生成 HTML 报告：

```bash
genhtml lcov.info -o coverage_html
```

可在浏览器中打开 `coverage_html` 目录查看交互式覆盖率报告。

### 差异覆盖率

查看特定测试独占覆盖的代码行：

```bash
sui move coverage lcov --differential-test <TEST_NAME>
```

### 单测覆盖率

仅生成单个测试的覆盖率：

```bash
sui move coverage lcov --only-test <TEST_NAME>
```

## 字节码覆盖率

高级调试时可查看反汇编字节码的覆盖率：

```bash
sui move coverage bytecode --module <MODULE_NAME>
```

## 可视化工具集成

LCOV 格式兼容多种覆盖率可视化工具：

- **genhtml** — 生成 HTML 覆盖率报告
- **VS Code Coverage Gutters** — 在编辑器中可视化覆盖率
- **Codecov / Coveralls** — 上传到覆盖率跟踪服务

## 命令速查表

| 命令 | 描述 |
| --- | --- |
| `sui move test --coverage` | 运行测试并收集覆盖率数据 |
| `sui move test --coverage --trace` | 运行测试并生成追踪数据（LCOV 所需） |
| `sui move coverage summary` | 显示每个模块的覆盖率百分比 |
| `sui move coverage summary --summarize-functions` | 按函数分解显示覆盖率 |
| `sui move coverage summary --csv` | CSV 格式输出覆盖率摘要 |
| `sui move coverage source --module <NAME>` | 显示模块的逐行覆盖率 |
| `sui move coverage lcov` | 生成 LCOV 报告 |
| `sui move coverage bytecode --module <NAME>` | 显示字节码覆盖率 |

## 小结

- 使用 `--coverage` 标志收集测试覆盖率数据
- `sui move coverage summary` 提供模块级和函数级的覆盖率概览
- `sui move coverage source` 显示逐行覆盖情况，帮助定位未测试的代码路径
- LCOV 格式支持与 CI/CD、HTML 报告、编辑器插件等外部工具集成
- 差异覆盖率分析可了解每个测试的独特贡献
