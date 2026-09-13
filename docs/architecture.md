# Architecture
Flutter → HTTPS Hono Worker → D1 (source of truth) / private R2。Google ID tokenはWorkerでJWKS検証し、7日JWTを発行。FlutterはSecure Storageに保存する。Driftはユーザー別スナップショットを保持し、表示後に同期。書込みはオンラインのみ。

Feature-first UI、共有Api/Session/Cache、URL subsystem (safe fetch / parser / optional AI)、ImageProcessor interfaceを使用。画像は原本保存後に非同期処理。D1は所有者スコープのprepared statementを使用する。画像配信も認証必須。
