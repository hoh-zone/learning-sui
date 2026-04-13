# 第二章 · 实战练习

## 实战一：环境自检脚本

1. 在仓库中执行：`src/02_getting_started/code/check-env.sh`（需已安装 `sui`）。
2. 若失败，按本章 2.1 节重装或修正 `PATH`。
3. **验收**：脚本打印 `sui` 版本号。

## 实战二：测试网钱包与水龙头

1. 按 2.3 节创建地址：`sui client new-address ed25519`（或你使用的方案）。
2. 配置 `sui client` 指向 **testnet**，从水龙头领取测试 SUI。
3. **验收**：`sui client balance`（或等价命令）显示非零余额。

## 实战三：确认示例包可构建

1. 克隆或进入仓库后，打开 `src/03_first_move/code/hello_world/`。
2. 执行 `sui move build`（无需先理解 `Move.toml` 中每一项含义）。
3. **验收**：构建成功。若对 `edition` / `rev` 有疑问，读完第五～六章后再看[第六章 §6.11](../06_move_intermediate/11-move-2024.md)。
