-- ニットをトップスへ統合し、つなぎ系もトップスへ寄せる。
UPDATE wardrobe_items
   SET category = 'tops',
       sub_category = COALESCE(NULLIF(sub_category, ''), 'ニット')
 WHERE category = 'knitwear';

UPDATE wardrobe_items
   SET category = 'tops',
       sub_category = COALESCE(NULLIF(sub_category, ''), 'オールインワン')
 WHERE category = 'other'
   AND (
     name LIKE '%オールインワン%'
     OR name LIKE '%つなぎ%'
     OR name LIKE '%ジャンプスーツ%'
     OR name LIKE '%カバーオール%'
     OR lower(name) LIKE '%all-in-one%'
     OR lower(name) LIKE '%all in one%'
     OR lower(name) LIKE '%jumpsuit%'
     OR lower(name) LIKE '%coverall%'
   );

DELETE FROM categories WHERE id = 'knitwear';

UPDATE categories SET sort_order = 0 WHERE id = 'outerwear';
UPDATE categories SET sort_order = 1 WHERE id = 'tops';
UPDATE categories SET sort_order = 2 WHERE id = 'shirts';
UPDATE categories SET sort_order = 3 WHERE id = 'pants';
UPDATE categories SET sort_order = 4 WHERE id = 'suits';
UPDATE categories SET sort_order = 5 WHERE id = 'shoes';
UPDATE categories SET sort_order = 6 WHERE id = 'accessories';
UPDATE categories SET sort_order = 7 WHERE id = 'other';
