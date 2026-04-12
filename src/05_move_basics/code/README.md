# 第五章 · 示例代码（每节一包）

**5.1–5.22** 中除 **§5.4**（概念节，无独立包）外，各小节对应**独立可编译**的 Move 2024 包（`edition = "2024.beta"`，Framework 由本地 `sui` CLI 隐式提供）。目录名与正文 **`NN-标题.md`** 对齐。

| 小节 | 目录 | 说明 |
|------|------|------|
| 5.1 | `01-module/` | 模块声明 |
| 5.2 | `02-comments/` | 注释 |
| 5.3 | `03-importing-modules/` | 跨模块 `use` |
| 5.4 | — | 默认导入 / Prelude（无独立 `code/`） |
| 5.5 | `04-integers/` | 整数与字面量 |
| 5.6 | `05-booleans-and-casts/` | 布尔与分支 |
| 5.7 | `06-address-type/` | `address` |
| 5.8 | `07-tuples-and-unit/` | 元组与 unit |
| 5.9 | `08-expression/` | 表达式与 `if` 求值 |
| 5.10 | `09-variables-and-scope/` | 变量与遮蔽 |
| 5.11 | `10-equality/` | 相等比较 |
| 5.12 | `11-struct/` | `struct` |
| 5.13 | `12-abilities-introduction/` | 多种能力组合 |
| 5.14 | `13-ability-drop/` | `drop` |
| 5.15 | `14-ability-copy/` | `copy` |
| 5.16 | `15-constants/` | `const` |
| 5.17 | `16-conditionals/` | 条件分支 |
| 5.18 | `17-loops-and-labels/` | `while` 循环 |
| 5.19 | `18-assert-and-abort/` | `assert!` / `abort`（模块名避免使用关键字 `abort`） |
| 5.20 | `19-function-basics/` | 私有/公开函数 |
| 5.21 | `20-entry-and-public/` | `entry` 与 `public` |
| 5.22 | `21-visibility/` | `public(package)` 与多模块 |

## 构建某一节

```bash
cd 04-integers   # 示例：5.5
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

第六至八章正文与示例代码已分别在 **`../06_move_intermediate/`**、**`../07_move_macros/`**、**`../08_move_advanced/`**（含各自 `code/` 每节一包或第七章整章一包）；见各章 `00-index.md` 与 `code/README.md`。
