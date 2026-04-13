# 第十五章 · 示例代码（代币）

## `silver_coin/`

与 **[§15.2 · 注册与 OTW](../02-registry-otw.md)** 一致的 **`coin_registry::new_currency_with_otw` + `finalize`** 流程（需 OTW 结构体 `SILVER`）。

```bash
cd silver_coin
sui move build
```

发布与铸造请在测试网按正文步骤使用 `sui client`；单元测试涉及 `init` 与 OTW，可在扩展练习中补充 `test_scenario` 发布包。
