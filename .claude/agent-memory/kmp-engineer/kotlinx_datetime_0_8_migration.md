---
name: kotlinx-datetime-0-8-migration
description: kotlinx-datetime 0.6→0.8 で Instant/Clock を kotlin.time へ移すときの opt-in 確認方法・typealias の実体・Obj-C 書き出しへの影響の裏取り手順（DU-3a〜DU-3c で確認。全モジュール移行完了）
metadata:
  type: project
---

## `kotlin.time.Instant` / `Clock` に `@OptIn(ExperimentalTime::class)` は要らない（Kotlin 2.4.21 時点）

stdlib jar の `kotlin/time/Instant.class` / `Clock.class` を `javap -v` すると
`@SinceKotlin("2.3")` + `@WasExperimental(markerClass = ExperimentalTime::class)` が付いている。
`WasExperimental` は **プロジェクトの apiVersion が SinceKotlin より古い場合だけ** opt-in を要求する仕組みなので、
Kotlin 2.4.21（apiVersion 既定 2.4 > 2.3）では無条件で安定 API として使え、
`build-logic` に `optIn("kotlin.time.ExperimentalTime")` を追加する必要はない。
裏取り: `unzip` で stdlib jar を展開 → `javap -v -classpath <dir> <dir>/kotlin/time/Instant.class | grep -i "SinceKotlin\|WasExperimental"`。

## `kotlinx.datetime.Instant` / `Clock` は 0.8.0 で「削除」ではなく「deprecated typealias」

`import kotlinx.datetime.Instant` を使い続けているファイルをコンパイルすると消えるのは**エラーではなく warning**:
`'typealias Instant = Instant' is deprecated. This type is deprecated in favor of kotlin.time.Instant.`
つまり **DU-3 を複数 dispatch に分割しても、未移行のモジュール（`data-firebase` / `feature/*`）は warning だけで普通にコンパイルが通る**
（[`docs/tasks.md`](../../../docs/tasks.md) DU-3 の想定どおり「下流は壊れていてよい」の実態は『壊れない、警告が出るだけ』）。

## 重要: Obj-C/Swift 書き出しの型名は「どのモジュールが import を直したか」とは無関係に、依存バージョン 1 つで全体が切り替わる

`kotlinx.datetime.Instant` が実体を持たない typealias になった時点で、**全ソースコードの `Instant` 型注釈は
（`kotlinx.datetime.Instant` と書いていても `kotlin.time.Instant` と書いていても）同一の実体クラスを指す**。
Kotlin/Native の Obj-C ヘッダ生成はエイリアス名ではなく実体クラスに基づいて 1 つの Obj-C class を出すため、
**`shared/framework` の umbrella を kotlinx-datetime 0.8.0 でリビルドした瞬間、`CoffeeRecord.createdAt` 等
Instant 型プロパティ全部が Swift から見える Obj-C 型名が一括で切り替わる**
（現状ヘッダは 0.6.2 ビルドのスナップショットで `SharedLogicKotlinx_datetimeInstant` のまま。裏取り:
`shared/framework/build/bin/iosArm64/releaseFramework/SharedLogic.framework/Headers/SharedLogic.h` を
`grep -n "Kotlinx_datetimeInstant"` し、ファイルの mtime が `libs.versions.toml` の変更より前であることを確認した）。
**DU-3 をサブタスクに分けても「どのファイルを import 修正したか」で Swift 側の破壊タイミングはコントロールできない。
umbrella を 0.8.0 でリビルドした瞬間に Instant を持つ全 data class が影響を受ける**ため、
段階的 dispatch の意図（Kotlin 側の作業を小分けにする）と Swift 側の破壊タイミング（framework リビルド時に一括発生）は別軸。
親が `assembleSharedLogicXCFramework` を実行するタイミングを DU-3 全体の完了後に合わせるべきかを判断する材料として渡す。

## DU-3b（`data-local` / `data-firebase`）で追加確認したこと

- 置換は **import 文の張り替えのみ**で済んだ（`import kotlinx.datetime.Instant` → `import kotlin.time.Instant`）。
  `Instant.fromEpochMilliseconds` / `fromEpochSeconds(epochSeconds, nanosecondAdjustment)` / `.epochSeconds` / `.nanosecondsOfSecond` は
  `kotlin.time.Instant` でも同じシグネチャで存在するため、Firestore `Timestamp` ↔ Instant 変換コード（`CoffeeFirestoreMapper` /
  `SavedCafeFirestoreMapper`）も含め本体ロジックの書き換えは不要だった。`monthNumber` / `dayOfMonth` はこの 2 モジュールには存在しなかった
  （LocalDate は `visitedOn` の文字列パースのみで month/day 分解していない）
- `shared/data-firebase` は `commonMain` が `api(projects.shared.domain)` の再公開のみ・`androidMain` にのみ実コードがあるため、
  `compileKotlinIosSimulatorArm64` は **`NO-SOURCE` で成功**する（iosMain 自体が存在しない）。これは正常であり、
  このモジュールの iOS 向け検証は実質 `shared/domain` 側の検証に委譲されている
- import の並び順はこのコードベースでは厳密な ASCII アルファベット順ではなく、**`kotlinx.*` のグループ → `kotlin.*` のグループ**という
  2 段構成になっている箇所が多い（`kotlin.time.Instant` を機械的に追加する時はこの並びに揃える）
- 検証は `testAndroidHostTest`（data-local 46 件 + data-firebase 15 件、全 pass）/ `compileKotlinIosSimulatorArm64` +
  `compileTestKotlinIosSimulatorArm64`（data-local、実コンパイル確認）/ `verifySqlDelightMigration` の 3 系統。
  いずれも新規実行分（UP-TO-DATE でない回）で `warning:` 出力 0 件を確認した

## DU-3c（`shared/feature/*`、`androidApp`/`sharedUI` は対象ゼロ）で追加確認したこと

- `androidApp` / `sharedUI` には `kotlinx.datetime.Instant/Clock` も `monthNumber`/`dayOfMonth` も 1 件もヒットしなかった（grep 0 件）。feature 側で domain モデル経由に閉じている設計のおかげで、エントリポイント層まで datetime 型が直接漏れていなかった
- `monthNumber` の実例が 1 箇所だけ見つかった（`CoffeeListViewModel.yearMonth()`）。`visitedOn.month.number` に置換し `import kotlinx.datetime.number` を追加（`visitedOn` は `LocalDate` でこのモジュールには他に `kotlinx.datetime.*` import が無かったため、`kotlin.*` グループと別に単独追加）
- 置換対象 15 ファイルは commonTest が 11 / commonMain が 4（`CoffeeRecordBuilder` / `CoffeeEditorMapping` / `CoffeeEditorViewModel` / `MapViewModel` / `CafeDetailViewModel` の 5 ファイルが `Clock.System.now()` 等で実際に `Clock` を使用、残りは生成した `Instant` 値をテストフィクスチャで組み立てるだけ）。commonMain 側はいずれも `Clock.System.now()` / `Clock.System.todayIn()` の戻り値を domain モデル（`CoffeeRecord.createdAt` 等、DU-3a で既に `kotlin.time.Instant` 化済み）にそのまま代入するだけで、**feature 層自身が公開する UIState / 関数シグネチャに `Instant`/`Clock` が直接現れる箇所はゼロ**だった（`grep -rn "Instant" shared/feature --include='*.kt' | grep -v commonTest | grep -v import` が空）。したがって DU-3c 単体では Swift から見える型の新規変更は無い（型自体の切り替えは DU-3a の domain 変更＋ umbrella リビルドで一括発生する、上の「重要」節のとおり）
- 1 ファイルだけ fully-qualified 参照（import なしの `kotlinx.datetime.Instant.fromEpochMilliseconds(...)`）があった（`CafeDetailViewModelDetailsRefreshTest.kt`）。import 文の grep だけでは見つからないので、`monthNumber`/`dayOfMonth` と同じ正規表現に `Instant\.`/`Clock\.` の素の文字列一致を含めておくと安全
- import 置換は機械的にスクリプト化できた: `kotlinx.datetime.Instant`→`kotlin.time.Instant` / `kotlinx.datetime.Clock`→`kotlin.time.Clock` の行を削除し、既存の `kotlin.*` import グループ（`kotlin.test.*` 等が既にある場合はその中）に挿入 → グループ内を再ソート。`kotlin.test` < `kotlin.time` の順になるので `kotlin.time.Clock`/`Instant` は `kotlin.test.*` より後ろに来るのが正しい並び
- 検証は `testAndroidHostTest :androidApp:assembleDebug`（触った 7 feature モジュール全部が UP-TO-DATE でなく実行され、BUILD SUCCESSFUL）/ `compileKotlinIosSimulatorArm64 compileTestKotlinIosSimulatorArm64`（`shared:framework` 含め全モジュール成功、`data-firebase` 同様の `NO-SOURCE` は出ない＝ feature は iosMain 持ちではないが compileTestKotlinIosSimulatorArm64 は実行された）。どちらも `grep -i warning` でヒットするのは Gradle の deprecation 告知だけで、datetime 関連 warning は 0 件

## 検証に使ったコマンド

- `./gradlew :shared:domain:dependencyInsight --configuration iosSimulatorArm64CompileKlibraries --dependency kotlinx-datetime --console=plain`
  — `kotlinx-datetime:0.8.0-0.6.x-compat`（Ktor 経由で推移的に要求される版）との競合有無を確認できる。
  `shared/domain` / `shared/core` は ktor に依存しないため、この configuration では compat 版は要求されず単純に `0.8.0` が解決される
  （`~/.gradle/caches/modules-2/files-2.1/org.jetbrains.kotlinx/kotlinx-datetime-jvm/` 配下には `0.8.0` と `0.8.0-0.6.x-compat` の両方がキャッシュされているが、
  それは他モジュール・他 configuration の解決結果が混在しているだけで、このモジュール単体の競合を意味しない）
- `monthNumber` → `month.number`（`import kotlinx.datetime.number` が要る。`LocalDate.month` が `Month` enum を返し、`number: Int` は拡張プロパティ）
