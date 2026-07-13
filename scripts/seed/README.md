# Firestore seed スクリプト

Firestore へのデータ投入スクリプト置き場。いずれも Admin SDK 使用（サービスアカウント鍵が必要、鍵は非コミット）、ドキュメント ID 固定の `set()` による冪等 upsert（再実行 = 上書き更新）、`--dry-run` はバリデーションのみで firebase-admin 不要。

## 共通: サービスアカウント鍵の取得（ユーザー作業）

1. [Firebase Console](https://console.firebase.google.com/project/coffeevision-a54aa/settings/serviceaccounts/adminsdk) → プロジェクトの設定 → サービスアカウント → 「新しい秘密鍵の生成」で JSON 鍵を取得（**リポジトリにコミットしない**。`*service-account*.json` は .gitignore 済み）
2. `cd scripts/seed && npm install`

---

## beanProfiles seed（豆ナレッジ初期データ）

`beanProfiles` コレクション（サービス管理 / クライアント read-only）への初期データ投入。データ本体は `bean-profiles.json`（主要産地網羅 38 件）。表記規約・flavorNotes 統一語彙の正本は [`docs/data-model.md`](../../docs/data-model.md) §3.2。

```sh
# 検証（鍵不要）: 必須フィールド / processings の enum 名 / flavorNotes の統一語彙 / beanId の重複・書式
node seed-bean-profiles.mjs --dry-run

# 本番投入
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json node seed-bean-profiles.mjs
```

- ドキュメント ID = `beanId`。JSON から項目を消した場合は Firebase Console で手動削除する
- 投入後の確認: 実機の分析タブ「好みの豆の傾向」/「未経験の豆への探索提案」、エディタの産地サジェスト（`docs/tasks/verification-checklist.md` の 15-E-3 項目）。アプリはメモリキャッシュ（one-shot get）のため、投入後はアプリを再起動する

---

## coffees seed（エクスポート JSON の開発用投入）

アプリのエクスポート JSON（設定 → データのエクスポート。`{ exportedAt, version: 1, records: [] }`）を `users/{uid}/coffees` へ投入する開発用スクリプト。エクスポートしたデータの再投入・別アカウントへの付け替え投入・手書きダミーデータの投入に使う。

```sh
# 検証（鍵不要）: envelope v1 / 必須フィールド / enum 名 / 日付形式 / id 重複 + 変換サンプル表示
node seed-coffees.mjs --dry-run export.json

# 本番投入
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json \
  node seed-coffees.mjs --uid <firebase-auth-uid> export.json
```

- `--uid` は投入先の Firebase Auth uid（Firebase Console → Authentication で確認）。**全レコードの `userId` をこの値で上書き**するので、別アカウントのエクスポートもそのまま投入できる
- ドキュメント ID = `record.id`。Firestore 直列化規則（[`docs/data-model.md`](../../docs/data-model.md) §`users/{uid}/coffees`）へは投入時に変換する: null フィールドはキーごと省略 / `createdAt`・`updatedAt` は Timestamp 化 / **photos は常に空配列**（画像ファイルは端末ローカルのみのため、メタデータだけ投入しても解決できない）
- 投入後は実機のサインイン中リスナーが自動反映する（アプリ起動中なら即時、未起動なら次回起動時。再インストール不要）
- 投入したレコードは通常のレコードとして全端末に同期される。消したくなったら Firebase Console かアプリから削除する
