---
name: mapper-enum-fallback-and-raw-row-test
description: Coffee_record.toDomain() の enum 復元を valueOf から entries.firstOrNull にフォールバックさせる修正の実施記録と、ドメインモデルを経由せず SQLDelight クエリへ直接不正値を書き込むテスト手法
metadata:
  type: project
---

## 作業ノウハウ

`shared/data-local/.../db/Mapper.kt` の `Coffee_record.toDomain()` で enum 復元に
`BrewMethod.valueOf(...)` 系を使うと、未知文字列（enum リネーム/削除後の旧データ等）で
`IllegalArgumentException` が飛び、`observeAll` の `mapToList` 内で全行処理中に落ちて
Flow 全体が死ぬ。`entries.firstOrNull { it.name == raw } ?: fallback` に置換するのが定石
（`values()` ではなく `entries` を使う）。

## 未知 enum 文字列をテストする方法

ドメインモデル（`CoffeeRecord`）経由だと enum 型で縛られるため不正文字列を作れない。
`db.coffeeRecordQueries.upsert(...)` を **`LocalCoffeeRepository.save()` を介さず直接呼ぶ**
テストヘルパーを commonTest に用意すると、生の TEXT カラムへ任意の未知文字列を書き込める。
`notes` カラムは `NOT NULL` のため `null` ではなく `""` を渡す（`CoffeeRecord.sq` のスキーマ定義を
確認してから書くこと。他の nullable/non-null カラムも同様に取り違えやすい）。

## 検証実績

`compileCommonMainKotlinMetadata` / `compileKotlinIosSimulatorArm64` /
`compileTestKotlinIosSimulatorArm64` / `testAndroidHostTest` は全て OVERRIDE フラグなしで通った
（`Mapper.kt` は internal 関数のみの変更で `commonMain` 公開 API に影響しないため
`assembleSharedLogicXCFramework` は不要と判断）。
