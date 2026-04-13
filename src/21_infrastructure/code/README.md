# 第十九章 · 示例代码（基础设施）

链下观测常见形态之一：**JSON-RPC 客户端**连测试网并读取 checkpoint。

## `infra_demo/`

```bash
cd infra_demo
npm install
npm run check
npm run demo
```

索引器、gRPC 服务、监控告警等请在独立运维仓库按规模部署；Move 合约仍可用本书各章 `code/` 包作为被观测对象。

## 实战补充

- `graphql-example.sh`：示例 GraphQL POST（测试网）。
- `METRICS-NOTES.md`：Prometheus / Grafana 关注点备忘。
