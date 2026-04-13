/**
 * 第十五章实战：读取某对象的动态字段列表（需 SUI_DYNAMIC_PARENT_ID）。
 */
import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';

async function main(): Promise<void> {
  const parent = process.env.SUI_DYNAMIC_PARENT_ID?.trim();
  if (!parent) {
    console.log('请设置 SUI_DYNAMIC_PARENT_ID 为带动态字段的父对象 ID');
    process.exit(0);
  }
  const client = new SuiJsonRpcClient({
    url: getJsonRpcFullnodeUrl('testnet'),
    network: 'testnet',
  });
  const fields = await client.getDynamicFields({ parentId: parent, limit: 5 });
  console.log('dynamic field count (first page):', fields.data.length);
  if (fields.data[0]) {
    console.log('first name:', JSON.stringify(fields.data[0].name));
  }
}

await main();
