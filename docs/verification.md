# Verification record

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
