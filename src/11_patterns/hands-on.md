# 第十一章 · 实战练习

## 实战一：Capability 链上走一遍

1. 进入 `src/11_patterns/code/patterns_lab/`。
2. `sui move build` / `test`，确认 `AdminCap` 在 `init` 中发给部署者。
3. 发布到测试网后，用 PTB 调用需要 `&AdminCap` 的函数（若当前仅有 `is_admin`，可扩展一个 `entry` 仅做校验）。
4. **验收**：交易成功且逻辑与「持有 cap 才能过」一致。

## 实战二：Witness 最小草图

1. 在**新文件或注释**中，用伪代码写一个 `WITNESS` 结构体（`drop`），仅在模块内构造一次，用于授权 `Treasury` 创建。
2. 对照本章 Witness 一节，标出「哪些符号必须 `friend` / `public(package)`」。
3. **验收**：草图可被同伴 review，无明显泄露 witness 的洞。

## 实战三：Display 模板字符串

1. 打开 `simple_nft` 或本章正文 Display 示例，列出 NFT `name`、`description`、`image_url` 三条字段的模板来源。
2. 若使用本书 `src/14_nft_kiosk/code/simple_nft/`，尝试改一条模板字段并重新发布/升级（按你环境能力选做）。
3. **验收**：Explorer 或钱包里能看到更新后的元数据字段（若未上链则说明阻塞原因）。
