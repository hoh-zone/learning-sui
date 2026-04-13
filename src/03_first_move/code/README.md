# 第三章 · 示例代码

与正文 **3.1 Hello World** 对应：模块内定义 **`Hello` 对象**，**`entry fun mint_hello`** 将其转移给交易发送者。

## `hello_world/`

```bash
cd hello_world
sui move build
sui move test
```

- **Move 2024**：`edition = "2024"`，Framework 为隐式依赖（Sui 1.45+）。
- 发布后可调用 `mint_hello` 在链上创建属于自己的 `Hello` 对象；**3.2 / 3.3** 仍使用正文中的 TodoList 示例深入部署与 PTB。
