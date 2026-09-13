# Authentication

1. FlutterがGoogle Sign-InでID tokenを取得する。
2. `POST /api/auth/google`へ送る。
3. WorkerがGoogle JWKSのRS256署名、issuer、Web OAuth client ID audience、expiration、email verificationを確認する。
4. Google `sub`で利用者を作成または更新し、7日有効のWADROB JWTを返す。
5. FlutterはJWTをSecure Storageへ保存し、再起動時に `GET /api/auth/me` で確認する。

APIはJWTのsubjectから所有者を決定する。クライアントのuserIdは受理しない。アカウント変更時はDriftと画像キャッシュを削除し、進行中の旧同期を世代番号で破棄する。
