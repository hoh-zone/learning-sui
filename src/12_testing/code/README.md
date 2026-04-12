# 第十二章 · 示例代码（测试）

## `testing_lab/`

本章**独立**示例包：纯函数 `#[test]` + `test_scenario` 共享对象场景。

```bash
cd testing_lab
sui move test
```

其他章节的测试示例仍可对照：

- **`../../08_object_model/code/object_lab/`** — `test_scenario` + 共享对象
- **`../../09_using_objects/code/using_lab/`** — 转账路径断言
- **`../../11_patterns/code/patterns_lab/`** — `init` 与对象领取

本章正文中的 Builder / 覆盖率等内容建议在独立仓库中按项目规模扩展。
