---
name: kotlinx-serialization-export-gotchas
description: shared/domain に kotlinx-serialization を初導入して JSON export 用 DTO を作るときに踏んだ罠（encodeDefaults / SKIE invoke 呼び出し形）
metadata:
  type: project
---

## モジュールへの kotlinx-serialization 追加手順（既存パターン）

`libs.versions.toml` に `kotlinxSerialization` / `kotlinx-serialization-json` / `kotlinSerialization`
plugin alias は既に定義済み（`shared/data-places` / `shared/data-local` が先行採用）。新規モジュールに
足す場合は `build.gradle.kts` に

```kotlin
plugins {
    id("kmp.library")
    alias(libs.plugins.kotlinSerialization)
}
// commonMain.dependencies { implementation(libs.kotlinx.serialization.json) }
```

を追加するだけで良い（`kmp.library` と競合しない。`data-places` で実績あり）。DTO を public class の
まま置いても、公開 API で直接参照されない限り `implementation`（api でなく）scope で downstream の
コンパイルは壊れない（DTO を直接 import する consumer が無ければ OK）。

## 罠: `Json { prettyPrint = true }` だけだとデフォルト値のフィールドが消える

kotlinx-serialization は `encodeDefaults` の既定値が **false**。data class のプロパティ値が
宣言時のデフォルト値と一致すると判定されると、そのキーごと JSON から省略される。

- 例: `data class Envelope(val version: Int = 1, ...)` を `version = 1` で生成すると、
  出力 JSON に `"version"` キー自体が現れない（テストで `root["version"]!!` が NPE になった）
- 空リストのデフォルト（`tags: List<String> = emptyList()` 等）も同様に、実際に空なら省略される

**対策**: 「デフォルト値のフィールドも常に出力したい」export 用途では
`Json { prettyPrint = true; encodeDefaults = true }` を明示する。

## 罠: nullable フィールド（デフォルトなし）が JSON 上で `null` になるとテストの `assertNull` は使えない

`kotlinx.serialization.json.JsonObject`（`Map<String, JsonElement>`）から取り出した値が JSON の
`null` を表す場合、Kotlin としては `JsonNull` という**非 null のオブジェクト**が返る
（マップの value 自体が null になるわけではない）。`assertNull(obj["cafe"])` は失敗する。
正しくは `assertEquals(JsonNull, obj["cafe"])`（`import kotlinx.serialization.json.JsonNull` が要る）。

## SKIE: `operator fun invoke` は Swift の `callAsFunction` に変換されない

`ExportCoffeeRecordsUseCase` のような `suspend operator fun invoke(...)` を持つ UseCase でも、
`.swiftinterface` を確認したところ SKIE は Swift 側に `func invoke(userId:) async throws -> String`
として出力するだけで、`callAsFunction` 化はされない。Swift からは
`useCase.invoke(userId: uid)` と明示的に `.invoke` を呼ぶ必要がある（`useCase(userId: uid)` は不可）。
ドキュメントコメントで「Swift から `useCase(...)` の形で呼べる」と推測で書かないこと
（`docs/kmp-bridge.md` の「.swiftinterface で裏取りする」原則どおり、必ず確認してから断定する）。

## サンドボックスでの XCFramework リンク確認（再確認）

`:shared:framework:assembleSharedLogicXCFramework` はデフォルトの `xcode-select -p`
（CommandLineTools）だと `linkDebugFrameworkIosSimulatorArm64` 等が `xcrun xcodebuild -version`
失敗で FAILED になるが、`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` を
付けて自分（サブエージェント）で実行すれば通る（2026-07-07 再確認。約 49 秒、debug/release 両方
XCFramework 生成成功）。`commonMain` の公開 API 変更時はこれで最後まで検証してから報告してよい。

## Swift シグネチャの裏取り方法

`grep -rn "<ClassName>" shared/framework/build/XCFrameworks/debug/SharedLogic.xcframework/ios-arm64-simulator/SharedLogic.framework/Modules/SharedLogic.swiftmodule/*.swiftinterface`
で `extension SharedLogic::<ClassName> { public func ... }` の実際のシグネチャを確認できる
（`assembleSharedLogicXCFramework` 実行後に生成される）。
