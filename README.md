# Move on Sui: 从零到精通

一本面向 Sui 与 Move 的入门到进阶教程，由 [HOH Community](https://github.com/hoh-zone) 编写与维护。涵盖 Move 语言基础、Sui 对象模型、代币与 NFT、客户端 SDK、全栈 DApp、包升级与安全、基础设施与前沿技术等内容。

## 在线阅读

（部署后在此填写在线地址，例如：<https://hoh-zone.github.io/learning-sui/>）

## 本地阅读与构建

本书使用 [mdBook](https://rust-lang.github.io/mdBook/) 构建。

### 安装 mdBook

```bash
cargo install mdbook
# 或
brew install mdbook   # macOS
```

### 本地预览（推荐）

在项目根目录执行：

```bash
mdbook serve
```

浏览器打开 <http://localhost:3000>，支持热重载，修改 `src/` 下 Markdown 后自动刷新。

### 构建静态站点

```bash
mdbook build
```

输出在 `book/` 目录，可将该目录部署到任意静态托管（如 GitHub Pages、Vercel）。

## 项目结构

```
learning-sui/
├── book.toml          # mdBook 配置
├── src/
│   ├── SUMMARY.md     # 目录（侧边栏结构）
│   ├── 00-foreword.md # 前言
│   └── 01_introduction/ …  # 各章目录内正文为 NN-标题.md（NN 为 00–99，顺序见 SUMMARY）
├── book/              # 构建输出（已加入 .gitignore）
└── README.md
```

- **修改目录**：编辑 `src/SUMMARY.md` 可增删章节与顺序。
- **正文内容**：所有章节为 Markdown，位于 `src/` 各子目录；文件名含章节内顺序号，可用 `scripts/renumber_mdbook_sources.py` 按 SUMMARY 批量重排。

## 贡献

欢迎提交 Issue 与 Pull Request。修改或新增内容时，请保持与现有风格一致；本书示例遵循 [Sui Dev Skills](https://github.com/MystenLabs/sui-dev-skills) 中的 Move / TypeScript / 前端约定（见项目内 `.claude/skills/sui-dev-skills/`）。

## 许可证

（可在此补充许可证类型，如 MIT、CC BY-SA 等）
