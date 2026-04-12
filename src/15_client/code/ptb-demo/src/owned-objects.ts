/**
 * 第十五章实战：分页读取当前地址下的对象（需 SUI_PT_DEMO_ADDRESS）。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';

async function main(): Promise<void> {
  const owner = process.env.SUI_PT_DEMO_ADDRESS?.trim();
  if (!owner) {
    console.log('请设置环境变量 SUI_PT_DEMO_ADDRESS');
    process.exit(1);
  }
  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });
  const page = await client.getOwnedObjects({
    owner,
    limit: 5,
    options: { showType: true },
  });
  const first = page.data[0];
  if (!first) {
    console.log('该地址下暂无对象。');
    return;
  }
  console.log('objectId:', first.data?.objectId);
  console.log('type:', first.data?.type);
}

await main();
