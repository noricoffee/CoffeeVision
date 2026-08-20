---
name: sqldelight-migration-version-semantics
description: AppDatabase.Schema.migrate(driver, oldVersion, newVersion) のバージョン番号の実際の意味と、テーブル再作成型 migration をユニットテストで検証するときの構築手順
metadata:
  type: project
---

## `Schema.version` / `migrate()` のバージョン番号の実際の意味

`migrations/N.sqm` が `M` 個あるとき、生成される `AppDatabase.Schema.version` は **`M + 1`**
（baseline = version 1、`N.sqm` は「version N → N+1」への遷移を表す）。生成コードは各 `.sqm` を

```kotlin
if (oldVersion <= N && newVersion > N) { /* N.sqm の内容 */ }
```

という条件で実行する。つまり **`oldVersion == N` でも `N.sqm` は実行される**（`oldVersion <= N` が真になるため）。
「migration N まで適用済みの状態」を表すには `oldVersion = N + 1` を渡す必要がある（`oldVersion > N` にして
条件を偽にする）。例えば `.sqm` が 5 個ある場合、`.sqm` 5 個目だけを実行したいなら
`Schema.migrate(driver, 5L, 6L)` を呼ぶ（`4L, 5L` ではない。5.sqm 未満の migration が再実行され、
`ALTER TABLE ... ADD COLUMN` で `duplicate column name` エラーになる）。

## `Schema.migrate(driver, 0, N)` は空の DB に対して使えないことがある

`1.sqm` が `ALTER TABLE` のような「既存テーブルの変更」の場合、`migrate(driver, 0, N)` は
空の in-memory DB に対して `no such table` で失敗する（`1.sqm` は「アプリ最初期の baseline スキーマに
既に存在するテーブル」を前提にしており、その baseline 自体は `.sq`/`.sqm` のどこにも残っていない
— 現在の `.sq` ファイルは常に「最新（head）」を表し、過去のバージョンのスナップショットは持たない）。

**対策**: 特定の中間バージョン（例: 直前の migration 適用後の状態）を再現したいときは、
`Schema.migrate` に頼らず、その時点のテーブル定義を**生 DDL で直接 `driver.execute()` して構築する**
（`CoffeeRecordMigration5Test.kt` の `createV4Schema()` 参照）。

## テーブル再作成型 migration（NOT NULL 撤廃等）で FK を壊さない書き方

SQLite は「列の NOT NULL 撤廃」の ALTER をサポートしないため、公式手順どおり
CREATE 新テーブル → INSERT SELECT → DROP 旧テーブル → RENAME → インデックス再作成、を
`PRAGMA foreign_keys=0` / `PRAGMA foreign_keys=1` で挟む。

- SQLDelight の `.sqm` グラマは `PRAGMA foreign_keys=ON` / `=OFF`（キーワード）を受け付けない
  （`<pragma value real> expected, got 'ON'` でパースエラー）。**`0` / `1` の数値リテラルを使うこと**。
- `verifySqlDelightMigration` タスクはこのパースエラーも検出する（`:shared:data-local:verifySqlDelightMigration`）。

## iOS ターゲット（`NativeSqliteDriver` / sqliter）で同じテストを書く方法

`androidHostTest` の `JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)` に相当する「生ドライバ（スキーマ
自動管理なし）」は `NativeSqliteDriver` にも存在する。`app.cash.sqldelight:native-driver` の低レベル
コンストラクタ `NativeSqliteDriver(configuration: co.touchlab.sqliter.DatabaseConfiguration, maxReaderConnections: Int = 1)`
を使う（`schema:`/`name:` を渡す便利コンストラクタは DB 未作成時に必ず `schema.create()` = head スキーマを
直接構築してしまうため、中間バージョンの再現には使えない）。

```kotlin
val driver = NativeSqliteDriver(
    DatabaseConfiguration(
        name = "test.db",
        version = 1,
        create = { /* no-op: 生 DDL で自前構築するので何もしない */ },
        inMemory = true,
        extendedConfig = DatabaseConfiguration.Extended(foreignKeyConstraints = true),
    ),
)
```

以降は `driver.execute(null, "<DDL>", 0, null)` で v4 相当のテーブルを直接構築し、
`AppDatabase.Schema.migrate(driver, 5L, 6L)` を呼ぶ（`androidHostTest` 版と同じ手順）。
`co.touchlab.sqliter.DatabaseConfiguration` は `native-driver` の公開 API に露出しているため、
`iosMain.dependencies { implementation(libs.sqldelight.driver.native) }` があれば追加の依存宣言なしで
`iosTest` から import できる（transitively 解決される）。

**API 確認の裏取り方法**: Obj-C ヘッダも `.swiftinterface` も無い Kotlin/Native ライブラリの正確な
public API（コンストラクタのオーバーロード等）を確認するには、`~/.gradle/caches/modules-2/files-2.1/`
配下の `.klib` に対して `$KONAN_HOME/bin/klib dump-abi <path-to-klib>` を実行する。
シグネチャが型レベルで正確に得られる（`strings` で `.knm` を漁るより確実で速い）。

## サンドボックスでの `iosSimulatorArm64Test` 実行（2026-07-12 実績）

CLAUDE.md / 他エージェントのメモリには「sandbox 制約で `iosSimulatorArm64Test` は実行できない」とあるが、
今回 `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew :shared:data-local:iosSimulatorArm64Test`
は実際に成功した（`linkDebugTestIosSimulatorArm64` → `iosSimulatorArm64Test` まで完走、5 テストスイート全 green）。
環境によっては実行できる場合があるので、`compileTestKotlinIosSimulatorArm64` で満足せず、まず実行を試す価値がある
（失敗したら諦めて親に委ねる。1 回で判断する）。

## 関連

`sqldelight_migration_check.md`（`verifySqlDelightMigration` の基本）と併読。
