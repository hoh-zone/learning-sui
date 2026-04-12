#!/usr/bin/env bash
# 构建 src 下所有含 Move.toml 的章节约示工程。需在 PATH 中安装 `sui`。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
failed=0
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  echo "========== $dir =========="
  if (cd "$dir" && sui move build); then
    :
  else
    failed=1
  fi
done < <(find src -path '*/code/*/Move.toml' -print0)

if [[ "$failed" -ne 0 ]]; then
  echo "Some packages failed to build." >&2
  exit 1
fi
echo "All chapter Move packages built OK."
