#!/usr/bin/env bash
# 附录：常用 CLI 自检（需已安装 Sui CLI）。
set -euo pipefail
echo "== sui 版本 =="
sui --version
echo "== 当前环境（若已配置）==="
sui client active-env 2>/dev/null || echo "（未配置 active-env，可运行 sui client new-env）"
echo "== 完成 =="
