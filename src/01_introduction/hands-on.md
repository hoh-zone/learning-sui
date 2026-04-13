# 第一章 · 实战练习

## 实战一：确认本机工具链

1. 安装或更新 [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install)（若使用 `suiup`，按[第二章 §2.1](../02_getting_started/01-install-sui.md)切换版本）。
2. 执行 `sui --version`，记下主版本号，与[官方发布说明](https://github.com/MystenLabs/sui/releases)对照。
3. **验收**：终端能输出 `sui` 版本，无报错。

## 实战二：在浏览器里读一笔真实交易

1. 打开 [Sui Explorer](https://suiexplorer.com/)（或测试网 Explorer），任选**最近**一笔成功交易。
2. 在页面上找到：发送者、Gas、至少一个 **Input**、**Effects** 中的变更摘要。
3. **验收**：用自己的话写 3～5 句话，说明「这笔交易在链上改变了什么状态」。

## 实战三：对象模型 vs 账户模型（小短文）

1. 回顾本章 1.2 中关于 Sui **以对象为中心**的表述。
2. 对比你熟悉的「全局账户 nonce」模型，列出 **2 条** Sui 设计带来的直接后果（例如并行性、费用支付对象等）。
3. **验收**：写成一段不超过 200 字的笔记即可。
