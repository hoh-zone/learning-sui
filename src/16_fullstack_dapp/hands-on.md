# 第十六章 · 实战练习

## 实战一：三层目录各跑一遍

1. **Move**：`src/16_fullstack_dapp/code/move_lab/` → `sui move build`。
2. **脚本**：`src/16_fullstack_dapp/code/scripts/` → `npm install && npm run demo`。
3. **前端**：`src/16_fullstack_dapp/code/web_stub/` → `npm install && npm run check`，可选 `npm run dev` 在浏览器看 testnet chain id。
4. **验收**：三层均无报错。

## 实战二：链上 bump Counter

1. 将 `move_lab` 发布到测试网，记录 Counter 对象 ID。
2. 用 PTB 调用 `entry fun bump`（`sui client` 或 TS SDK）。
3. **验收**：对象 version 递增，字段 `n` 增加。

## 实战三：端到端草图

1. 画一张图：浏览器 → 钱包签名 → 全节点 → Move 模块 → 对象变更。
2. 标出你的 `Counter` 在哪一步被读写。
3. **验收**：一张图 + 10 行以内说明。
