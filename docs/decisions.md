# Decisions
## ADR-001: 認証とキャッシュ
Google subを外部Identityとし、RS256 JWKS検証後、aud/iss/exp付きHS256 JWTを7日発行。クライアントuserIdは信用しない。Drift行はuserIdで分離し、logout時に全ローカル行を削除する。進行中同期は世代番号で無効化。
## ADR-002: 画像
原本はprivate R2。表示用画像を別キーに保存する。Android端末上のONNXセグメンテーションで服を切り抜くため、白背景に限らず床・木目・カーペットにも対応する。その後Dart isolateでorientation/foreground bounds/centering/padding/thumbnail処理を行う。ONNX処理が失敗した場合は保守的な境界処理、さらに失敗した場合は原本へフォールバックする。外部プロバイダを必須にしない。URL画像も原本アップロード後、端末から非同期処理する。端末モデルにより処理時間と精度は変わるため、詳細画面で原本と処理済み画像を切替可能にする。
## ADR-003: URL取得
リダイレクト毎にURLとDNSの公開アドレスを検証、サイズと時間を制限。Workerの公開ネットワークfetchを利用し、HTTP/HTTPSのみ許可。決定的parserを優先し、不足時にのみResponses Structured Outputsを使用。AIは既存値を上書きしない。
## ADR-004: 最小構成
Riverpodによる依存注入、Dio、Drift、Navigatorによる画面stackを採用。小規模アプリに不要なcode generation/model hierarchyを追加しない。

## ADR-005: カテゴリを実際に着る物に合わせる
master-prompt §34 のカテゴリ一覧は網羅的だが、オーナー（男性・個人利用）はデニム・セットアップ・バッグ・オールインワン（ワンピースの受け皿）を使わない。使わないカテゴリがナビゲーションとチップに並ぶと、閲覧と登録のどちらも遅くなるため、削除して「スーツ」を追加した。

最終的なカテゴリ: アウター / トップス / シャツ / ニット / パンツ / スーツ / シューズ / アクセサリー / その他。

削除したカテゴリを持つ既存itemは `other` へ寄せてから削除する（migration `0002_category_tuning.sql`）。ワンピース・スカートは追加しない。袖丈（長袖/半袖）はカテゴリと直交する属性なので、カテゴリには混ぜず別軸で扱う方針とする。
