#!/usr/bin/env bash
# release APK を静的検査する。
# 必要なネイティブライブラリが入っているか、削除した依存が復活していないかを見る。
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apk="${1:-$root/apps/mobile/build/app/outputs/flutter-apk/app-release.apk}"

if [ ! -f "$apk" ]; then
  printf 'APK not found: %s\n' "$apk" >&2
  printf 'build it first: cd apps/mobile && flutter build apk --release ...\n' >&2
  exit 1
fi

printf 'checking %s\n' "$apk"
failed=0
listing="$(unzip -l "$apk")"

# 必要なネイティブライブラリ（sqlite3 は drift のローカルcacheに必須）。
for lib in libsqlite3.so libapp.so libflutter.so; do
  if [ "$(printf '%s\n' "$listing" | grep -c -- "$lib")" -gt 0 ]; then
    printf '  -> ok: %s\n' "$lib"
  else
    printf '  -> MISSING: %s\n' "$lib"
    failed=1
  fi
done

# 削除した依存が復活していないこと（サイズとクラッシュ要因の回帰防止）。
for gone in libonnxruntime.so libonnxruntime4j_jni.so; do
  if [ "$(printf '%s\n' "$listing" | grep -c -- "$gone")" -gt 0 ]; then
    printf '  -> UNEXPECTED: %s（背景除去は削除済み）\n' "$gone"
    failed=1
  else
    printf '  -> ok: %s は含まれない\n' "$gone"
  fi
done

if [ "$failed" -ne 0 ]; then
  printf '\nFAILED: release APK の内容が想定と違う。\n' >&2
  exit 1
fi
printf '\nrelease APK class check passed\n'
