# 第二章 · 实战练习

## 实战一：环境自检脚本

1. 在仓库中执行：`src/02_getting_started/code/check-env.sh`（需已安装 `sui`）。
2. 若失败，按本章 2.1 节重装或修正 `PATH`。
3. **验收**：脚本打印 `sui` 版本号。

## 实战二：测试网钱包与水龙头

1. 按 2.3 节创建地址：`sui client new-address ed25519`（或你使用的方案）。
2. 配置 `sui client` 指向 **testnet**，从水龙头领取测试 SUI。
3. **验收**：`sui client balance`（或等价命令）显示非零余额。

## 实战三：Move 2024 Edition 对齐

1. 打开任意本书配套包（如 `src/03_first_move/code/hello_world/Move.toml`），确认 `edition = "2024.beta"`（或本书约定版本）。
2. 在该目录执行 `sui move build`。
3. **验收**：构建成功且无 edition 相关报错。
