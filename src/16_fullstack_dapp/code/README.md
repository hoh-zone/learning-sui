# 第十六章 · 示例代码（全栈 DApp）

本章目录含 **Move + 浏览器前端 + Node 脚本** 三套独立子工程（各自 `package.json` / `Move.toml`）。

| 目录 | 说明 |
|------|------|
| **`move_lab/`** | 发布时发给部署者的 `Counter`，含 `entry fun bump` |
| **`web_stub/`** | Vite + React，浏览器内用 `@mysten/sui/jsonRpc` 读测试网 chain id |
| **`scripts/`** | Node 下 `Transaction` PTB 模板（与第十五章思路一致） |

```bash
cd move_lab && sui move build
cd ../web_stub && npm install && npm run check && npm run dev
cd ../scripts && npm install && npm run demo
```

更复杂的全栈（CI、密钥、多环境）建议在独立仓库扩展；合约也可继续复用 `../../13_tokens/code/silver_coin/` 等包。
