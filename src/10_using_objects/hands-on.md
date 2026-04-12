# 第十章 · 实战练习

## 实战一：编译 using_lab

1. 进入 `src/10_using_objects/code/using_lab/`。
2. `sui move build` 与 `sui move test`。
3. **验收**：无错误；阅读 `sources/gift.move`（或当前模块）中 `key` / `store` 与 `transfer` 的用法。

## 实战二：画转移路径

1. 根据模块逻辑，用纸或 Mermaid **画出**「从铸造到转赠」的对象所有权变化（地址所有 → …）。
2. 标注使用的 API：`public_transfer` / `share_object` / `freeze_object` 等（以实际代码为准）。
3. **验收**：图与代码一致。

## 实战三：freeze 与不可变（概念题）

1. 任选一个本书中带 `public_freeze_object` 或文档中的 freeze 示例（若本包未 freeze，可查阅第十章动态字段章节）。
2. 说明：对象被 freeze 后，**哪些字段**仍可能通过包装或动态字段间接变更（若不可能则说明原因）。
3. **验收**：5 句以内结论。
