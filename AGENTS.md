# AGENTS.md

WADROB（Flutter + Cloudflare Workers）の作業ルール。担当エージェントが変わっても同じ手順で進めるための取り決め。

## 進捗管理（必須）

- **作業を始める前に [docs/status.md](docs/status.md) を読む。** 現在地と次の作業はここに集約している。
- **作業を終えたら同じ変更の中で [docs/status.md](docs/status.md) を更新する。** 該当項目の状態と根拠、末尾の「更新履歴」を直す。
- 状態は3段階。**実機または本番で確認できるまでは ✅ にしない**（🟡 実装済み / ⬜ 未着手）。
- 検証した結果は [docs/verification.md](docs/verification.md) へ日付つきで追記する。生の証跡（コマンド結果・スクリーンショット名・Worker version）を残す。
- 仕様は [docs/master-prompt.md](docs/master-prompt.md)、設計判断は [docs/decisions.md](docs/decisions.md) に書く。実装と乖離したら同じ変更で直す。

## 検証コマンド

変更を入れたら最低限これを通す。

```sh
cd workers/api && npm run typecheck && npm run lint && npm test
cd apps/mobile && dart format lib test && flutter analyze && flutter test
```

Cloudflareへの反映は `cd workers/api && npm run deploy`。端末で確認する場合は release APK を再ビルドして `adb install -r` する（`--dart-define=API_BASE_URL=https://wadrob-api.tsuchida.workers.dev --dart-define=GOOGLE_SERVER_CLIENT_ID=...`）。

## 守ること

- 秘密情報（`OPENAI_API_KEY` / `SESSION_SECRET`）は `wrangler secret` に置く。リポジトリへ書かない・ログへ出さない。
- workerdではグローバル `fetch` をフィールドへ代入して `this.request(...)` と呼ぶと `Illegal invocation` で失敗する。素の関数呼び出しにする。
- 商品ページは EUC-JP / Shift_JIS があり得る。デコードは `decodeHtml()` を通す。
- Browser Run の `quickAction()` はローカル開発で動かない（デプロイ後のみ）。ブロックページを成功レスポンスとして返すため、403判定を必ず入れる。
- AIの抽出は決定的解析の後に回し、既存値を上書きしない。`purchasePrice`・`size`・`purchasedAt` はAIでも自動確定しない。
- 価格0は「未取得」として扱う。
