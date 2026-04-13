# Prometheus 与 Grafana 监控

本节讲解如何使用 Prometheus 和 Grafana 监控 Sui dApp 的后端服务。我们以 NFT 铸造 API 为例，展示指标采集、仪表板搭建和告警配置的完整流程。

## 监控架构

```
┌─────────────────────────────────────────────────┐
│              监控架构                             │
├─────────────────────────────────────────────────┤
│                                                   │
│  用户 ──► REST API ──► Sui 区块链                  │
│               │                                   │
│               │ /metrics（暴露指标）                │
│               ▼                                   │
│          Prometheus（采集指标）                     │
│               │                                   │
│               ▼                                   │
│           Grafana（可视化 + 告警）                  │
│                                                   │
└─────────────────────────────────────────────────┘
```

## 场景：NFT 空投 API

假设我们有一个 NFT 空投服务：

- NFT 不预先铸造，按需铸造
- 用户不支付 gas 费
- 只有管理员地址可以铸造
- 需要支持并发请求

## 定义指标

### Node.js + prom-client

```typescript
// src/metrics.ts
import { Registry, Counter, Histogram, Gauge } from 'prom-client';

export const register = new Registry();

// 请求总数
export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// 铸造请求计数
export const mintRequestsTotal = new Counter({
  name: 'mint_requests_total',
  help: 'Total number of mint requests',
  labelNames: ['status'],
  registers: [register],
});

// 请求响应时间
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30],
  registers: [register],
});

// 队列中的待处理请求
export const pendingRequests = new Gauge({
  name: 'pending_mint_requests',
  help: 'Number of mint requests currently being processed',
  registers: [register],
});
```

### Express API 集成

```typescript
// src/index.ts
import express from 'express';
import { register, httpRequestsTotal, httpRequestDuration, mintRequestsTotal, pendingRequests } from './metrics';
import { mintHero } from './helpers/mintHero';

const app = express();
app.use(express.json());

// 指标端点
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// 健康检查
app.get('/', (req, res) => {
  res.send('Hello, world!');
});

// 铸造端点
app.post('/mint', async (req, res) => {
  const end = httpRequestDuration.startTimer({ method: 'POST', route: '/mint' });
  pendingRequests.inc();

  try {
    const { recipient } = req.body;
    const result = await mintHero(recipient);

    mintRequestsTotal.inc({ status: 'success' });
    httpRequestsTotal.inc({ method: 'POST', route: '/mint', status: '200' });
    res.json({ success: true, digest: result.digest });
  } catch (error) {
    mintRequestsTotal.inc({ status: 'error' });
    httpRequestsTotal.inc({ method: 'POST', route: '/mint', status: '500' });
    res.status(500).json({ success: false, error: String(error) });
  } finally {
    pendingRequests.dec();
    end();
  }
});

app.listen(8000, () => {
  console.log('API running on http://localhost:8000');
  console.log('Metrics at http://localhost:8000/metrics');
});
```

### 铸造辅助函数

```typescript
// src/helpers/mintHero.ts
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Transaction } from '@mysten/sui/transactions';
import { getAdminSigner } from './getAdminSigner';

const client = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});

export async function mintHero(recipient: string) {
  const signer = getAdminSigner();
  const tx = new Transaction();

  tx.moveCall({
    target: `${process.env.PACKAGE_ID}::hero::new_hero`,
    arguments: [
      tx.pure.string('Airdrop Hero'),
      tx.pure.u64(100),
      tx.object(process.env.REGISTRY_ID!),
    ],
  });

  tx.transferObjects(
    [tx.object(/* hero result */)],
    tx.pure.address(recipient),
  );

  return client.signAndExecuteTransaction({
    signer,
    transaction: tx,
    options: { showEffects: true },
  });
}
```

## Prometheus 配置

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'mint-api'
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s
```

## Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - '9090:9090'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    extra_hosts:
      - 'host.docker.internal:host-gateway'

  grafana:
    image: grafana/grafana:latest
    ports:
      - '3001:3000'
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    depends_on:
      - prometheus
```

## 启动监控栈

```bash
# 1. 启动 API
cd api
npm install
npm run dev

# 2. 启动 Prometheus + Grafana
docker-compose up -d

# 3. 验证
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3001 (admin/admin)
```

## Grafana 仪表板配置

### 添加数据源

1. 访问 Grafana → Connections → Data Sources
2. 选择 Prometheus
3. URL: `http://prometheus:9090`
4. 点击 Save & Test

### 常用面板查询

**请求速率（QPS）**：
```promql
rate(http_requests_total[5m])
```

**铸造成功率**：
```promql
rate(mint_requests_total{status="success"}[5m])
/ rate(mint_requests_total[5m])
```

**平均响应时间**：
```promql
rate(http_request_duration_seconds_sum[5m])
/ rate(http_request_duration_seconds_count[5m])
```

**P95 响应时间**：
```promql
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)
```

**错误率**：
```promql
rate(mint_requests_total{status="error"}[5m])
/ rate(mint_requests_total[5m])
```

**当前待处理请求**：
```promql
pending_mint_requests
```

## 告警配置

### Grafana 告警规则

在每个面板上可以配置告警规则：

| 告警 | 条件 | 持续时间 |
|------|------|---------|
| 高错误率 | 错误率 > 10% | 1 分钟 |
| 慢响应 | 平均响应时间 > 5s | 2 分钟 |
| 队列堆积 | 待处理请求 > 50 | 30 秒 |
| 服务宕机 | 无数据 | 1 分钟 |

### Prometheus 告警规则

```yaml
# alert-rules.yml
groups:
  - name: mint-api-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          rate(mint_requests_total{status="error"}[5m])
          / rate(mint_requests_total[5m]) > 0.1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: 'Mint API error rate is above 10%'

      - alert: SlowResponses
        expr: |
          histogram_quantile(0.95,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: 'P95 response time is above 5 seconds'
```

## 压力测试

```bash
#!/bin/bash
# mint.sh - 模拟 50 个并发请求
for i in $(seq 1 50); do
  curl -s -X POST http://localhost:8000/mint \
    -H "Content-Type: application/json" \
    -d "{\"recipient\": \"0x$(printf '%064x' $i)\"}" &
done
wait
echo "All requests completed"
```

## 小结

- 使用 `prom-client` 在 Node.js 应用中定义和暴露 Prometheus 指标
- 常用指标类型：Counter（计数）、Histogram（分布）、Gauge（当前值）
- Prometheus 定期抓取 `/metrics` 端点采集数据
- Grafana 提供强大的可视化和告警能力
- 关注关键指标：QPS、错误率、响应时间分布、队列深度
- 配置合理的告警阈值和持续时间，避免误报
- 使用 Docker Compose 快速搭建完整的监控栈
