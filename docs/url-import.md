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

## 名前とブランドから探す (2026-09-13)

`POST /api/import/search` は商品名とブランドから商品ページの候補を返す。写真や手動で登録するとき、名前とブランドだけで写真・価格・カテゴリを取り込めるようにするための入口。

- OpenAI Responses の `web_search` ツールを使い、**URLは推測させず検索結果に出たものだけ**を返す。取り込めないサイト（ログイン必須のSNS・動画・まとめサイト）だけを `filters.blocked_domains` で除外し、それ以外は幅広く探す
- 廃番・完売の商品を救うため、**中古・リユース（メルカリ、Yahoo!オークション、2nd STREET、ZOZO USED）やブランド公式**も候補に含める。候補は最大8件

### 商品画像の候補（2026-09-13）

JSON-LDとOGPは商品画像を1枚しか持たないことが多く、実ページにはギャラリーがある。
そのため `collectPageImages()` で商品画像を最大40枚集め、JSON-LD/OGPの画像を先頭に足して候補にする。収集元は次の2つ。

- DOMの `<img>`（`src` / `data-src` / `data-original` / `srcset`）
- HTML全体のテキスト。ギャラリーがJS/JSONの中にだけ相対URLで入っているショップ（楽天の旧テンプレート等）に対応する

- 装飾・UI・プレースホルダ（sprite / logo / icon / banner / btn / blank / designAssets / elements / symbols / assets など）と、静的アセット配信ホスト（`s.yimg.jp` 等）は除外
- 小さいサムネイル表記（`_50` `_100` `_150` `_300` `_thumb` 等）は除外し、`_500` や `_12` のような商品画像は残す
- 同一パスは重複除去。URLは推測せずDOMにあるものだけを使う
- 実測（従来はいずれもJSON-LD/OGPの1枚のみ）

| ショップ | 従来 | 現在 |
| --- | --- | --- |
| Yahoo!ショッピング（ZOZO店） | 1 | 28〜34（同一商品のみ） |
| 楽天市場 | 1 | 26 |
| UNIQLO | 1 | 22（全て商品画像） |
| WEAR（商品ページ） | 1 | 40 |
| andST（dot-st.com） | 1 | 2 |

候補は最大40枚。**商品のトークン**（URLや既知の画像に含まれる、数字を含む5文字以上の英数字。`106137321b`、`yctops82`、`465185` のような型番も拾う）と一致する画像を優先し、一致が5枚以上なら他（関連商品・ナビゲーション）を落とす。

判定するときはパス区切りを意識する。たとえば `/AsianCommon/` を `/common/` の除外ルールで消してしまう事故を防ぐ。UNIQLOのように関連商品が181枚並ぶページでも、その商品の画像だけが残る。

### 内容が薄いページの取り直し（2026-09-13）

JS描画のページやbot対策で内容が薄い場合、決定的解析の結果（名前の有無・画像枚数）でスコアを見て、**Browser Runで描画した結果のほうが良ければ差し替える**。描画結果は常にページの内容のみを根拠にし、URLや値の推測はしない。
- 返した候補はクライアントが既存の `POST /api/import/url` に渡すため、抽出は決定的解析 + 既存AI補助の経路を通る（検索結果をそのまま信用しない）
- 1回あたり Web検索 $0.01 + トークン、実測5〜6秒。候補が0件でも失敗にせず、URL手入力へ案内する
- AI呼び出しは一時的なネットワーク障害やrate limitを最大3回まで短く再試行する。未完了・拒否・JSON schema不一致は失敗として扱い、quota・billingエラーは再試行しない。API入口は認証ユーザー単位で20回/分に制限する
