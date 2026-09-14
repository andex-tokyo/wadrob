# AGENTS.md

WADROB（Flutter + Cloudflare Workers）の作業ルール。担当エージェントが変わっても同じ手順で進めるための取り決め。

## 進捗管理（必須）

- **作業を始める前に [docs/status.md](docs/status.md) を読む。** 現在地と次の作業はここに集約している。
- **作業を終えたら同じ変更の中で [docs/status.md](docs/status.md) を更新する。** 該当項目の状態と根拠、末尾の「更新履歴」を直す。
- 状態は3段階。**実機または本番で確認できるまでは ✅ にしない**（🟡 実装済み / ⬜ 未着手）。
- 検証した結果は [docs/verification.md](docs/verification.md) へ日付つきで追記する。生の証跡（コマンド結果・スクリーンショット名・Worker version）を残す。
- 仕様は [docs/master-prompt.md](docs/master-prompt.md)、設計判断は [docs/decisions.md](docs/decisions.md) に書く。実装と乖離したら同じ変更で直す。

## 検証コマンド

変更を入れたら最低限これを通す（まとめて実行できる）。

```sh
./scripts/check.sh          # すべて
./scripts/check.sh worker   # Workerのみ
./scripts/check.sh app      # Flutterのみ
```

検証は3層に分かれている。**全部を端末E2Eでやらない。**

| 層 | 対象 | コマンド |
| --- | --- | --- |
| ロジック | 検索・フィルタ・ソート・キャッシュ・エディタ反映 | `./scripts/check.sh`（Flutter unit/widget） |
| API | CRUD・archive・import・画像ステート | `./scripts/check.sh`（Worker Vitest） |
| OS / ネイティブ | 画像正規化・SQLite・写真/カメラ・Googleサインイン | `./scripts/smoke-device.sh [device-id]`（実機/エミュレータ） |

- release ビルドは `flutter drive` が非対応なので、release特有のリスク（R8がJNI用クラスを消す等）は `./scripts/check-release-apk.sh` で静的に検査する。APKを作り直したら必ず通す。
- 端末E2Eを手で流すのは「リリース前」「認証・ネイティブ・画像処理を触ったとき」だけにする。座標タップでの手動操作は再現性が低いので、繰り返す検証はテストへ移す。
- GitHub Actions（`.github/workflows/check.yml`）は worker と app を並列実行し、release APK 検査は Android・依存が変わったときだけ実行する（毎回ビルドすると数分かかるため）。

Cloudflareへの反映は `cd workers/api && npm run deploy`。端末で確認する場合は release APK を再ビルドして `adb install -r` する（`--dart-define=API_BASE_URL=https://wadrob-api.tsuchida.workers.dev --dart-define=GOOGLE_SERVER_CLIENT_ID=...`）。

## 守ること

- 秘密情報（`OPENAI_API_KEY` / `SESSION_SECRET`）は `wrangler secret` に置く。リポジトリへ書かない・ログへ出さない。
- workerdではグローバル `fetch` をフィールドへ代入して `this.request(...)` と呼ぶと `Illegal invocation` で失敗する。素の関数呼び出しにする。
- 商品ページは EUC-JP / Shift_JIS があり得る。デコードは `decodeHtml()` を通す。
- Browser Run の `quickAction()` はローカル開発で動かない（デプロイ後のみ）。ブロックページを成功レスポンスとして返すため、403判定を必ず入れる。
- AIの抽出は決定的解析の後に回し、既存値を上書きしない。`purchasePrice`・`size`・`purchasedAt` はAIでも自動確定しない。
- 価格0は「未取得」として扱う。
- release APKの必須ネイティブライブラリと、削除済みONNXライブラリが再混入していないことは `scripts/check-release-apk.sh` で確認する。
- アプリ表示名は WDRB。アイコン・スプラッシュは `python3 tool/generate_brand_assets.py` で生成する（クローゼット見出しと同じRoboto・字間、`#FAFAF8` 地に `#252522` の文字）。applicationId とリソース名は変更しない。
