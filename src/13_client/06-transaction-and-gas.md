# 交易提交与 Gas 管理

在 Sui 上执行交易涉及构建交易、签名、提交和处理结果。Gas 管理是其中的关键环节——理解 Gas Budget、Gas Price 和 Balance Changes 有助于构建可靠的应用。本节将详细介绍交易提交的完整流程和 Gas 管理策略。

## 交易提交流程

```
构建交易 → 签名 → 提交 → 等待确认 → 处理结果
   │          │        │         │           │
Transaction  Keypair  Client  waitFor    Effects
```

## 构建和签名交易

### 基本流程

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

const client = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
});
const keypair = Ed25519Keypair.fromSecretKey(secretKey);

// 构建交易
const tx = new Transaction();
const [coin] = tx.splitCoins(tx.gas, [1_000_000_000]);
tx.transferObjects([coin], "0xRECIPIENT");

// 签名并执行
const result = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

if (result.$kind === "FailedTransaction") {
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}
await client.waitForTransaction({ digest: result.Transaction.digest });
```

### 分步执行

如果需要更细粒度的控制：

```typescript
// 步骤 1: 构建交易字节
tx.setSender(keypair.toSuiAddress());
const bytes = await tx.build({ client });

// 步骤 2: 签名
const signature = await keypair.signTransaction(bytes);

// 步骤 3: 提交（低层 API；一般直接使用 signAndExecuteTransaction 即可）
const result = await client.core.executeTransaction({
  transaction: bytes,
  signatures: [signature.signature],
  include: { effects: true },
});

if (result.$kind === "FailedTransaction") {
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}
await client.waitForTransaction({ digest: result.Transaction.digest });
```

## Gas 管理

### Gas Budget

Gas Budget 是你愿意为这笔交易支付的最大 Gas 量。设置过低会导致交易失败，设置过高不会多扣费（只收实际消耗）。

```typescript
const tx = new Transaction();
// 手动设置 Gas Budget（单位：MIST，1 SUI = 10^9 MIST）
tx.setGasBudget(10_000_000); // 0.01 SUI

// 通常不需要手动设置——SDK 会自动估算
```

### Gas Price

Gas Price 由网络的参考 Gas Price 决定。你可以查询当前参考价格：

```typescript
// v2：参考 Gas 价格可通过 getReferenceGasPrice 或链上查询获取，具体以 SDK 文档为准
const gasPrice = await client.getReferenceGasPrice?.();
console.log(`Reference Gas Price: ${gasPrice ?? "N/A"}`);
```

### Gas Coin

默认使用发送者的 SUI 代币作为 Gas Coin。你也可以指定特定的代币对象：

```typescript
const tx = new Transaction();
tx.setGasPayment([
  { objectId: "0xCOIN_ID", version: "123", digest: "..." },
]);
```

### 赞助交易（Sponsored Transactions）

让第三方为交易支付 Gas：

```typescript
// 赞助者构建和签名 Gas 部分
const tx = new Transaction();
tx.setSender(userAddress);
tx.setGasOwner(sponsorAddress);

// 用户签名交易内容
const userSignature = await userKeypair.signTransaction(
  await tx.build({ client })
);

// 赞助者签名 Gas 部分
const sponsorSignature = await sponsorKeypair.signTransaction(
  await tx.build({ client })
);

// 提交（包含两个签名）
await client.core.executeTransaction({
  transaction: await tx.build({ client }),
  signatures: [userSignature.signature, sponsorSignature.signature],
});
```

## 处理交易结果

### 检查执行状态

执行后根据 `result.$kind` 判断成功（`Transaction`）或失败（`FailedTransaction`）：

```typescript
const result = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

if (result.$kind === "FailedTransaction") {
  console.error("Transaction failed:", result.FailedTransaction.status.error?.message);
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}

console.log("Transaction succeeded!", result.Transaction.digest);
await client.waitForTransaction({ digest: result.Transaction.digest });
```

### Balance Changes

成功后可从 `waitForTransaction` 返回或单独查询交易效果获取 balance changes；如需在内存中直接使用，可解析返回的 effects。

### 解析余额变化

```typescript
import { SUI_TYPE_ARG } from "@mysten/sui/utils";

function parseBalanceChanges(
  balanceChanges: any[],
  address: string,
  coinType: string = SUI_TYPE_ARG,
) {
  return balanceChanges
    .filter(
      (change) =>
        (change.owner as any)?.AddressOwner === address &&
        change.coinType === coinType
    )
    .map((change) => ({
      amount: BigInt(change.amount),
      coinType: change.coinType,
    }));
}
```

### Object Changes

交易成功后，可调用 `client.core.getTransaction({ digest, include: { balanceChanges: true, objectTypes: true } })` 获取 object changes；或在应用层根据事件/返回结果推断新创建的对象。

## 等待交易确认

```typescript
const result = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

if (result.$kind === "FailedTransaction") {
  throw new Error(result.FailedTransaction.status.error?.message ?? "Transaction failed");
}

await client.waitForTransaction({ digest: result.Transaction.digest });
```

## Dry Run（模拟执行）

在提交前模拟执行交易，预览结果和 Gas 消耗：

```typescript
const tx = new Transaction();
// ... 构建交易

tx.setSender(keypair.toSuiAddress());
const dryRunResult = await client.core.simulateTransaction({
  transaction: await tx.build({ client }),
});

console.log("Dry run status:", dryRunResult.effects?.status);
console.log("Gas used:", dryRunResult.effects?.gasUsed);
console.log("Balance changes:", dryRunResult.balanceChanges);
```

## 完整示例：转账 SUI

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SUI_TYPE_ARG } from "@mysten/sui/utils";

async function transferSUI(
  client: SuiGrpcClient,
  signer: Ed25519Keypair,
  recipient: string,
  amountInSUI: number,
) {
  const amountInMIST = BigInt(amountInSUI * 1_000_000_000);

  const tx = new Transaction();
  const [coin] = tx.splitCoins(tx.gas, [amountInMIST]);
  tx.transferObjects([coin], recipient);

  const result = await client.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });

  if (result.$kind === "FailedTransaction") {
    throw new Error(result.FailedTransaction.status.error?.message ?? "Transfer failed");
  }

  await client.waitForTransaction({ digest: result.Transaction.digest });

  return {
    digest: result.Transaction.digest,
    amount: amountInMIST,
  };
}
```

## 小结

- 交易流程：构建 → 签名 → 提交 → 等待确认 → 处理结果
- Gas Budget 是最大花费限制，SDK 通常可自动估算
- `include` 参数控制返回哪些信息（effects、balanceChanges、objectTypes、events）
- Dry Run 可在提交前模拟执行，预览结果和 Gas 消耗
- 赞助交易允许第三方支付 Gas，改善用户体验
- 始终根据 `result.$kind` 判断成功/失败，成功后调用 `waitForTransaction` 再处理业务
