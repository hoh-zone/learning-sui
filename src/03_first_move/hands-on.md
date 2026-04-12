# 第三章 · 实战练习

## 实战一：本地编译 Hello World

1. 进入 `src/03_first_move/code/hello_world/`。
2. 执行 `sui move build`，再执行 `sui move test`（若有测试模块）。
3. **验收**：`build/` 生成且无编译错误。

## 实战二：发布到测试网

1. 使用第二章配置好的测试网账户，在本包目录执行 `sui client publish --gas-budget <预算>`（具体参数以当前 CLI 帮助为准）。
2. 记录输出的 **Package ID**。
3. **验收**：在 Explorer 中能根据 Package ID 查到已发布模块。

## 实战三：链上读一次对象

1. 用 `sui client object <OBJECT_ID>` 或 Explorer，查看你发布包产生的**任意链上对象**（例如 `UpgradeCap`、或模块创建的对象）。
2. 指出该对象的 `owner` 类型（地址所有 / 共享 / 不可变等）。
3. **验收**：截图或文字记录对象 ID + owner 类型。
