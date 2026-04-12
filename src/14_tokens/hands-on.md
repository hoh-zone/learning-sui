# 第十四章 · 实战练习

## 实战一：自定义币发布与铸造

1. 进入 `src/14_tokens/code/silver_coin/`。
2. 执行 `sui move build`，再发布到测试网。
3. 使用 `TreasuryCap` 调 `mint`（或包内 `mint_to_sender` entry），给自己铸少量 **`SILVER`**。
4. **验收**：钱包或 `sui client` 能看到该 `Coin` 类型余额。

## 实战二：注册表与元数据

1. 在浏览器或 CLI 中找到 **`CoinRegistry`** 下本币种的 **`Currency<SILVER>`**（或等价展示）。
2. 对照 [§14.3](03-coin-metadata.md)，写出 **`symbol`、`decimals`** 与 **`MetadataCap`** 的关系。
3. **验收**：能向他人说明「共享的是类型元数据，余额在各地址的 `Coin` 里」。

## 实战三：Owner Coin —— 拆分与支付

1. 自己持有至少两枚可合并的 **`Coin<SILVER>`**（或一枚大额），用 PTB **`splitCoins`** 拆出小额。
2. 再向**第二个测试地址**转一笔（`transferObjects` 或等价 API）。
3. **验收**：发送方剩余总额 + 接收方增加额 = 原总额（注意 gas 另计）。

## 实战四（进阶）：受监管初始化

1. 复制 `silver_coin` 为新包，在 **`finalize` 前** 调用 **`coin_registry::make_regulated`**（测试网练习，勿与主网真实资产混用）。
2. 部署后用 **`DenyCapV2`** 对测试地址做一次 **`deny_list_v2_add`**（需 **`DenyList` 共享对象** 引用）。
3. **验收**：理解 **下一 epoch 生效** 的语义；可查 **`deny_list_v2_contains_current_epoch`**。

## 实战五（进阶）：闭环 Token

1. 阅读 `sui::token` 源码中的 **`new_policy` / `share_policy` / `from_coin`**。
2. 在独立测试模块中：铸 **`Coin`** → **`from_coin` 得 `Token` + `ActionRequest`** → 设计最小 **`allow`** 或 Rule 使 **`confirm_request`** 可通过（需在测试场景构造 **`TokenPolicy`** 引用）。
3. **验收**：能口述 **`ActionRequest`** 与 **`TokenPolicy.rules`** 的匹配关系。

## 实战六：嵌入式 Balance（金库）

1. 仿照 [§14.13](13-balance-vault-patterns.md)，写一个 **`PrizePool`**，实现 **`deposit(Coin)`** 与 **`withdraw` → `Coin`**。
2. `sui move test` 或链上调用验证余额守恒。
3. **验收**：能解释为何 **`Balance` 字段**不会出现在钱包「对象列表」里单独成行。
