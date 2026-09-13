#!/usr/bin/env bash
# 変更を入れたときに回す高速チェック。端末やネットワークは使わない。
#   ./scripts/check.sh          # すべて
#   ./scripts/check.sh worker   # Workerのみ（CIの並列実行用）
#   ./scripts/check.sh app      # Flutterのみ（CIの並列実行用）
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
failures=()

step() {
  local name="$1"
  shift
  printf '\n=== %s ===\n' "$name"
  if "$@"; then
    printf '  -> OK\n'
  else
    printf '  -> FAILED: %s\n' "$name"
    failures+=("$name")
  fi
}

if [ "$target" = "all" ] || [ "$target" = "worker" ]; then
  cd "$root/workers/api"
  step "worker typecheck" npm run typecheck
  step "worker lint" npm run lint
  step "worker test" npm test
fi

if [ "$target" = "all" ] || [ "$target" = "app" ]; then
  cd "$root/apps/mobile"
  step "flutter format" dart format --output=none --set-exit-if-changed lib test integration_test test_driver
  step "flutter analyze" flutter analyze
  step "flutter test" flutter test
fi

printf '\n============================\n'
if [ ${#failures[@]} -eq 0 ]; then
  printf 'all checks passed\n'
  exit 0
fi
printf 'failed: %s\n' "${failures[*]}"
exit 1
