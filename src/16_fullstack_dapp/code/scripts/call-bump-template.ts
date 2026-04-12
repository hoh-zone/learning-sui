/**
 * 第十六章实战模板：对已发布的 Counter 调用 `bump`（需自行填 package / object / gas）。
 * 用法见同目录 README 或本章 hands-on.md。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';

async function main(): Promise<void> {
  const pkg = process.env.CH16_PACKAGE_ID?.trim();
  const counter = process.env.CH16_COUNTER_ID?.trim();
  const sender = process.env.SUI_PT_DEMO_ADDRESS?.trim();
  if (!pkg || !counter || !sender) {
    console.log(
      '请设置 CH16_PACKAGE_ID、CH16_COUNTER_ID、SUI_PT_DEMO_ADDRESS（测试网）',
    );
    process.exit(0);
  }

  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });

  const tx = new Transaction();
  tx.setSender(sender);
  const { data: coins } = await client.getCoins({
    owner: sender,
    coinType: '0x2::sui::SUI',
    limit: 1,
  });
  if (!coins[0]) {
    console.log('无 SUI gas');
    return;
  }
  const g = coins[0];
  tx.setGasPayment([
    { objectId: g.coinObjectId, version: g.version, digest: g.digest },
  ]);
  tx.setGasBudget(10_000_000);
  tx.moveCall({
    target: `${pkg}::counter::bump`,
    arguments: [tx.object(counter)],
  });

  const bytes = await tx.build({ client });
  console.log('PTB 已构建（未签名），字节长度:', bytes.length);
  console.log('下一步：用钱包或 keypair signAndExecuteTransaction');
}

await main();
