# 第十二章实战 · `#[test_only]` 与包可见性（备忘）

- 测试模块（如 `ch12_testing_lab::demo_tests`）与 `sources/` 下模块同属一包，可调用目标模块的 **`public` / `public(package)`**（同包）函数。
- 访问 **`friend` 模块**或**他包** `public(package)` API 时，需按语言规则使用 `#[test_only]` 辅助函数或将测试放在有权限的包内（参见本章「扩展外部模块」正文）。
