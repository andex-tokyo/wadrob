-- 袖丈を属性として持たせる（任意）。カテゴリと直交する軸なので、カテゴリには混ぜない。
ALTER TABLE wardrobe_items ADD COLUMN sleeve TEXT;
CREATE INDEX items_owner_sleeve ON wardrobe_items(user_id, sleeve);
