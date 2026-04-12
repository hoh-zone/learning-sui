# 第二十章 · 实战练习

## 实战一：infra_demo

1. 进入 `src/20_infrastructure/code/infra_demo/`。
2. `npm install && npm run demo`，记录打印的 `chain id` 与 checkpoint sequence。
3. **验收**：能解释为何索引器常从 checkpoint / cursor 开始同步。

## 实战二：GraphQL 一次查询

1. 使用测试网 GraphQL 端点（见本章 19.4），用 `curl` 或 GraphQL Playground 查询**最近一个 checkpoint** 或**指定对象的 owner**。
2. 保存请求 JSON 与响应片段（脱敏）。
3. **验收**：至少一条查询成功返回数据。

## 实战三：观测指标扫盲

1. 阅读 19.5 节，列出 Prometheus 上你会关心的 **2 个** Sui 相关指标名（可查文档占位）。
2. 说明 Grafana 上图表告警的用途（一句话）。
3. **验收**：半页学习笔记即可。
