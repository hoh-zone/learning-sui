# 第六章 · 实战练习

## 实战一：Vector 累加

1. 进入 `src/06_move_intermediate/code/02-vector/`。
2. 在模块中新增函数：输入 `vector<u64>`，返回所有元素之和（注意空 vector）。
3. `sui move build`，并可选添加 `#[test]` 验证。
4. **验收**：测试或编译通过。

## 实战二：Option 与模式匹配

1. 使用 `src/06_move_intermediate/code/03-option/` 或 `06-pattern-matching/`。
2. 实现「从 `Option<u64>` 取值，若为 `None` 则返回默认 `0`」的函数，用 `match` 或 `if let` 风格编写。
3. **验收**：代码风格符合本章「安全取值」习惯。

## 实战三：宏展开心智演练

1. 打开 `src/06_move_intermediate/code/08-macros/sources/macros.move`。
2. 在不改坏编译的前提下，为 `add!` 再增加一个调用点（例如 `add!(10u64, 20u64)` 的包装函数）。
3. **验收**：`sui move build` 成功；能向同伴解释「宏在编译期展开」与函数调用的区别。

## 实战四：Move.toml 与 Move 2024 对照

1. 阅读[§6.11 Move 2024 Edition 与语法对照](11-move-2024.md)中的「启用 Move 2024」与「Sui Framework 依赖：`rev` 与网络」。
2. 任选本书一章配套包，打开其 `Move.toml`，指出 `edition` 与 `[dependencies]`（或隐式框架）与当前 `sui client` 环境是否匹配。
3. **验收**：能口头说明 `framework/mainnet` 与 `framework/testnet` 的选用场景；`sui move build` 仍通过。
