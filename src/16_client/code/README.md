# 第十五章 · 示例代码（客户端与 PTB）

本章以 **TypeScript / `@mysten/sui`、钱包与 PTB** 为主，合约侧练习请使用前面各章 `code/` 中已可编译的包，在本地用 `sui client` 或自写脚本调用。

## `ptb-demo/`

最小 **`Transaction`** 示例（连接测试网 JSON-RPC，可选环境变量完成 `build({ client })`）：

```bash
cd ptb-demo
npm install
npm run check
npm run demo
# 可选：export SUI_PT_DEMO_ADDRESS=0x...   # 测试网上有余额的地址
npm run demo
# 实战配套脚本：
# npm run owned    # getOwnedObjects（需 SUI_PT_DEMO_ADDRESS）
# npm run dynamic  # getDynamicFields（需 SUI_DYNAMIC_PARENT_ID）
```

推荐工作流：

1. 在 **`../17_fullstack_dapp/code/`**（若已有全栈示例）或自建工程安装 `@mysten/sui`。
2. 将链上包发布到测试网后，用 PTB 调用 `silver_coin`、`simple_nft` 等模块的 `entry`（可自行在对应包内添加 `entry` 包装函数）。

本书不强制在仓库内提交 node_modules；以保持仓库轻量。
