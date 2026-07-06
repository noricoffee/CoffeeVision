---
name: repository-2stage-addition
description: CoffeeRepository と同型の新規 Repository（ローカル+リモート 2 段構成）を追加するときのファイル一覧・雛形・検証コマンド
metadata:
  type: project
---

`CoffeeRepository` / `RemoteCoffeeDataSource` パターンを新エンティティ（例: フェーズ 15-A の `SavedCafe`）に
適用するときの実地手順。`docs/data-model.md` に既に設計が確定している前提（親が事前確定）。

## 触るファイル一覧（新エンティティ `Foo` の例）

1. `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/Foo.kt` — data class
2. `shared/domain/src/commonMain/kotlin/com/noricoffee/repository/FooRepository.kt` — UI 向け interface
3. `shared/domain/src/commonMain/kotlin/com/noricoffee/repository/RemoteFooDataSource.kt` — プラットフォーム別実装用 interface
4. `shared/data-local/.../sqldelight/com/noricoffee/db/Foo.sq` + `sqldelight/migrations/N.sqm`（既存 migrations の最大連番+1）
5. `shared/data-local/.../db/Mapper.kt` に `Foo.toRow()` / `Row.toDomain()` を追記（新規ファイルにしない。既存の JSON 直列化ヘルパ `encodeToJson()`/`decodeStringList()` を再利用）
6. `shared/data-local/.../repository/LocalFooRepository.kt`
7. `shared/core/.../repository/FooRepositoryImpl.kt` — **`WritePolicy` は新規 enum を作らず `CoffeeRepositoryImpl.WritePolicy` を再利用**（「WritePolicy 共用」の指示はこの意味。nested enum を型として直接参照すれば良く、top-level に切り出す必要はない）
8. `shared/data-firebase/androidMain/.../FooFirestoreMapper.kt` + `RemoteFooDataSourceAndroidImpl.kt`（`RemoteCoffeeDataSourceAndroidImpl` の awaitTask ヘルパをそのままコピーで良い。共通化しなくてよい —既存コードもコピー方式）
9. `AppContainer.kt`: 主要/セカンダリ全コンストラクタに `remoteFooDataSource` パラメータを追加（SKIE はデフォルト引数を出さないため、既存の複数セカンダリコンストラクタ全部に増やす。iOS/Android 双方の呼び出し箇所が壊れるので必ず「iOS 側追随依頼」をレポートに書く）
10. `androidApp/.../CoffeeVisionApp.kt` の `AppContainer(...)` 呼び出しにも新パラメータを追加（androidApp はスコープ内なので自分で直す）
11. `shared/framework/.../AppContainerViewModelFactory.kt` の該当 `make*ViewModel` に repository を追加配線
12. 既存 ViewModel（例: MapViewModel）に repository を追加する場合、**既存の commonTest 内の Fake 実装呼び出し全箇所**に新パラメータが要る。`python3` の一括置換（`content.replace(pattern, replacement)`）が早い

## 検証コマンド

```
./gradlew :shared:domain:compileKotlinIosSimulatorArm64 :shared:data-local:compileKotlinIosSimulatorArm64
./gradlew :shared:core:compileKotlinIosSimulatorArm64 :shared:data-firebase:compileKotlinIosSimulatorArm64 \
  :shared:feature:<xxx>:compileKotlinIosSimulatorArm64
./gradlew :shared:framework:compileKotlinIosSimulatorArm64   # commonMain 公開 API 変更の実質チェック
./gradlew :shared:<module>:compileTestKotlinIosSimulatorArm64
./gradlew :shared:<module>:testAndroidHostTest
./gradlew :androidApp:assembleDebug
./gradlew :shared:data-local:verifySqlDelightMigration   # migration ファイル ↔ 最終スキーマの整合確認
```

`:shared:framework:assembleSharedLogicXCFramework` は `xcode-select -p` が CommandLineTools を指す
デフォルト状態だと `linkDebugFrameworkIosSimulatorArm64` 等が `xcrun xcodebuild -version` 失敗で FAILED になる。
**ただし `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` を付けて自分（サブエージェント）で
実行すれば通る**（2026-07-06 確認。フルビルド 47 秒、debug/release 両 XCFramework 生成成功）。
`iosSimulatorArm64Test`（実機/シミュレータ実行を伴う）は依然サンドボックス制約でサブエージェントには不可だが、
リンクだけの `assembleSharedLogicXCFramework` は DEVELOPER_DIR 環境変数だけで解決するので、
`commonMain` 公開 API 変更時は自分で最後まで検証してから報告してよい（親への委任は不要）。

## data-local の commonTest 配置ルール（既存パターン）

`XxxRepositoryImpl`（local+remote 合成）は `shared/core` に置くが、そのテストは
`shared/data-local/src/commonTest` に置く（`createInMemoryTestSqlDriver` の expect/actual が
data-local の commonTest に閉じているため。`shared/core/build.gradle.kts` の commonTest には
sqldelight テストドライバが無い）。`shared/core` の `commonTest.dependencies` に
`implementation(projects.shared.core)` が既に data-local 側にあるので、data-local → core の
依存で `XxxRepositoryImpl` を import できる。
