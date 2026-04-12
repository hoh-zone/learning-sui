#!/usr/bin/env bash
# 第二章：确认本机已安装 Sui CLI（Move 2024 与本书示例依赖）。
set -euo pipefail
if ! command -v sui >/dev/null 2>&1; then
  echo "未找到 sui 命令，请先安装 Sui CLI。" >&2
  exit 1
fi
echo "sui $(sui --version)"
