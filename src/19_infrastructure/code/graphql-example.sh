#!/usr/bin/env bash
# 第十九章实战：测试网 GraphQL 查询示例（需 curl）。
set -euo pipefail
URL="${SUI_GRAPHQL_URL:-https://graphql.testnet.sui.io/graphql}"
curl -sS -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ checkpoint { sequenceNumber } }"}' | head -c 800
echo
