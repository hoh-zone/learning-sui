/**
 * 第十九章：链下客户端连测试网 JSON-RPC，读取最新 checkpoint（索引器/观测常见入口形态之一）。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';

async function main(): Promise<void> {
  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });
  const seq = await client.getLatestCheckpointSequenceNumber();
  const chain = await client.getChainIdentifier();
  console.log('testnet chain id:', chain);
  console.log('latest checkpoint sequence:', seq);
}

await main();
