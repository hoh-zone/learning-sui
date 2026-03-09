# 编译模式（Modes）

**编译模式**（Modes）允许你只在显式启用某个命名构建模式时，才把**不可发布**的代码编入包中。可以把它理解为 `#[test_only]` 的泛化：除了内置的 `test` 模式外，你还可以定义 `debug`、`benchmark`、`spec` 等任意模式，用于调试、压测或规范代码。

## 要点一览

- 使用 `#[mode(name, ...)]` 标注模块或成员；`#[test_only]` 是 `#[mode(test)]` 的简写。
- 使用 `--mode <name>`（或 `--test` 跑单测）构建时，只有标注了该模式的项会被编入；未匹配的项会被**排除**。
- **只要启用了任意模式**（包括 `--test`），生成的产物都**不可发布**，从而保证调试/测试代码不会上链。
- **未标注** `#[mode(...)]` / `#[test_only]` 的项**始终**会被编入。

> 提示：模式是编译期过滤，不影响运行时字节码。适合用于调试辅助、模拟器和不应发布的 mock 类型与函数。

## 语法

与 `#[test_only]` 一样，可以把模式属性挂在模块或单个成员上：

```move
// 整个模块仅在启用对应模式时编入
#[mode(debug)]
module my_pkg::debug_tools {
    public fun dump_state() { /* ... */ }
}

module my_pkg::library {
    // 仅在 debug 或 test 构建中存在
    #[mode(debug, test)]
    public fun assert_invariants() { /* ... */ }

    // 仅测试；等价于 #[mode(test)]
    #[test_only]
    fun mk_fake() { /* ... */ }
}
```

一个属性中可以写多个模式：`#[mode(name1, name2, ...)]`。只要**任一**列出的模式被启用，该项就会被编入。**没有**模式标注的项始终编入。

> `#[mode(test)]` 与 `#[test_only]` 等价。

## 如何按模式构建

用 Sui CLI 在构建或测试时启用模式：

```bash
# 启用自定义模式构建
sui move build --mode debug

# 跑单测（自动包含 #[test_only]）
sui move test --test

# 同时启用 test 与 debug（例如带调试输出的测试）
sui move test --test --mode debug
```

启用某模式时，标注了该模式的项会被编入；只标注了其他模式的项会被排除；未标注的项始终编入。

> **发布前**：只要用过 `--mode` 或 `--test` 构建，产物都不可发布。发布前请用**不带** `--mode`/`--test` 的干净构建：`sui move build`。

## test 模式（单元测试）

`#[test_only]` 即内置的 `test` 模式，行为与 `#[mode(test)]` 一致。使用 `sui move test --test` 时，会自动启用 `test` 模式，从而编入所有 `#[test_only]` 的模块和函数。详见第十二章「测试」。

## 自定义模式示例：debug

例如你希望只在开发/调试时编入带日志的包装函数，而不影响正式构建：

```move
#[mode(debug)]
module my_pkg::bank_debug {
    use std::debug;
    use my_pkg::bank;

    public fun transfer_with_logs(from: &signer, to: address, amount: u64) {
        debug::print(&b"[DEBUG] transfer".to_vector());
        bank::transfer(from, to, amount);
    }
}
```

构建时若不加 `--mode debug`，`bank_debug` 不会被编入；用 `sui move build --mode debug` 或 `sui move test --test --mode debug` 时才会包含。

## 小结

- **编译模式**：`#[mode(name, ...)]` 控制项在何种构建下被编入；`#[test_only]` ≡ `#[mode(test)]`。
- **构建**：`sui move build --mode <name>`、`sui move test --test`（自动启用 test）。
- **发布**：启用任意模式后的产物不可发布；发布前必须执行不带 `--mode`/`--test` 的 `sui move build`。
