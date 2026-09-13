#!/usr/bin/env bash
# 変更を入れたときに回す高速チェック。端末やネットワークは使わない。
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

cd "$root/workers/api"
step "worker typecheck" npm run typecheck
step "worker lint" npm run lint
step "worker test" npm test

cd "$root/apps/mobile"
step "flutter format" dart format --output=none --set-exit-if-changed lib test integration_test test_driver
step "flutter analyze" flutter analyze
step "flutter test" flutter test

printf '\n============================\n'
if [ ${#failures[@]} -eq 0 ]; then
  printf 'all checks passed\n'
  exit 0
fi
printf 'failed: %s\n' "${failures[*]}"
exit 1
