# 第十八章 · 实战练习

## 实战一：发布 upgrade_lab

1. 进入 `src/18_upgrade/code/upgrade_lab/`。
2. `sui move build` 后发布到测试网，保存 **Package ID** 与 **UpgradeCap** 对象 ID。
3. **验收**：Explorer 可见 UpgradeCap。

## 实战二：兼容升级

1. 修改 `sources/version.move` 中 `SCHEMA_VERSION`（或新增 `public fun`），保持存储布局兼容（仅加新函数或常量）。
2. 使用 `sui client upgrade`（参数以 CLI `--help` 为准）升级包。
3. **验收**：升级交易成功；旧对象仍可正常使用（若有）。

## 实战三：版本化共享对象（设计）

1. 阅读 17.3 节，为你自己的一个共享对象设计「版本号字段」迁移策略（仅文档）。
2. 列出升级时**不能**做的事（例如随意改已有 struct 字段顺序）。
3. **验收**：半页设计说明。
