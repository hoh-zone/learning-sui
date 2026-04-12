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

1. 在已发布本包的前提下，执行 `sui client ptb --move-call <PACKAGE_ID>::hello_world::mint_hello`（或按 §3.3 组合 PTB），在交易结果里找到 **Created Objects** 中的 `Hello`。
2. 用 `sui client object <HELLO_OBJECT_ID>` 查看 `greeting` 字段与 `owner`（应为你的活跃地址）。
3. **验收**：记录 `Hello` 的对象 ID，并确认 `owner` 为 **AddressOwner(你的地址)**。
