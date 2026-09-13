# Verification record

## Gallery selection by product id (2026-09-14)

「UNIQLOで最初の何枚かしか取れない」事象を修正した（Worker version `53f91eda-57c9-479b-8555-9f4713b73fe7`）。

- 原因1: 収集の上限（12枚）が、関連商品の画像が先に並ぶページで商品画像に届く前に埋まっていた
- 原因2: 商品IDを持つ画像と無関係な画像を区別していなかった
- 対応: 収集は最大500件まで行い、URLや既知の画像（JSON-LD/OGP）に含まれる4桁以上の数字（商品ID）と一致する画像を優先。一致が5枚以上なら他は落とす。最終的な候補は40枚まで
- UIアセットの除外を追加（色チップ、サイズ表、ケア画像、`/static/`、スタッフ着用画像など）。同一画像のクエリ違い（`?width=600`）は統合
- 実測: UNIQLO 12→22枚（全て `jpgoods_*_465185_*` の商品画像。関連商品のNAVI画像181枚は除外）、Yahoo 12→28、楽天 12→26、WEAR 40、andST 2
- Worker Vitest 44 tests（商品ID優先・クエリ違いの統合・上限を追加）

## Waiting feedback, WEAR/WORLD, render retry (2026-09-13)

- 待機表示: エディタの処理中はオーバーレイで理由を出す（商品情報を取得中… / 候補を探しています… / 写真を準備しています… / 保存しています…）。処理中は保存を無効化
- WEAR（wear.jp）: 実ページで取得可能。商品ページはJSON-LD Productと`og:image`を持ち、画像CDN（images.wear2.jp / c.imgz.jp）も取得できる。コーデページは商品のProduct JSON-LDとコーデ写真を持つ。UIバナーは `/banner/` 除外で混入しない
- WORLD公式EC（store.world.co.jp）: `Wadrob/1.0`でもブラウザ相当のUAでも403（bot対策）。決定的解析とBrowser Runの描画で取り直す経路を追加したが、取得可否は実機で要確認。代替として各ブランドの商品は楽天・Yahoo!ショッピング・ZOZO・WEAR経由でも拾える
- 内容が薄いページの取り直し: 決定的解析のスコア（名前・ブランド・価格・画像枚数）で、Browser Run描画のほうが良ければ差し替える。Worker Vitestで「薄い→描画で改善」「描画が悪ければ元のまま」を検証
- AI検索の指示に、ブランド公式ECとWEARの商品ページを候補に含めることを明記

## Gallery images and picker modal (2026-09-13)

「Yahoo!ショッピングで1枚しか取れない」事象を修正し、画像はモーダルで選ぶ形にした（Worker version `dea2ff2d-3e7b-49aa-8021-03d338ed2112`）。

- 原因: 商品ページの画像はJSON-LD `image` と `og:image` の1枚しか見ていなかった（実ページにはギャラリーがある）
- `collectPageImages()` を追加し、DOMの `<img>`（`src`/`data-src`/`data-original`/`srcset`）から最大12枚を収集。JSON-LD/OGPの画像を先頭に置く
- UI/装飾（sprite・logo・banner・designAssets・elements・symbols・assets等）と静的アセットホスト（`s.yimg.jp`）、小さいサムネイル表記（`_50`・`_100`・`_300`等）を除外
- ギャラリーがJS/JSONの中にだけ相対URLで入っているショップ（楽天の旧テンプレート）にも対応するため、HTML全体のテキストも走査する
- 実測（従来はいずれもJSON-LD/OGPの1枚のみ）: Yahoo!ショッピング 1→12 / 楽天市場 1→12 / UNIQLO 1→12 / andST（dot-st） 1→4
- アプリ: 取込直後に画像選択モーダルを開き、既定は1枚。タップで追加/解除し、番号順が並び順になる。撮影した写真も候補に加わる。「画像を選ぶ（N枚から）」で再選択できる
- Worker Vitest 39 tests（DOM収集のフィルタ・重複除去・上限）、Flutter 11 tests（モーダルで2枚目を選ぶと保存payloadが `[{url:a},{url:b}]` になることを検証）

## Background removal removed (2026-09-13)

端末内ONNXによる背景除去を削除し、正規化だけを残した（ADR-006）。

- `image_background_remover` を依存から削除。`ImageService` の既定は `NormalizationProcessor`（向き補正・前景の外接矩形・中央配置・余白・960px/360px生成）
- `libonnxruntime.so`（arm64 19MB / armv7 14MB）と `libonnxruntime4j_jni.so` がAPKから消え、配布サイズが減った
- R8がJNI参照クラスを消して落ちる不具合の要因も同時に消えたため、`proguard-rules.pro` のONNX用keepルールを撤去
- `scripts/check-release-apk.sh` は「必要なネイティブライブラリ（libsqlite3/libapp/libflutter）がある」＋「ONNXは含まれない」を検査する形に変更
- 端末スモークは `integration_test/image_pipeline_test.dart` に置き換え（正規化の4:5検証＋端末のsqlite3でローカルcacheの読み書き）
- Flutter test 11件 pass、Worker 37件 pass

## Image selection on import (2026-09-13)

URL取込で入る複数画像から、採用する画像を選べるようにした（Worker version `3b45d97e-4b6c-428b-b800-12eeb2ee382c`）。

- エディタのプレビューで、タップ＝メイン（一覧の1枚目）、×＝使わない画像を外す。先頭に「メイン」バッジを表示
- 保存APIは `images: [{id}|{url}]` の順序つき配列を受け取る。先頭が `is_primary=1` / `sort_order=0`、以降は順に `sort_order` が入る。既存の `imageIds` / `imageUrls` も後方互換で受理（古いAPKが動き続ける）
- Flutter test 11 tests（3枚→メイン選択→1枚削除→保存payloadが `[{url:b},{url:a}]` の順になることを検証）

## Release signing (2026-09-13)

配布用のアップロード鍵を作成し、releaseビルドをこの鍵で署名するようにした。

- 鍵: `/Users/yuki/keystores/wadrob-upload.jks`（alias `wadrob-upload`、RSA 4096、有効期限 2054-01-29）
- 公開鍵: `/Users/yuki/keystores/wadrob-upload.pem`（Android デベロッパーの確認に使う）
- SHA-1: `C8:45:D1:55:6B:FF:6D:F9:68:9B:6E:E1:09:E4:A8:62:F7:9F:17:16`
- SHA-256: `24:8E:61:F7:B4:DD:92:92:CB:49:19:57:A5:1E:78:54:F4:99:A1:5E:81:E3:49:3F:4A:A4:6C:BB:60:CF:6F:AE`
- `apps/mobile/android/key.properties` にGradle用の設定を置き、`.gitignore` と `apps/mobile/android/.gitignore` の両方で除外（リポジトリには鍵もパスワードも入らない）
- `build.gradle.kts` は `key.properties` があればそれを使い、無い環境（CI）はdebug鍵にフォールバックする
- AAB/APKを再生成し、`keytool -printcert` でAABの署名が上記SHA-1と一致することを確認（AAB 95.2MB / APK 125.4MB）
- `scripts/check-release-apk.sh` は新しい鍵でもpass（R8のkeepルールは維持）

未対応: Google CloudのOAuth AndroidクライアントへのSHA-1追加（配布ビルドでGoogleサインインを有効にするため）と、Play Console「Android デベロッパーの確認」での鍵登録。

## Sleeve attribute and size normalisation (2026-09-13)

- `wardrobe_items.sleeve` を追加（migration `0003_sleeve.sql`、ローカル・本番D1へ適用済み、`user_id/sleeve` に索引）
- 値は 半袖 / 長袖 / ノースリーブ / 七分袖。カテゴリとは別軸の属性として扱う
- エディタ: カテゴリの隣に袖丈チップ（可視）。名前からの推定（`POST /api/classify`）で未選択のときだけ埋める。URL取込の解析結果にも含まれる
- フィルタ: ブランド / カラー / 袖丈 / サイズ / 手放した服
- サイズ正規化: `M` / `Ｍ` / `Mサイズ` / `メンズM` / `38cm` を比較キーで名寄せ（ブランドと同じ方式）。表示は元の表記を残す
- 検索: 「半袖」など日本語ラベルでも引けるよう、検索対象に袖丈のラベルを追加
- Worker Vitest 37 tests（袖丈の値域・classificationへの追加）、Flutter 10 tests（サイズ名寄せ・袖丈フィルタ・日本語検索）
- master-prompt を改訂（カテゴリ一覧、袖丈、フィルタ、groupIdの説明、アプリ表示名）

## Category tuning (2026-09-13)

オーナーの利用に合わせてカテゴリを調整した（migration `0002_category_tuning.sql`、Worker version `1b01ae0c-7914-4401-9ee6-90ddee624ee2`）。

- 削除: デニム / セットアップ / バッグ / オールインワン（既存itemが持っていた場合は `other` へ寄せてから削除）
- 追加: スーツ
- 適用結果（本番D1の `categories` を照会して確認）: アウター / トップス / シャツ / ニット / パンツ / スーツ / シューズ / アクセサリー / その他
- クライアントのチップとナビは定数マップで同じ並び。AIの抽出・カテゴリ推定の選択肢も同じenumから生成される
- Worker Vitest 36 tests（`suits` を含み `denim` 等を含まないこと、`suits` を受け付け `denim` を拒否することを追加）

## Photo-first registration and category inference (2026-09-13)

写真から20秒で登録できるようにするため、エディタを再構成した（Worker version `0f35f936-7e67-4a5b-ad2d-2e712048ac09`）。

- 詳細項目を「詳細を入力」へ畳み、保存をAppBarにも置いた（スクロール不要）。写真選択直後に商品名へフォーカス、カメラ/ライブラリの選択を記憶、保存後は「続けて撮る」で連続登録
- カテゴリは `POST /api/classify` で推定し、未選択のときだけ埋める。チップで1タップ修正できる
- 実APIでの確認（`gpt-5.6-luna`・推論なし・約1.4〜1.8秒）:
  - `レザースニーカー / adidas` → `shoes` + `sneakers`
  - `メンズ コットンTシャツ` → `tops` + `Tシャツ`
  - `フレアワンピース / SNIDEL` → **`all_in_one`**（後述のカテゴリ不足による）
- Worker Vitest 35 tests（カテゴリ推定の正常系・想定外enumの破棄・失敗系を追加）、Flutter 7 tests（カテゴリチップの選択状態を検証）
- 未確認: 実機での写真撮影〜保存の通し（エミュレータのメディア/カメラが不安定なため）

### 見つけた論点: ワンピース・スカートのカテゴリが無い

master-prompt §34 のカテゴリenumに「ワンピース」「スカート」が無いため、ワンピースは `all_in_one`（オールインワン）に寄せられた。実際には別物なので、enumに追加するか「その他」に倒すかを決める必要がある（§34の定義からの逸脱になるため保留）。

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
