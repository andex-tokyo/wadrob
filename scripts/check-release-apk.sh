#!/usr/bin/env bash
# release APK を静的検査する。
# R8 が JNI から名前で参照されるクラスを消すと、端末上でだけクラッシュする。
# 端末を待たずに数十秒で検出するためのチェック。
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apk="${1:-$root/apps/mobile/build/app/outputs/flutter-apk/app-release.apk}"

if [ ! -f "$apk" ]; then
  printf 'APK not found: %s\n' "$apk" >&2
  printf 'build it first: cd apps/mobile && flutter build apk --release ...\n' >&2
  exit 1
fi

# require: <apk 内に残っているべき文字列> <説明>
require() {
  local needle="$1" label="$2" count
  count="$(unzip -p "$apk" 'classes*.dex' 2>/dev/null | strings | grep -c -- "$needle" || true)"
  if [ "$count" -lt 1 ]; then
    printf '  -> MISSING: %s (%s)\n' "$needle" "$label"
    return 1
  fi
  printf '  -> ok: %s x%s (%s)\n' "$needle" "$count" "$label"
}

printf 'checking %s\n' "$apk"
failed=0
require 'ai/onnxruntime/OrtSession' 'background removal (ONNX Runtime Java API)' || failed=1
require 'com/masicai/flutteronnxruntime' 'background removal plugin' || failed=1

# native ライブラリは常に同梱されている必要がある。
# grep は -c を使う（-q は読み取り途中で閉じて pipefail と衝突する）。
listing="$(unzip -l "$apk")"
for lib in libonnxruntime.so libonnxruntime4j_jni.so; do
  if [ "$(printf '%s\n' "$listing" | grep -c -- "$lib")" -gt 0 ]; then
    printf '  -> ok: %s\n' "$lib"
  else
    printf '  -> MISSING: %s\n' "$lib"
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  printf '\nFAILED: release APK lost classes needed by JNI.\n' >&2
  printf 'Check apps/mobile/android/app/proguard-rules.pro\n' >&2
  exit 1
fi
printf '\nrelease APK class check passed\n'
