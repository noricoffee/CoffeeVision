---
name: coffee-record-column-addition
description: CoffeeRecord に nullable TEXT 列を1つ追加する（cup と同型の属性追加）ときの全ファイル一覧と、見落としやすい LocalCoffeeRepository の upsert() 呼び出し・export DTO/Mapper 追随
metadata:
  type: project
---

`CoffeeRecord.brewRecipe`（フェーズ 15-E-1）で実施した、既存 nullable TEXT 属性と同型のカラムを
追加するときの一連の変更箇所。同じパターンの次回作業でチェックリストとして使う。

## 触るファイル一覧

1. `shared/domain/.../CoffeeRecord.kt` — data class にフィールド追加（デフォルト値なし。既存の `cup` と
   同じ扱いに揃えるなら default を付けない方が docs の記述と一致する）
2. `shared/data-local/.../sqldelight/com/noricoffee/db/CoffeeRecord.sq` — カラム定義 + `upsert` の
   列リスト・VALUES のプレースホルダ数を +1
3. `shared/data-local/.../sqldelight/migrations/N.sqm`（既存最大連番+1）— `ALTER TABLE ... ADD COLUMN`
4. `shared/data-local/.../db/Mapper.kt` — `toRow()` / `toDomain()` 両方
5. **`shared/data-local/.../repository/LocalCoffeeRepository.kt` の `save()` 内 `coffeeRecordQueries.upsert(...)`
   呼び出し** — ここが最も見落としやすい。`Mapper.toRow()` で `Coffee_record` オブジェクトの生成は直しても、
   `LocalCoffeeRepository.save()` は SQLDelight 生成の `upsert` 関数を **named parameter で 1 つずつ**
   呼んでいるため、`row.toRow()` を直しただけでは `row.brew_recipe` を upsert 呼び出しに渡す行が
   自動生成されない。`compileKotlinIosSimulatorArm64` で `No value passed for parameter 'brew_recipe'` として検出される
6. `shared/data-firebase/androidMain/.../CoffeeFirestoreMapper.kt` — `toDocument`（`?.let { doc[...] = it }`）
   と `fromDocument`（`data["..."] as? String`）の両方 + docstring のフィールド列挙コメント
7. `shared/feature/coffee-editor/.../CoffeeEditorViewModel.kt` — `CoffeeDraft` フィールド、
   `on<Field>Changed`、`validate()`、`buildRecord()`、`defaultDraft()`、`toDraft()`、
   （複製要件があれば）`toDuplicateDraft()` と `Mode.Duplicate` の docstring 2 箇所
   （sealed interface 側と private 拡張関数側、両方に同じ列挙文言がある）
8. `shared/core/.../dev/DummyCoffeeData.kt` — `RawData` にフィールド追加（`= null` デフォルト推奨。
   既存 30 件の呼び出しを全部触らずに済む）
9. **`shared/domain/.../domain/export/CoffeeRecordExportDto.kt` + `CoffeeRecordExportMapper.kt`**
   （要件 §7-4 / `data-model.md` §8）— 2026-07-22 の `region` 追加ではここだけ追随漏れし、無言のデータ
   欠損（2026-07-25 に `docs/data-model.md` 棚卸しで発覚・修正）。DTO の `data class` にフィールド追加
   （`CoffeeRecord` と同じ並び順に揃える）+ `Mapper.toDto()` の 1 行。**忘れると `grep -rl
   "CoffeeRecordExportDto\|CoffeeRecordExportMapper" shared --include="*.kt" | grep -v /build/`
   でしか気づけない**（Kotlin コンパイラは検出しない。DTO は独立した `data class` で `CoffeeRecord` を
   継承しないため）。次回からはカラム追加のたびにこの grep を横断点検の定番セットに含める

## 影響を受ける既存テストファイル（コンパイル対応のみ）

`CoffeeRecord(...)` を直接構築しているテストファイルは、多くが「1 ファイルにつき 1 つのファクトリ関数
（`sampleRecord()` 等）」パターンなので、そのファクトリに `cup = null,` の直後へ 1 行足すだけで済む
（実際に 15-E-1 では 11 ファイルがこのパターンだった）。事前に
`grep -rl "CoffeeRecord(" --include="*.kt" shared androidApp | grep -v /build/` で全箇所を洗い出し、
各ファイルの `cup = null,` 行の直後に `brewRecipe = null,` を挿入するスクリプト一括置換が速い。

## 検証コマンド

`repository_2stage_addition.md` と同様だが、このパターン特有の一次チェックとして
`:shared:data-local:compileKotlinIosSimulatorArm64`（`LocalCoffeeRepository.kt` の upsert 呼び出し漏れは
ここで検出される。`compileCommonMainKotlinMetadata` では検出されない可能性があるので過信しない）。

## 既存の「中間バージョン再現」migration テストが道連れで壊れる（2026-07-22 region 追加で発覚）

`CoffeeRecordMigration5Test.kt` / `CoffeeRecordMigration5IosTest.kt`
（`sqldelight_migration_version_semantics.md` の「中間バージョン再現」パターン）のように、
生 DDL で古いスキーマを構築してから `db.coffeeRecordQueries.upsert(...)`（型付き API）で
シード行を挿入するテストは、**新しい列を追加するたびにコンパイルエラーになるだけでなく
放置すると実行時エラーにもなる**。

- 型付き `coffeeRecordQueries` は常に**現行 head の `.sq`** から生成されるため、`upsert()` の
  SQL 文には新しい列（`region` 等）が含まれる。生 DDL で組んだ「旧バージョンのテーブル」に
  その列が無いと `INSERT` が `no such column` で失敗する
- **対策**: (1) 生 DDL の中間スキーマにも新しい列を追加する（テスト対象の migration 自体が
  その列に触れなければ実害なし）、(2) `AppDatabase.Schema.migrate(driver, oldVersion, newVersion)`
  の `newVersion` を head バージョン（`.sqm` 数 + 1）まで引き上げ、追加した列を作る migration
  （今回なら 6.sqm）まで実行させる。これで migrate 後の `selectById` 等（型付き SELECT）が
  実際のテーブル列と一致する
- 新しい列を追加したら `grep -rn "coffeeRecordQueries.upsert(" shared/data-local` で
  この種のテストヘルパー（`insertRawRecord` 等の名前が付いていることが多い）を洗い出し、
  同じ要領で追随させる
