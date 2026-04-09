# 钱包与测试币

在 Sui 上部署和调用智能合约需要消耗 SUI 代币作为 Gas 费用。在开发阶段，我们可以通过 Sui CLI 创建钱包并从水龙头（Faucet）获取免费测试币。本节将介绍钱包的创建、网络环境切换以及测试币的获取方法。

## 创建钱包

### 首次初始化

第一次运行 `sui client` 时，CLI 会引导你完成钱包初始化：

```bash
sui client
```

系统会依次提示你配置以下内容：

```
Config file ["/Users/<username>/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```

输入 `y` 后选择连接的网络：

```
Sui Full node server URL (Defaults to Sui Devnet if not specified) :
```

可选的网络地址：

| 网络 | RPC 地址 |
|------|----------|
| 本地网络 | `http://127.0.0.1:9000` |
| Devnet | `https://fullnode.devnet.sui.io:443` |
| Testnet | `https://fullnode.testnet.sui.io:443` |
| Mainnet | `https://fullnode.mainnet.sui.io:443` |

接下来选择密钥方案：

```
Select key scheme to generate keypair (0 for ed25519, 1 for secp256k1, 2 for secp256r1):
```

三种密钥方案的区别：

- **ed25519**（推荐）：最常用的方案，性能好，安全性高
- **secp256k1**：与比特币和以太坊使用相同的曲线，适合跨链场景
- **secp256r1**：也称为 P-256，广泛用于 Web 标准和硬件安全模块

> **建议**：如果没有特殊需求，选择 `0`（ed25519）即可。

初始化完成后，系统会生成一个新的密钥对并显示你的地址：

```
Generated new keypair and alias for address with scheme "ed25519" [trusting-sapphire: 0x...]
```

### 导入已有密钥

如果你已有私钥或助记词，可以导入：

```bash
# 通过助记词导入
sui keytool import "<your-mnemonic-phrase>" ed25519

# 通过私钥导入
sui keytool import <private-key-base64> ed25519
```

## 地址管理

### 查看当前活跃地址

```bash
sui client active-address
```

输出示例：

```
0x7d20dcdb2bca4f508ea9613994683eb4e76e9c4ed371169571c0156a9e38437e
```

### 查看所有地址

```bash
sui client addresses
```

### 生成新地址

```bash
sui keytool generate ed25519
```

### 切换活跃地址

```bash
sui client switch --address <地址或别名>
```

## 网络环境管理

### 查看当前环境

```bash
sui client envs
```

输出示例：

```
╭──────────┬─────────────────────────────────────────┬────────╮
│ alias    │ url                                     │ active │
├──────────┼─────────────────────────────────────────┼────────┤
│ devnet   │ https://fullnode.devnet.sui.io:443      │ *      │
│ testnet  │ https://fullnode.testnet.sui.io:443     │        │
╰──────────┴─────────────────────────────────────────┴────────╯
```

### 添加新环境

```bash
# 添加 devnet
sui client new-env --alias devnet --rpc https://fullnode.devnet.sui.io:443

# 添加 testnet
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443

# 添加 mainnet
sui client new-env --alias mainnet --rpc https://fullnode.mainnet.sui.io:443

# 添加本地网络
sui client new-env --alias local --rpc http://127.0.0.1:9000
```

### 切换网络

```bash
sui client switch --env devnet
```

> **注意**：切换网络后，你的地址不变，但链上状态（余额、对象等）是网络独立的。也就是说，你在 devnet 上的余额和 testnet 上的余额是完全独立的。

## 获取测试币

### 通过 CLI 获取

在 devnet 或 testnet 上，你可以通过内置的水龙头命令获取免费测试币：

```bash
# 确保已切换到 devnet 或 testnet
sui client switch --env devnet

# 请求测试币
sui client faucet
```

成功后会看到类似输出：

```
Request successful. It can take up to 1 minute to get the coin.
```

> **提示**：水龙头有请求频率限制，如果收到速率限制错误，请等待一段时间后重试。

### 通过 Web 水龙头获取

你也可以通过浏览器访问水龙头页面：

- Devnet：[https://faucet.devnet.sui.io/](https://faucet.devnet.sui.io/)
- Testnet：[https://faucet.testnet.sui.io/](https://faucet.testnet.sui.io/)

输入你的地址即可获取测试币。

### 通过 cURL 获取

```bash
curl --location --request POST 'https://faucet.devnet.sui.io/v2/gas' \
--header 'Content-Type: application/json' \
--data-raw "{
    \"FixedAmountRequest\": {
        \"recipient\": \"$(sui client active-address)\"
    }
}"
```

## 查看余额和对象

### 查看余额

```bash
sui client balance
```

输出示例：

```
╭─────────────────────────────────────────╮
│ Balance of coins owned by this address  │
├─────────────────────────────────────────┤
│ ╭─────────────────┬────────────────╮    │
│ │ coin            │ balance (MIST) │    │
│ ├─────────────────┼────────────────┤    │
│ │ 0x2::sui::SUI   │ 1000000000     │    │
│ ╰─────────────────┴────────────────╯    │
╰─────────────────────────────────────────╯
```

> **换算关系**：1 SUI = 10^9 MIST。上面的 1000000000 MIST 就是 1 SUI。

### 查看拥有的对象

```bash
sui client objects
```

输出会列出你地址下所有的对象，包括 SUI 代币（Coin 对象）和其他资产。

### 查看特定对象详情

```bash
sui client object <object-id>

# 以 JSON 格式查看
sui client object <object-id> --json
```

## 安全提醒

- **永远不要**在公开场合分享你的私钥或助记词
- 密钥文件默认存储在 `~/.sui/sui_config/sui.keystore`
- 开发时使用 devnet/testnet，**不要**用主网私钥进行测试
- 建议为开发和生产使用不同的密钥对

## 小结

本节介绍了如何通过 Sui CLI 创建钱包、管理地址、切换网络环境以及获取测试币。核心命令包括：`sui client`（初始化）、`sui client active-address`（查看地址）、`sui client switch --env`（切换网络）、`sui client faucet`（获取测试币）和 `sui client balance`（查看余额）。这些是后续开发和部署合约的基础操作。下一节我们将了解 Move 2024 版本的新特性。
