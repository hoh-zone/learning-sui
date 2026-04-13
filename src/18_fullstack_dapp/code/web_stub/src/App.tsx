import { getJsonRpcFullnodeUrl, SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { useEffect, useState } from 'react';

export default function App() {
  const [chain, setChain] = useState<string>('');
  const [err, setErr] = useState<string>('');

  useEffect(() => {
    const client = new SuiJsonRpcClient({
      url: getJsonRpcFullnodeUrl('testnet'),
      network: 'testnet',
    });
    client
      .getChainIdentifier()
      .then(setChain)
      .catch((e: unknown) =>
        setErr(e instanceof Error ? e.message : String(e)),
      );
  }, []);

  return (
    <main style={{ fontFamily: 'system-ui', padding: '1.5rem' }}>
      <h1>第十六章 · 前端骨架</h1>
      <p>
        浏览器内使用 <code>@mysten/sui/jsonRpc</code> 读取测试网链标识；钱包与 dApp
        Kit 接入见第十五章与官方文档。
      </p>
      {err ? <p>错误: {err}</p> : null}
      {!err && <p>testnet chain id: {chain || '…'}</p>}
      <p>
        合约示例见同目录 <code>../move_lab/</code>，脚本见 <code>../scripts/</code>。
      </p>
    </main>
  );
}
