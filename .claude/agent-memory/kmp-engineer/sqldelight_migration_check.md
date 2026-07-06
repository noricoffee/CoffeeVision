---
name: sqldelight-migration-check
description: SQLDelight の migrations/N.sqm と .sq 最終スキーマの整合を機械確認するタスク
metadata:
  type: project
---

新しい `migrations/N.sqm` を追加したとき（N は既存最大連番+1、`.sq` ファイルの `CREATE TABLE` /
`CREATE INDEX` と内容を一致させる必要がある）、以下のタスクで
「migration を N 回適用した結果」と「現在の `.sq` から生成した最終スキーマ」が一致するか
機械的に検証できる:

```
./gradlew :shared:data-local:verifySqlDelightMigration
```

内部的に `verifyCommonMainAppDatabaseMigration` を実行する。schema version は明示的な定数指定が
どこにも無く、`migrations/*.sqm` のファイル数から自動算出される（`DatabaseDriverFactory` 側に
バージョン番号を書く箇所は無い）。
