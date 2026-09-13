#!/usr/bin/env bash
# 端末（実機/エミュレータ）でネイティブ経路のスモークを回す。
#   scripts/smoke-device.sh [device-id]           # debug（速い・既定）
#   MODE=profile scripts/smoke-device.sh [id]     # profile（リリースに近い）
#
# release は flutter drive が非対応のため、release の検証は
# scripts/check-release-apk.sh（R8でJNI用クラスが消えていないかの静的検査）で行う。
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device="${1:-}"
mode="${MODE:-debug}"
target="integration_test/image_pipeline_test.dart"

cd "$root/apps/mobile"
flutter pub get >/dev/null

if [ "$device" = "" ]; then
  device="$(flutter devices --machine | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x["id"] for x in d if x.get("targetPlatform","").startswith("android")), ""))')"
  if [ "$device" = "" ]; then
    printf 'no android device found. connect one or start an emulator.\n' >&2
    exit 1
  fi
fi

printf 'device=%s mode=%s\n' "$device" "$mode"
if [ "$mode" = "release" ]; then
  printf 'flutter drive does not support release mode.\n' >&2
  printf 'use MODE=profile for a release-like run, and run:\n' >&2
  printf '  bash scripts/check-release-apk.sh   # R8 stripping check\n' >&2
  exit 1
fi

if [ "$mode" = "profile" ]; then
  flutter drive --profile -d "$device" \
    --driver=test_driver/integration_test.dart --target="$target"
else
  flutter test "$target" -d "$device"
fi
