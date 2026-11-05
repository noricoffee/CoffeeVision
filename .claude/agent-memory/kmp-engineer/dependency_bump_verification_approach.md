---
name: dependency-bump-verification-approach
description: KMP ライブラリ（coroutines / serialization / sqldelight / ktor / androidx）の一括バージョン更新タスクで、新しい安定版の有無を確認し、SQLDelight の gradle-plugin 内の deprecation 原因をバイトコードから裏取りする方法
metadata:
  type: project
---

## 「これより新しい安定版はないか」を確認するコマンド

Maven Central は `curl`/`WebFetch` で `maven-metadata.xml` を直接見れば、`<versioning><versions>` の中から
alpha/beta/rc を除いた最新版が分かる（2026-11-05 時点で確認した URL）。
`org/jetbrains/kotlinx/kotlinx-coroutines-core` / `kotlinx-serialization-json` /
`app/cash/sqldelight/runtime` / `io/ktor/ktor-client-core` は `repo1.maven.org/maven2/...` 配下。
**AndroidX（appcompat / core-ktx / activity / espresso / test ext）は Maven Central ではなく
`dl.google.com/android/maven2/...` 配下**（Maven Central の方は 404 になるので google maven2 に切り替える）。

## SQLDelight gradle-plugin が出す `Configuration.setVisible(boolean)` deprecation は 2.4.1 でも残っている

DU-1（2.1.0 → 想定）時点で報告された `Configuration.setVisible` deprecation warning は、
sqldelight を 2.4.1 まで上げても **消えない**。原因は SQLDelight 自身の
`app.cash.sqldelight.gradle.SqlDelightDatabase`（`projectDependenciesConfiguration` /
`consumableDatabaseConfiguration` の internal Configuration 生成）が `setVisible(false)` を呼んでいるため。
裏取り方法: `~/.gradle/caches/modules-2/files-2.1/app.cash.sqldelight/gradle-plugin/<version>/.../gradle-plugin-<version>.jar`
を unzip し、`find . -name "*.class" | xargs grep -la setVisible` で該当 class を特定できる
（`SqlDelightDatabase.class` 等）。プロジェクト側の `build.gradle.kts` には該当コードが無いため、
これは SQLDelight 側の将来リリース待ちであり、こちら側では対処不可（report に「アップストリーム待ち」と書く）。

## DU-2（coroutines 1.11 / serialization 1.12 / sqldelight 2.4.1 / ktor 3.6.1 / lifecycle 2.11.0 /
appcompat 1.8.0 / core-ktx 1.19.1）はすべて `libs.versions.toml` の version 文字列置換のみで通った

`PlacesClientImpl` / `PlacesHttpClient.{ios,android}.kt`（Ktor Darwin/OkHttp エンジン、
ContentNegotiation、HttpResponseValidator）、SQLDelight の `.sq` スキーマ・migration、
coroutines-test の `runTest` 系はいずれも破壊的変更の影響を受けなかった（2026-11-05 時点）。
新しく出た warning は無し（既存の `kotlinx.datetime.Clock`/`Instant` 非推奨警告と
`BuildCoffeeStatsUseCaseTest` の `!!` 警告は版更新前から存在する別件）。
