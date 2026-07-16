---
name: commontest-first-setup-in-feature-module
description: これまでテストが存在しなかった shared/feature/<name> モジュールに commonTest を初めて追加するときの手順とハマりどころ
metadata:
  type: project
---

`shared/feature/coffee-detail` のように `src/commonTest` ディレクトリ自体が存在しないモジュールにテストを新設するときの手順（coffee-list 等の既存モジュールに追記する場合と違い、いくつか見落としやすい点がある）。

**手順**:
1. `build.gradle.kts` の `sourceSets` に `commonTest.dependencies { implementation(libs.kotlin.test); implementation(libs.kotlinx.coroutines.test) }` を追加（他 feature モジュールと同型）
2. **ドメインモデルのフィクスチャを直接コンストラクトするテストの場合**、そのモデルが `kotlinx.datetime.LocalDate` / `Instant` 等の型をプロパティに持つなら、`commonTest.dependencies` に `implementation(libs.kotlinx.datetime)` も追加する。`shared/domain` 側の依存は `implementation`（`api` ではない）なので、そのモデルを使う側のモジュールが独自にテストで型を触るなら自モジュールの build.gradle.kts に明示追加が必要（commonMain 側に無い場合は commonMain にも足す必要はなく、commonTest だけで足りる — commonTest は commonMain に依存するが、commonMain 自体が kotlinx.datetime を使っていなければ推移的に入ってこない）
3. `Write` ツールで `src/commonTest/kotlin/<package>/<Name>Test.kt` を新規作成すればディレクトリごと作られる（`mkdir` 不要）

**検証で確認できたこと**:
- `commonMain` の公開 API（ViewModel のメソッドシグネチャ）を変更したあと `:shared:framework:assembleSharedLogicDebugXCFramework` を実行すると、sandbox では `compileKotlinIosArm64` / `compileKotlinIosSimulatorArm64`（framework モジュール含む全 shared モジュール）までは成功し、`linkDebugFrameworkIosArm64` / `linkDebugFrameworkIosSimulatorArm64` だけが `xcrun xcodebuild -version` の失敗で FAILED になる。これは既知の sandbox 制約（`xcode-select` が CommandLineTools を指す）であり、コンパイルまで全部通っていれば commonMain API 変更は問題なしと判断してよい（親に link 検証だけ依頼すればよい）
