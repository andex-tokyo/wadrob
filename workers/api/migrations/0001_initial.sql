PRAGMA foreign_keys = ON;
CREATE TABLE users (id TEXT PRIMARY KEY, google_sub TEXT NOT NULL UNIQUE, email TEXT NOT NULL, display_name TEXT, photo_url TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL);
INSERT INTO categories VALUES ('outerwear','アウター',0),('tops','トップス',1),('shirts','シャツ',2),('knitwear','ニット',3),('pants','パンツ',4),('denim','デニム',5),('setup','セットアップ',6),('all_in_one','オールインワン',7),('shoes','シューズ',8),('bags','バッグ',9),('accessories','アクセサリー',10),('other','その他',11);
CREATE TABLE item_groups (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), name TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(id,user_id));
CREATE TABLE wardrobe_items (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), name TEXT NOT NULL,
 brand TEXT, category TEXT REFERENCES categories(id), sub_category TEXT, original_color TEXT, normalized_color TEXT,
 size TEXT, list_price INTEGER CHECK(list_price>=0), purchase_price INTEGER CHECK(purchase_price>=0), currency TEXT NOT NULL DEFAULT 'JPY',
 purchased_at TEXT, product_code TEXT, sku TEXT, shop_name TEXT, source_url TEXT, description TEXT,
 status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','archived')), group_id TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 FOREIGN KEY(group_id,user_id) REFERENCES item_groups(id,user_id)
);
CREATE INDEX items_owner_status ON wardrobe_items(user_id,status,created_at);
CREATE INDEX items_owner_category ON wardrobe_items(user_id,category);
CREATE INDEX items_owner_color ON wardrobe_items(user_id,normalized_color);
CREATE INDEX items_owner_brand ON wardrobe_items(user_id,brand);
CREATE INDEX items_owner_source ON wardrobe_items(user_id,source_url);
CREATE TABLE item_images (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), item_id TEXT REFERENCES wardrobe_items(id) ON DELETE CASCADE,
 original_url TEXT NOT NULL, display_url TEXT, thumbnail_url TEXT, original_source_url TEXT,
 source TEXT NOT NULL CHECK(source IN ('upload','product_url','manual')),
 processing_status TEXT NOT NULL DEFAULT 'pending' CHECK(processing_status IN ('none','pending','processing','completed','failed')),
 sort_order INTEGER NOT NULL DEFAULT 0, is_primary INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
);
CREATE INDEX images_item ON item_images(item_id,sort_order);
CREATE INDEX images_owner ON item_images(user_id);
