# Lessons（自己改善ループ用メモ）

実装を進める中で気付いた、再発させたくない落とし穴・お作法を蓄積する場所です。
セッション開始時に見直し、関連するルールを再確認してください。

---

## 2026-06-02

### SQLDelight 2.x の命名規則

- `.sq` ファイル内の `CREATE TABLE coffee_item` から生成される Kotlin クラスは **`Coffee_item`**（先頭大文字のみ）になる。`CoffeeItem` にはならない
- カラム名 `cafe_place_id` もそのまま `cafe_place_id` プロパティになる（自動 camelCase 化しない）
- Queries クラスは `.sq` ファイル名から: `Visit.sq` → `VisitQueries`、`CoffeeItem.sq` → `CoffeeItemQueries`。データクラス名と命名が揃わないので注意
- ドメインモデルと生成行クラスの名前衝突は **import alias**（`import com.noricoffee.domain.Visit as DomainVisit`）で解消する

### KMP + SQLDelight のテスト配置

- `sqlite-driver`（JdbcSqliteDriver）は **JVM 専用**。`commonTest` の `dependencies` に入れると iosTest コンパイルで落ちる
- 解決策: 共通テストロジックは `commonTest` に書きつつ、ドライバ生成だけ `expect fun createInMemoryTestSqlDriver(): SqlDriver` で逃がす。actual を `androidHostTest`（JdbcSqliteDriver）と `iosTest`（NativeSqliteDriver の `onConfiguration = { it.copy(inMemory = true) }`）に置く
- `androidHostTest` の Gradle 依存追加は `sourceSets { getByName("androidHostTest").dependencies { ... } }` で行う

### Gradle タスク名（android KMP プラグイン）

- `androidHostTest` という名前のタスクは存在しない。実行タスクは `testAndroidHostTest`
- コンパイル単体は `compileAndroidHostTest`
- iOS テストのコンパイル確認は `compileTestKotlinIosSimulatorArm64`（実機起動なしで通せる）

### `expect class` の Beta 警告

- Kotlin 2.x で `expect class` は Beta 扱いで警告が出る
- `kotlin { compilerOptions { freeCompilerArgs.add("-Xexpect-actual-classes") } }` で抑止
- KMP のレシピでは `expect/actual` クラスは引き続き標準。Beta は警告レベルの話で機能は安定

### SQLDelight トランザクションと Flow の emit タイミング

- `db.transaction { ... }` 内で複数テーブルを upsert しても、`asFlow()` の購読者には **トランザクション commit 後に一度だけ** 通知が届く
- 子テーブル（coffee_item / food_item / photo）だけを更新した場合、`visit` 行を観測している `observeAll` には emit が **来ない**。Phase 1 は常に `save(visit)` で visit 行も更新する設計のため問題なしだが、将来子テーブル単独更新を入れるなら `combine` で複数 Query を束ねる

### iOS で `Undefined symbol: _sqlite3_bind_blob` が出たとき

- 原因: `NativeSqliteDriver`（の依存 `sqliter`）は iOS の **システム SQLite** に動的リンクする。`SharedLogic.framework` を `isStatic = true` で出しているので、最終リンク（Xcode 側のアプリビルド）で `-lsqlite3` が要る
- **`sharedLogic/build.gradle.kts` の framework ブロックに `linkerOpts("-lsqlite3")` を入れただけでは不十分**（実測: 31 件の `_sqlite3_*` 未解決が残った）。`isStatic = true` の framework は Xcode 側のアプリリンクにフラグを伝播しないことがある
- 確実な対処: **Xcode の xcconfig に `OTHER_LDFLAGS = $(inherited) -lsqlite3` を追加**する。本プロジェクトでは `iosApp/Configuration/Config.xcconfig` がアプリの base configuration として使われているので、そこに書く
- Xcode のキャッシュが古い framework を掴んでいると反映されないので、**Product → Clean Build Folder** してから再ビルド
- なお Gradle 側の `linkerOpts("-lsqlite3")` も残しておくのが安全（KMP の build 内で iOS テスト等を走らせるときに必要になり得る）

### ドメインモデルとマッパの責任分担

- バリデーション（rating の 1..5、name の長さ等）は **ViewModel 層に置く** 方針（`data-model.md` §7）
- Mapper は純粋な型変換に徹し、例外を投げる箇所を増やさない
- Enum の DB 表現は `name` 文字列。未知の値が DB に入っていたら `valueOf` が `IllegalArgumentException` を投げるが、これは「マイグレーション漏れ」を即座に検知できるのでむしろ望ましい

---

## 2026-06-04

### SKIE の SuspendInterop は呼び出し方向限定

- SKIE は「Kotlin の `suspend` / `Flow` を Swift から **呼び出す**」方向のエルゴノミクス改善ツール。Swift 側で `async throws` / `for await` が自然に使える
- **逆方向（Swift で Kotlin interface を実装する側）には効果が及ばない**: 生成された Obj-C プロトコル準拠の生シグネチャ（`completionHandler:` 形式 / `Kotlinx_coroutines_coreFlow` 戻り値）を実装する必要がある
- Phase 2 では `AuthRepositoryIosImpl.swift` / `RemoteVisitDataSourceIosImpl.swift` がこのパターンに該当
- Swift から Kotlin `Flow` を作って返すには `MutableStateFlow(initialValue:)` を SKIE 経由で構築し、イベントごとに `setValue` で更新するのが第一候補
- 両方向の interop を SKIE が魔法のように解決する、という誤解は禁物。Kotlin 側の interface 定義時から「Swift 実装」と「Swift 呼び出し」の両側を意識すること

### Firestore で nullable フィールドは `null` ではなくキー省略で書く

- `null` を入れると Firestore のクエリで `where("origin", "==", null)` のような扱いが必要になり、無駄に複雑化する
- 書き込み側で nullable が nil のときは辞書からキー自体を省略する（`if let value = optional { data["key"] = value }`）
- 読み込み側は `data["key"] as? String` が nil を返してそのまま nil として扱えば良いので、decode コードもシンプルになる
- enum / Timestamp / Double などすべての型で同じ方針を採る

### SKIE は Kotlin のデフォルト引数を Swift に引き出さない

- Kotlin の `fun foo(x: Int, scope: CoroutineScope = MainScope())` や `class Bar(scope: CoroutineScope = MainScope())` のデフォルト値は SKIE 経由で Swift に届かない
- Swift 側からは「全引数を明示する版」しか見えないため、デフォルト値の意味するインスタンス（例: `MainScope()`）を Swift で作る必要が出る → 結果として **ダミー値を作る hack に走られる**（Phase 2 で `IosMainScope`（dispatcher なし）を Swift で実装してしまったのが実例）
- 回避策: デフォルト引数を持たせず、**セカンダリコンストラクタ / オーバーロードで「scope 引数なし版」を別途定義**して内部で `MainScope()` を生成する。プライマリ側もデフォルト値を消し、用途（テスト / 本番）でコンストラクタを分ける
- SKIE 採用プロジェクトでは「Swift から呼ぶ API は **全部明示引数で書く**」を原則にしておくと、デフォルト引数の hack 化リスクを早期に潰せる

---

## 2026-06-06

### Firebase CLI の重複インストールに注意（npm 経由を入れても古い Standalone が PATH 上で先に解決される）

- macOS で `firebase` バイナリが 2 ヶ所に入りうる:
  - `/opt/homebrew/bin/firebase` → npm 経由（`npm install -g firebase-tools`）の最新版へのシンボリックリンク
  - `/usr/local/bin/firebase` → 過去に Firebase 公式インストーラ（curl 一発スクリプト）で入れた Standalone Binary。root 所有、サイズ 150MB 級
- PATH 上で `/usr/local/bin` が `/opt/homebrew/bin` より先になっていると、`firebase --version` は古い Standalone を返し続ける。`npm install -g firebase-tools@latest` を何回叩いても変わらない
- 切り分け: `which firebase` / `which -a firebase` でフルパスを並べる → 各パスをフルパス指定で `--version` 叩いてバージョンを照合
- 対処: `sudo rm /usr/local/bin/firebase` で古い Standalone を削除。Standalone は npm 経由とは別経路なので、消しても npm 側の運用には影響しない
- 教訓: CLI のバージョンを上げたつもりが下のバイナリが残っていて症状が変わらないパターンは Firebase に限らずよくある。`which -a <cmd>` を最初に確認するクセを付ける

### Firebase Storage の新規プロジェクト有効化は Blaze プラン（従量課金）必須

- 2024 年 10 月頃から Firebase の方針変更で、**新規プロジェクト**で Storage を「使用開始」するには Blaze プランへのアップグレード（= クレカ登録）が必要になった。既に有効化済みの古いプロジェクトは Spark のままで使い続けられる
- 公式 SDK で Storage を触らずに `firebase deploy --only storage` だけ叩いても、`HTTP 404 / Resource 'projects/<id>/locations/global/applications/<id>' was not found` で落ちる。エラー文言に「Storage が未有効化」とは書かれないので原因究明に時間がかかる
- 無料枠（5GB 容量 / 1GB/日 ダウンロード / 20,000/日 アップロード操作）は Blaze でも維持されるので、個人開発・検証用途なら実質無料
- 個人開発で Blaze 化のハードル / 用途を考慮して **Storage 不採用 + 端末ローカル保存** を選ぶ場合は、`firebase.json` から `storage` キーを外して `firestore` のみで運用すれば Spark プランのまま完結する。`storage.rules` ファイルだけ残しておけば将来復活も容易

### Firebase Security Rules はリポジトリ管理が現実的（Console 編集との併用は避ける）

- `firebase.json` / `.firebaserc` / `*.rules` をリポジトリに置き、`firebase deploy --only <target>` で反映する運用は Firestore / Storage / RTDB / Functions すべて共通
- 差分レビュー / 履歴 / 再現性のメリットが大きく、Console 直接編集と比較してデメリットはほぼない
- ただし **Console 編集との併用は厳禁**。Console で編集したルールは次の `firebase deploy` で上書き消失する。チーム内で「ルールはリポジトリ管理する」と決めたら Console 側のルールエディタは触らない運用を徹底
- `.firebase/` キャッシュディレクトリは `.gitignore` で除外する（デプロイ毎に再生成されるため）

---

## 2026-06-08

### `includeBuild` + version catalog のパス問題

- `build-logic` のような `includeBuild` 配下の build から `gradle/libs.versions.toml` を参照するには、`build-logic/settings.gradle.kts` で `dependencyResolutionManagement { versionCatalogs { create("libs") { from(files("../gradle/libs.versions.toml")) } } }` を **明示宣言** する
- 相対パスの基準は `build-logic/` ディレクトリ。ルートの `gradle/libs.versions.toml` を指すには `../gradle/libs.versions.toml`
- ルート build と `build-logic` build は **別 build** なので、同じカタログファイルを参照していても両方の settings で個別宣言が必要（ルート側はデフォルトの `gradle/libs.versions.toml` 自動検出に任せて OK、`build-logic` 側は明示宣言が必須）
- これを書き忘れると `build-logic/convention/build.gradle.kts` で `libs.kotlin.gradle.plugin` 等の type-safe accessor が解決できず、`Unresolved reference: libs` で落ちる

### precompiled script plugin と `gradlePlugin { plugins.register(...) }` を併用しない

- `kotlin-dsl` プラグインを使う build では `src/main/kotlin/<id>.gradle.kts` というファイル名から自動的に plugin id `<id>` が生成・登録される
- ここに加えて `gradlePlugin { plugins.register("<id>") { implementationClass = "..." } }` を書くと plugin descriptor が二重生成されて衝突する（または `implementationClass` を要求される — precompiled script では不要）
- 「Convention Plugin を 3 つ作る」目的なら、`src/main/kotlin/` にファイルを 3 つ置くだけで足りる。`gradlePlugin` ブロックは書かない
- 適用側は `plugins { id("kmp.library") }` で参照できる（id はファイル名そのまま）

### Convention Plugin に `jvmToolchain(N)` を入れると開発機の JDK バージョン依存が生まれる

- `kotlin { jvmToolchain(17) }` を Convention Plugin に書くと、開発機に該当 JDK が無い場合 Gradle Toolchain auto-provisioning（`toolchainManagement` + `foojay-resolver-convention`）が未設定だとビルドが落ちる
- 「現状の開発機 JDK バージョンに依らず動く」を優先するなら `jvmToolchain` は付けず、`compilerOptions.jvmTarget = JvmTarget.JVM_11`（Android 側）/ JS / Native は target ごとに別 API、で JVM target を個別宣言する流儀の方が運用が楽
- CI で JDK バージョンを固定したくなったら、別途 `toolchainManagement` + `foojay-resolver-convention` を入れて auto-provisioning を有効化する

### `build-logic` 内では `projects.shared.core` の type-safe project accessor が使えない

- ルート `settings.gradle.kts` の `enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")` は **その build 内でのみ有効**
- `build-logic` は別 build なので `projects.*` accessor が生成されない。precompiled script plugin 内で別プロジェクトを参照するときは文字列 API `project(":shared:core")` を使う
- 各モジュールの `build.gradle.kts` ではこれまで通り `projects.shared.core` が使える（同じルート build 内のため）

### KMP iOS framework の `export(...)` は `api(...)` 依存とは別に明示が必要

- `commonMain.dependencies { api(projects.shared.other) }` は klib への取り込みを保証するが、`framework { ... }` ブロックで `export(projects.shared.other)` を **追加で明示** しないと Obj-C ヘッダに依存モジュールの class 宣言が出てこない
- 症状: ビルド・リンク・`import SharedLogic` はすべて成功するのに、Swift から `AppContainer` / `VisitRepository` 等が「Cannot find type in scope」になる。自モジュール内シンボル（`Greeting` 等）だけは引き続き見える
- 切り分け: `sharedLogic/build/bin/iosSimulatorArm64/releaseFramework/SharedLogic.framework/Headers/SharedLogic.h` を `wc -l` / `grep` で覗く。export 抜けだと数百行、`export(...)` 追加後は数千行に激変する（実測 631 行 → 2412 行）
- Umbrella framework パターン（`shared/framework` モジュール）でも同じ知見が必要。`export(...)` 群を framework モジュール側に集約する

### `expect/actual` を含む test ヘルパは「ヘルパが置かれているモジュールの内部から閉じる」

- `expect fun createInMemoryTestSqlDriver()` を `shared/data-local` の commonTest に置くと、その actual は同モジュールの `androidHostTest` / `iosTest` にしか書けない。他モジュールの commonTest から再利用する標準手段はない（`testFixtures` 導入 or ヘルパ自体を `commonMain` に置くなど工夫が必要）
- 結果として「`VisitRepositoryImpl` のテストを `shared/core` 側に置きたい」が、`data-local` の expect/actual ドライバを再利用したいので **テストを `data-local` 側に置く** 妥協が現実解になる
- 教訓: `expect/actual` は「同モジュール内で完結する」前提で設計する。一度書いた expect/actual を他モジュールから使いまわすコストは高いので、最初から「ヘルパだけ別の共有テストモジュールに切り出す」設計を選ぶか、テストの所属モジュールを実装の所属と切り離す覚悟を持つ

### KMP の `XCFramework(name)` と framework `baseName` は揃えると warning が消えタスク名も直感的になる

- `binaries.framework { baseName = "X" }` と `XCFramework("Y")` を別々の文字列にすると、最終 XCFramework 名と内部 framework 名の mismatch warning が出る: `w: XCFramework Name Mismatch with Inner Frameworks. ... Framework renaming is not supported yet`
- 揃えると warning が消えるだけでなく、生成タスクが `assemble<XCFrameworkName>XCFramework`（揃えた名前）となり直感的になる
- Swift 側の `import` 文は `baseName` 側に固定される（XCFramework 名は関係ない）。既存 Swift コードの import を壊したくないなら、`baseName` を維持して XCFramework 名側を揃える
- 改名する場合は CI の `.github/workflows/*.yml` の `assemble<Name>XCFramework` タスク名追随を忘れない

### `XCFramework(name)` ヘルパ宣言なしでは `assemble<Name>XCFramework` タスクは生成されない

- iOS framework target に `framework { ... }` ブロックを書くだけだと自動生成されるのは `linkDebugFrameworkIos*` / `linkReleaseFrameworkIos*` まで
- `assemble<Name>XCFramework` を得るには `import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework` + `val xcf = XCFramework("Name")` を宣言し、各 framework block で `xcf.add(this)` を呼ぶ必要がある
- 切り分け: `./gradlew :module:tasks --all | grep -iE xcframework` で task 一覧を見ると、ヘルパ未宣言だと該当 task が存在しないことが即わかる

### Umbrella framework 移行で Xcode 側に必要な変更は Run Script 1 行のみ

- 内部 framework `baseName` を維持して umbrella モジュールに切り替えるなら、Xcode 側で変更すべきは `project.pbxproj` の Run Script `./gradlew :<old>:embedAndSignAppleFrameworkForXcode` → `./gradlew :<new>:embedAndSignAppleFrameworkForXcode` の 1 行のみ
- Framework Search Paths / PBXBuildFile / PBXFrameworksBuildPhase / inputPaths / outputPaths は無変更で OK（`embedAndSignAppleFrameworkForXcode` が `$BUILT_PRODUCTS_DIR` ベースに framework を配置するため、Xcode 側の探索パスは変わらない）
- Swift 側コードも `import SharedLogic` 等が無変更で動く（内部 framework 名が変わらないため）

### SourceKit の `No such module 'X'` は実ビルド成功と乖離することがある

- `xcodebuild` で BUILD SUCCEEDED でも、SourceKit（IDE インデックス）が `import X` を「No such module」と報告することがある
- 原因はインデックスキャッシュ。`Product → Clean Build Folder` + `~/Library/Developer/Xcode/DerivedData/iosApp-*` 削除で直ることが多い
- そもそも `import X` が当該ファイル内で使われていなければ **import 自体を削除** するのが最もエレガント（dead code 削除 + SourceKit 黄信号解消）

### KDoc 内に `/*` を含む文字列を書くとネストコメント開始として解釈される

- KDoc（`/** ... */`）の中で glob パターンや path をそのまま書いて `feature/*` のような `/*` シーケンスが現れると、Kotlin コンパイラがネストコメントの開始と解釈し「Unclosed comment」エラーになる
- 回避: `feature/<name>` / `feature/...` / バッククォートで囲んで `feature/_NAME_` 等、`/*` を文字列リテラル含めて出さないように書き換える
- バッククォート ``` `feature/*` ``` でも回避できない（コメントは字句的にトークン化されるためバッククォートはエスケープにならない）
- 単発のミスではなく、glob を「そのまま記載すれば伝わる」と思って書くと踏むパターン。pattern 例を KDoc に載せる用途なら最初から表記を `feature/<name>` で統一する

---

## 2026-06-09

### SKIE EnumInterop: Kotlin `enum class` は Swift の `@frozen enum` に変換される（case 名は camelCase）

- SKIE 0.10.12 は Kotlin の `enum class`（`BrewMethod` / `ProcessingMethod` / `RoastLevel` 等）を Swift の `@frozen enum : Hashable, CaseIterable` に EnumInterop 変換する
- **case 名は camelCase 変換**: `HandDrip` → `.handDrip`、`FullCity` → `.fullCity`。Kotlin 側のキャメル分割位置をそのまま採用する
- **全ケース列挙は `.allCases`**: `CaseIterable` 準拠のため `BrewMethod.allCases` で取れる。Obj-C ヘッダ（`.h`）に存在する `.entries` プロパティは Swift からは使えない / 使わない
- **元名へのアクセス**: `.name` プロパティが残るので Kotlin 側の元名文字列（`"HandDrip"` 等）が必要なら経由できる
- Picker 等で使うパターン: `ForEach(BrewMethod.allCases, id: \.name) { value in Text(value.name).tag(value as BrewMethod?) }`

### Swift 側の SKIE 型は `.swiftinterface` を見る（`.h` は Obj-C 互換用で実態と乖離する）

- SKIE が生成する Swift API の真実は `shared/framework/build/.../SharedLogic.framework/Modules/SharedLogic.swiftmodule/*.swiftinterface`
- `SharedLogic.framework/Headers/SharedLogic.h`（Obj-C ヘッダ）は Obj-C 互換の生 API で、SKIE 変換後の Swift API（`@frozen enum` / `async throws` / `SkieSwiftFlow` 等）は出てこない
- 「`.h` に `BrewMethodEntries` が見えるから Swift から `BrewMethod.entries` で呼べるはず」と思ったら Swift 側からは「no member」エラーになる、というのが典型的な踏み方
- 切り分け順: `grep` で `.swiftinterface` を見る → ない場合のみ `.h` を見る

### Xcode の DerivedData が古い symlink を掴むとビルド成功と SourceKit が乖離する別パターン

- 既出の「SourceKit `No such module 'X'`」とは別系統で、DerivedData に過去 SDK 向けの broken symlink（`iphonesimulator17.x` 等）が残っていると、SDK アップグレード後にビルドの検索パスがそちらを先に当てて、`.swiftinterface` が見つからず `'.allCases' has no member` 系のエラーになることがある
- 対処: `~/Library/Developer/Xcode/DerivedData/iosApp-*` を消してから `Product > Clean Build Folder` + 再ビルド
- 切り分け: `xcodebuild` の `-showBuildSettings` でフレームワーク検索パスを出して、broken symlink が含まれていないかを確認
