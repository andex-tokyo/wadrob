# WADROB（ワドロブ）
# Personal Digital Wardrobe
# Master Build Prompt

> 2026-09-13 改訂
> - アプリの表示名は **WDRB**（旧 WADROB）。リポジトリ名・Worker・applicationId は `wadrob` のまま
> - カテゴリをオーナーの実際の利用に合わせて調整（**スーツ追加 / デニム・セットアップ・バッグ・オールインワンを削除**）
> - **袖丈**を属性として追加（半袖 / 長袖 / ノースリーブ / 七分袖）
> - 経緯と判断は [decisions.md](decisions.md) の ADR-005 と [status.md](status.md) を参照

あなたは、このプロジェクトを設計・実装・テスト・UX仕上げまで担当する
シニアFlutterエンジニア兼Cloudflareアーキテクトです。

Flutter + Cloudflare を使用して、
デジタルクローゼットアプリ
「ワドロブ / WADROB」
をゼロから開発してください。

リポジトリは空の状態を前提とします。

PoC、画面モック、サンプルコードではなく、
実際にAndroid端末で日常利用できるMVPを完成させてください。

細かい実装判断で私への確認待ちを行わず、
合理的なデフォルトを選択して最後まで進めてください。

重要な設計判断のみ docs/decisions.md にADRとして記録してください。


==================================================
1. PRODUCT NAME
==================================================

正式名称:

ワドロブ


英字表記:

WADROB


WARDROBEをベースにした造語。


推奨内部名:

repository:
wadrob

Flutter app:
wadrob

Cloudflare Worker:
wadrob-api

D1:
wadrob-db

R2:
wadrob-images


日本語UIを第一言語とする。


==================================================
2. PRODUCT VISION
==================================================

WADROBは、

「自分が所有している服を、
ファッションECサイトのように美しく・高速に閲覧し、
購入した服をできるだけ少ない操作で登録できる」

デジタルクローゼットアプリ。


コンセプト:

「自分専用のファッションカタログ」


重要なのは、

- 持っている服が一目で分かる
- クローゼットを眺めること自体が気持ちいい
- 新しく買った服を簡単に登録できる
- 服が増えても探しやすい
- 画像の出所が違っても一覧が美しく見える

こと。


AIそのものをプロダクト価値の中心にしない。


==================================================
3. PRIORITIES
==================================================

設計・実装上のトレードオフが発生した場合は
以下の順に優先する。


1. クローゼット閲覧UX

2. 商品画像の統一感・見栄え

3. URLからの登録UX

4. 登録データの正確性

5. 検索 / Filter / Category browsing

6. Item Detail

7. 写真 / 手動登録

8. その他


機能数を増やすために
1〜3の品質を下げない。


==================================================
4. OUT OF SCOPE
==================================================

MVPでは以下を実装しない。


- AIコーデ提案
- AIスタイリスト
- AIレコメンド
- 類似アイテム推薦
- Fashion Profile
- AIによる服の特徴タグ付け
- 着用履歴
- 着用回数
- Cost Per Wear
- コーデ記録
- カレンダー
- SNS
- フォロー
- コメント
- いいね
- Wishlist
- 価格追跡
- 通知
- 課金
- クローゼット共有
- 公開プロフィール
- Role / Permission管理


OpenAI APIは、
商品URLから商品情報を抽出するときの
補助用途にのみ使用する。


==================================================
5. PRIMARY PLATFORM
==================================================

MVPのPrimary PlatformはAndroid。


完成条件として、

Android EmulatorまたはAndroid実機で
主要User Flowが実際に動作すること

を必須とする。


Flutterを採用するため、
可能な限りplatform-independentな実装とする。


ただしMVPでは以下をBlockerとしない。


- iOS実機確認
- iOS Google Sign-In設定
- iOS Provisioning
- App Store設定
- iOS build成功


iOS対応のために
Android MVPの完成を遅らせない。


==================================================
6. ANDROID DEFINITION OF DONE
==================================================

最低限Androidで以下を確認する。


1.
アプリ起動


2.
Google Sign-In


3.
初回ユーザー作成


4.
再起動後のSession復元


5.
クローゼット表示


6.
ローカルキャッシュからの即時表示


7.
Backend同期


8.
URL Import


9.
Item登録


10.
画像R2保存


11.
Wardrobe Grid表示


12.
Search


13.
Category Filter


14.
Advanced Filter


15.
Sort


16.
Item Detail


17.
Item編集


18.
Archive


19.
写真登録


20.
手動登録


21.
Logout


==================================================
7. TECHNOLOGY
==================================================

Frontend:

Flutter
Dart


推奨:

Riverpod
go_router
Dio
freezed
json_serializable
Drift
flutter_secure_storage
cached_network_image
image_picker
google_sign_in


Backend:

Cloudflare Workers
TypeScript
Hono

Cloudflare D1
Cloudflare R2
Wrangler


必要になった場合のみ:

Cloudflare Queues
Cloudflare Browser Rendering


AI:

OpenAI Responses API
Structured Outputs


OpenAIはURL Importの補助に限定。


==================================================
8. MONOREPO
==================================================

基本構成:


/
  apps/
    mobile/

  workers/
    api/

  docs/

  README.md


不要に複雑なMonorepo toolは導入しない。


==================================================
9. AUTHENTICATION
==================================================

認証方式はGoogle Sign-Inのみ。


対応:

Google Sign-In


対応しない:

Email / Password
Magic Link
Anonymous Login
独自Password
Apple Sign-In


Flutterでは
google_sign_in packageを使用。


==================================================
10. GOOGLE AUTH FLOW
==================================================

Android:

Google Sign-In

↓

Google ID Token取得

↓

POST /api/auth/google

↓

Cloudflare WorkerがGoogle ID Token検証

↓

Userを取得
または初回作成

↓

WADROB Session発行

↓

以降のAPIではWADROB Sessionを使用


Google ID Tokenを
Clientから受け取っただけで信用しない。


Backendで最低限検証:

signature

iss

aud

exp


必要に応じて:

email_verified


Google Accountの安定した外部識別子として

sub

を使用。


emailをDB上の主Identityとして使用しない。


==================================================
11. APP SESSION
==================================================

Google ID Tokenを
すべてのAPI Requestへ直接付け続けない。


POST /api/auth/google

で認証成功後、
WADROB Session Tokenを発行する。


SessionはJWT等、
Cloudflare Workersで安全かつ単純に実装できる方式を採用。


Worker Secret:

SESSION_SECRET


Session expiration:

合理的な期間を設定。

初期値は7日程度でよい。


Flutter:

flutter_secure_storageへSession Tokenを保存。


App再起動:

保存Session
↓
GET /api/auth/me
↓
有効ならそのまま利用


Session期限切れ:

Google側の認証状態から
可能なら再認証
↓
新しいGoogle ID Token
↓
/api/auth/google
↓
Session再発行


頻繁にGoogle Login UIを表示しない。


==================================================
12. USER MODEL
==================================================

users table:


id

googleSub

email

displayName

photoUrl

createdAt

updatedAt


googleSub:

NOT NULL
UNIQUE


emailはIdentityとして扱わない。


==================================================
13. DATA OWNERSHIP
==================================================

所有データはuserIdに紐付ける。


wardrobe_items:

userId NOT NULL


item_groups:

userId NOT NULL


item_imagesは
WardrobeItem経由でownership判定してよい。


重要:

Clientから送信されたuserIdを
Authorizationには使用しない。


Authenticated Sessionから
BackendがuserIdを決定する。


例:

GET /api/items

は常に

authenticated user
のItemのみ取得する。


すべてのRead / Update / Deleteで
ownershipをBackend側で検証する。


==================================================
14. LOCAL CACHE AND USER
==================================================

Flutter側のDrift cacheも
認証ユーザーを考慮する。


異なるGoogle Accountへ切り替えた場合に
前ユーザーのWardrobeが表示されてはいけない。


方法は合理的なものを選択。


例:

local rowにuserIdを持たせる

または

account変更時にcacheをclearして再同期


実装方式はdocs/decisions.mdに記録。


==================================================
15. AUTH API
==================================================

最低限:


POST /api/auth/google


Request:

{
  "idToken": "..."
}


Response例:

{
  "token": "...",
  "expiresAt": "...",
  "user": {
    "id": "...",
    "email": "...",
    "displayName": "...",
    "photoUrl": "..."
  }
}


GET /api/auth/me


POST /api/auth/logout


Stateless JWTを使用する場合、
logoutはClient側Token削除中心でも構わない。


==================================================
16. AUTH SECURITY
==================================================

必須:


Google ID Token validation

Session signature validation

Session expiration validation

User ownership validation


Logへ絶対に出さない:

Google ID Token

Session Token

SESSION_SECRET

OPENAI_API_KEY


==================================================
17. LOCAL CACHE
==================================================

D1をSource of Truthとする。


Flutter側はDriftへCacheを持つ。


アプリ起動:

Session確認

↓

Drift cacheからWardrobe即表示

↓

background API sync

↓

最新snapshot取得

↓

Drift transaction update

↓

UI更新


クローゼットを見るだけなのに
毎回Network Loadingを待たせない。


高度なoffline syncは不要。


不要:

offline mutation queue

conflict resolution

complex sync engine


追加・編集・Archive・削除は
オンライン必須で構わない。


==================================================
18. MOST IMPORTANT SCREEN
==================================================

WADROBで最も重要なのは

クローゼット画面。


目標:

「服を管理するDB」

ではなく、

「自分の服だけが並ぶ
上質なファッションカタログ」。


機能がすべて動いていても
この画面が雑なら完成とはみなさない。


==================================================
19. FIRST IMPRESSION
==================================================

Login済みの場合、
起動直後に服が見えること。


不要:

Dashboard

Welcome page

統計Card

おすすめBanner

Hero Banner

説明中心Home


Loginが必要な場合のみ
Login Screenを表示。


Login後はWardrobeへ直行。


==================================================
20. VISUAL DIRECTION
==================================================

Keywords:

Minimal
Editorial
Fashion
Clean
Quiet
Premium


Base colors:

White
Off White
Near Black
Gray


UI自体を派手にしない。


商品写真そのものが
画面上の色になる設計。


避ける:

業務システム風

家計簿風

大量のMaterial Card

大量のBorder

強いShadow

Gradient主体

AIサービス風

Chat UI

カラフルすぎるUI


==================================================
21. VISUAL HIERARCHY
==================================================

優先順位:


1.
商品画像


2.
Brand


3.
Product Name


4.
補助情報


AppBar
Button
Chip
Icon
Border

が商品写真より目立たない。


==================================================
22. WARDROBE GRID
==================================================

クローゼット体験の中心。


Grid density:

2 columns
3 columns
4 columns


Android smartphone default:

2 columns


変更した密度は保存。


2列:

large image
brand
product name


3列:

image
brand
short product name


4列:

mostly image
必要ならbrand


==================================================
23. ITEM TILE
==================================================

一般的なMaterial Cardを並べない。


基本:


[ IMAGE ]

BRAND
Product Name


避ける:

常時表示Edit button

price badge

SKU

大量のtags

overflow menu常設

Card border

強いshadow


商品間の境界はWhitespaceで表現。


商品名:

最大2行。


==================================================
24. IMAGE CANVAS
==================================================

以下が混ざっても
一覧の統一感を崩さない。


公式EC画像

Mercari等のフリマ画像

自分で撮影した写真


共通Visual Canvasを使用。


基本候補:


Aspect ratio:
4:5


Fit:
contain


Background:
Off White / Very Light Gray


Padding:
normalized common margin


服全体が見えることを優先。


画像を大きく見せるために
袖や裾を不自然にcropしない。


==================================================
25. IMAGE STORAGE
==================================================

Originalと表示用を分ける。


item_images:


id

itemId

originalUrl

displayUrl

thumbnailUrl

originalSourceUrl

source

processingStatus

sortOrder

isPrimary

createdAt


source:

upload
product_url
manual


processingStatus:

none
pending
processing
completed
failed


==================================================
26. IMAGE PERSISTENCE
==================================================

登録確定した画像は原則R2へ保存。


外部EC画像URLへ
永久依存しない。


Import Previewでは
外部画像を一時表示して構わない。


Item登録確定時:

必要画像をR2へ保存。


==================================================
27. IMAGE NORMALIZATION
==================================================

商品画像を
共通Canvas上で整えて表示できるようにする。


最低限:

orientation normalization

auto crop

foreground bounding box

object centering

padding normalization

thumbnail generation


処理失敗で
Item登録を失敗させない。


==================================================
28. BACKGROUND REMOVAL
==================================================

自動背景除去 / 切り抜きに対応する。


ただし目的は、

「背景削除機能」

を提供することではなく、

Wardrobe Gridの見た目を整えること。


Originalは必ず保持。


成功:

processed imageをdisplay imageへ使用。


失敗:

originalへfallback。


ユーザーは後から、

元画像

処理済み画像

を切替可能にする。


高度なmanual mask editorは不要。


==================================================
29. IMAGE PROCESSOR
==================================================

背景除去方式を特定Providerへ
domain設計レベルで固定しない。


ImageProcessor abstractionを作る。


例:


ImageProcessor

NormalizationProcessor

BackgroundRemovalProcessor


実装時点で利用可能かつ
品質・保守性・コストのバランスが良い方式を選択。


外部Serviceを追加する場合は
docs/decisions.mdに理由を記録。


背景除去の実装が
MVP全体を大きく遅延させる場合でも、

image normalization

centering

padding normalization

thumbnail

は完成させる。


==================================================
30. ASYNC IMAGE PROCESSING
==================================================

画像処理完了を待たないと
Item登録できない設計は禁止。


理想:


Item saved

↓

Original表示

↓

Background processing

↓

Processed image完成

↓

Grid imageを自然に更新


大きなProcessing Screen不要。


==================================================
31. WARDROBE ITEM
==================================================

wardrobe_items:


id

userId

name

brand

category

subCategory

originalColor

normalizedColor

sleeve

size

listPrice

purchasePrice

currency

purchasedAt

productCode

sku

shopName

sourceUrl

description

status

groupId

createdAt

updatedAt


nullableを適切に許容。


最低限:

name

のみでも保存可能。


==================================================
32. PRICE MODEL
==================================================

必ず分離:


listPrice

purchasePrice


listPrice:

定価 / 通常販売価格


purchasePrice:

実際に支払った価格


例:


listPrice:
15400


purchasePrice:
2999


URLから取得した価格を
purchasePriceへ自動設定しない。


原則listPrice候補。


purchasePriceは
Userが確認する。


==================================================
33. COLOR
==================================================

分離:


originalColor

normalizedColor


例:


originalColor:
チャコールグレー


normalizedColor:
gray


normalized values:


black
gray
white
navy
blue
brown
beige
green
red
purple
yellow
orange
silver
gold
multi
other


表示:

originalColor優先


Search / Filter:

normalizedColor


==================================================
34. CATEGORY
==================================================

internal:


outerwear
tops
shirts
knitwear
pants
suits
shoes
accessories
other


Japanese UI:


アウター
トップス
シャツ
ニット
パンツ
スーツ
シューズ
アクセサリー
その他


将来的に追加しやすい構造。


2026-09-13 改訂:
オーナーの実際の利用に合わせて、
デニム・セットアップ・バッグ・オールインワンを削除し、
スーツを追加した。
ワンピース・スカートは追加しない。
理由と経緯は docs/decisions.md の ADR-005 を参照。


==================================================
35. SETUP / GROUP
==================================================

スーツやセットアップは、

ジャケット
パンツ

などを別Itemとして登録。


groupIdで関連付け可能。


2026-09-13 改訂:
セットアップ／オールインワンのカテゴリは削除したが、
上下を別ItemとしてgroupIdで紐付ける仕組みは
スーツのために残す。


==================================================
36. STATUS
==================================================

status:


active

archived


通常Wardrobe:

activeのみ。


「手放す」:

archive。


Filter:

手放した服


完全削除:

明示的操作のみ。


==================================================
37. APP BAR
==================================================

コンパクト。


例:


ワドロブ        Search   Filter


縦スペースを大量消費する
Large Headerを避ける。


==================================================
38. CATEGORY NAVIGATION
==================================================

Grid上部に軽量な横スクロール。


例:


すべて

アウター

トップス

シャツ

ニット

パンツ

スーツ

シューズ

アクセサリー


巨大Chipにしない。


カテゴリUIより服を目立たせる。


==================================================
39. SEARCH
==================================================

Search iconから
inline searchへ自然に遷移。


検索のためだけに
別Pageを作らない。


入力中に即時反映。


検索対象:


name
brand
category
subCategory
originalColor
normalizedColor
productCode
sku
shopName


日本語利用前提。


可能な範囲で
Drift側のLocal Searchを利用し、
入力ごとにNetwork Requestしない。


==================================================
40. FILTER
==================================================

Bottom Sheetを基本。


Filter:


brand
category
color
sleeve
size
status


複数条件指定可能。


Filter有効中:

小さなIndicator
または件数。


大量のChipを
Gridへ常時表示しない。


Clear All。


==================================================
41. SORT
==================================================

最低限:


最近追加

古い順

ブランド

購入価格

定価


独立Screen不要。


Menu / Bottom Sheet等で完結。


==================================================
42. SCROLL QUALITY
==================================================

重要。


禁止:


scroll jank

layout shift

画像load後のTile size変更

過剰rebuild


placeholder時点から
最終Image Canvasと同じサイズ。


Gridではthumbnailを使用。


Original高解像度画像を
大量decodeしない。


==================================================
43. GRID TO DETAIL
==================================================

Item tap:

Detail。


可能ならHero transition。


Grid image
↓
Detail image


が自然につながる。


Animationは短く静かに。


==================================================
44. SCROLL RESTORATION
==================================================

Detailから戻った場合、


scroll position

category

filter

sort

grid density


を保持。


Detailを見るたびに
Grid先頭へ戻る挙動は
重大なUX defect。


==================================================
45. ITEM DETAIL
==================================================

上部:

large product image


複数画像:

horizontal paging


その下:


Brand

Product Name


詳細:


Color

Size

Category

List Price

Purchase Price

Purchased Date

Product Code

SKU

Shop

Source URL


元URL:

商品ページを見る


操作:


編集

手放す

削除

画像表示切替

必要なら画像再処理


DeleteをPrimary CTAにしない。


==================================================
46. ADD ITEM
==================================================

追加操作は発見しやすくする。


ただし巨大FABで
商品画像を覆わない。


候補:

small / medium FAB

AppBar +


Tap:


1.
URLから追加


2.
写真から追加


3.
手動で追加


URLを最上位。


==================================================
47. URL IMPORT
==================================================

WADROBの主要機能。


Ideal Flow:


商品購入

↓

URLコピー

↓

WADROB

↓

URLから追加

↓

Paste

↓

自動解析

↓

Preview

↓

必要項目だけ修正

↓

Save


Keyboard入力を
できるだけ減らす。


==================================================
48. URL IMPORT API
==================================================

POST /api/import/url


Request:


{
  "url": "https://..."
}


このAPIでは
WardrobeItemを保存しない。


Import Previewを返す。


==================================================
49. URL IMPORT PIPELINE
==================================================

順序:


URL validation

↓

Page fetch

↓

schema.org Product JSON-LD

↓

Open Graph

↓

Twitter Card

↓

HTML metadata

↓

必要最小限のHTML本文抽出

↓

Deterministic merge

↓

必要な場合のみOpenAI

↓

Preview DTO


==================================================
50. DETERMINISTIC FIRST
==================================================

最初からOpenAIへ丸投げしない。


優先:


JSON-LD

Open Graph

HTML metadata

HTML


既に高信頼で取得できた値を
OpenAIに勝手に上書きさせない。


理由:


Accuracy

Latency

Cost

Hallucination prevention


==================================================
51. OPENAI ROLE
==================================================

OpenAI APIは

URL Importの補助のみ。


対象:


name

brand

category

subCategory

originalColor

normalizedColor

listPrice

currency

sku

productCode

shopName

description


Workerが取得した


JSON-LD

metadata

必要最小限の本文

必要であれば商品画像


を入力として使用。


URL文字列だけをOpenAIへ渡して
商品情報取得を丸投げしない。


==================================================
52. OPENAI OUTPUT
==================================================

Structured Outputsを使用。


不明な値:


null


存在しない情報を推測しない。


特に:


brand

price

sku

productCode

size


を根拠なく生成しない。


OpenAI障害時も、

JSON-LD / OGP / HTML

までの解析結果で
Previewを返す。


==================================================
53. OPENAI CONFIG
==================================================

モデル名をコードへ固定しない。


Worker Environment:


OPENAI_MODEL


Secret:


OPENAI_API_KEY


現在利用可能なOpenAI API仕様を
実装時点で公式documentationから確認して使用する。


==================================================
54. IMPORT PROVENANCE
==================================================

Preview DTOでは
各値のSourceを内部的に保持可能にする。


source:


json_ld

open_graph

html

ai

user


例:


{
  "brand": {
    "value": "HARE",
    "source": "json_ld",
    "confidence": 1.0
  }
}


UIへ常時表示する必要はない。


==================================================
55. IMPORT PREVIEW
==================================================

自動解析結果を
勝手にDB保存しない。


必ずPreview / Editor。


表示:


商品画像

Brand

Product Name

Color

Size

Category

List Price

Purchase Price

Purchased Date

Product Code

SKU

Shop


すべて編集可能。


特に:


size

purchasePrice

purchasedAt


はUser確認前提。


==================================================
56. IMPORT FAILURE
==================================================

解析失敗で
行き止まりにしない。


取得できた値を保持。


URLを保持。


そのまま手動Editorへ進める。


Network Errorでも
入力済み値を消さない。


==================================================
57. PAGE FETCHER
==================================================

抽象化:


PageFetcher


SimpleFetcher

BrowserFetcher


MVP:

SimpleFetcher優先。


JavaScript rendering必須サイトへ
後から対応可能にする。


必要なら
Cloudflare Browser Renderingを使用。


==================================================
58. PRODUCT PARSER
==================================================

Architecture:


ProductParser

GenericJsonLdParser

OpenGraphParser

GenericHtmlParser

SiteSpecificParser


将来的に:


ZozoParser

MercariParser

UniqloParser

GUParser

RakutenFashionParser


等を追加可能。


MVPでSite-specific parserを
大量に実装しない。


==================================================
59. PHOTO IMPORT
==================================================

Camera
または
Photo Library。


Flow:


Image select

↓

Original upload

↓

R2

↓

Image normalization

↓

Background removal when available

↓

Item Editor

↓

Save


OpenAI Visionで
服情報を推測しない。


入力補助:

既存ブランド候補

Category selector

Color selector


など通常UIを使う。


==================================================
60. MANUAL IMPORT
==================================================

完全手動登録可能。


最低限:


name


画像は任意。


その他Fieldはnullable。


==================================================
61. DUPLICATE DETECTION
==================================================

同じUserの同じsourceUrlが
既に存在する場合:


「この商品はすでに登録されている可能性があります」


warningを表示。


ただし保存は禁止しない。


理由:


色違い

サイズ違い

複数所有


があり得る。


==================================================
62. MAIN API
==================================================

Auth:


POST /api/auth/google

GET /api/auth/me

POST /api/auth/logout


Wardrobe:


GET /api/items

GET /api/items/:id

POST /api/items

PUT /api/items/:id

DELETE /api/items/:id

POST /api/items/:id/archive


Import:


POST /api/import/url


Images:


POST /api/images

POST /api/images/:id/process


Metadata:


GET /api/brands

GET /api/categories


必要なら合理的に整理してよい。


==================================================
63. API CONTRACT
==================================================

docs/api.mdへ
主要APIについて以下を定義。


Request schema

Response schema

代表JSON

Validation

Errors

Authentication


特に:


POST /api/auth/google

POST /api/items

PUT /api/items/:id

POST /api/import/url

POST /api/images


を詳細化。


==================================================
64. API ERROR
==================================================

統一形式:


{
  "error": {
    "code": "IMPORT_FAILED",
    "message": "商品情報を取得できませんでした",
    "requestId": "..."
  }
}


Stack TraceをClientへ返さない。


==================================================
65. DATABASE
==================================================

最低限:


users

wardrobe_items

item_images

categories

item_groups


Migration:

workers/api/migrations/


連番管理。


==================================================
66. DATABASE RULES
==================================================

日時:

ISO 8601 UTC


金額:

最小通貨単位integer


Index候補:


users.google_sub

wardrobe_items.user_id

wardrobe_items.status

wardrobe_items.category

wardrobe_items.normalized_color

wardrobe_items.brand

wardrobe_items.source_url

wardrobe_items.created_at


Foreign Key有効。


所有Item queryは
必ずuserIdでscope。


==================================================
67. ARCHIVE UX
==================================================

「手放す」

はarchive。


Detail:

手放す

↓

Confirm

↓

archive

↓

通常Gridから消える


Archived:

Filterから確認。


完全削除:

より明示的な操作。


Swipeだけで削除しない。


==================================================
68. LOADING UX
==================================================

Local Cacheあり:

即Grid。


大きなSpinner不要。


Cacheなし:

Grid Skeleton。


画像Placeholderも
最終Canvasと同じSize。


==================================================
69. ERROR UX
==================================================

Backend Sync Error:

Cache維持。


非侵襲的に:


「最新情報を取得できませんでした」


既存Wardrobeを隠さない。


Image Processing Error:

Originalへfallback。


URL Import Error:

Editorへ継続。


==================================================
70. PULL TO REFRESH
==================================================

対応。


Refresh中も
既存Gridを消さない。


更新成功後に差分反映。


==================================================
71. EMPTY STATE
==================================================

Wardrobeが0件:


まだ服がありません

URLや写真から追加できます


[ URLから追加 ]


Filter結果0件:


この条件の服はありません


[ 条件を解除 ]


説明を長くしない。


==================================================
72. ADD COMPLETION
==================================================

保存後に
「登録完了」専用Pageを表示しない。


Save

↓

Wardrobe

↓

新しいItem表示


軽いFeedbackは可。


Confetti等不要。


==================================================
73. UI STATE PERSISTENCE
==================================================

保存:


Grid density

Category

Filter

Sort


Search queryは必須ではない。


==================================================
74. ACCESSIBILITY
==================================================

Tap target:

48dp程度。


Text Scaling

Contrast

Semantics


を考慮。


==================================================
75. SHARE INTENT
==================================================

MVP必須:

URL Paste


将来的に:


Browser / EC App

↓

Share

↓

WADROB

↓

Import Preview


へ拡張可能な構造。


Android Share Intentは
本体完成を妨げない範囲なら
MVPに追加してもよい。


==================================================
76. ANDROID GOOGLE CONFIG
==================================================

READMEにAndroid Google Sign-In設定を
具体的に記載。


最低限:


Android applicationId

Signing certificate SHA fingerprint

Google Cloud OAuth configuration

Android OAuth Client

Backend verification用Client ID

必要なGradle / Manifest設定


Debug buildで
Google Sign-Inを実際に確認。


認証設定をTODOで放置しない。


==================================================
77. FLUTTER STRUCTURE
==================================================

Feature-first。


過剰なClean Architecture禁止。


例:


lib/

  app/

  core/
    api/
    auth/
    db/
    images/
    theme/
    models/
    widgets/

  features/

    authentication/

    wardrobe/

    item_detail/

    item_editor/

    url_import/

    photo_import/

    settings/


==================================================
78. OPENAI BOUNDARY
==================================================

OpenAI依存は
URL Import subsystem内に閉じ込める。


OpenAI停止時にも:


Authentication

Wardrobe閲覧

CRUD

Search

Filter

Sort

Archive

Photo Import

Manual Import

Deterministic URL Import


は動作する。


==================================================
79. URL SECURITY
==================================================

URL Importは
SSRF対策必須。


許可:


http

https


拒否:


localhost

loopback

private IP ranges

link-local

cloud metadata endpoints

file://

ftp://

その他scheme


Redirect先も再validation。


さらに:


timeout

redirect limit

maximum response size

Content-Type validation


を実装。


==================================================
80. IMAGE FETCH SECURITY
==================================================

外部商品画像取得にも
安全性制御を入れる。


scheme validation

response size limit

Content-Type validation

timeout


巨大画像による
memory exhaustionを防ぐ。


==================================================
81. PERFORMANCE
==================================================

特にWardrobe Gridを優先。


Thumbnail

Lazy loading

Image cache

Fixed canvas

Drift local query

不要なWidget rebuild回避

Original imageの大量decode禁止


画像処理は
UI threadをblockしない。


==================================================
82. TESTING
==================================================

Backend minimum:


Google auth token verification abstraction

Session validation

Authorization / ownership

CRUD

Archive

Search

Filter

Sort

Duplicate detection

URL validation

SSRF

JSON-LD parser

Open Graph parser

HTML parser

Import merge

OpenAI Structured Output validation

Image upload metadata

Image processing state


External Google/OpenAI callsは
Testでmock可能にする。


Flutter minimum:


Authentication state

Wardrobe Grid

Grid density

Cache-first display

Account change cache safety

Scroll restoration

Category navigation

Search

Filter

Sort

Item Detail

Item Editor

URL Import

Import Preview

Photo Import

Archived Filter

Image fallback


==================================================
83. ANDROID TEST / BUILD
==================================================

最低限成功させる:


dart / flutter format

flutter analyze

flutter test

flutter build apk


可能なら:


flutter build appbundle


さらにAndroid Emulatorまたは
実機で主要Flowを確認。


単にbuild成功だけで
完成扱いしない。


==================================================
84. DOCUMENTATION
==================================================

作成:


docs/product.md

docs/architecture.md

docs/database.md

docs/api.md

docs/auth.md

docs/url-import.md

docs/images.md

docs/ux.md

docs/decisions.md


実装と乖離させない。


==================================================
85. README
==================================================

READMEだけで
新しい開発環境から起動できることを目指す。


記載:


Project overview

Architecture

Flutter setup

Android setup

Google Sign-In setup

Cloudflare setup

Wrangler

D1 setup

Migrations

R2 setup

OpenAI setup

Secrets

Local development

Tests

Android build

Cloudflare deploy


==================================================
86. CONFIG / SECRETS
==================================================

Cloudflare Secrets:


SESSION_SECRET

OPENAI_API_KEY


Environment:


GOOGLE_SERVER_CLIENT_ID

OPENAI_MODEL


Flutter config:


API_BASE_URL

GOOGLE_SERVER_CLIENT_ID


OAuth client configurationについては
Google / Androidの方式に合わせて
必要な設定を正しく分離する。


Secretの実値を
Repositoryへcommitしない。


==================================================
87. WARDROBE UX QUALITY GATE
==================================================

以下に1つでも該当する場合、
Wardrobe UIを完成扱いしない。


商品写真よりUI chromeが目立つ

商品画像が小さい

起動するたびNetwork待ち

Scroll jank

画像LoadによるLayout Shift

Detailから戻ると先頭へ戻る

Filterごとに別画面へ移動

EC画像と自撮り画像のサイズ感がバラバラ

Tileの情報量が多すぎる

Card / Shadow / Borderが多い

登録完了Pageを毎回挟む

Sync ErrorでWardrobeが消える

Image Processing ErrorでItem登録も失敗する


==================================================
88. WARDROBE UI REVIEW
==================================================

機能実装後、
Wardrobe画面だけを独立して再レビューする。


評価:


Visual hierarchy

Image consistency

Image scale

Whitespace

Typography

Grid density

Scroll smoothness

Category navigation

Search usability

Filter discoverability

Loading

Empty

Error

Grid → Detail

Detail → Back

Scroll restoration


最終判断:


「自分の服を眺めるために
このアプリを開きたくなるか」


基準を満たさない場合、
UIを再調整してから完成とする。


==================================================
89. DEFINITION OF DONE
==================================================

FLOW A — Authentication


App Launch

↓

Google Sign-In

↓

Backend verifies Google ID Token

↓

User creation / retrieval

↓

WADROB Session

↓

Wardrobe


----------------------------------------


FLOW B — Browse


App Launch

↓

Session restore

↓

Local CacheからWardrobe即表示

↓

Backend sync

↓

最新データ更新

↓

Category / Search / Filter / Sort

↓

Detail

↓

Back

↓

同じScroll Position


----------------------------------------


FLOW C — URL Import


URL Paste

↓

Page fetch

↓

JSON-LD / OGP / HTML

↓

必要な場合のみOpenAI

↓

Import Preview

↓

Edit

↓

Save

↓

Image R2 persistence

↓

Image normalization

↓

Wardrobe Grid


----------------------------------------


FLOW D — Photo Import


Camera / Library

↓

Original R2 upload

↓

Image normalization

↓

Background removal if available

↓

Editor

↓

Save

↓

Wardrobe Grid


----------------------------------------


FLOW E — Manual


Manual Add

↓

Editor

↓

Save

↓

Wardrobe


----------------------------------------


FLOW F — Archive


Detail

↓

手放す

↓

Archive

↓

通常Wardrobeから非表示

↓

Archive Filterでは表示


----------------------------------------


FLOW G — Logout / Login


Logout

↓

Local authenticated state解除

↓

別Google AccountでLogin可能

↓

前AccountのLocal Cacheが表示されない

↓

新UserのWardrobe Sync


==================================================
90. IMPLEMENTATION PROCESS
==================================================

このPromptを受け取ったら
確認待ちで停止しない。


まず:


1.
Product requirements整理


2.
Architecture


3.
Database schema


4.
Authentication design


5.
API contracts


6.
Wardrobe UX


7.
Implementation plan


をdocsへ作成。


その後そのまま実装。


推奨Phase:


1. Project foundation

2. Cloudflare / D1 / R2 foundation

3. Google Authentication

4. Flutter foundation / Theme

5. Wardrobe Grid

6. Drift local cache

7. CRUD / Detail / Editor

8. Search / Category / Filter / Sort

9. URL Import deterministic pipeline

10. OpenAI extraction fallback

11. Image persistence

12. Image normalization

13. Background removal / cutout

14. Android UX polish

15. Testing

16. Android build

17. Wardrobe UI final review


各Phaseで可能な限り:


format

lint

typecheck

test

build check


を実施。


壊れた状態を積み上げない。


==================================================
91. DO NOT DO
==================================================

禁止:


Mock画面だけで終了

Fake Backendだけで終了

AuthenticationをTODOで終了

OpenAI部分をTODOで終了

Memory DBだけで終了

大量の未使用Boilerplate

過剰なClean Architecture

不要なMicroservices

AIコーデ追加

Recommendation追加

SNS追加

着用履歴追加

大量の確認質問


==================================================
92. FINAL VERIFICATION
==================================================

完成後:


Flutter format

Flutter analyze

Flutter test

Flutter build apk

Worker lint

Worker typecheck

Backend tests

D1 migrations

Authentication flow

Authorization / ownership

Secret leakage

README


を確認。


可能なら:

flutter build appbundle


も実行。


Android EmulatorまたはAndroid実機で
主要User Flowを確認。


==================================================
93. FINAL REPORT
==================================================

最後に簡潔に報告:


実装した機能

Architecture

Authentication方式

Database構成

主要User Flow

Android動作確認結果

Cloudflare Deploy方法

Google OAuth設定方法

必要Secrets

OpenAI設定

画像処理方式

Tests / Build結果

既知の制約

今後改善可能な項目


==================================================
94. FINAL PRINCIPLE
==================================================

WADROBの主役は、

「ユーザーが持っている服」。


Google Sign-Inは
安全に所有データへアクセスするための基盤。


OpenAIは
URL登録を少し賢くする裏方。


画像処理は
所有服を美しく並べる裏方。


最重要なのは、

「ログイン後、
クローゼットを開いた瞬間に
自分の服が綺麗に並び、
触っていて気持ちいいこと」。


新機能によって
Wardrobe閲覧UXが悪化する場合は
機能を追加しない。


重大な技術的矛盾がない限り
私への確認待ちで停止せず、

設計
実装
テスト
Android動作確認
UI磨き込み

まで進め、

Androidで日常利用可能なMVPを完成させてください。
