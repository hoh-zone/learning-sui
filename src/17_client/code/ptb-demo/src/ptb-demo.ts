/**
 * 第十五章最小示例：`Transaction` 组合多条命令；完整序列化需 `build({ client })` 与链上 gas。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';

const PLACEHOLDER_SENDER =
  '0x0000000000000000000000000000000000000000000000000000000000000001';

/** 从 gas coin 拆出 0.001 SUI 再并回 —— 演示 PTB 内命令链。 */
export function buildSplitMergeTemplate(): Transaction {
  const tx = new Transaction();
  tx.setSender(PLACEHOLDER_SENDER);
  const [chunk] = tx.splitCoins(tx.gas, [1_000_000]);
  tx.mergeCoins(tx.gas, [chunk]);
  return tx;
}

async function main(): Promise<void> {
  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });

  const chain = await client.getChainIdentifier();
  console.log('已连接 testnet，chain identifier:', chain);

  const owner = process.env.SUI_PT_DEMO_ADDRESS?.trim();
  if (!owner) {
    const tx = buildSplitMergeTemplate();
    const n = tx.getData().commands.length;
    console.log(
      '未设置 SUI_PT_DEMO_ADDRESS：当前仅构造 PTB（命令条数:',
      n,
      '）。设置该环境变量为测试网有余额的地址后可执行完整 build({ client })。',
    );
    return;
  }

  const tx = new Transaction();
  tx.setSender(owner);
  const { data } = await client.getCoins({
    owner,
    coinType: '0x2::sui::SUI',
    limit: 1,
  });

  if (data.length === 0) {
    console.log('该地址在测试网上没有 SUI coin，无法解析 gas。');
    return;
  }

  const c = data[0];
  tx.setGasPayment([
    { objectId: c.coinObjectId, version: c.version, digest: c.digest },
  ]);
  tx.setGasBudget(10_000_000);
  const [chunk] = tx.splitCoins(tx.gas, [1_000_000]);
  tx.mergeCoins(tx.gas, [chunk]);

  const bytes = await tx.build({ client });
  console.log('build({ client }) 成功，序列化字节长度:', bytes.length);
}

await main();
