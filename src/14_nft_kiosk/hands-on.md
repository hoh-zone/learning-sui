# 第十四章 · 实战练习

## 实战一：铸造并持有 NFT

1. 进入 `src/14_nft_kiosk/code/simple_nft/`。
2. `sui move build`，发布后用包内函数铸造至少 1 个 NFT 对象。
3. **验收**：Explorer 中对象类型为你的 NFT struct。

## 实战二：转移 NFT

1. 将其中一个 NFT `public_transfer` 到另一测试地址（或同一地址另一对象作为练习）。
2. 核对 owner 字段变化。
3. **验收**：交易 effects 显示 `Transferred`。

## 实战三：Kiosk 上架（选做）

1. 阅读本章 Kiosk 一节，列出上架所需的对象（`Kiosk`、`TransferPolicy` 等）。
2. 若时间与测试网允许，按官方示例或本书步骤创建 Kiosk 并将 NFT 上架；否则写出**阻塞你完成**的具体错误与环境。
3. **验收**：书面记录「完成路径」或「卡点」。
