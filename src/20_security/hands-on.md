# 第二十章 · 实战练习

## 实战一：威胁建模（security_lab）

1. 阅读 `src/20_security/code/security_lab/sources/guarded.move`。
2. 写出至少 **2 条** 真实攻击面（例如：谁都能构造 `Vault` 吗？`read_balance` 是否应对 `sender` 校验？）。
3. **验收**：每条攻击面附带一句缓解思路。

## 实战二：对照清单改 silver_coin

1. 打开 `src/15_tokens/code/silver_coin/sources/silver.move`（或主模块）。
2. 使用本章「代码质量检查清单」或附录 F，勾选你能审查的项（可见性、溢出、`abort` 等）。
3. **验收**：列出 3 条「已通过」或「待改进」结论。

## 实战三：错误码策略

1. 在 `src/05_move_basics/code/18-assert-and-abort/` 中找一个 `assert!`。
2. 说明若改为 `#[error]` / Clever Errors，用户端能获得什么额外信息（查阅本章 18.3）。
3. **验收**：3～5 句笔记。
