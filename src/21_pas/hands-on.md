# 第二十一章 · 实战练习

## 实战一：pas_lab 编译与阅读

1. 进入 `src/21_pas/code/pas_lab/`，`sui move build`。
2. 对照本章 `Namespace`、`Chest`、`Policy` 术语，说明 `policy_stub` 若扩展成真 PAS 缺哪些类型。
3. **验收**：列表形式写出至少 3 条差距。

## 实战二：与合规代币实战对照

1. 阅读（若仓库已有）`21_pas/06-practice-simple.md` / `07-practice-kyc.md` 的大纲。
2. 将 `silver_coin` 与 PAS 中的「策略检查」对比：各在**哪一层**做合规（链上模块 vs 链下）。
3. **验收**：一段对比文字。

## 实战三：Clawback 场景推演

1. 根据 21.5 节，设想「用户违规需收回资产」的一条链上路径。
2. 列出需要预先在 **Policy** 里埋好的权限或延时条件。
3. **验收**：步骤列表（无需实现代码）。
