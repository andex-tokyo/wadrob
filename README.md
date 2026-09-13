# WDRB（ワドロブ）

Flutter Android + Cloudflare Workers/D1/R2で動く個人用デジタルクローゼット。ローカルcacheから即表示し、Google Sign-In、所有権付きCRUD、URL取込、写真/手動登録、検索、filter、sort、archive、端末内画像正規化を備える。

アプリの表示名は **WDRB**。リポジトリ名・Worker・D1/R2・Android applicationId（`tokyo.andex.wadrob`）は既存のまま変更しない（Google OAuth の登録やリソース名に紐づくため）。アイコンとスプラッシュは白地に黒文字のワードマークで、`python3 tool/generate_brand_assets.py` で再生成できる。

## Requirements

- Flutter 3.44 / Dart 3.12、Android SDK、Java 17
- Node 22、Cloudflare account、Wrangler
- Google Cloud OAuth consent screen、Android OAuth client、Web OAuth client

## Cloudflare

```sh
cd workers/api
npm install
npx wrangler login
npx wrangler d1 create wadrob-db
npx wrangler r2 bucket create wadrob-images
```

本番環境ではD1 `wadrob-db`、R2 `wadrob-images`、Worker `wadrob-api` を作成済み。API URLは `https://wadrob-api.tsuchida.workers.dev`。再構築時は返されたD1 IDを `wrangler.jsonc` に設定してから:

```sh
npm run db:local
npx wrangler secret put SESSION_SECRET
# URL補助解析を使う場合だけ
npx wrangler secret put OPENAI_API_KEY
npm run deploy
```

`SESSION_SECRET` は32文字以上の乱数。`GOOGLE_SERVER_CLIENT_ID` はWeb OAuth client ID。`OPENAI_MODEL` は任意で既定は `gpt-5.6-luna`。OpenAI停止中も決定的URL解析と他機能は動く。ローカルでは `.dev.vars.example` を `.dev.vars` にコピーして値を入れ、`npm run dev`。

## Google Sign-In / Android

applicationIdは `tokyo.andex.wadrob`。debug署名fingerprintを確認:

```sh
cd apps/mobile/android
./gradlew signingReport
```

Google Cloud ConsoleでOAuth consent screenを設定し、Android clientにpackage名とSHA-1を登録する。別にWeb application OAuth clientを作り、そのClient IDをWorkerの `GOOGLE_SERVER_CLIENT_ID` とFlutterの同名dart-defineへ同じ値で渡す。releaseではrelease signing certificateのSHAもAndroid clientへ追加する。Firebaseは不要。

## Run and build

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787 --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
flutter test
flutter analyze
flutter build apk --release --dart-define=API_BASE_URL=https://wadrob-api.tsuchida.workers.dev --dart-define=GOOGLE_SERVER_CLIENT_ID=716602977800-6nmaih1hdrvvdp3498oclef4j8eeuo5j.apps.googleusercontent.com
flutter build appbundle --release --dart-define=API_BASE_URL=https://wadrob-api.tsuchida.workers.dev --dart-define=GOOGLE_SERVER_CLIENT_ID=716602977800-6nmaih1hdrvvdp3498oclef4j8eeuo5j.apps.googleusercontent.com
```

実機からlocal Workerを使う場合はPCのLAN IPまたは `adb reverse tcp:8787 tcp:8787` を使う。release APK/App BundleにはHTTPSのWorker URLを指定する。秘密値はFlutterへ入れない。

## Verification

```sh
./scripts/check.sh                    # worker + flutter の高速チェック
./scripts/check-release-apk.sh        # release APK のネイティブ依存検査
./scripts/smoke-device.sh [device-id] # 端末の画像正規化・SQLiteスモーク
```

検証は「ロジック（Flutterテスト）/ API（Workerテスト）/ OS・ネイティブ（端末スモーク）」の3層に分けている。詳細と現在地は [docs/status.md](docs/status.md)。push時は GitHub Actions が高速チェックと release APK 検査を実行する。

D1 migration: `npm run db:local`。実アカウント確認はWorker deploy、OAuth client作成、端末ログインが必要。

現在の進捗と残タスクは [status](docs/status.md) に集約している。詳細は [architecture](docs/architecture.md)、[API](docs/api.md)、[auth](docs/auth.md)、[images](docs/images.md)、[URL import](docs/url-import.md)、[UX](docs/ux.md)、[decisions](docs/decisions.md)。

## Current constraints

AI背景除去モデルは精度・サイズ・安定性の理由で削除済み。現在は端末内で向き補正、明るく均一な背景だけの保守的な整理、4:5への中央配置、サムネイル生成を行う。床・木目・カーペットなど背景が均一でない写真は構図を保って4:5へ正規化する。

検証結果は [verification record](docs/verification.md) を参照。
