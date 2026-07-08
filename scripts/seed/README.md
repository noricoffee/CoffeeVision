# beanProfiles seed（豆ナレッジ初期データ）

Firestore `beanProfiles` コレクション（サービス管理 / クライアント read-only）への初期データ投入スクリプト。データ本体は `bean-profiles.json`（主要産地網羅 38 件）。表記規約・flavorNotes 統一語彙の正本は [`docs/data-model.md`](../../docs/data-model.md) §3.2。

## 検証（鍵不要）

```sh
node seed-bean-profiles.mjs --dry-run
```

必須フィールド / `processings` の enum 名 / `flavorNotes` の統一語彙 / `beanId` の重複・書式をチェックする。firebase-admin のインストールは不要。

## 本番投入（ユーザー作業）

1. [Firebase Console](https://console.firebase.google.com/project/coffeevision-a54aa/settings/serviceaccounts/adminsdk) → プロジェクトの設定 → サービスアカウント → 「新しい秘密鍵の生成」で JSON 鍵を取得（**リポジトリにコミットしない**。`*service-account*.json` は .gitignore 済み）
2. 依存をインストールして実行:

```sh
cd scripts/seed
npm install
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json node seed-bean-profiles.mjs
```

ドキュメント ID = `beanId` の `set()` による冪等 upsert なので、データ修正後の再実行は安全（上書き更新）。ドキュメントの削除はしないため、JSON から項目を消した場合は Firebase Console で手動削除する。

## 投入後の確認

実機の分析タブ「好みの豆の傾向」/「未経験の豆への探索提案」、エディタの産地サジェストに反映されること（`docs/tasks/verification-checklist.md` の 15-E-3 項目）。アプリはメモリキャッシュ（one-shot get）のため、投入後はアプリを再起動する。
