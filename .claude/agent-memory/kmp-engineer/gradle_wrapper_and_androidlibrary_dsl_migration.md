---
name: gradle-wrapper-and-androidlibrary-dsl-migration
description: Gradle wrapper の手動更新手順と、AGP 9.5 / Kotlin 2.4 系で KMP の androidLibrary {} ブロックが android {} に置き換わった際の対処法（DU-1 依存更新タスクで確認）
metadata:
  type: project
---

## Gradle wrapper をメジャー更新するときの手順（9.4.1 → 9.8.2 で確認）

`./gradlew wrapper --gradle-version <new>` を**旧バージョンの wrapper でそのまま叩くと失敗する**ことがある
（例: AGP 9.5.0 が新しい Gradle の Project Types API を要求し、旧 Gradle 9.4.1 で
`NoClassDefFoundError: org/gradle/features/binding/ProjectTypeBinding` になる）。

対処: `gradle/wrapper/gradle-wrapper.properties` の `distributionUrl` / `distributionSha256Sum` を
**先に手で新バージョンへ書き換えてから** `./gradlew wrapper --gradle-version <new>` を実行する
（新しい distribution を使って wrapper タスク自体を走らせる）。sha256 は
`https://services.gradle.org/versions/current`（または `/versions/all`）の JSON の `checksum` フィールドで取れる。
1 回目の実行で `gradle-wrapper.jar` / `gradlew` / `gradlew.bat` / `gradle-wrapper.properties` が
新形式に更新される（`properties` に `retries` / `retryBackOffMs` が追加される）。2 回目は UP-TO-DATE になるだけ。

## AGP 9.5 + Kotlin 2.4 系: KMP の `androidLibrary { }` ブロックが deprecated

`com.android.kotlin.multiplatform.library` 経由で `kotlin { androidLibrary { ... } }` と書いていたコードは、
AGP 9.5 で `android { ... }` ブロックに置き換わる（**プロパティ・ネストした `compilerOptions` / `withHostTest` は同じ形で使える**、
ブロック名の変更のみ）。警告文言は
`'fun KotlinMultiplatformExtension.androidLibrary(configure: Action<DeprecatedKotlinMultiplatformAndroidLibraryTarget>): Unit' is deprecated. The 'androidLibrary' block is deprecated. Please use 'android' instead.`
このシグネチャは Gradle / AGP / KGP いずれの配布 jar をバイトコード検索しても見つからない
（Gradle の Project Types API が実行時に動的生成するアクセサのため）。該当箇所は `grep -rln "androidLibrary {"` で洗い出し、
`sed -i '' 's/androidLibrary {/android {/'` で一括置換すれば十分（本文中の他の使い方は無い）。
置換後は警告が実際に消えることを `./gradlew projects --warning-mode all --no-configuration-cache` で確認する。

## AGP 9.5: `com.android.build.gradle.LibraryExtension` も deprecated

純粋な `com.android.library` 用 Convention Plugin（例: `android.library.gradle.kts`）で
`import com.android.build.gradle.LibraryExtension` を使っていると「Replaced by
`com.android.build.api.dsl.LibraryExtension`」という警告が出る。import を
`com.android.build.api.dsl.LibraryExtension` に変えるだけで解決する（`compileSdk` / `defaultConfig { minSdk }` /
`compileOptions { sourceCompatibility / targetCompatibility }` は同じ形で使える）。

## Kotlin 2.4 系: `kotlin-dsl` プラグインの buildSrc で JVM target 不一致警告が出る

`build-logic/convention/build.gradle.kts` のように `kotlin-dsl` だけ適用して `java { sourceCompatibility = 17 }`
しか書いていないモジュールは、Kotlin 2.4 で `compileKotlin` の jvmTarget が実行環境の JDK（21 等）に追随し、
「Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks」警告が出る。
`kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }` を明示すれば消える
（`import org.jetbrains.kotlin.gradle.dsl.JvmTarget` が必要）。

## Compose Multiplatform 1.12.2 への更新で `compileSdk` 36 → 37 が強制される

CMP 1.12.2 が引き込む `androidx.compose.*` 1.12.1 系は **compileSdk 37 以上を要求**する
（`:sharedUI` / `androidApp` のビルドが「`:sharedUI` is currently compiled against android-36」エラーで失敗）。
`gradle/libs.versions.toml` の `android-compileSdk` を `"37"` に上げれば解決する。
ローカル SDK に `platforms/android-37.0` が無くても、ライセンスファイル（`licenses/android-sdk-license`）が
既に受理済みであれば AGP が自動ダウンロードする（sandbox でもネットワークがあれば成功した）。
`android-minSdk` / `android-targetSdk` はこの要求に含まれないので変更不要。

## sandbox の iOS リンク系タスクの失敗は `MissingXcodeException` で判別できる

`./gradlew build` で `linkDebugFrameworkIos*` / `linkDebugTestIosSimulatorArm64` 等が失敗しても、
ログに `org.jetbrains.kotlin.konan.MissingXcodeException` /
`Failed command: /usr/bin/xcrun xcodebuild -version` が出ていれば、CommandLineTools しか無い sandbox の
既知の制約であり自分の変更のせいではない（`.claude/agents/kmp-engineer.md` が明記する既知事項）。
`grep -n "^e: " build.log` で「Failed to build cache for .../*.klib」のような二次エラーも全部この xcrun 失敗が
根本原因であることを確認してから無視してよい。
`compileKotlinIosSimulatorArm64` / `compileTestKotlinIosSimulatorArm64` が全モジュールで成功していれば、
コンパイルは問題ない（リンクより前の段階で完結する）。

## SKIE 生成 Swift API の before/after 比較が sandbox でできないケース

`.swiftinterface` は最終リンク段階（`linkReleaseFramework*` / `assembleXXXFramework`）で生成されるため、
sandbox で `MissingXcodeException` によりリンクが失敗すると「更新後」の `.swiftinterface` を生成できない。
`shared/framework/build/**/*.swiftinterface` に古い build 由来のファイルが残っていても、それは「更新前」の
スナップショットとしてしか使えない。before/after 差分の確認は親の `DEVELOPER_DIR` 環境での再ビルドに委ねる。
