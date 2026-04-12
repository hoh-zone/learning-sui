# 第五章 · 示例代码（每节一包）

**5.1–5.21** 各对应**独立可编译**的 Move 2024 包（`edition = "2024.beta"`，Framework 由本地 `sui` CLI 隐式提供）。目录名与正文 **`NN-标题.md`** 对齐。

| 小节 | 目录 | 说明 |
|------|------|------|
| 5.1 | `01-module/` | 模块声明 |
| 5.2 | `02-comments/` | 注释 |
| 5.3 | `03-importing-modules/` | 跨模块 `use` |
| 5.4 | `04-integers/` | 整数与字面量 |
| 5.5 | `05-booleans-and-casts/` | 布尔与分支 |
| 5.6 | `06-address-type/` | `address` |
| 5.7 | `07-tuples-and-unit/` | 元组与 unit |
| 5.8 | `08-expression/` | 表达式与 `if` 求值 |
| 5.9 | `09-variables-and-scope/` | 变量与遮蔽 |
| 5.10 | `10-equality/` | 相等比较 |
| 5.11 | `11-struct/` | `struct` |
| 5.12 | `12-abilities-introduction/` | 多种能力组合 |
| 5.13 | `13-ability-drop/` | `drop` |
| 5.14 | `14-ability-copy/` | `copy` |
| 5.15 | `15-constants/` | `const` |
| 5.16 | `16-conditionals/` | 条件分支 |
| 5.17 | `17-loops-and-labels/` | `while` 循环 |
| 5.18 | `18-assert-and-abort/` | `assert!` / `abort`（模块名避免使用关键字 `abort`） |
| 5.19 | `19-function-basics/` | 私有/公开函数 |
| 5.20 | `20-entry-and-public/` | `entry` 与 `public` |
| 5.21 | `21-visibility/` | `public(package)` 与多模块 |

## 构建某一节

```bash
cd 04-integers   # 示例：5.4
sui move build
```

## 构建本章全部包

```bash
# 在仓库根目录
for d in src/05_move_basics/code/[0-2][0-9]-*/; do
  [ -f "$d/Move.toml" ] || continue
  (cd "$d" && sui move build) || exit 1
done
```

第六、七章正文与示例代码已分别在 **`../06_move_intermediate/`**、**`../07_move_advanced/`**（含各自 `code/` 每节一包）；见两章的 `00-index.md` 与 `code/README.md`。
