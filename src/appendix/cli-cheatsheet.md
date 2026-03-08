# CLI 速查表

本附录汇总 `sui` CLI 最常用的命令，方便日常开发快速查阅。

## 环境管理

```bash
# 查看当前环境
sui client envs

# 添加新环境
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client new-env --alias mainnet --rpc https://fullnode.mainnet.sui.io:443
sui client new-env --alias localnet --rpc http://127.0.0.1:9000

# 切换环境
sui client switch --env testnet

# 查看当前活跃地址
sui client active-address

# 切换活跃地址
sui client switch --address <ADDRESS>

# 获取 chain identifier
sui client chain-identifier
```

## 密钥管理

```bash
# 生成新密钥对
sui keytool generate ed25519
sui keytool generate secp256k1
sui keytool generate secp256r1

# 列出所有密钥
sui keytool list

# 导出私钥
sui keytool export --key-identity <ADDRESS>

# 格式转换
sui keytool convert <BECH32_PRIVATE_KEY>

# 从助记词导入
sui keytool import "<MNEMONIC>" ed25519
```

## 多签

```bash
# 创建多签地址
sui keytool multi-sig-address \
  --pks <PK1> <PK2> <PK3> \
  --weights 1 1 1 \
  --threshold 2

# 签名交易
sui keytool sign --address <ADDRESS> --data <TX_BYTES_BASE64>

# 组合多签
sui keytool multi-sig-combine-partial-sig \
  --pks <PK1> <PK2> <PK3> \
  --weights 1 1 1 \
  --threshold 2 \
  --sigs <SIG1> <SIG2>
```

## 账户与余额

```bash
# 获取测试代币
sui client faucet

# 查看 gas 余额
sui client gas

# 查看所有 gas coins
sui client gas --json
```

## Move 项目

```bash
# 创建新 Move 项目
sui move new my_package

# 构建
sui move build

# 运行测试
sui move test

# 带详细输出的测试
sui move test --verbose

# 运行特定测试
sui move test --filter test_name
```

## 发布与升级

```bash
# 发布包
sui client publish

# 发布（指定构建环境）
sui client publish --build-env testnet

# 升级包
sui client upgrade --upgrade-capability <UPGRADE_CAP_ID>

# 测试发布（localnet）
sui client test-publish

# 测试升级
sui client test-upgrade --upgrade-capability <UPGRADE_CAP_ID>
```

## 对象查询

```bash
# 列出拥有的对象
sui client objects

# 查看特定对象
sui client object <OBJECT_ID>

# 查看对象详情（JSON 格式）
sui client object <OBJECT_ID> --json

# 查看动态字段
sui client dynamic-field <PARENT_OBJECT_ID>
```

## 调用函数

```bash
# 调用 Move 函数
sui client call \
  --package <PACKAGE_ID> \
  --module <MODULE> \
  --function <FUNCTION> \
  --args <ARG1> <ARG2>

# 使用类型参数
sui client call \
  --package <PACKAGE_ID> \
  --module <MODULE> \
  --function <FUNCTION> \
  --type-args "0x2::sui::SUI" \
  --args <ARG1>

# 传递对象参数
sui client call \
  --package <PACKAGE_ID> \
  --module hero \
  --function new_hero \
  --args "Warrior" 100 <REGISTRY_ID>
```

## 转账

```bash
# 转移 SUI
sui client transfer-sui \
  --to <RECIPIENT> \
  --sui-coin-object-id <COIN_ID> \
  --amount 1000000000

# 转移对象
sui client transfer \
  --to <RECIPIENT> \
  --object-id <OBJECT_ID>

# 合并 coins
sui client merge-coin \
  --primary-coin <PRIMARY_COIN_ID> \
  --coin-to-merge <COIN_ID>

# 拆分 coin
sui client split-coin \
  --coin-id <COIN_ID> \
  --amounts 1000000000
```

## 交易查询

```bash
# 查看交易详情
sui client tx-block <DIGEST>

# 执行已签名的交易
sui client execute-signed-tx \
  --tx-bytes <TX_BYTES> \
  --signatures <SIGNATURE>
```

## 本地网络

```bash
# 启动本地网络
sui start

# 带水龙头启动
sui start --with-faucet

# 强制重新生成
sui start --with-faucet --force-regenesis

# 指定日志级别
RUST_LOG="off,sui_node=info" sui start --with-faucet
```

## 验证与调试

```bash
# 验证源码
sui move build --dump-bytecode-as-base64

# 查看包信息
sui client object <PACKAGE_ID>

# 干跑（Dry Run）交易
# 通过 SDK 的 client.core.simulateTransaction 方法实现
```

## 实用技巧

### 使用 JSON 输出解析

```bash
# 获取 Package ID（从发布输出）
sui client publish --json | jq '.objectChanges[] | select(.type=="published") | .packageId'

# 获取创建的对象
sui client publish --json | jq '.objectChanges[] | select(.type=="created")'
```

### 环境变量

```bash
# 设置默认 gas 预算
export SUI_GAS_BUDGET=100000000

# 设置 RPC URL
export SUI_RPC_URL=https://fullnode.testnet.sui.io:443
```

## 小结

| 类别 | 常用命令 |
|------|---------|
| 环境 | `sui client envs` / `switch --env` |
| 密钥 | `sui keytool generate` / `list` / `export` |
| 构建 | `sui move build` / `test` / `new` |
| 发布 | `sui client publish` / `upgrade` |
| 查询 | `sui client objects` / `object` |
| 调用 | `sui client call` |
| 网络 | `sui start --with-faucet` |
