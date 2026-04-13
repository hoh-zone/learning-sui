# 第二十二章 · 实战练习

## 实战一：Clock 模块编译

1. 进入 `src/22_advanced_topics/code/advanced_lab/`。
2. `sui move build`。
3. **验收**：理解 `Clock` 为共享系统对象，函数需从前端/PTB 传入 `0x6` 引用。

## 实战二：ZKLogin / 多签 二选一调研

1. **A 路径**：阅读官方 ZKLogin 文档，写出 OAuth 提供商、地址派生、**user salt** 保管要点各一条。
2. **B 路径**：阅读多签文档，说明阈值 `k-of-n` 与链上 `MultiSig` 验证的关系。
3. **验收**：选一路径，10 行以内摘要 + 参考链接。

## 实战三：Walrus / DeepBook 体验（选做）

1. 任选一个：Walrus 上传小文件，或 DeepBook 下测试单（需环境与代币）。
2. 记录 CLI/SDK 命令与**失败原因**（若失败）。
3. **验收**：诚实记录环境限制即可得分。
