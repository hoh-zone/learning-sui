# Walrus 去中心化存储

本节介绍 Walrus——Sui 生态系统中的去中心化存储协议。Walrus 提供高可用、低成本的数据存储服务，特别适合存储大文件、媒体内容和 dApp 前端。

## 存储原理

### 纠删码技术

Walrus 使用 Red Stuff 纠删码将数据编码为碎片（slivers），分布在全球存储节点上：

```
┌──────────────────────────────────────────────┐
│           Walrus 存储原理                      │
├──────────────────────────────────────────────┤
│                                                │
│  原始文件 ──► 纠删码编码 ──► N 个碎片            │
│                                                │
│  只需要 N/3 个碎片即可重建原始文件               │
│  即使 2/3 的节点离线，数据仍可恢复              │
│                                                │
│  碎片分布在不同的存储节点上                      │
│  每个节点只存储一个碎片                          │
│                                                │
└──────────────────────────────────────────────┘
```

### 与 Sui 的关系

- **Walrus 存储大数据**：文件、图片、视频、前端代码
- **Sui 存储元数据**：Blob ID、所有权、存储凭证
- **Sui 管理经济模型**：存储费支付、节点质押

## 数据上传

### 使用 CLI

```bash
# 安装 Walrus CLI
# 参考 https://docs.walrus.site/usage/setup.html

# 上传文件
walrus store my-file.png

# 输出 Blob ID
# Blob ID: 0x1234...abcd

# 指定存储时长（以 epochs 为单位）
walrus store my-file.png --epochs 5
```

### 使用 HTTP API

```typescript
// 通过 Publisher API 上传
async function uploadToWalrus(data: Uint8Array): Promise<string> {
  const response = await fetch('https://publisher.walrus-testnet.walrus.space/v1/blobs', {
    method: 'PUT',
    body: data,
    headers: {
      'Content-Type': 'application/octet-stream',
    },
  });

  const result = await response.json();

  if (result.newlyCreated) {
    return result.newlyCreated.blobObject.blobId;
  } else if (result.alreadyCertified) {
    return result.alreadyCertified.blobId;
  }

  throw new Error('Upload failed');
}
```

### 使用 TypeScript SDK

```typescript
import { WalrusClient } from '@mysten/walrus';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const suiClient = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: 'https://fullnode.testnet.sui.io:443',
});

const walrusClient = new WalrusClient({
  network: 'testnet',
  suiClient,
});

// 上传数据
const { blobId } = await walrusClient.writeBlob({
  blob: new TextEncoder().encode('Hello, Walrus!'),
  deletable: true,
  epochs: 5,
  signer: keypair,
});

console.log('Blob ID:', blobId);
```

## 数据下载

### 使用 CLI

```bash
# 下载文件
walrus read <BLOB_ID> -o output.png
```

### 使用 HTTP API

```typescript
async function downloadFromWalrus(blobId: string): Promise<Uint8Array> {
  const response = await fetch(
    `https://aggregator.walrus-testnet.walrus.space/v1/blobs/${blobId}`
  );

  if (!response.ok) {
    throw new Error(`Download failed: ${response.status}`);
  }

  return new Uint8Array(await response.arrayBuffer());
}
```

### 在浏览器中显示

```typescript
// 直接在 img 标签中使用 Walrus URL
function WalrusImage({ blobId }: { blobId: string }) {
  const url = `https://aggregator.walrus-testnet.walrus.space/v1/blobs/${blobId}`;
  return <img src={url} alt="Walrus stored image" />;
}
```

## 与 Move 合约集成

### 在 NFT 中引用 Walrus 数据

```move
module my_nft::nft;

use std::string::String;

public struct MediaNFT has key, store {
    id: UID,
    name: String,
    description: String,
    blob_id: String,     // Walrus Blob ID
    media_type: String,  // "image/png", "video/mp4" 等
}

public fun mint(
    name: String,
    description: String,
    blob_id: String,
    media_type: String,
    ctx: &mut TxContext,
): MediaNFT {
    MediaNFT {
        id: object::new(ctx),
        name,
        description,
        blob_id,
        media_type,
    }
}
```

### 前端展示

```typescript
function NFTCard({ nft }: { nft: { name: string; blob_id: string; media_type: string } }) {
  const mediaUrl = `https://aggregator.walrus-testnet.walrus.space/v1/blobs/${nft.blob_id}`;

  return (
    <div className="nft-card">
      <h3>{nft.name}</h3>
      {nft.media_type.startsWith('image/') ? (
        <img src={mediaUrl} alt={nft.name} />
      ) : (
        <video src={mediaUrl} controls />
      )}
    </div>
  );
}
```

## Walrus Sites：去中心化前端托管

Walrus Sites 允许将 Web 应用的前端代码托管在 Walrus 上：

```bash
# 构建前端
cd my-dapp
pnpm run build

# 发布到 Walrus Sites
walrus sites publish ./dist

# 输出访问 URL
# Site published at: https://<site-id>.walrus.site
```

### 更新站点

```bash
# 更新已发布的站点
walrus sites update ./dist --site <SITE_OBJECT_ID>
```

## 结合 Seal 使用加密存储

```typescript
// 1. 加密文件
const { encryptedObject, key } = await sealClient.encrypt({
  threshold: 2,
  packageId: fromHEX(policyPackageId),
  id: fromHEX(accessPolicyId),
  data: fileContent,
});

// 2. 将加密文件存储到 Walrus
const blobId = await uploadToWalrus(encryptedObject);

// 3. 在链上记录 Blob ID
const tx = new Transaction();
tx.moveCall({
  target: `${PACKAGE_ID}::encrypted_storage::register`,
  arguments: [
    tx.pure.string(blobId),
    tx.pure.string(accessPolicyId),
  ],
});

// 4. 授权用户可以通过 Seal 策略解密
// seal_approve* 函数控制谁能解密
```

## 存储成本

| 方面 | 说明 |
|------|------|
| 计费单位 | 按存储大小和时长（epochs） |
| 支付代币 | WAL（Walrus 代币）或 SUI |
| 最小存储期 | 1 epoch |
| 数据冗余 | 自动，由纠删码保证 |

## 小结

- Walrus 使用纠删码提供高可用、低成本的去中心化存储
- 支持 CLI、HTTP API 和 TypeScript SDK 多种使用方式
- 特别适合存储 NFT 媒体文件、dApp 前端和用户数据
- Walrus Sites 实现完全去中心化的 Web 应用托管
- 结合 Seal 可以实现加密存储和访问控制
- 与 Sui 紧密集成：Sui 管理元数据和经济模型，Walrus 存储数据
