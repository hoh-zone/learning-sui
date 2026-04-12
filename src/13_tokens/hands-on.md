# 第十三章 · 实战练习

## 实战一：自定义币发布与铸造

1. 进入 `src/13_tokens/code/silver_coin/`（或你按本章正文改名的包）。
2. `sui move build`，再发布到测试网。
3. 使用 `TreasuryCap` 调 `mint`（或包内提供的 entry），给自己铸少量代币。
4. **验收**：钱包或 `sui client` 能看到该 `CoinType` 余额。

## 实战二：元数据对象

1. 若包内包含 `CoinMetadata` 创建流程，在 Explorer 找到 metadata 对象 ID。
2. 记录 `symbol`、`decimals` 字段来源。
3. **验收**：能解释 metadata 与 treasury 的关系。

## 实战三：PTB 转账给另一地址

1. 使用第十五章思路，构造 PTB：`splitCoins` + `transferObjects` 或 `coin::transfer`。
2. 向**第二个测试地址**转少量自定义币。
3. **验收**：对方地址余额增加（Explorer 核对）。
