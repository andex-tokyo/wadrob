# API

すべての `/api/*`（`POST /api/auth/google`を除く）は `Authorization: Bearer <session>` が必要。失敗は `{"error":{"code":"...","message":"...","requestId":"..."}}`。

## Authentication

- `POST /api/auth/google` — `{ "idToken": "..." }` → `{ token, expiresAt, user }`。ID token必須、最大10KB。
- `GET /api/auth/me` → `{ user }`。
- `POST /api/auth/logout` → `{ ok: true }`。端末側token削除が主体。

## Items

- `GET /api/items?status=active&category=&brand=&normalizedColor=&sleeve=&size=&search=&sort=recent` → `{ items }`。
- `GET /api/items/:id` → `{ item }`。
- `POST /api/items` / `PUT /api/items/:id` — 商品fieldと画像。`name`のみ必須。`sleeve` は `short|long|sleeveless|three_quarter`。金額は0以上の整数。通貨は3文字。URLはHTTP/HTTPS。
  - 画像は `images: [{id}|{url}, ...]` の**順序つき配列**で渡す。先頭がメイン画像（`is_primary=1`、`sort_order=0`）になり、URLの画像は保存時にR2へ取り込む。最大8枚。
  - `imageIds` / `imageUrls` も後方互換で受け付ける（`images` があればそちらを優先）。
- `POST /api/items/:id/archive` → `{ item }`。
- `DELETE /api/items/:id` → `{ ok: true }`。

代表登録: `{"name":"ウールコート","brand":"AURALEE","category":"outerwear","listPrice":88000,"purchasePrice":62000,"currency":"JPY","imageIds":["uuid"]}`。

## Import and images

- `POST /api/import/url` — `{ "url": "https://shop.example/item" }` → `{ sourceUrl, fields, draft, warnings, duplicate }`。保存しない。
- `POST /api/import/search` — `{ "name": "ウールコート", "brand": "AURALEE" }` → `{ query, candidates: [{ url, title, shop }] }`。OpenAIのweb検索で商品ページ候補を最大8件返す。URLは推測させず検索結果に出たものだけを返し、ログイン必須のSNS・動画・まとめサイトを `blocked_domains` で除外する。保存しない。
- `POST /api/classify` — `{ "name": "タートルネック ニット セーター", "brand": "classicalelf" }` → `{ category?, normalizedColor?, sleeve?, subCategory? }`。名前からカテゴリ・検索用カラー・袖丈を推定する。許可値のenumで拘束し、判断できない項目は返さない。保存しない。
- `POST /api/images` — JPEG/PNG/WebP binary、最大10MB → `{ image }`。
- `GET /api/images/:id/{original|display|thumbnail}` — 所有者のみ。
- `POST /api/images/:id/process` — multipartの `display` と `thumbnail`、または `status=processing|failed`。
- `GET /api/brands`、`GET /api/categories`。

AIを利用し得る `/api/import/*` と `/api/classify` は認証ユーザー単位で20回/分に制限する。超過時は `429 RATE_LIMITED`。OpenAIへの呼び出しは一時的なネットワーク障害と `408` / `409` / `429` / `5xx` を短い指数バックオフで最大3回まで再試行し、`Retry-After` が再試行予算内なら優先する。quota・billingエラー、未完了・拒否・不正な構造化出力は再試行せず各機能の失敗として扱う。
