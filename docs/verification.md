# Verification record

## Product search by name and brand (2026-09-13)

写真・手動登録を楽にするため、商品名とブランドから商品ページ候補を探す `POST /api/import/search` を追加した（Worker version `5949c6b3-09f8-49bd-a928-3e36db7084ff`）。

- 実APIでの確認（`gpt-5.6-luna` + `web_search`）:
  - `ユニクロ エアリズムコットンオーバーサイズTシャツ` → 3件（Yahoo!ショッピング2、楽天1）／5.3秒
  - `PUBLIC TOKYO メッシュボーダーニット` → 1件（`https://store.shopping.yahoo.co.jp/zozo/82019293.html`）／5.9秒。これは先にZOZO取込で使った商品と同一で、候補から既存の取込経路に渡せることを確認
- URLは推測させず検索結果のみを返す。`validateUrl` で安全性を検査し、重複を除外、最大5件に制限（テストで確認）
- 料金は Web検索 $10/1k calls + トークン。1回あたり約$0.012
- Worker Vitest 32 tests（検索のURL検証・重複除外・キー未設定・失敗系を追加）、Flutter 7 tests（候補検索→取り込みのウィジェットテストを追加）
- 未確認: 端末UIでの検索操作（エミュレータがログアウト状態のため。ウィジェットテストと実APIで代替）

## CI speedup (2026-09-13)

push時のCIが8分21秒かかっていたため短縮した。

- 直列だった worker / app のジョブを並列化（直列だと待ち時間が足し算になる）
- release APK のR8検査は `apps/mobile/android/**` や pubspec が変わったときだけ実行（毎回Gradleのダウンロードで数分かかるため）。`workflow_dispatch` では常に実行
- Gradleキャッシュを追加、同一ブランチの古い実行は `concurrency` で打ち切り
- `scripts/check.sh` に `worker` / `app` の引数を追加し、CIから必要な半分だけ実行できるようにした

## Brand assets (2026-09-13)

アプリ表示名を WDRB に変更し、アイコンとスプラッシュを白地・黒文字のワードマークへ統一した。

- 書体: ログイン画面の描画と同じ Roboto（Weight 500）。Android端末の `/system/fonts/RobotoFlex-Regular.ttf` を取り出して `tool/fonts/` に同梱し、生成は `tool/generate_brand_assets.py`
- アイコン: `mipmap-*/ic_launcher.png`（48〜192）と、Android 8+ のアダプティブアイコン（`mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_foreground.png`、背景は白）
- スプラッシュ: `drawable-nodpi/splash_logo.png` を `launch_background.xml` で中央配置し、Android 12+ は `values-v31/styles.xml` の `windowSplashScreenBackground` / `windowSplashScreenAnimatedIcon` で白地 + ワードマークに統一
- 実機確認: ランチャーのアイコン表示、スプラッシュの白地 + WDRB、ログイン画面の WDRB 表記をスクリーンショットで確認（クローゼットのAppBarはコード変更のみ。サインイン状態で未確認）
- スプラッシュの光学中心: 修正前 47.6% → 修正後 49.9%（画面高に対するワードマーク中心の実測値）
- 生成画像のインク中心はアイコン・前景・スプラッシュすべてでキャンバス中心と一致することを座標で確認

Verified on 2026-09-13:

- Worker TypeScript typecheck: pass
- Worker ESLint: pass
- Worker Vitest: 11 tests pass
- Production dependency audit: 0 vulnerabilities
- D1 local migration: 15 statements pass
- D1 production migration: 15 statements pass
- Cloudflare Worker deploy: pass (`https://wadrob-api.tsuchida.workers.dev`)
- Deployed `/health`: HTTP 200 with `{"ok":true}`
- Deployed protected endpoint without a session: HTTP 401 with structured `UNAUTHORIZED` response
- Flutter format: pass
- Flutter analyze: no issues
- Flutter tests: 3 tests pass
- Android debug APK: pass (228MB)
- Android release APK: pass (124.8MB)
- Android release App Bundle: pass (94.8MB)
- Pixel 6a / Android 36.1 emulator: final `tokyo.andex.wadrob` release install and launch pass; Google account sign-in screen reached
- Repository secret scan: no token/private key found

The emulator was under severe host memory pressure and showed Pixel Launcher/System UI ANR dialogs during its first full boot. After dismissing the system dialog, WADROB rendered and remained the top resumed activity. No WADROB crash was observed.

Not yet verified: completion of real Google account sign-in, authenticated CRUD against production, live URL imports, optional OpenAI fallback, and background removal quality across representative floor photos. The ONNX code and native Android bundle compile successfully.

Release artifacts:

- APK SHA-256: `7ceb8d913baf6ded7213d5f645d8445e6b1c028ccad15fe0cb80dfc2f40c661d`
- AAB SHA-256: `b816e5f4681cc86a0dc9ac940096b57ecb0c66fb6497c489f93a3a8448a13942`

## OpenAI fallback (2026-09-13)

`OPENAI_API_KEY` を本番Workerへ登録し、`OPENAI_MODEL` を `gpt-5.6-luna` へ変更して deploy した（Worker version `0f723d3a-28bf-49df-8e92-1076bd910ef1`）。`gpt-5-nano` は 2026-12-11、`gpt-4.1-nano` は 2026-10-23 に API から削除予定のため採用しない。

- 実APIでの疎通: HTTP 200 / `status: completed` / Structured Outputs で5項目を抽出（reasoning tokens 0）
- Workerコード経由のフォールバック検証: `importUrl` をスタブPageFetcherと実キーで実行し、brand / originalColor / productCode / shopName が `source: ai` で補完され、既存の決定的解析値（name）は上書きされないことを確認
- 失敗時は無言で空を返さず、import previewの `warnings` に「補助解析を利用できませんでした」を残すよう変更

未検証: 本番環境での実URL取込（要ログインセッション）と、AIが返す値の精度評価。

## AI extraction scope (2026-09-13)

AI抽出を `category`、`subCategory`、`normalizedColor`、`listPrice`、`currency` へ拡張し、発火条件を「決定的解析でいずれかの項目が未取得」へ緩めた。`category` と `normalizedColor` はJSON Schemaのenumで拘束し、想定外の値は破棄する。商品名・ブランドは装飾とサイト名の重複を除去する。

- Worker Vitest: 18 tests pass（AIマッピング、enum値の破棄、非JPY価格の最小単位換算、失敗時warning、発火条件、API key未設定時のスキップ、ラベル整形）
- Flutter test: 4 tests pass（URL取込の解析結果がエディタのカテゴリ・カラー・定価・通貨へ反映されるウィジェットテストを追加）
- 実APIでの確認: JSON-LD付き日本語ページに対し、`category: knitwear`、`subCategory: プルオーバー`、`normalizedColor: gray` を `source: ai` で補完し、JSON-LDの `name`/`brand`/`listPrice` は上書きしないことを確認（レイテンシ約2秒）
- 本番 deploy 済み（Worker version `0dcf5fbd-67d0-413e-9ec7-9da7261a988d`）

## Live shop verification (2026-09-13)

実機（Pixel 6aエミュレータ・署名済みセッション）から本番Worker経由でURL取込を実行した。

- **URL取込が本番で全滅していた不具合を修正**: `SimpleFetcher` がグローバル `fetch` をフィールド経由でメソッド呼び出ししており、workerd の `Illegal invocation` で必ず失敗していた。素の関数呼び出しに変更（Worker version `086c79b8-ccb3-42fe-b07d-d970aa8094b0`）。
- Yahoo!ショッピング: 取込成功（商品画像・商品名・ブランド・商品表記カラー・定価、およびAIによるカテゴリ「ニット」・検索用カラー「マルチ」の自動入力を実機で確認）— `wadrob-import-yahoo.png`
- andST（dot-st.com）: 取込成功（商品画像・商品名・ブランド。店名サフィックスを除去）— `wadrob-import-andst.png`
- ZOZOTOWN（zozo.jp）: `FETCH_FAILED`。403のためWorkerからは取得できない — `wadrob-import-zozo.png`
- 楽天市場: 商品ページが EUC-JP のため文字コード判定を追加。文字化けしていた商品名が正しく取得できることを確認
- 追加した回帰テスト: 0円価格の無視、文字コード判定、店名サフィックスの除去、`fetch` を this 無しで呼ぶこと（Worker Vitest 24 tests）

## ZOZOTOWN support via Browser Run and mirror (2026-09-13)

ZOZOTOWNは `zozo.jp` 本体を403で拒否するため、2段の代替経路を追加した（Worker version `c8563898-3e5e-4b41-97d2-4a8cdcc34cee`）。

1. **ミラー取得**: `/shop/<shop>/goods/<id>/` を `store.shopping.yahoo.co.jp/zozo/<id>.html` へ自動変換。ZOZO商品と同一IDで同一商品が取得できることを確認済み（例: `publictokyo/goods/82019293`）。
2. **Browser Run**: `browser` binding + `quickAction("content")` でJavaScript描画。ZOZO本体は描画しても「Access Denied」を返すため、403とブロックページは取得失敗として扱う（誤って「Access Denied」を商品名にしない）。

- 実機確認: `https://zozo.jp/shop/publictokyo/goods/82019293/` から、商品画像・商品名「サマーニット セーター ニット メッシュボーダー…」・ブランド「PUBLIC TOKYO」・カテゴリ「ニット」・検索用カラー「マルチ」・定価13860を取得 — `wadrob-import-zozo.png`
- 保存時の画像取得: ミラー先の画像（`z-shopping.c.yimg.jp`）がHTTP 200 / image/jpegで取得できることを確認
- Worker Vitest: 29 tests pass（Browser Runの描画・ブロックページ拒否・ミラーURL変換・チェーン順序を追加）

## Device E2E and test rework (2026-09-13)

実機（Pixel 6aエミュレータ）で「URL取込 → 保存 → Grid → Detail → 編集 → 手放す → アーカイブフィルタ」を通した。手放す＝`status=archived`、編集＝`size=M` がD1に反映されることを確認し、画像は原本R2保存→端末ONNX→display/thumbnail生成（`processing_status=completed`）まで完了した。

### 発見した不具合（release限定クラッシュ）

保存直後にアプリが `SIGABRT` で落ちた。tombstoneの abort message は

```
JNI DETECTED ERROR IN APPLICATION: java_class == null
    in call to GetMethodID
    from boolean[] ai.onnxruntime.OrtSession.run(...)
```

R8が `ai.onnxruntime.**` を難読化・削除したため、JNIがクラスを解決できずプロセスごと落ちていた。debugビルドでは再現しない。`apps/mobile/android/app/proguard-rules.pro` に keep ルールを追加して解決（release APK内の `ai/onnxruntime/OrtSession` 文字列は 3 → 8 に回復）。

処理前に `processing` を立てたまま落ちるため、次回起動でも同じ画像を処理してクラッシュループになる。対策として、一度失敗した画像は端末側で再試行しないガードを入れた（`Session.processPending`）。

### 検証を3層に再編

手動の座標タップE2Eは遅く再現性が低いため、繰り返す検証をテストへ移した。

- `scripts/check.sh`: worker typecheck / lint / Vitest と flutter format / analyze / test をまとめて実行（今回 all checks passed）
- `scripts/check-release-apk.sh`: release APKに `ai/onnxruntime/OrtSession`、`com/masicai/flutteronnxruntime`、`libonnxruntime*.so` が残っているかを静的検査（R8回帰の検出）
- `scripts/smoke-device.sh`: `integration_test/native_pipeline_test.dart` を端末で実行し、ONNX背景除去と4:5正規化（960x1200 / 360x450）を検証。debug / profile で pass を確認
- `flutter drive` は release 非対応のため、release固有の検証は静的APK検査で代替する（profileビルドはminifyされないことを確認済み）
- `.github/workflows/check.yml`: push ごとに `check.sh` と release APK 検査を実行

### 未確認

- 写真・カメラ登録: エミュレータのメディアDBが壊れており（`MediaProviderClient` 例外、Photo Picker内部エラー）、アプリのアップロード処理まで到達しない。実機で確認する
- 手動登録、Logout / 再ログイン
