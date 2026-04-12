/**
 * 第十六章脚本层：与第十五章 `ptb-demo` 相同思路，演示 Transaction 组合（可改为 move_call 调 `ch16_move_lab::counter::bump`）。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';

export function buildSplitMergeTemplate(): Transaction {
  const tx = new Transaction();
  tx.setSender(
    '0x0000000000000000000000000000000000000000000000000000000000000001',
  );
  const [c] = tx.splitCoins(tx.gas, [1_000_000]);
  tx.mergeCoins(tx.gas, [c]);
  return tx;
}

async function main(): Promise<void> {
  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });
  console.log('chain:', await client.getChainIdentifier());
  const tx = buildSplitMergeTemplate();
  console.log('PTB 命令条数:', tx.getData().commands.length);
}

await main();
