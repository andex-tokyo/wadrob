# WADROB 実装ステータス

最終更新: 2026-09-13

**このファイルが進捗の唯一の台帳。** 作業を進めたら同じ変更の中でここも更新する。モデルや担当が変わっても、まずこのファイルを読めば現在地と次の作業が分かるように保つ。

- 仕様・合格条件: [master-prompt.md](master-prompt.md)
- 検証の生ログ: [verification.md](verification.md)
- 設計判断（ADR）: [decisions.md](decisions.md)
- 個別仕様: [architecture.md](architecture.md) / [api.md](api.md) / [auth.md](auth.md) / [database.md](database.md) / [images.md](images.md) / [url-import.md](url-import.md) / [ux.md](ux.md)

状態の凡例: ✅ 完了（実機または本番で確認済み） / 🟡 実装済み（実データ・実機での確認が未） / ⬜ 未着手

## 環境

| 項目 | 値 |
| --- | --- |
| API | `https://wadrob-api.tsuchida.workers.dev` |
| Worker | `wadrob-api` 最新 version `f90b0b74-1e3b-4b59-9651-b15702ab0390`（2026-09-13、袖丈を追加） |
| D1 / R2 | `wadrob-db` / `wadrob-images`（Browser Run binding `BROWSER` あり） |
| AI | `gpt-5.6-luna`（`OPENAI_API_KEY` 登録済み、`reasoning.effort: none`） |
| 端末 | Pixel 6a エミュレータ（Android 36.1）、release APK インストール済み・Googleログイン済み |
| 署名 | **アップロード鍵で署名**（`~/keystores/wadrob-upload.jks`、`apps/mobile/android/key.properties` はgit管理外）。`key.properties` が無い環境はdebug鍵にフォールバック（CI用） |
| release APK | 2026-09-13 23:03 / 125.4MB |
| release AAB | 2026-09-13 23:02 / 95.2MB・アップロード鍵で署名済み |
| Play Console | アプリ `WDRB` / `tokyo.andex.wadrob` を作成済み（未公開）。「Android デベロッパーの確認」で鍵の登録待ち |

## 検証コマンド

```sh
./scripts/check.sh                    # worker + flutter の高速チェック（端末不要）
./scripts/check-release-apk.sh        # release APK の JNI クラス検査（R8対策）
./scripts/smoke-device.sh [device-id] # 端末のネイティブ経路（ONNX）スモーク
```

検証は **ロジック（Flutterテスト）/ API（Workerテスト）/ OS・ネイティブ（端末スモーク）** の3層に分ける。手動の端末E2Eはリリース前とネイティブ・認証・画像処理を触ったときだけ。push時は GitHub Actions が `check.sh` と release APK 検査を回す。

Workerのデプロイは `cd workers/api && npm run deploy`。端末で確認する場合は release APK を再ビルドして `adb install -r` する。

## Android Definition of Done（master-prompt §6）

| # | 項目 | 状態 | 根拠・補足 |
| --- | --- | --- | --- |
| 1 | アプリ起動 | ✅ | 実機起動（`wadrob-home.png`） |
| 2 | Google Sign-In | ✅ | 実アカウントで同意画面→ログイン後クローゼット表示（`wadrob-authenticated.png`） |
| 3 | 初回ユーザー作成 | ✅ | サインイン成功に含む（D1 `users`） |
| 4 | 再起動後のSession復元 | ✅ | APK再インストール後もサインイン状態を維持 |
| 5 | クローゼット表示 | ✅ | 0件の空状態を実機確認 |
| 6 | ローカルキャッシュからの即時表示 | 🟡 | キャッシュが空のため未確認 |
| 7 | Backend同期 | ✅ | 認証付き `GET /api/items` が成功（0件） |
| 8 | URL Import | ✅ | Yahoo!ショッピング / andST / ZOZOTOWN（ミラー）/ 楽天を実機確認 |
| 9 | Item登録 | ✅ | ZOZO商品を保存しD1へ登録されることを確認 |
| 10 | 画像R2保存 | ✅ | 原本保存→表示用/サムネイル生成→`processing_status=completed`、Grid表示まで確認 |
| 11 | Wardrobe Grid表示 | ✅ | 実データ1件で画像・ブランド・商品名の表示を確認 |
| 12 | Search | 🟡 | ローカル検索はユニットテストのみ |
| 13 | Category Filter | 🟡 | 実装済み、実データ未確認 |
| 14 | Advanced Filter | 🟡 | ブランド・カラー・サイズ・状態。実データ未確認 |
| 15 | Sort | 🟡 | 実装済み、実データ未確認 |
| 16 | Item Detail | ✅ | 実機で表示・元画像/整えた画像の切替を確認 |
| 17 | Item編集 | ✅ | 実機でサイズ=Mを入力して保存、D1に反映されることを確認 |
| 18 | Archive | ✅ | 実機で手放す→通常Gridから消える→「手放した服」フィルタに表示、を確認 |
| 19 | 写真登録 | 🟡 | 実装済み。エミュレータのメディアDBが壊れており**実機待ち**（アプリ側のアップロード処理まで到達を確認） |
| 20 | 手動登録 | 🟡 | 実装済み、実機未確認（数十秒で確認できる） |
| 21 | Logout | 🟡 | 実装済み、実機未確認 |

## フロー（master-prompt §89）

| フロー | 状態 | 補足 |
| --- | --- | --- |
| A 認証 | ✅ | 実アカウントで完走 |
| B 閲覧 | 🟡 | 同期まで確認。キャッシュ即表示・スクロール復元は実データで未確認 |
| C URL Import | ✅ | 取込とAI自動入力まで実機確認。R2保存のみ未確認 |
| D 写真 Import | 🟡 | 未確認 |
| E 手動 | 🟡 | 未確認 |
| F Archive | 🟡 | 未確認 |
| G Logout / アカウント切替 | 🟡 | キャッシュ分離の実機確認が未 |

## 実装済みの主要機能

- ブランド: 表示名 WDRB。白地に黒文字のワードマークで、アイコン（アダプティブ含む）とスプラッシュをログイン画面と同じ Roboto に統一。`tool/generate_brand_assets.py` で再生成できる
- 登録の入口: URL取込に加えて、**商品名とブランドから商品候補を探す**（`POST /api/import/search`）。候補を選ぶと既存の取込経路で写真・価格・カテゴリを取り込む。写真・手動登録でも同じ導線を使える
- 属性: **袖丈**（半袖/長袖/ノースリーブ/七分袖）をカテゴリと直交する軸として保持。フィルタとチップに対応。**サイズは表記ゆれを名寄せ**（M / Ｍ / Mサイズ / メンズM）
- 認証: Google ID token をWorkerでJWKS検証 → 7日JWT発行 → Secure Storage保存 → 再起動時 `GET /api/auth/me`
- データ: D1をSource of Truth、全クエリを `user_id` でスコープ。Driftのローカルキャッシュ（ユーザー別、logout時に全消去）
- クローゼット: 2/3/4列グリッド（密度保存）、カテゴリ横スクロール、インライン検索、複合フィルタ、ソート、Pull to Refresh、空状態・エラー時の非破壊表示
- 登録: URL取込（決定的解析 → 必要時のみAI）、写真（カメラ/ライブラリ）、手動
- URL取込: SSRF対策（リダイレクト毎の再検証・DNS・サイズ・Content-Type・タイムアウト）、charset判定（EUC-JP/Shift_JIS対応）、商品名・ブランド整形、重複警告
- 画像: 原本R2保存 → 端末内ONNXで背景除去 → 4:5正規化 → display/thumbnail をR2へ → 失敗時は原本へフォールバック、詳細で切替・再処理
- AI補助: `name` / `brand` / `category` / `subCategory` / `originalColor` / `normalizedColor` / `listPrice` / `currency` / `productCode` / `shopName`。決定的解析値を上書きしない

## テスト

| 対象 | 現在 | 要件（§82）との差 |
| --- | --- | --- |
| Worker（Vitest） | 37 tests | 認可・所有権、CRUD、Archive、検索/フィルタ/ソート、重複検知、画像メタデータ、処理状態、Google検証のモック、SSRFリダイレクト/DNS再検証が未（商品検索・カテゴリ／袖丈推定は追加済み） |
| Flutter | 10 tests | 認証状態、キャッシュ先行表示、アカウント切替の分離、スクロール復元、ソート、Detail、写真、Archive、画像フォールバックが未（URL取込・商品検索・チップ・サイズ名寄せは追加済み） |
| 端末スモーク（integration_test） | 2 tests | ONNX背景除去と4:5正規化。debug / profile で実行、releaseは `check-release-apk.sh` で代替 |

## テスト体制

端末を介した手動E2Eが遅く再現性も低いため、検証手段を3層に分けた。

| 層 | 対象 | 手段 |
| --- | --- | --- |
| ロジック | 検索・フィルタ・ソート・密度・キャッシュ先行表示・エディタ反映・ブランド名寄せ | Flutterのunit/widgetテスト（`scripts/check.sh`） |
| API・データ | URL取込・CRUD・archive・重複検知・画像ステートマシン | Worker Vitest（`scripts/check.sh`）。実HTTPの通しテストは未整備 |
| OS・ネイティブ | ONNX背景除去・画像正規化・写真/カメラ・Googleサインイン | `scripts/smoke-device.sh`（端末）。ピッカー系は実機 |

- release限定のリスク（R8がJNI参照クラスを削除）は `scripts/check-release-apk.sh` が数十秒で検出する。`flutter drive` は release 非対応のため、静的検査で代替している
- 写真・カメラはOSの外部UIのため自動化せず、実機で確認する
- 端末の手動操作は座標タップに依存して脆いので、繰り返す検証はテストへ移す方針

## 次にやること（優先順）

1. 手動登録・Logout → 再ログインを実機で確認して残りの🟡を潰す（短時間）
2. 写真・カメラ登録を実機で確認（エミュレータのメディアDBが壊れているため。`docs/verification.md` 参照）
3. 画像の背景除去・正規化の品質確認（白背景以外の床・木目・カーペットなど代表写真）
4. 実HTTPの通しテストをローカルWorker（`wrangler dev` + 発行したJWT）で整備し、API層を端末なしで検証できるようにする
5. §82 のテスト拡充（優先: 認可/所有権 → CRUD/Archive → 認証状態とキャッシュ系）
6. release署名は完了。**Google CloudのOAuthクライアントにアップロード鍵のSHA-1を追加**（Play配信用）→ Play Consoleの「Android デベロッパーの確認」でこの鍵を登録
7. Wardrobe UIレビュー（§87の品質ゲート／§88の観点）と記録
8. 小粒: セットアップの `groupId` UI（§35）、Share Intent（§75）、ミラー未掲載ZOZO商品の扱い

## 既知の制約

- ZOZOTOWN: `zozo.jp` 本体は403。商品IDが同一のYahoo!店へミラーして取得するため、**ミラー未掲載の商品は取り込めない**（Browser Runで描画しても「Access Denied」）
- 楽天: ページ構造により `listPrice` がnullのことがある
- andST（dot-st.com）: Product JSON-LDが無く、カラーはページに記載が無いとnull
- ワンピース・スカートは master-prompt §34 のカテゴリenumに無いため「その他」になる
- Browser Runの `quickAction()` はローカル開発では動作しない（デプロイ後のみ）

## 再発防止メモ

- workerdではグローバル `fetch` をフィールドへ代入して `this.request(...)` と呼ぶと `Illegal invocation` で失敗する。素の関数呼び出しにする（過去に本番のURL取込が全滅した原因）
- Browser Runは403のブロックページも成功レスポンスとして返す。`meta.status` とブロックページ判定で弾く
- 楽天などは EUC-JP。`decodeHtml()` を通さないと商品名が文字化けする
- 価格0は「未取得」として扱う。`purchasePrice`・`size`・`purchasedAt` はAIでも自動確定しない
- 秘密情報は `wrangler secret` へ。`OPENAI_API_KEY` / `SESSION_SECRET` をリポジトリへ書かない

## 更新履歴（新しい順）

- 2026-09-13: 配布用のアップロード鍵を作成し、releaseビルドに設定（`key.properties` はgit管理外）。AAB/APKを同鍵で再生成。Play Consoleの開発者確認に登録するSHA-1/SHA-256と公開鍵（.pem）を用意
- 2026-09-13: 袖丈（半袖/長袖/ノースリーブ/七分袖）を属性として追加（migration `0003_sleeve.sql`、可視チップ＋AI推定＋フィルタ）。サイズの表記ゆれを名寄せ（M/Ｍ/Mサイズ/メンズM）。master-prompt を改訂し、カテゴリ・袖丈・フィルタ・groupIdの記述を実装に合わせた
- 2026-09-13: カテゴリを実際に着る物へ調整（デニム・セットアップ・バッグ・オールインワンを削除、スーツを追加）。migration `0002_category_tuning.sql` をローカル・本番D1へ適用。ADR-005に記録
- 2026-09-13: 写真登録を短縮。エディタを「写真・商品名・カテゴリ・保存」中心に再構成し、詳細は折りたたみ、保存をAppBarにも配置、撮影直後に名前へフォーカス、写真ソースの記憶、保存後の「続けて撮る」を追加。カテゴリは `POST /api/classify` で自動推定し、チップで1タップ修正
- 2026-09-13: 商品名とブランドから商品候補を探す `POST /api/import/search` を追加（OpenAI web検索、許可ドメイン限定、URLは検索結果のみ）。エディタに「AIで商品を探す」を追加し、候補タップで写真・価格・カテゴリを取り込めるようにした。CIを並列化し、release APK検査はAndroid・依存の変更時のみ実行（8分21秒 → 通常2分台）
- 2026-09-13: アプリ表示名を WDRB に変更。アイコン（レガシー + アダプティブ）とスプラッシュ（Android 12+ のシステムスプラッシュ含む）を白地・黒文字のワードマークに統一し、書体をログイン画面と同じ Roboto w500 に揃えた。文字の光学中心ズレを修正（スプラッシュ中心 47.6% → 49.9%）
- 2026-09-13: 検証体制を3層に再編。`scripts/check.sh` / `check-release-apk.sh` / `smoke-device.sh` と GitHub Actions を追加。releaseのR8がONNXのJavaクラスを削除して保存直後にクラッシュする不具合を keep ルールで修正（`proguard-rules.pro`）。実機E2Eで 保存→R2→背景除去→詳細→編集→手放す まで確認
- 2026-09-13: 進捗台帳を新設し初回コミット。ZOZOTOWN対応（Yahoo!店ミラー + Browser Run）、URL取込の `Illegal invocation` 修正、charset判定、ブランド表記ゆれの正規化、AI抽出の項目拡張（`gpt-5.6-luna`）
