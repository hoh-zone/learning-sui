# Nautilus TEE 可信计算

本节讲解 Nautilus——一个在 Sui 上实现安全、可验证的链下计算框架。Nautilus 利用可信执行环境（TEE）将复杂计算移到链下执行，同时通过链上合约验证计算结果的真实性。

## Nautilus 解决的问题

```
┌──────────────────────────────────────────────┐
│              计算模式对比                       │
├──────────────────────────────────────────────┤
│                                                │
│  链上计算：                                     │
│  ✓ 去信任、可验证                               │
│  ✗ 昂贵（gas 费用）                             │
│  ✗ 公开（无隐私）                               │
│  ✗ 计算能力有限                                 │
│                                                │
│  传统链下计算：                                  │
│  ✓ 便宜、快速                                   │
│  ✓ 可保护隐私                                   │
│  ✗ 需要信任运营者                               │
│  ✗ 无可验证性保证                               │
│                                                │
│  Nautilus（TEE）：                               │
│  ✓ 便宜、快速                                   │
│  ✓ 隐私保护（隔离内存）                          │
│  ✓ 密码学可验证                                 │
│  ✓ 去信任（验证而非信任）                        │
│                                                │
└──────────────────────────────────────────────┘
```

## 核心概念

### 可信执行环境（TEE）

TEE 是处理器内的安全区域，保证加载其中的代码和数据在机密性和完整性方面受到保护：

1. **执行隔离**：代码在受保护内存中运行，即使主机操作系统也无法访问
2. **身份证明**：可以生成密码学证明来证明正在运行的代码
3. **秘密保护**：私钥和敏感数据永远不会离开 enclave

### PCR（平台配置寄存器）

PCR 是 SHA-384 哈希值，唯一标识 enclave 的代码和配置：

| PCR | 测量内容 | 变化条件 |
|-----|---------|---------|
| **PCR0** | 操作系统和启动环境 | Enclave 镜像或内核变化 |
| **PCR1** | 应用程序代码 | 任何代码更改 |
| **PCR2** | 运行时配置 | `run.sh` 或流量规则变化 |

任何组件的单字节变化都会导致 PCR 改变，使链上合约能验证 enclave 运行的代码。

### 证明文档（Attestation Document）

AWS 签发的密码学证明，包含：
- enclave 运行在真实的 AWS Nitro 硬件上
- 运行代码的 PCR 值
- enclave 的公钥
- 时间戳

## 架构设计

### 完整数据流

```
用户                 Enclave (TEE)           Sui 区块链
 │                      │                      │
 │  1. 请求处理          │                      │
 │─────────────────────►│                      │
 │                      │ 2. TEE 内处理         │
 │                      │   - 获取外部数据       │
 │                      │   - 签名响应           │
 │  3. 签名的响应        │                      │
 │◄─────────────────────│                      │
 │                      │                      │
 │  4. 提交交易（附带 enclave、签名、数据）      │
 │─────────────────────────────────────────────►│
 │                      │                      │
 │                      │     5. 验证签名        │
 │                      │     6. 执行应用逻辑    │
 │  7. 交易结果          │                      │
 │◄─────────────────────────────────────────────│
```

### Enclave 端点

每个 Nautilus enclave 暴露三个 HTTP 端点：

| 端点 | 用途 |
|------|------|
| `GET /health_check` | 验证 enclave 可访问外部域名 |
| `GET /get_attestation` | 获取签名的证明文档（链上注册时使用） |
| `POST /process_data` | 执行自定义应用逻辑（开发者实现） |

## Move 合约示例

### 天气预言机

```move
module weather::weather;

use nautilus::enclave::Enclave;

const WEATHER_INTENT: u8 = 0;
const EInvalidSignature: u64 = 0;

/// 天气响应数据（必须与 Rust 端 BCS 序列化完全匹配）
public struct WeatherResponse has drop {
    location: String,
    temperature: u64,
}

/// 天气 NFT
public struct WeatherNFT has key, store {
    id: UID,
    location: String,
    temperature: u64,
    timestamp_ms: u64,
}

/// 验证 enclave 签名后铸造天气 NFT
public fun update_weather<T>(
    location: String,
    temperature: u64,
    timestamp_ms: u64,
    sig: &vector<u8>,
    enclave: &Enclave<T>,
    ctx: &mut TxContext,
): WeatherNFT {
    // 验证签名
    let res = enclave.verify_signature(
        WEATHER_INTENT,
        timestamp_ms,
        WeatherResponse { location, temperature },
        sig,
    );
    assert!(res, EInvalidSignature);

    // 签名有效，铸造 NFT
    WeatherNFT {
        id: object::new(ctx),
        location,
        temperature,
        timestamp_ms,
    }
}
```

### Enclave 配置

```move
module weather::config;

use nautilus::enclave;

/// OTW 名称须与模块名一致（ALL_CAPS）
public struct CONFIG() has drop;

fun init(otw: CONFIG, ctx: &mut TxContext) {
    // 创建 enclave 配置（初始 PCR 为占位值）
    enclave::new_cap<CONFIG>(otw, ctx);
    enclave::create_enclave_config<CONFIG>(
        x"000000...", // PCR0 占位
        x"000000...", // PCR1 占位
        x"000000...", // PCR2 占位
        ctx,
    );
}
```

## Rust Enclave 实现

### 应用逻辑（mod.rs）

```rust
use serde::{Deserialize, Serialize};
use nautilus_server::common::{
    AppState, IntentMessage, ProcessDataRequest,
    ProcessedDataResponse, EnclaveError, to_signed_response,
};

#[repr(u8)]
pub enum IntentScope {
    ProcessData = 0,
}

#[derive(Deserialize)]
pub struct WeatherRequest {
    pub location: String,
}

#[derive(Serialize)]
pub struct WeatherResponse {
    pub location: String,
    pub temperature: u64,
}

pub async fn process_data(
    State(state): State<Arc<AppState>>,
    Json(request): Json<ProcessDataRequest<WeatherRequest>>,
) -> Result<Json<ProcessedDataResponse<IntentMessage<WeatherResponse>>>, EnclaveError> {
    let location = &request.payload.location;

    // 1. 调用外部天气 API
    let weather = fetch_weather(location).await?;

    // 2. 验证时间戳新鲜度（拒绝超过 1 小时的请求）
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_millis() as u64;
    let timestamp = request.timestamp_ms;
    if now - timestamp > 3_600_000 {
        return Err(EnclaveError::InvalidTimestamp);
    }

    // 3. 使用 enclave 临时密钥签名响应
    Ok(Json(to_signed_response(
        &state.eph_kp,
        WeatherResponse {
            location: location.clone(),
            temperature: weather.temp,
        },
        timestamp,
        IntentScope::ProcessData as u8,
    )))
}
```

### 允许的外部端点

```yaml
# allowed_endpoints.yaml
- api.weatherapi.com
```

## 部署流程

```
1. 开发
   ├── 克隆 nautilus 模板
   ├── 实现自定义逻辑（mod.rs）
   ├── 配置允许的域名
   └── 本地调试测试

2. 构建
   ├── 构建可重现的 enclave 镜像
   ├── 记录 PCR0、PCR1、PCR2
   └── 公开源代码

3. 部署合约
   ├── 部署 enclave 配置合约
   ├── 在链上设置 PCR 值
   └── 部署应用合约

4. 部署 Enclave
   ├── 配置 AWS EC2 + Nitro Enclave
   ├── 部署 enclave 镜像
   └── 获取证明文档

5. 注册
   ├── 提交证明文档到合约
   ├── 合约验证 PCR 匹配
   └── 存储 enclave 公钥

6. 运行
   ├── 前端发送请求到 enclave
   ├── Enclave 处理并签名
   └── 签名响应在链上验证
```

## 安全考虑

### Nautilus 能防护的

- **运营者篡改**：PCR 验证代码
- **数据泄露**：TEE 隔离内存
- **响应伪造**：密码学签名
- **重放攻击**：时间戳验证

### Nautilus 不能防护的

- **侧信道攻击**：TEE 有已知的侧信道漏洞
- **应用代码 bug**：验证的代码仍然可能有逻辑错误
- **依赖链攻击**：构建过程中的供应链攻击
- **AWS 被攻破**：信任根是 AWS（国家级威胁）

## 小结

- Nautilus 通过 TEE 实现可验证的链下计算，兼顾性能和安全
- PCR 值唯一标识 enclave 运行的代码，任何更改都会导致 PCR 变化
- 每个响应都由 enclave 的临时密钥签名，链上合约验证真实性
- 适用场景：预言机、隐私计算、密封拍卖、可验证随机数
- 开发者只需实现 `mod.rs`（Rust 逻辑）和 `weather.move`（验证逻辑）
- 信任是密码学的——用户验证而非信任运营者
