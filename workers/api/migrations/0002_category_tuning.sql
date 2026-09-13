-- 実際に使う服に合わせてカテゴリを調整する。
-- 削除: デニム / セットアップ / バッグ / オールインワン（ワンピースの受け皿）
-- 追加: スーツ
-- 既存itemが削除対象を持っていたら「その他」へ寄せてから消す。
UPDATE wardrobe_items SET category = 'other'
 WHERE category IN ('denim', 'setup', 'bags', 'all_in_one');

DELETE FROM categories WHERE id IN ('denim', 'setup', 'bags', 'all_in_one');

INSERT OR IGNORE INTO categories (id, name, sort_order) VALUES ('suits', 'スーツ', 5);

UPDATE categories SET name = 'アウター', sort_order = 0 WHERE id = 'outerwear';
UPDATE categories SET name = 'トップス', sort_order = 1 WHERE id = 'tops';
UPDATE categories SET name = 'シャツ', sort_order = 2 WHERE id = 'shirts';
UPDATE categories SET name = 'ニット', sort_order = 3 WHERE id = 'knitwear';
UPDATE categories SET name = 'パンツ', sort_order = 4 WHERE id = 'pants';
UPDATE categories SET name = 'スーツ', sort_order = 5 WHERE id = 'suits';
UPDATE categories SET name = 'シューズ', sort_order = 6 WHERE id = 'shoes';
UPDATE categories SET name = 'アクセサリー', sort_order = 7 WHERE id = 'accessories';
UPDATE categories SET name = 'その他', sort_order = 8 WHERE id = 'other';
