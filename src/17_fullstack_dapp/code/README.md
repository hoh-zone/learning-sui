# 第十六章 · 示例代码（全栈 DApp）

本章目录含 **Move + 浏览器前端 + Node 脚本** 三套独立子工程（各自 `package.json` / `Move.toml`）。

| 目录 | 说明 |
|------|------|
| **`move_lab/`** | 发布时发给部署者的 `Counter`，含 `entry fun bump` |
| **`web_stub/`** | Vite + React，浏览器内用 `@mysten/sui/jsonRpc` 读测试网 chain id |
| **`scripts/`** | Node 下 `Transaction` PTB 模板；`call-bump-template.ts` 为对已发布 Counter 调 `bump` 的构建模板 |

```bash
cd move_lab && sui move build
cd ../web_stub && npm install && npm run check && npm run dev
cd ../scripts && npm install && npm run demo
# 实战：设置 CH16_PACKAGE_ID、CH16_COUNTER_ID、SUI_PT_DEMO_ADDRESS 后
# npm run bump-template
```

更复杂的全栈（CI、密钥、多环境）建议在独立仓库扩展；合约也可继续复用 `../../14_tokens/code/silver_coin/` 等包。
