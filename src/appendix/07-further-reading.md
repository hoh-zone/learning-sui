# 附录 G · 延伸阅读

本附录列出与 Move / Sui 相关的**官方文档、书籍与论文**，便于在读完本书正文后继续深入；仅作入口，不替代正文。

## 官方文档与规范

| 资源 | 说明 |
|------|------|
| [Sui Documentation](https://docs.sui.io/) | 概念、RPC、CLI、Move 模型与最新版本说明 |
| [The Move Book](https://move-book.com/) | Mysten 维护的 Move + Sui 英文教程，含 [Move Reference](https://move-book.com/reference) |
| [Sui Framework 源码](https://github.com/MystenLabs/sui/tree/main/crates/sui-framework/packages) | 链上 API 的最终参照 |

阅读顺序建议：**本书章节 → 官方文档对应主题 → Framework 源码签名**。

## 论文与形式化工作（选读）

下列工作与 Move 资源安全、借用检查或 Sui 执行模型相关，适合希望了解理论背景的读者。

| 题目 | 说明 |
|------|------|
| [The Move Borrow Checker](https://arxiv.org/abs/2205.05181) | Move 借用检查与类型系统 |
| [Resources: A Safe Language Abstraction for Money](https://arxiv.org/abs/2004.05106) | Diem 时代资源模型 |
| [Robust Safety for Move](https://arxiv.org/abs/2110.05043) | Move 字节码安全 |

## 本书与上述资源的关系

本书面向**中文读者**与 **Sui 全栈路径**（含客户端、工程化与生态专题），与英文 Move Book / Reference **互补**：细节以官方文档与当前主网行为为准；若正文与官方文档冲突，**以官方文档与编译器/验证器结果为准**。
