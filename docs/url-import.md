# URL import

`POST /api/import/url` は保存せず編集可能なpreviewを返す。HTTP/HTTPS、資格情報なし、標準port、公開DNSのみを許可する。各redirectを再検証し、4回まで、12秒、HTML 2MB、画像10MB、許可Content-Typeに制限する。

抽出順はschema.org Product JSON-LD、Open Graph/Twitter、HTML。決定的解析で `category`、`normalizedColor` などの項目が埋まらず、API keyがある場合に限りOpenAI Responses Structured Outputsを呼ぶ。対象は `name`、`brand`、`category`、`subCategory`、`originalColor`、`normalizedColor`、`listPrice`、`currency`、`productCode`、`shopName`。`category` と `normalizedColor` は許可値のenumで拘束し、判断できない場合はnullを返させる。

ページ本文は信頼しない入力として扱い、明記された値だけを抽出する。決定的解析で得た高信頼の値はAIに上書きさせない（`mergeFields`の先勝ち）。商品名・ブランドは装飾や末尾の店名（`og:site_name`と一致する区切り以降）を除去して整える。失敗時もURLを維持して手動編集へ進み、`warnings` に理由を残す。取得価格は `listPrice` 候補で、`purchasePrice`、`size`、`purchasedAt` はAIでも自動確定しない。

モデルは `OPENAI_MODEL` で指定する（既定は `gpt-5.6-luna`、`reasoning.effort: none`）。`OPENAI_API_KEY` 未設定時は決定的解析のみで動作する。

## 実サイトでの確認 (2026-09-13)

| サイト | 取得 | 結果 |
| --- | --- | --- |
| Yahoo!ショッピング | 可 | JSON-LD Product + Breadcrumb を取得。カテゴリ・カラー・定価まで自動入力できる |
| andST（dot-st.com） | 可 | Product JSON-LD は無く OGP のみ。商品名・ブランド・カテゴリはAIで補完できる。カラーはページに記載が無いと null |
| 楽天市場 | 可 | 商品ページは EUC-JP。文字コード判定が必須 |
| ZOZOTOWN（zozo.jp） | 可（ミラー経由） | zozo.jp本体は403。同一商品IDのZOZOTOWN Yahoo!店へ自動で切り替えて取得する |

ZOZOTOWNの商品は `store.shopping.yahoo.co.jp/zozo/<商品ID>` にも同一IDで出品されている。`/shop/<shop>/goods/<id>/` 形式のURLは自動でこのミラーへ切り替える。ミラーに無い商品はCloudflare Browser Runで描画を試み、それでも取得できなければ手動入力へフォールバックする。

### 取得の優先順位

1. `SimpleFetcher`（通常のfetch）
2. ZOZOTOWNの商品URLのみ `MirroredFetcher`（Yahoo!店の同一商品）
3. `BrowserFetcher`（Cloudflare Browser RunでJavaScriptを描画。`quickAction("content")`）

Browser Runの描画結果が403や「Access Denied」のブロックページだった場合は取得失敗として扱う。

### 実装上の注意

- グローバル `fetch` をフィールドへ代入して `this.request(...)` と呼ぶと、workerd では `Illegal invocation` で失敗する。必ず素の関数呼び出しとして実行する。
- 文字コードは `Content-Type` の charset、次に `<meta charset>` の順で判定する。EUC-JP / Shift_JIS / ISO-2022-JP は workerd の `TextDecoder` で扱える。
- 0円の価格は「未取得」として扱う。取得価格（`purchasePrice`）と購入日はAIでも自動確定しない。
- Browser Runのbindingは `wrangler.jsonc` の `browser` で設定する。`quickAction()` は `compatibility_date` 2026-03-24 以降が必要で、ローカル開発では動作しない（デプロイ後のみ）。
