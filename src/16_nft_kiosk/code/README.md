# 第十六章 · 示例代码（NFT / Kiosk）

## `simple_nft/`

最小 **`Hero`** 对象，演示 `key + store`、铸造与 `public_transfer`。

```bash
cd simple_nft
sui move build
sui move test
```

Kiosk、转移策略与市场示例依赖更多链上交互，建议在单独前端仓库或本书部署章节中扩展。
