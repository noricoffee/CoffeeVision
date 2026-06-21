# Lessons（自己改善ループ用メモ）

実装を進める中で気付いた、再発させたくない落とし穴・お作法を蓄積する場所です。
セッション開始時に見直し、関連するルールを再確認してください。

---

## 2026-06-17

### `runTest` で Flow を永続購読する ViewModel をテストするとき `MutableStateFlow` Fake は `UncompletedCoroutinesError` を起こす

- `init` で `repository.observeXxx()` を `scope.launch { collect }` する ViewModel（例: `AccountViewModel` の `observeAccount()`）を `runTest` でテストする際、Fake repo が `MutableStateFlow`（= 完了しない無限 Flow）を返すと、`advanceUntilIdle()` が待機中コルーチンの完了を待ち続けて `UncompletedCoroutinesError` になる
- 回避: テスト Fake では `flowOf(value)` で **1 値 emit 後に完了する Flow** を返す。`MapViewModel` テストの `FakeVisitRepository.observeAll` が `flowOf(emptyList())` を使っているのと同じ理由
- 「状態更新の連続変化をテストしたい」場合は `backgroundScope` を使った別アプローチが必要
- 発生源: Phase 5 アカウント機能 KMP 実装（`AccountViewModelTest` / `DeleteAccountUseCaseTest`）

### `SignInWithAppleButton`（SwiftUI 組み込み）は rawNonce を外部公開しない

- Firebase の `OAuthProvider.appleCredential(withIDToken:rawNonce:)` は nonce 検証のため rawNonce が必須だが、SwiftUI 標準の `SignInWithAppleButton` は内部で nonce を扱い外に出さない → link/signIn の nonce 突き合わせができない
- 対処: `ASAuthorizationController` を `async` ラップしたカスタムコーディネータ（`AppleSignInCoordinator`、CryptoKit で nonce 生成 + SHA256）を自作し、見た目は `applelogo` SF Symbol のカスタム黒ボタン（Apple HIG 相当）で代替する
- 補足: シミュレータでは `ASAuthorizationController` の Apple ID フローは起動しない（実機必須）。動作確認は実機作業になる
- 発生源: Phase 5 アカウント機能 iOS 実装（`AppleSignInCoordinator.swift` / `AccountView.swift`）

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

---

## 2026-06-10

### PhotosPicker の `selection` バインディングは選択処理後に必ず空配列にリセットする

- SwiftUI の `PhotosPicker(selection: $items, ...)` は、ユーザーが同じアイテムを再選択しても `selection` が前回と同一なら `onChange(of: items)` が発火しない
- 結果として「一度選択した写真と全く同じ写真をもう一度選んだとき」「選択 → 削除 → 同じ写真をもう一度選んだとき」に 2 回目以降が無視される
- 回避: `onChange(of: selectedPickerItems)` のハンドラ末尾で `selectedPickerItems = []` する。次の選択は必ず空 → 非空への遷移になるため確実に発火する
- 「選択結果をメモリで処理（Data 読み込み + ドメインモデル作成）した後にバインディングをクリア」のパターンが iOS 16+ のレシピ通り

### SourceKit の `No such module 'SharedLogic'` は実ビルドが通っていれば無視可（既出）

- 本プロジェクトでは Phase 2.5 以降頻発する。`xcodebuild` は BUILD SUCCEEDED でも IDE のインデックスだけ赤くなる
- 詳細は同ファイル既出の「SourceKit の `No such module 'X'` は実ビルド成功と乖離することがある」エントリ参照
- Phase 3 写真ピッカー実装時にも複数ファイルで同警告が出たが、`xcodebuild` 成功確認で問題ないと判断した

### KMP `androidMain` で kotlinx-datetime 等 `implementation` 宣言のライブラリは推移しない

- `shared/domain` が `kotlinx-datetime` を `implementation` で宣言している場合、`api` 依存で `domain` を取り込んでいても `androidMain` の Kotlin ソースからは `Instant` / `LocalDate` が見えない（コンパイルエラー）
- 対処: 使う側モジュールの `androidMain.dependencies { implementation(libs.kotlinx.datetime) }` に個別追加する。`commonMain` 側でも同様
- 同じことが他の `implementation` 宣言ライブラリ（`kotlinx-coroutines-core` 等）にも起きる。KMP の `androidMain` は JVM classpath として扱われるため、推移的依存の `api` / `implementation` 区別が strict に効く
- 公開 API（`Visit` data class が `Instant` プロパティを持つなど）の型として `kotlinx-datetime` が露出するなら `domain` 側で `api` 宣言に変えるべきだが、影響範囲が広がるため判断は慎重に

### callbackFlow 内での coroutine 起動は ProducerScope を取り出して使う

- `callbackFlow { ... }` の ProducerScope は `CoroutineScope` を実装しているため、ブロック内で `this.launch(Dispatchers.IO) {}` が使える
- リスナーコールバック（非 suspend）から suspend 処理（子コレクション取得など）を起こす場合は `val flowScope = this` でスコープを保持 → コールバック内で `flowScope.launch { ... }` するパターンが安全
- `GlobalScope` は使わない（ライフサイクルが callbackFlow と切り離されて、リスナー削除後も走り続けるリスク）

### Firebase Android SDK の `Task<T>` は `suspendCancellableCoroutine` で十分薄くラップできる

- `kotlinx-coroutines-play-services` を依存追加せずに、約 10 行のヘルパで `Task<T>.await(): T` を書ける
- 実装パターン:
  ```kotlin
  suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { cont ->
      addOnSuccessListener { cont.resume(it) }
      addOnFailureListener { cont.resumeWithException(it) }
  }
  ```
- Firebase Task のキャンセル自体はできないが、`invokeOnCancellation` でコールバック側無視で安全に破棄可能
- 将来本格的にキャンセル制御が必要になれば `kotlinx-coroutines-play-services:1.10.2` への切り替えは 1 行依存追加で済む

### SQLDelight 2.x の schemaVersion は migration ファイル名で自動決定される

- `build.gradle.kts` の `sqldelight { databases { create("AppDatabase") { ... } } }` に `schemaVersion` の明示指定は **不要**
- `src/commonMain/sqldelight/migrations/N.sqm`（N は旧バージョン番号）を置くだけで `AppDatabase.Schema.version` が自動的に `N + 1` になる。例: `1.sqm` を置けば Schema.version は `2`、`2.sqm` まで置けば `3`
- `AndroidSqliteDriver(AppDatabase.Schema, context, dbName)` / `NativeSqliteDriver(AppDatabase.Schema, dbName)` が Schema.version と既存 DB の `user_version` を比較して必要な migration を順次自動実行する
- migration ファイルの配置先は `.sq` ファイルと同じ `sqldelight` フォルダ内の `migrations/` サブディレクトリ（`src/commonMain/sqldelight/migrations/N.sqm`）。`build.gradle.kts` 側で srcDir 指定は不要
- migration ファイルの中身は SQL のみ（`.sqm` フォーマット）。例: `ALTER TABLE photo ADD COLUMN file_name TEXT;` のような ALTER 系を素で書ける
- 既存検証データを残したまま列追加できるため、Phase 中の開発でも端末データを毎回消す必要がない

### 既存 xcconfig がある環境で新規 xcconfig を base configuration に差し替える際の継承漏れ

- Xcode プロジェクトの `XCBuildConfiguration` で `baseConfigurationReference` を別 xcconfig に差し替えると、**既存 xcconfig の設定は引き継がれない**。`baseConfigurationReference` は「上書き」ではなく「差し替え」のため、`PRODUCT_BUNDLE_IDENTIFIER` / `TEAM_ID` / `OTHER_LDFLAGS` 等の必須設定が一斉に消える
- `xcodebuild` がたまたま BUILD SUCCEEDED するケースがあるが（DerivedData キャッシュ + KMP framework 側の linkerOpts 等で間接的に sqlite3 リンクが効くなど）、初回クリーンビルド or 別環境で破綻する
- 回避策: 新規 xcconfig の先頭で `#include "既存.xcconfig"`（必須 include）を書いて継承する。または既存 xcconfig 側に追記する
- 検証手順: 差し替え後の bundle ID が想定通りか `xcodebuild` ログの `--bundle-identifier ...` を必ず確認する（変更前後で bundle ID が変わっていないこと）
- 教訓の発生源: Phase 4 スライス 2-B で `Base.xcconfig` を新規追加して base に差し替えた際、既存 `Config.xcconfig` の `PRODUCT_BUNDLE_IDENTIFIER` / `OTHER_LDFLAGS = -lsqlite3` の継承が落ちた。事後検出 → `Base.xcconfig` 先頭に `#include "Config.xcconfig"` 追加で復旧

---

## 2026-06-16

### 横断 doc（architecture 現状図 / CLAUDE モジュール表 / 手動サマリ）は構造的に陳腐化する

Phase 5 まで進んだ時点で docs 全体を精査したところ、個々の doc の質は高いのに、全体を俯瞰する記述が Phase 2.5 で凍結し実態と乖離していた（`architecture.md`「現状」が 4 フェーズ古い / `CLAUDE.md` モジュール表が「Phase 3 以降で追加予定」のまま / `implementation_note.md`「現在生きてる方針サマリ」の include 件数・data-firebase 空殻・写真パスが旧情報）。原因は単発の更新漏れではなく構造的なので、汎用パターンとして記録する。

**なぜ起きるか（再発条件）:**

- doc は「進めると必ず触るフロー型（`tasks.md` / 各 implementation_note エントリ）」と「進めても触らないストック型（architecture 現状図 / CLAUDE 表 / 手動サマリ）」に分かれる。**作業動線上にあるかどうかが更新の有無を決める**。ストック型は明示タスクが無いと誰も触らない
- **「現状 / 目標」の二段構えは、目標達成後に逆機能する**。「Phase N で追加予定」と書いた未来が現在になった瞬間、現状節を書き換える明示アクションが無ければ恒久的に嘘になる
- **手動メンテのサマリ／キャッシュは、更新規律が切れると「一番信頼されるのに一番古い」最悪状態になる**。キャッシュ無効化トリガー（「モジュール追加時はサマリも直す」）を運用ルールに紐付けていないと腐る
- **縦スライス進行は横断 doc を孤児化する**。1 スライス＝1 機能の責任分界だと、そのスライスに直接関係する doc は触るが、全体俯瞰の横断 doc は「どのスライスの担当でもない」ため拾われない
- **方針転換の伝播漏れ**: 決定は一箇所（implementation_note）で更新されても、その旧仮説を前提に書かれた他 doc の記述（初期スケッチ）が連動更新されず化石化する（例: data-model の `VisitRepositoryImpl(firestore)` 直叩き例、kmp-bridge の `SharedFramework` 表記、requirements の「Android 後追いリリース」）
- サブエージェントは docs を読むが書けない → 「現状図と実態がズレている」というフィードバックループが弱く、検知が親の自発性頼みになる

**再発防止策:**

- 横断 doc は可能なら「現状 / 目標」の二段をやめ、**コード追従の一段**にして陳腐化面を減らす。将来構想は別途「ロードマップ」節に隔離し、現状記述と混ぜない
- **「モジュール追加・方針転換時は同 PR で CLAUDE 表・サマリ・architecture 現状図も直す」をチェックリスト化**（キャッシュ無効化を作業動線に組み込む）
- `settings.gradle.kts` 等の**機械的事実と doc を定期突き合わせる棚卸し**を定例化する。doc 全体精査自体をその定例とみなしてよい
- 方針転換時は implementation_note の「重要な方針転換は新エントリで旧を参照 / 陳腐化したら削除」ルールを、**昇格先・周辺 doc の旧記述消し込みまで**含めて運用する（決定の単一更新で終わらせない）

---

## 2026-06-19

### Kotlin/Native クロスモジュールの nullable プロパティは smart cast が効かない（commonMain では検出されない）

- `compileKotlinMetadata`（commonMain コンパイル）は通過するのに `compileKotlinIosArm64` / `assembleSharedLogicXCFramework` で `Smart cast to 'T' is impossible, because 'prop' is a public API property declared in different module` が出るケースがある
- 別モジュールで宣言された `val` プロパティは、`if (x?.prop != null)` の後でも別モジュールコンパイル時に smart cast されない（例: `feature/coffee-editor` から `domain` の `Cafe?` プロパティを参照）
- **修正パターン**: `val localProp = x?.prop; if (localProp != null) { use(localProp) }` でローカル変数にキャプチャ
- **検証への含意**: commonMain のコンパイル成功だけで KMP の正しさを判断しない。**`assembleSharedLogicXCFramework`（iOS ターゲット実コンパイル）を検証ステップに必ず含める**。Phase 7 の Visit→CoffeeRecord 再設計で発生
- 発生源: Phase 7 Phase 1（`CoffeeEditorViewModel` の `initial?.cafe` 参照）

### JdbcSqliteDriver（Android Host Test）は PRAGMA foreign_keys = ON が必要

- `testAndroidHostTest` が使う `JdbcSqliteDriver` は SQLite の Foreign Key サポートがデフォルト OFF。`ON DELETE CASCADE` のテストが通らない
- `AppDatabase.Schema.create(driver)` の直後に `driver.execute(null, "PRAGMA foreign_keys = ON", 0, null)` を実行する（`createInMemoryTestSqlDriver()` に追加）
- 実機の `AndroidSqliteDriver` / iOS の `NativeSqliteDriver` とは挙動が異なる。iOS テストで CASCADE を検証する場合も同様の pragma 設定を確認すること
- 発生源: Phase 7 Phase 1（`coffee_record` ⇄ `photo` の CASCADE 削除テスト）

### iOS ビルド検証で `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES` を付けると SharedLogic の Gradle ビルドがスキップされ「偽の成功」になる

- `xcodebuild ... OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES build` は「Compile Kotlin Framework」run script phase の **Gradle 起動をスキップ**する（ログに `Skipping Gradle build task invocation due to OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED environment variable set to "YES"`）
- DerivedData に前回ビルドの `SharedLogic.framework` が温存されていると、KMP 公開 API を変えた直後でも **古いフレームワークに対して Swift がコンパイルされ BUILD SUCCEEDED になる**。クリーンな DerivedData では `error: Unable to find module dependency: 'SharedLogic'` で落ちる
- **KMP の公開 API を変更した後の iOS 検証は、必ず override フラグ無し**（`xcodebuild -project iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -configuration Debug build`）で行い、ログに `> Task :shared:framework:...` と `BUILD SUCCESSFUL`（Gradle）が出ることを確認する
- サブエージェントが override フラグ付きで「BUILD SUCCEEDED」と報告したら、親は **フラグ無しで再検証**してから完了扱いにする
- IDE（SourceKit）の `No such module 'SharedLogic'` 診断は、フレームワーク未ビルドのインデックス環境では出る**偽陽性**のことが多い。`xcodebuild` の実ビルド結果を真とする
- 発生源: Phase 7 Phase 3（ios-engineer が override フラグ付きで成功報告 → 親のフラグ無し再検証で原因切り分け）

---

## 2026-06-21

### `KotlinDouble?` を `String(format:)` に直接渡すと 0.0 になる（nullable primitive の SKIE ブリッジ）

- Kotlin の nullable primitive（`Double?` / `Int?` 等）は SKIE 経由でも Swift では `KotlinDouble?` / `KotlinInt?`（= `NSNumber` 派生）になり、Swift native の `Double?` には**ならない**
- `String(format: "%.1f", kotlinDouble)` のように `KotlinDouble`(NSNumber) を `%f` に直接渡すと、`%f` が NSNumber のポインタ値を double として誤読し **0.0**（や不正値）を表示する。**コンパイルは通る**（NSNumber は CVarArg 準拠）ため気づきにくい
- **修正パターン**: `kotlinDouble.doubleValue` で Swift `Double` に変換してから渡す。算術演算に使う場合も同様
- **参照パターン**: 同一ファイル内で正しく `.doubleValue` を使っている箇所（例: `tastingAverages.sweetness?.doubleValue`）があれば、それに揃っているか全 use を grep で点検する
- 発生源: 分析タブの平均評価が 0.0 表示（`AnalysisView` の `CoffeeStats`/`CategoryStat`/`CafeStat` の `averageRating` 計 8 箇所。Phase A-3 からの潜在バグが 9-4b 作業中に発覚）

### オンデバイス小型 LLM（Foundation Models）の tool calling は instructions の「逃げ道」で呼ばれなくなる

- Foundation Models（Apple Intelligence のオンデバイス小型モデル）に `Tool` を登録しても、instructions が「ツールで照会して**よい**」（許可形）＋「不明なら『分かりません』と返す」（tool 未使用の早期 escape）を併記していると、モデルは tool を呼ばず安易に「分かりません」を返しがち
- **改善パターン**: ①個別データの問いには「**必ず**ツールを呼ぶ／ツールを呼ばずに分からないとは言わない」と命令形で書く ②「分かりません」は「**ツールを呼んだ結果が 0 件のときだけ**」に限定して早期 escape を塞ぐ ③tool description も指示的にする
- **切り分けの仕込み**: tool の `call` 冒頭/末尾と、セッション選択経路に診断 `print` を入れ、「tool が呼ばれていない」のか「呼ばれたが 0 件（filter マッチ漏れ）」なのかを実機ログで判別できるようにする。instructions 強化だけで不足なら、質問をプロンプト側で「個別 / 全体傾向」に事前分類してセッション分岐する案が次の手
- 発生源: 9-4b 対話 Q&A v2（個別記録の質問に「不明」を返す → instructions の逃げ道が原因）

## 2026-06-22

### `commonMain` で `Map.mapNotNull` + ローカル `data class` + `maxWith(compareByDescending)` が実行時に全 null を返した（原因未確定）

- `map.mapNotNull { (k, v) -> ローカル data class Candidate(...) }` のリストに対し `.maxWith(compareByDescending<Candidate> { ... }.thenBy { ... })` をチェーンしたところ、**コンパイルは通るが実行時に常に null / 期待外れの結果**になる現象が Phase B-1（`BuildCoffeeStatsUseCase` の好み判定）で発生
- 疑い: `compareByDescending<Candidate>` の型推論が `Candidate?` 側に解釈され比較が壊れた可能性（**根本原因は未確定**）。これは仮説なので鵜呑みにしない
- **対処**: 明示的な `for ((label, group) in map)` ループ＋並列 `MutableList`＋手動比較に書き直して解消。ユニットテストで挙動を担保（収縮逆転・タイ時のラベル順など境界ケース）
- **教訓**: 集計の選定ロジックは「コンパイルが通る＝正しい」ではない。`mapNotNull`＋ローカル data class＋`maxWith(comparator)` の合わせ技は避けるか、**必ず境界ケースのユニットテストで実挙動を確認**する

### 統計的な「好み判定」は単体テストでなく無相関ペルソナで偽陽性率を測ってから閾値を決める

- 「収縮＋件数ガード」のような統計ヒューリスティックは、機構ごとの単体テスト（収縮が効くか・タイ処理）が全部通っても**特異度（好みが無いときに黙れるか）は別問題**。無相関ノイズデータを多シード生成して**偽陽性率を実測**して初めて見える
- 実例: `FavoriteSignals` のカテゴリ好みは「最大群が globalMean を超えたら信号化」だが、これは「複数群の最良が平均を超えるか」＝**ほぼ恒真**で偽陽性率 100%。tasting 軸の「5 軸 max|r|≥0.3」も多重比較で 40%。どちらも単体テストでは検出不能だった
- **教訓**: ①「最大値が全体平均を超えたら採用」は閾値ガードにならない（最良は大抵平均を超える）。effect-size 閾値（差 > δ）や信頼区間下限など「ゼロからの距離」で見る ②複数候補から max を拾う設計は多重比較で偽陽性が乗る ③assert 閾値は**測定してから**決める（理論値を仮置きで hard-fail させると、偶然 pass か設計欠陥かを取り違える）。null ペルソナで「全フィールド null」を期待する固定シード assert を書く前に、本当に null になるシードが存在するかスキャンで確認する

### winner's curse には「固定オフセット閾値」でなく「ばらつき連動（n 連動）閾値」で対処する

- 複数候補から最良を選ぶと、最良の推定値は偶然ぶん上振れする（winner's curse）。この上振れ幅は**サンプリングのばらつき σ/√n に比例して膨らむ**ので、`値 − 基準 > 固定δ` のような固定オフセット足切りでは止まらない（B-1c 実測: カテゴリ偽陽性は δ を 0.10→0.30 に上げても 100%→87% しか下がらない）
- 一方、テイスティング軸の |r| 下限を `max(0.3, c/√n)` と**n 連動**にしたら偽陽性 40%→22%（c 上げで 8.7%）に下がった。閾値を不確実性に合わせてスケールさせるのが効く
- **教訓**: 「最良候補が基準を有意に超えるか」を問うガードは、固定オフセットでなく `差 > z · SE`（SE ≈ stdev/√n）のような n 連動の信頼区間ゲートにする。固定 δ は対症療法に留まると疑う
- **親の運用**: サブエージェントの「これはテストの人工物で実データなら問題ない」という説明は、数理 or 実測で裏が取れるまで**留保**する。鵜呑みにせず「現実的な分布で測り直す」一手を挟む（CLAUDE.md No Laziness / Verification Before Done）
