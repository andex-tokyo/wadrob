# Database

D1を正本とする。`users` はGoogle `sub`を一意キーにし、`wardrobe_items`、`item_groups`、`item_images` はすべて所有者IDを持つ。画像の所有権は画像行でも検査する。日時はISO 8601 UTC、金額は最小通貨単位の整数。

主要テーブルは `users`、`categories`、`wardrobe_items`、`item_groups`、`item_images`。検索対象列と `user_id/status` に索引を持つ。初期schemaとカテゴリseedは `workers/api/migrations/0001_initial.sql`。

カテゴリはオーナーの実際の利用に合わせて `0002_category_tuning.sql` で調整済み: アウター / トップス / シャツ / ニット / パンツ / スーツ / シューズ / アクセサリー / その他（デニム・セットアップ・バッグ・オールインワンは削除）。

袖丈は `0003_sleeve.sql` で `wardrobe_items.sleeve` を追加（任意・`user_id/sleeve` に索引）。値は 半袖 / 長袖 / ノースリーブ / 七分袖。カテゴリと直交する属性として扱い、カテゴリには混ぜない。
