# 第十章实战 · Clock + 业务 `moveCall`（PTB 伪代码）

以下为 **TypeScript `Transaction`** 思路，不必上链即可在代码里理清顺序：

```typescript
import { Transaction } from '@mysten/sui/transactions';

const CLOCK = '0x0000000000000000000000000000000000000000000000000000000000000006';

function buildTx(packageId: string, moduleName: string, fn: string) {
  const tx = new Transaction();
  const clock = tx.object(CLOCK);
  tx.moveCall({
    target: `${packageId}::${moduleName}::${fn}`,
    arguments: [clock],
  });
  return tx;
}
```

要点：**Clock** 作为共享对象先绑定为输入，再作为 `&Clock` 传入 Move（具体 `moveCall` 参数顺序以目标函数签名为准）。
