# Lessons（自己改善ループ用メモ）

実装を進める中で気付いた、再発させたくない落とし穴・お作法を蓄積する場所です。
セッション開始時に見直し、関連するルールを再確認してください。
セクションは発生日ごと・日付昇順。新しい教訓は末尾に追記する（2026-07-04 整列。旧例文は現行モデルに更新済み。2026-07-10 に完全重複 2 組を統合 — 昇格済みの教訓も発生源として残す方針は維持）。

---

## 主題別インデックス

本文は日付順で並ぶため、テーマから引くための地図。各項目末尾の `(MM-DD)` は該当エントリが載る日付セクション（`## 2026-MM-DD` を Cmd+F でジャンプ）。**新規 lesson を追記したら、この索引にも 1 行足す**（`record-lesson` skill の手順に含める）。

- **SKIE / KMP ブリッジ（Swift⇄Kotlin）**: SuspendInterop は呼び出し方向限定 (06-04) / デフォルト引数を引き出さない (06-04) / EnumInterop enum→@frozen・camelCase (06-09) / SKIE 型は `.swiftinterface` を見る (06-09) / `KotlinDouble?` を `String(format:)` 直渡しで 0.0 (06-21)
- **Gradle / Convention Plugin / XCFramework / 署名**: Gradle タスク名 (06-02) / includeBuild + version catalog パス (06-08) / precompiled script plugin と `register` 併用不可 (06-08) / `jvmToolchain(N)` で JDK 依存 (06-08) / build-logic で type-safe accessor 不可 (06-08) / `export` は `api` と別に明示 (06-08) / `XCFramework(name)` = `baseName` を揃える・宣言なしでタスク無し (06-08) / Umbrella 移行は Run Script 1 行 (06-08) / SPM `upToNextMajor` で古いメジャー解決 (07-14) / archive は Development 署名固定・`CODE_SIGN_IDENTITY` 明示で失敗 (07-20)
- **ビルド成功⇄実態の乖離（SourceKit / DerivedData / 偽成功）**: `No such module` が実ビルドと乖離 (06-08) / DerivedData 古い symlink (06-09) / `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES` は偽の成功 (06-19) / 実機バイナリは `grep -a` で確認 (06-23) / JVM green・iOS だけコンパイル不能の 2 種 (07-07)
- **SQLDelight / ローカル DB / migration**: 命名規則・テスト配置・`expect class` Beta 警告・トランザクションと Flow emit・`sqlite3_bind_blob` 未定義・モデルとマッパの責任分担 (06-02) / `schemaVersion` は `.sqm` ファイル名で決まる (06-10) / JdbcSqliteDriver は `PRAGMA foreign_keys=ON` (06-19) / 列追加は `Mapper.toRow` と `upsert` 両方 (07-07) / `Schema.migrate` の `oldVersion` の意味 (07-13)
- **Firebase / Firestore / Auth**: nullable はキー省略 (06-04) / Firebase CLI 重複インストール・Storage は Blaze 必須・Security Rules はリポジトリ管理 (06-06) / Android `Task` を `suspendCancellableCoroutine` (06-10) / `SignInWithAppleButton` rawNonce 非公開 (06-17) / Firestore マッパー二重手書きの追随漏れ (07-08)
- **xcconfig / Places / API キー / シリアライズ**: 既存 xcconfig の継承漏れ (06-10) / フォールバック宣言は `#include?` の前 (06-23) / REST DTO `emptyList` + `expectSuccess=false` で握り潰し・`encodeDefaults=false` で default フィールド脱落 (06-23)
- **Coroutines / Flow / ViewModel scope / テスト**: test ヘルパは実装モジュール内で閉じる (06-08) / `androidMain` の `implementation` は推移しない・`callbackFlow` は ProducerScope を取り出す (06-10) / `runTest` 永続購読 Fake で `UncompletedCoroutinesError` (06-17) / `runCatching` はコルーチン内で使わない・所有 `viewModelScope` + `clear()` (06-24) / 所有 scope テストは `finally { clear() }` (06-25) / `combine` に `MutableStateFlow` で 60 秒タイムアウト (06-29) / `clear()` は iOS/Native で `advanceUntilIdle` drain 必須・interface メソッド追加で fake 追随漏れ (07-06)
- **Kotlin/Native 言語仕様の罠**: KDoc 内 `/*` がネストコメント (06-08) / クロスモジュール nullable は smart cast 不可 (06-19) / `Map.mapNotNull` + `maxWith` が全 null・`maxWith(compareByDescending)` が逆 (06-22) / `enum.valueOf` は未知値で例外・`when(mode)` 早期 return で値を無言脱落・正規化辞書の contains 部分一致すれ違い (07-08)
- **iOS / SwiftUI / UI レイアウト**: PhotosPicker selection リセット (06-10) / 実機 debug の UI ジャンクは debug アーティファクトを疑う (06-23) / `UIWindow()` ゼロ引数 deprecated (06-24) / `Color.primary` ボタン背景がダークで不可視・タブ常駐 observation を `onDisappear` で切らない (06-25、07-03 再発) / `IPHONEOS_DEPLOYMENT_TARGET` 引き上げ後は `@available` を sweep (06-26) / `Group{if let}` + `.task` は発火しない (07-14) / `UIViewRepresentable` はサイズ明示 (07-15) / 深いネスト ViewBuilder が KeyPath エラーを誤誘導 (07-16) / 遅延コンテナ N 番目の `.task` が fold 下で未発火・位置が動く View の `DragGesture` は `.global` (07-22) / 幅を持つ子 View の `if` 条件生成は右寄せコンテナで兄弟をずらす (07-26)
- **統計 / 分析 / Foundation Models**: FM tool calling は instructions の逃げ道で呼ばれない (06-21) / 好み判定は無相関ペルソナで偽陽性率を測る・winner's curse は n 連動閾値 (06-22)
- **プロセス / 設計 / 診断の姿勢**: 横断 doc は構造的に陳腐化 (06-16) / テストダブルの接続を本番と乖離させない・dev シードが本番バグをマスク・KMP テスト実行の環境メモ (07-03) / 無音フォールバックは偽バグ報告になる (07-06) / 地図の「表示」と「解決」の集合ズレ (07-08) / 外部 SDK の required 判定はクライアントで制御不能 (07-14) / レイアウト実測の再入ガードが過渡値を破棄 (07-15) / ドメインのフィールドが写る先は 5 経路・export DTO が抜けやすい (07-25) / background dispatch 中の `git add -A` はコミットを混ぜる (07-25)

---

## 2026-06-02

### SQLDelight 2.x の命名規則

- `.sq` ファイル内の `CREATE TABLE coffee_record` から生成される Kotlin クラスは **`Coffee_record`**（先頭大文字のみ）になる。`CoffeeRecord` にはならない
- カラム名 `cafe_place_id` もそのまま `cafe_place_id` プロパティになる（自動 camelCase 化しない）
- Queries クラスは `.sq` ファイル名から: `CoffeeRecord.sq` → `CoffeeRecordQueries`、`Photo.sq` → `PhotoQueries`。データクラス名と命名が揃わないので注意
- ドメインモデルと生成行クラスの名前衝突は **import alias**（`import com.noricoffee.domain.Photo as DomainPhoto`）で解消する

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
- 子テーブル（`photo`）だけを更新した場合、`coffee_record` 行を観測している `observeAll` には emit が **来ない**。現行設計は常に `save(record)` で本体行も更新するため問題なしだが、将来子テーブル単独更新を入れるなら `combine` で複数 Query を束ねる

### iOS で `Undefined symbol: _sqlite3_bind_blob` が出たとき

- 原因: `NativeSqliteDriver`（の依存 `sqliter`）は iOS の **システム SQLite** に動的リンクする。`SharedLogic.framework` を `isStatic = true` で出しているので、最終リンク（Xcode 側のアプリビルド）で `-lsqlite3` が要る
- **`shared/framework/build.gradle.kts` の framework ブロックに `linkerOpts("-lsqlite3")` を入れただけでは不十分**（実測: 31 件の `_sqlite3_*` 未解決が残った）。`isStatic = true` の framework は Xcode 側のアプリリンクにフラグを伝播しないことがある
- 確実な対処: **Xcode の xcconfig に `OTHER_LDFLAGS = $(inherited) -lsqlite3` を追加**する。本プロジェクトでは `iosApp/Configuration/Config.xcconfig` がアプリの base configuration として使われているので、そこに書く
- Xcode のキャッシュが古い framework を掴んでいると反映されないので、**Product → Clean Build Folder** してから再ビルド
- なお Gradle 側の `linkerOpts("-lsqlite3")` も残しておくのが安全（KMP の build 内で iOS テスト等を走らせるときに必要になり得る）

### ドメインモデルとマッパの責任分担

- バリデーション（rating の範囲、name の長さ等）は **ViewModel 層に置く** 方針（`data-model.md` §7）
- Mapper は純粋な型変換に徹し、例外を投げる箇所を増やさない
- Enum の DB 表現は `name` 文字列。未知の値が DB に入っていたら `valueOf` が `IllegalArgumentException` を投げるが、これは「マイグレーション漏れ」を即座に検知できるのでむしろ望ましい

---

## 2026-06-04

### SKIE の SuspendInterop は呼び出し方向限定

- SKIE は「Kotlin の `suspend` / `Flow` を Swift から **呼び出す**」方向のエルゴノミクス改善ツール。Swift 側で `async throws` / `for await` が自然に使える
- **逆方向（Swift で Kotlin interface を実装する側）には効果が及ばない**: 生成された Obj-C プロトコル準拠の生シグネチャ（`completionHandler:` 形式 / `Kotlinx_coroutines_coreFlow` 戻り値）を実装する必要がある
- 現行では `AuthRepositoryIosImpl.swift` / `RemoteCoffeeDataSourceIosImpl.swift` / `CoffeeInsightProviderIosImpl.swift` がこのパターンに該当
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
- 2026-07-09 に `kmp-bridge.md`「デフォルト引数は Swift に伝播しない」節へルールとして昇格済み（本エントリは発生源として残す）

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
- 症状: ビルド・リンク・`import SharedLogic` はすべて成功するのに、Swift から `AppContainer` / `CoffeeRepository` 等が「Cannot find type in scope」になる。自モジュール内シンボルだけは引き続き見える
- 切り分け: `shared/framework/build/.../SharedLogic.framework/Headers/SharedLogic.h` を `wc -l` / `grep` で覗く。export 抜けだと数百行、`export(...)` 追加後は数千行に激変する（実測 631 行 → 2412 行）
- Umbrella framework パターン（`shared/framework` モジュール）でも同じ知見が必要。`export(...)` 群を framework モジュール側に集約する

### `expect/actual` を含む test ヘルパは「ヘルパが置かれているモジュールの内部から閉じる」

- `expect fun createInMemoryTestSqlDriver()` を `shared/data-local` の commonTest に置くと、その actual は同モジュールの `androidHostTest` / `iosTest` にしか書けない。他モジュールの commonTest から再利用する標準手段はない（`testFixtures` 導入 or ヘルパ自体を `commonMain` に置くなど工夫が必要）
- 結果として「合成リポジトリ（現 `CoffeeRepositoryImpl`）のテストを `shared/core` 側に置きたい」が、`data-local` の expect/actual ドライバを再利用したいので **テストを `data-local` 側に置く** 妥協が現実解になる
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
- 本プロジェクトでは `No such module 'SharedLogic'` として Phase 2.5 以降頻発（Phase 3 写真ピッカーでも複数ファイルで発生）。`xcodebuild` の BUILD SUCCEEDED を確認できていれば無視してよい（2026-06-10 の重複エントリを 2026-07-10 に統合）

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
- **enum の case 名も同様**: `.h` では全小文字に見えても Swift 実体は camelCase（2026-06-22 B-4 で `.roastlevel` と誤報告 → `.swiftinterface` 確認で `.roastLevel` が正と判明。ビルド成功が裏付け）。**docs に case 名を固定する前に** `strings <...>.swiftinterface | grep "case "` で実体を見る（2026-06-22 の重複エントリを 2026-07-10 に統合）

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

### KMP `androidMain` で kotlinx-datetime 等 `implementation` 宣言のライブラリは推移しない

- `shared/domain` が `kotlinx-datetime` を `implementation` で宣言している場合、`api` 依存で `domain` を取り込んでいても `androidMain` の Kotlin ソースからは `Instant` / `LocalDate` が見えない（コンパイルエラー）
- 対処: 使う側モジュールの `androidMain.dependencies { implementation(libs.kotlinx.datetime) }` に個別追加する。`commonMain` 側でも同様
- 同じことが他の `implementation` 宣言ライブラリ（`kotlinx-coroutines-core` 等）にも起きる。KMP の `androidMain` は JVM classpath として扱われるため、推移的依存の `api` / `implementation` 区別が strict に効く
- 公開 API（`CoffeeRecord` data class が `Instant` プロパティを持つなど）の型として `kotlinx-datetime` が露出するなら `domain` 側で `api` 宣言に変えるべきだが、影響範囲が広がるため判断は慎重に

### callbackFlow 内での coroutine 起動は ProducerScope を取り出して使う

- `callbackFlow { ... }` の ProducerScope は `CoroutineScope` を実装しているため、ブロック内で `this.launch(Dispatchers.IO) {}` が使える
- リスナーコールバック（非 suspend）から suspend 処理を起こす場合は `val flowScope = this` でスコープを保持 → コールバック内で `flowScope.launch { ... }` するパターンが安全
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

## 2026-06-17

### `SignInWithAppleButton`（SwiftUI 組み込み）は rawNonce を外部公開しない

- Firebase の `OAuthProvider.appleCredential(withIDToken:rawNonce:)` は nonce 検証のため rawNonce が必須だが、SwiftUI 標準の `SignInWithAppleButton` は内部で nonce を扱い外に出さない → link/signIn の nonce 突き合わせができない
- 対処: `ASAuthorizationController` を `async` ラップしたカスタムコーディネータ（`AppleSignInCoordinator`、CryptoKit で nonce 生成 + SHA256）を自作し、見た目は `applelogo` SF Symbol のカスタム黒ボタン（Apple HIG 相当）で代替する
- 補足: シミュレータでは `ASAuthorizationController` の Apple ID フローは起動しない（実機必須）。動作確認は実機作業になる
- 発生源: Phase 5 アカウント機能 iOS 実装（`AppleSignInCoordinator.swift` / `AccountView.swift`）

### `runTest` で Flow を永続購読する ViewModel をテストするとき `MutableStateFlow` Fake は `UncompletedCoroutinesError` を起こす

- `init` で `repository.observeXxx()` を `scope.launch { collect }` する ViewModel（例: `AccountViewModel` の `observeAccount()`）を `runTest` でテストする際、Fake repo が `MutableStateFlow`（= 完了しない無限 Flow）を返すと、`advanceUntilIdle()` が待機中コルーチンの完了を待ち続けて `UncompletedCoroutinesError` になる
- 回避: テスト Fake では `flowOf(value)` で **1 値 emit 後に完了する Flow** を返す。`MapViewModel` テストの Fake repo が `flowOf(emptyList())` を使っているのと同じ理由
- 「状態更新の連続変化をテストしたい」場合は `backgroundScope` を使った別アプローチが必要
- 発生源: Phase 5 アカウント機能 KMP 実装（`AccountViewModelTest` / `DeleteAccountUseCaseTest`）

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
- 実機の `AndroidSqliteDriver` / iOS の `NativeSqliteDriver` とは挙動が異なる。iOS テストで CASCADE を検証する場合も同様の pragma 設定を確認すること（→ 2026-07-03「テストダブルの接続設定」エントリで本番側の穴として顕在化）
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

---

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

### `maxWith(compareByDescending { ... })` は意図と逆の要素を返す

- `maxWith(Comparator)` は **Comparator 上で「最大」** の要素を返す。`compareByDescending { it.rating }` は「rating が大きいほど Comparator では小さい（前に来る）」順序なので、`maxWith` と組み合わせると **最低 rating の要素が選ばれる**（意図と逆）。コンパイルは通るので気づきにくい
- **正しいパターン**: 単一キーなら `maxByOrNull { it.rating }`。複合キー（rating 降順→日付降順→名前昇順 等）なら `sortedWith(compareByDescending<T>{ it.rating }.thenByDescending{...}.thenBy{...}).firstOrNull()`
- 2026-06-22 B-4（`ObserveTasteMatchedCafesUseCase` の代表記録選定）で発生。これは [[同日の mapNotNull+maxWith で全 null]] の「原因未確定」だった件の有力な真因でもある（`maxWith`+`compareByDescending` の取り違え）。**選定ロジックは必ず境界ケースのユニットテストで実挙動を確認する**（B-4 はテストで検出・修正済）

### winner's curse には「固定オフセット閾値」でなく「ばらつき連動（n 連動）閾値」で対処する

- 複数候補から最良を選ぶと、最良の推定値は偶然ぶん上振れする（winner's curse）。この上振れ幅は**サンプリングのばらつき σ/√n に比例して膨らむ**ので、`値 − 基準 > 固定δ` のような固定オフセット足切りでは止まらない（B-1c 実測: カテゴリ偽陽性は δ を 0.10→0.30 に上げても 100%→87% しか下がらない）
- 一方、テイスティング軸の |r| 下限を `max(0.3, c/√n)` と**n 連動**にしたら偽陽性 40%→22%（c 上げで 8.7%）に下がった。閾値を不確実性に合わせてスケールさせるのが効く
- **教訓**: 「最良候補が基準を有意に超えるか」を問うガードは、固定オフセットでなく `差 > z · SE`（SE ≈ stdev/√n）のような n 連動の信頼区間ゲートにする。固定 δ は対症療法に留まると疑う
- **親の運用**: サブエージェントの「これはテストの人工物で実データなら問題ない」という説明は、数理 or 実測で裏が取れるまで**留保**する。鵜呑みにせず「現実的な分布で測り直す」一手を挟む（CLAUDE.md No Laziness / Verification Before Done）

---

## 2026-06-23

### xcconfig はフォールバック宣言を `#include?` より「前」に置く（後ろだと実値を空で上書き）

- xcconfig は**同一キーの最後の代入が勝つ**。`#include? "Secrets.xcconfig"`（実キーを設定）の**後ろ**に `PLACES_API_KEY =`（空フォールバック）を書くと、Secrets の実キーが空文字で上書きされ、ビルドは通るが実行時に空キーになる
- 2026-06-23 の Places 疎通確認で、検索が常に「結果0件」になる真因がこれだった。フォールバックは必ず include の**前**に宣言する（`PLACES_API_KEY =` → `#include? "Secrets.xcconfig"` の順）
- **教訓**: 「Secrets があれば上書きする」系の xcconfig は、フォールバック→include の順序が絶対。検証は**ビルド成果物の `.app/Info.plist` を PlistBuddy で実読み**する（`$(VAR)` 置換の最終結果はソースを見ても分からない）

### Places/REST クライアントの DTO に `= emptyList()` デフォルト＋Ktor `expectSuccess=false` はエラーを握り潰す

- Ktor は既定（`expectSuccess=false`）で非2xxを例外化しない。レスポンス DTO の必須フィールドに `= emptyList()` 等のデフォルトがあると、403/400 のエラー JSON（`{"error":{...}}`）が `ignoreUnknownKeys=true` で**空の正常レスポンスにデコードされ**、例外もエラー表示も出ず「0件」に見える。**API 障害が常に『該当なし』に化ける**最悪のサイレント失敗
- 2026-06-23 Places 疎通確認で、空キー由来の 403 がこの経路で隠れ、真因特定が遅れた
- **教訓**: 外部 API クライアントの Ktor は `expectSuccess=true` を基本にし、必要なら `HttpResponseValidator` で**本文を含む**例外メッセージにする（デフォルトの `ResponseException.message` は本文を含まない）。「結果が空」を見たら、まず「本当に空 200 か / 握り潰した非2xx か」を疑う

### 実機バイナリに修正が入っているかは `grep -a` で文字列を直接確認できる

- 「ソース修正したのに挙動が変わらない」とき、ビルド/インストールが古い可能性を**バイナリ実読み**で切り分けられる。Kotlin/Native の静的フレームワークは Debug ビルドだと `<app>/coffeevision.debug.dylib` 側に入る（メイン実行ファイルは数十KBのスタブ）
- ヘッダ名やクラス名（例 `X-Ios-Bundle-Identifier` / `PlacesApiException`）を `LC_ALL=C grep -a -c "文字列" <dylib>` で検索し、在れば反映済・無ければ stale。`xcrun simctl get_app_container <udid> <bundleId>` で .app パスを取得

### kotlinx.serialization の `encodeDefaults=false`（既定）はリクエストのデフォルト値フィールドを丸ごと落とす

- kotlinx.serialization は既定で `encodeDefaults=false`。Ktor の ContentNegotiation で `Json{}` を構成する際に明示しないと、`data class` の**デフォルト値を持つフィールドがリクエスト JSON に含まれない**
- 2026-06-23 の Places で、`SearchNearbyRequest.includedTypes=listOf("cafe")` がデフォルト値ゆえに送信されず、型フィルタ無しの searchNearby になり駅・観光地が周辺ピンに並んだ。UI 上はエラーも出ず「それっぽい結果」が返るため気づきにくく、curl でリクエストボディを実送信比較して初めて発覚
- **教訓**: 外部 API クライアントの `Json{}` には `encodeDefaults=true` を明示する。`explicitNulls=false` と併用すれば null デフォルトは省略されるので「必須は送る・null は省く」が両立する。「サーバが期待するフィールドを送っているはず」を疑い、ビルドした実体の送信ボディを curl と突き合わせる
- 関連: Places searchNearby は `includedTypes`（副次タイプ含む・prominence 順）より `includedPrimaryTypes`（主タイプ）+ `rankPreference="DISTANCE"` の方が「実カフェを近い順」に絞れる
- 2026-07-09 に `coding-conventions.md` §1.12（kotlinx.serialization 規約）へ昇格済み（本エントリは発生源として残す）

### 「実機 debug でのみ重い」UI ジャンクは debug ビルド/デバッガアタッチのアーティファクトを最初に疑う

- 2026-06-23 カフェ検索タブで「キーボードを開くと重い」+ `Gesture: System gesture gate timed out.` / `Received external candidate resultset` / `containerToPush is nil` のログ。当初は MapKit 常駐や `.searchable` バインディングを疑ったが、ユーザー確認で **debug 状態以外では重くない**ことが判明し、実在の性能バグではなかった
- 原因の構造: (1) Kotlin/Native debug ビルドは非最適化で SKIE 往復・SwiftUI 再評価が桁違いに遅い、(2) Xcode デバッガアタッチ中は GeoServices 等がメインスレッドから吐く大量の os_log をコンソールへ転送するオーバーヘッドだけでメインスレッドが詰まり、キーボード提示のジェスチャが gate timeout する。Release（デバッガ非アタッチ）では消える
- **教訓**: 「重い」報告は最初に **(a) Release/Profile ビルドで再現するか (b) デバッガをデタッチして再現するか** を切り分ける。debug 限定なら追わない（MapKit ライフサイクル制御や Tab 構成の作り変えは実在しない問題への過剰設計になる）。`candidate resultset` / `containerToPush` / `gesture gate timed out` は OS フレームワーク由来のログでアプリからは抑制できない無害ノイズ
- 補足: このとき検索欄テキストを Kotlin StateFlow 直結から View ローカル `@State` + `.onChange` 一方向転送に変えた変更は、debug 問題とは独立に「表示を非同期ラウンドトリップに依存させない」定石として正しいので残した（`coding-conventions.md` §2.3 に昇格済み）

---

## 2026-06-24

### `runCatching` はコルーチン内（ViewModel / Repository）で使ってはいけない

- Kotlin の `runCatching` は `Throwable` 全体をキャッチするため、コルーチンキャンセル時の `CancellationException` も `onFailure` に落ちる。これにより (a) ローディングフラグをエラー扱いで上書きする競合、(b) スコープ上位へのキャンセル伝播の遮断（構造化並行性の協調キャンセルが弱まる）が起きる
- 2026-06-24 の Skill 観点レビュー（`kotlin-coroutines-flows`）で、各 feature の ViewModel と `CoffeeRepositoryImpl` に `launch { runCatching { ... }.onFailure { ... } }` パターンが横断的に存在していたのを発見・是正
- **教訓**: コルーチン内は `try/catch` を使い、`catch (e: CancellationException) { /* フラグをリセットして */ throw e }` を `catch (e: Exception)` より**前**に置いて明示再スローする。`IgnoreRemoteFailure`（Firestore リトライ委譲）のように `CancellationException` 以外を意図的に握りつぶすケースも、この `CancellationException` 先行 catch を入れれば `runCatching` を避けられる（[`implementation_note.md`](../implementation_note.md) 2026-06-24 エントリ参照）

### iOS 26 以降 `UIWindow()`（ゼロ引数 init）は deprecated

- `ASAuthorizationControllerPresentationContextProviding` のフォールバック等で `UIWindow()` を作ると iOS 26 でビルド警告が出る。`foregroundActive` な `UIWindowScene` を取得して `UIWindow(windowScene:)` を使う
- 2026-06-24 の Skill 観点レビュー（`ios-developer`）で `AppleSignInCoordinator` の `presentationAnchor(for:)` フォールバックを是正
- **教訓**: UIWindow を直接構築する箇所は到達しないフォールバックパスでも `UIWindowScene` 経由にする（警告ゼロを維持）

### 画面ごとの ViewModel に app-wide scope を共有させない（所有 scope + clear() で畳む）

- KMP の ViewModel に注入する `CoroutineScope` をアプリ全体で 1 本の `MainScope` のまま `launch` に使うと、push/pop 画面（NavigationStack push / sheet）の collector が画面破棄後も app-wide scope に残り**増殖リーク**になる。`onAppear` で per-job cancel していても、最後に開いた画面の collector は生き続ける
- 2026-06-24、`CafeDetailViewModel`（init collector）/ `CoffeeDetailViewModel`（onAppear collector）で顕在化。tab 常駐 VM は単一インスタンスゆえ増殖はしないが同根
- **教訓**: 各 ViewModel は注入 scope を親として `CoroutineScope(parent.coroutineContext + SupervisorJob(parentJob))` で**自分の子スコープを所有**し、`fun clear() { viewModelScope.cancel() }` を公開する。iOS Bridge は **`deinit`** で `kotlin.clear()` を呼ぶ（`onDisappear` は遷移アニメ中に発火するので push/pop 画面では不可）。`SupervisorJob(parentJob)` で親 Job に連結すれば app teardown 時の連鎖キャンセルも両立。`clear()` はスコープ畳みのみに留める（`Job.cancel()` はスレッドセーフ＝K/N の deinit スレッドから安全。`@MainActor` 前提の処理を足すと壊れる）（[`implementation_note.md`](../implementation_note.md) 2026-06-24「所有 viewModelScope + clear()」エントリ参照）
- **検証の落とし穴**: このリークは **Swift の Bridge を Instruments Allocations で見ても検出できない**。Bridge は `[weak self]` で循環がなく修正前から正しく deinit するため、Swift クラスでフィルタした Persistent は修正前後とも「表示中=1 / pop 後=0」で**変わらない**。実際に漏れるのは **app-wide scope で走り続ける Kotlin の collector と、それに掴まれて解放されない Kotlin VM**（Swift 名では出ず、K/N オブジェクトの解放追跡も Instruments では不安定）。→ 検証は**コルーチンの寿命**で見る: collector に `.onCompletion { println(...) }` を一時的に仕込み、push→pop で完了ログが出れば畳めている。修正前は出ない（孤児コルーチン継続）。「Swift 側の解放＝リーク解消」ではない点に注意

---

## 2026-06-25

### ボタン背景に `Color.primary` を使うとダークモードで不可視になる

- 2026-06-25、`AccountView` の「Apple でサインイン」ボタンが背景 `Color.primary.opacity(0.9)` + 前景 `.white` だった。`Color.primary` はライトで黒・**ダークで白**になるため、ダークモードで「白背景 + 白文字」となりボタンがほぼ見えなかった（ユーザー報告で発覚。ビルドは通るので静的には気づけない）
- 原因の構造: `Color.primary` / `Color(.label)` は前景テキスト用のセマンティックカラーで colorScheme に応じて反転する。これを**ボタンの背景**に使い、前景を固定色（`.white`）にすると、片方のモードで前景と背景が同色化する
- **教訓**: Sign in with Apple のような**固定配色が要るボタン**は `@Environment(\.colorScheme)` で背景・前景を明示分岐する（ライト: 黒背景+白文字 / ダーク: 白背景+黒文字+`Color(.separator)` ボーダー、が Apple HIG 慣習）。反転するセマンティックカラーを背景に使うときは前景も必ず連動させる。Preview 用ダミー View に同スタイルを複製している場合はそちらも同時修正

### 所有 viewModelScope（SupervisorJob 子スコープ）を持つ ViewModel のテストは `finally { vm.clear() }` が必須

- 「所有 viewModelScope + clear()」パターンの ViewModel を `runTest { ... }` でテストする際、親に `this`（TestScope）を渡すと VM の `viewModelScope` が `TestScope` の子 Job として登録される。テスト終了時にこの子スコープが生きていると `runTest` が `UncompletedCoroutinesError` を報告してテストが**失敗**する。`advanceUntilIdle()` だけでは collector 等が残るため不十分
- 2026-06-25、`CafeSearchViewModel` にバイアス版 `onSearchTapped` を追加してテストを通そうとした際に発覚。git stash で確認したところ**変更前から cafe-search の全テストが同エラーで落ちていた**（新メソッド追加で初めて実行され顕在化）
- **教訓**: 各テストの `runTest` ブロックを `try { ... } finally { vm.clear() }` で囲み（末尾で `vm.clear()` でも可）、テスト終了前に必ず scope を畳む。**横展開注意**: 同パターンを持つ他 feature の既存テストも同様に落ちる（2026-06-29 の `MapViewModel` タグフィルタ実装時にも同対応を実施）
- 注意: `scope = backgroundScope` は `advanceUntilIdle()` の到達範囲外になるケースがある（Job がルートになる実装）。「テスト中に完了を待つコルーチン」（`poiLookupJob` 等）には使わない

### タブ常駐 View の `@State` ブリッジ observation を `onDisappear` でキャンセルしない

- `Tab { CafeSearchView(...) }` のようにタブのルートに直接置かれた View は、タブ切替や子画面 push（`CafeDetailView` への `NavigationLink`）で `onDisappear` が発火するが、**View インスタンス自体は破棄されず `@State` も保持される**。ここで `.onDisappear { bridge.cancel() }` のように Kotlin `StateFlow` の `observationTask` を止めると、`startObservation()` は init でしか呼ばれないため、戻ってきても観測が再開されず、以降 Kotlin 側の状態更新が Swift に一切反映されなくなる
- 2026-06-25、`CafeSearchView` でこれが顕在化（検索 → カフェ詳細 push → 戻る、で検索が効かなくなる「1,2 回はできたが止まる」バグ）。`.onDisappear { bridge.cancel() }` を削除して解消
- **教訓**: タブ常駐 View（`@State` でブリッジを自前生成し、push/タブ切替で破棄されないもの）の observation は `onDisappear` でキャンセルしない。observation は**ブリッジの `deinit`（`kotlin.clear()`）まで生かす**。sheet/push で都度生成・破棄される使い方（同 View を sheet 起動するモード等）では、View 破棄 → `deinit` が自然に observation と Kotlin scope を片付ける。`onDisappear` は「遷移アニメ中にも発火する」「常駐 View では再 init されない」の二点で破棄フックとして不適。所有 viewModelScope の `clear()` を呼ぶのも同じ理由で `deinit` 起点にする（本ファイル 2026-06-24「画面ごとの ViewModel に app-wide scope を共有させない」エントリと同根）

---

## 2026-06-26

### `IPHONEOS_DEPLOYMENT_TARGET` を上げたら冗長な `@available` / `#if available` を即 sweep する

- デプロイターゲットが iOS 26.0 なのに `@available(iOS 26.0, *)` 属性や `if #available(iOS 26, *)` 分岐が各所に残っていた（Foundation Models 導入時に「26 専用 API だから」と機械的に付けた名残）。ターゲット = 対象 OS 下限なので、下限と同じバージョンの可用性ガードは**全て冗長**。
- 対処: ターゲットを上げた直後に `grep -rn "@available(iOS <target>" iosApp --include="*.swift"` と `if #available(iOS <target>` を sweep して除去する。型宣言に付いた `@available` が残ると、その型を参照する `#Preview` 内にも `@available` が連鎖して残り見落としやすい。
- `if #available { A } else { B }`（B = 下限未満フォールバック）は then 節 A を素のコードに開いて else を削る。
- 注意: ターゲット**より上**の OS を対象にした `@available`（例: ターゲット 26 で `@available(iOS 27, *)`）は当然残す。sweep 対象は「ターゲットと同一バージョン」のものだけ。
- 別件で混同しないこと: `#if DEBUG` には2用途がある。①機能ゲート（未リリースなら不要 → 除去）②Xcode Preview 補助（`#Preview` / preview 専用サンプル、リリースバイナリ除外目的 → 残す）。dev 専用ツール（ダミーデータ投入/削除など破壊的副作用を持つもの）の DEBUG ゲートも残す。
- 発生源: iOSDC LT 逆変換 PoC 追加後のクリーンアップ（`implementation_note.md` 2026-06-26）。

---

## 2026-06-29

### `combine` のアップストリームに `MutableStateFlow` を含めると `runTest` が 60 秒タイムアウトする

- `combine(flowA, flowB, mutableFlow)` の形で `MutableStateFlow`（完了しない Flow）を含めた `collect` を `scope = this`（TestScope）の viewModelScope で実行すると、コルーチンが終了しないため `runTest` が `UncompletedCoroutinesError` を出す
- **教訓**: `combine` に入れてよいのは「完了する Flow」（`flowOf` / DB ワンショット / `take(1)` 等）のみ。「選択状態」等の変化ストリームは `combine` から外し、変化イベントごとに副作用メソッドで即時再計算するキャッシュ変数パターンにする
- 2026-06-29、`MapViewModel` タグフィルタ実装で `_selectedTagsFlow` を `combine` に含めようとして顕在化

---

## 2026-07-03

### 「observation を onDisappear でキャンセルしない」既知パターンが CafeDetailView で再発

- 2026-06-25 に `CafeSearchView` で記録済みの同型バグ（本ファイル 2026-06-25「タブ常駐 View の `@State` ブリッジ observation を `onDisappear` でキャンセルしない」）が、`CafeDetailView` にも残存していたことが 2026-07-03 の iosApp 全件レビューで発覚。push → pop 後に `startObservation()` を再呼び出しする経路がなく、コーヒー一覧・カフェ情報が凍結する
- lessons 記録時（2026-06-25）に**横展開点検をしていなかった**のが直接原因。今回のレビューで全 `*ViewModelBridge` を横断点検し、凍結するのは `CafeDetailView` のみと確認（`CoffeeListView` / `AnalysisView` / `CoffeeDetailView` は `onAppear` で観測を再スタートする型のため自己回復する。ただし規約上は deinit まで生かす型に寄せるのが望ましい → 別途バックログ）
- **教訓**: バグパターンを lessons に記録したら、その場で `grep -rn "onDisappear" iosApp/ | grep -i "cancel"` 相当の横断点検までやり切る。点検結果（該当なし / 該当あり→修正）も lessons に残す。レビュー時のチェック観点: 「`cancel()` を呼ぶ `.onDisappear`」があれば、observation を再開する経路が本当にあるかを必ず追う

### テストダブルの接続設定を本番ドライバと乖離させると「テストは通るのに本番で壊れる」

- shared レビュー #3（FK 無効）の根: JVM テストドライバだけ `PRAGMA foreign_keys = ON` を明示し、本番 `DatabaseDriverFactory`（android / ios）と iOS テストドライバは既定 OFF のままだった。cascade テストは JVM でだけ green になり、本番では photo の `ON DELETE CASCADE` が一度も発火していなかった
- **教訓**: 接続レベルの設定（PRAGMA / driver config）はテストと本番で必ず同一にする。乖離させる場合（inMemory 等）は差分をコメントで明示する。スキーマに `ON DELETE CASCADE` / トリガ等「接続設定に依存する宣言」を書いたら、その場で全ターゲットの有効化を確認する
- 併発した第 2 の穴: commonTest を `testAndroidHostTest` でしか回しておらず、iOS ターゲットでは cascade テストが赤だったことに気づけなかった。**commonTest は iosSimulatorArm64Test でも回す**（CI 導入時は必須ターゲットに含める）

### dev シードデータが本番の作成経路のバグをマスクする

- shared レビュー #2（エディタの座標欠落）が長期間気づかれなかったのは、`DummyCoffeeData` が座標付きの `Cafe` を直接組み立てており、マップのピン表示がシードデータでは正常に見えていたため。本番経路（`CoffeeEditorViewModel.buildRecord`）は座標を常に null で保存していた
- **教訓**: シードデータは可能な限り本番の作成経路（ViewModel の save）を通す。直接組み立てる場合は「本番経路で作れない状態をシードが作っていないか」をレビュー観点にする。機能検証は最低 1 回シードなし（実経路のみ）で行う

### KMP テスト実行の環境メモ（Gradle タスク名 / sandbox の Xcode 制約）

- ユニットテスト実行タスクは `testAndroidHostTest`（`androidHostTest` はソースセット名。AGP 慣例で `test` プレフィックスが付く）。サブエージェントへの指示に検証コマンドを書くときは実在タスク名を確認してから書く
- サブエージェントの sandbox では `xcode-select` が CommandLineTools を指し、`iosSimulatorArm64Test` 等リンク・実行を伴うタスクは `MissingXcodeException` で失敗する。フロントエンドコンパイル（`compileKotlinIosSimulatorArm64` / `compileTestKotlinIosSimulatorArm64`）は通るため構文・型検証はそれで代替し、テスト実行は親セッションで `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew ...` を付けて行う（2026-07-03 実証済み）

## 2026-07-06

### 無音フォールバック設計の機能は環境要因と切り分けられず「偽バグ報告」になる

- **症状**: 15-B の現在地カフェサジェスト（要件 2-8）が「表示されない」とバグ報告された。実装は正常で、原因はシミュレータの **Features > Location が未設定（None）** で位置取得が失敗していたこと（Custom Location 設定で表示を確認）
- **原因の構造**: 2-8 は「許可未決定・位置取得失敗・Nearby 失敗をすべて無音にする」仕様のため、(a) アプリの許可が未決定 (b) シミュレータの Location 未設定 (c) 検索 0 件 (d) 実装バグ、のどれでも見た目が同一（何も出ない）になる。無音フォールバックを仕様にした時点で、切り分け手段を用意しない限りあらゆる環境要因が「バグに見える」
- **修正パターン**: 検証チェックリスト・目視依頼文に**環境前提**（シミュレータの Features > Location、アプリの位置情報許可状態）と**切り分け手順**（まずマップの現在地ボタンで許可 + 取得が生きているか確認 → 対象機能を見る）をセットで書く。tasks.md 15-B 検証行に追記済み
- **教訓**: 「失敗を無音にする」仕様を確定させるときは、同じ変更内で検証手順に環境前提を書き下ろす（仕様確定と検証手順はセット）。親がユーザーに目視依頼を出すときも依頼文にこの前提を含める
- **発生源**: フェーズ 15-B（`CoffeeEditorView` 現在地サジェスト、2026-07-06）
- **横展開点検（2026-07-06）**: `grep -rn "requestLocation()" iosApp` → 位置情報利用は `CoffeeEditorView`（無音設計・今回対処済み）と `MapTabView`（`activeToast` で `locationManager.error` を可視化する設計のため無音ではない）の 2 画面のみで該当なし。他の環境ゲート系（Foundation Models = フェーズ 8 / 12-C / 13、E-1 Apple サインイン、フェーズ 14 実 Places キー）は tasks.md 検証行に「Apple Intelligence 有効実機」「実機必須」「実 Places API キー必要」の前提が明記済み → 漏れなし

### VM テストの `vm.clear()` は iOS/Native では直後に `advanceUntilIdle()` で drain が要る

- **症状**: 15-D で `AnalysisViewModelReadinessTest` / `AnalysisViewModelQaTest` が **iosSimulatorArm64Test だけ 16 件全滅**（`UncompletedCoroutinesError: After waiting for 1m, there were active child jobs: [SupervisorJobImpl{Active}]`、各 60 秒）。`testAndroidHostTest` は全 green。各テストは `try { … } finally { vm.clear() }` を既に持っていた
- **原因の構造**: `vm.clear()`＝`viewModelScope.cancel()` は**キャンセルをスケジュールするだけ**。Kotlin/Native の `runTest` は完了チェックがこのキャンセル処理より先に走るため、VM の `SupervisorJob` が `Active` のまま残り timeout する。JVM（androidHostTest）は runTest の最終 drain がキャンセルを処理するため顕在化しない
- **修正パターン**: `finally { vm.clear() }` を **`finally { vm.clear(); testScheduler.advanceUntilIdle() }`** にする（キャンセルを test body 内で drain し、runTest の完了チェック前に SupervisorJob を finalize させる）。`backgroundScope` に VM を載せる案は「`advanceUntilIdle()` が VM の observe を駆動せず state が null になりアサーション失敗」という別の壊れ方をしたため不採用
- **教訓**:
  1. **VM テストは必ず `iosSimulatorArm64Test` でも実行する**（親作業。`testAndroidHostTest` の green はコルーチン後始末の Native 差を検出できない。既存教訓「commonTest は iosSimulatorArm64Test でも回す」の具体例）
  2. 独自 `viewModelScope`（`SupervisorJob(scope[Job])`）を持つ VM のテストで iOS だけ `UncompletedCoroutinesError` が出たら、まず clear 後の `advanceUntilIdle()` を疑う
- **発生源**: フェーズ 15-D（`shared/feature/analysis` の VM テスト、2026-07-06）
- **横展開点検（2026-07-06）**: `grep -rln "\.clear()" shared --include="*Test.kt"` で全 VM テスト 8 ファイルを点検。clear 後 drain を入れたのは analysis の 2 ファイルのみ。他 6（coffee-editor / coffee-list / map×2 / cafe-detail / cafe-search）は**現状 clear 後 drain 無しでも iOS green**（Map×2 / CoffeeList / CafeDetail / CoffeeEditor は本フェーズまでに iosSimulatorArm64Test 実測 green を確認済み）。＝現時点で壊れているのは analysis のみで修正済み。他は「同型リスクはあるが未発症」のためフラジャイルだが変更しない（Minimal Impact）。将来いずれかが iOS で同エラーを出したら 1 行（clear 後 drain）で直せる

### interface にメソッドを足したら、その interface を実装する**テスト用 fake** の追随漏れで commonTest が長期間コンパイル不能になりうる

- **症状**: 15-D 着手時、`AnalysisViewModelQaTest` の `FakeCoffeeInsightProvider` が `CoffeeInsightProvider.summarizeBeanTraits`（フェーズ 12-C で追加）を override しておらず、`compileTestKotlinIosSimulatorArm64` / `testAndroidHostTest` が**ずっと FAILED のまま見過ごされていた**（本体の `compileKotlinIosSimulatorArm64` は green なので気づけない）
- **原因の構造**: 本体（main）のコンパイルが通っても、同一モジュールの commonTest が別原因（interface 拡張時の fake 追随漏れ等）でコンパイル不能なまま放置されうる。テストが「存在するが一度も実行できていない」状態は、実行ログを見ないと本体ビルドの green に紛れて見えない
- **修正パターン**: `interface` に abstract メソッドを追加したら、その場で `grep -rln ": <InterfaceName>" shared --include="*Test.kt"` でテスト fake を洗い出し、`compileTestKotlin*` / `testAndroidHostTest` / `iosSimulatorArm64Test` まで通ることを確認する
- **教訓**: 既存 VM / interface に手を入れる際は「その commonTest が実際に**実行**できているか」を疑う（未着手 VM のテスト有無だけでなく、着手済みテストが実行可能かも）。CI 導入時は `iosSimulatorArm64Test` を必須ターゲットに含める（これが無いと Native のコンパイル/実行の破れが素通りする）
- **発生源**: フェーズ 12-C の `summarizeBeanTraits` 追加時（fake 追随漏れ）→ 15-D で発覚・修正（2026-07-06）
- **横展開点検（2026-07-06）**: `CoffeeInsightProvider` を実装する fake は `AnalysisViewModelQaTest`（修正済み）のみ（`grep -rn "CoffeeInsightProvider" shared --include="*Test.kt"`）。他 interface（`CoffeeRepository` / `RemoteCoffeeDataSource` / `CafeRepository` 等）の test fake は、直近フェーズ（15-A〜C）で各モジュールの `iosSimulatorArm64Test` が実測 green のため追随漏れ無しと確認

## 2026-07-07

### SQLDelight で列を追加したら `Mapper.toRow()` だけでなく Repository の `queries.upsert(...)` 呼び出しにも手で足す

- **症状**: 15-E-1 で `coffee_record` に `brew_recipe` 列を追加。`.sq` の `upsert` 文と `Mapper.toRow()` を直しても、`LocalCoffeeRepository.save()` 内の `coffeeRecordQueries.upsert(...)` は **named パラメータで各値を明示的に渡している**ため、新列の引数が漏れて `compileKotlinIosSimulatorArm64` が `No value passed for parameter 'brew_recipe'` で FAILED
- **原因の構造**: SQLDelight の生成 `upsert(...)` 関数は列ごとの引数を取る。`Mapper.toRow()` が `Coffee_record` 行オブジェクトを作っても、Repository が行オブジェクトを丸ごと渡さず個別引数で呼んでいると自動反映されない（`row.brew_recipe` を明示的に渡す 1 行が要る）
- **修正パターン**: 列追加時のチェックリスト = ①`.sq`（CREATE + upsert 文）②`migrations/N.sqm`（ALTER ADD COLUMN）③`Mapper.toRow()`/`toDomain()` ④**`LocalXxxRepository` の `queries.upsert(...)` 呼び出し** ⑤Firestore mapper（android/ios 両方）⑥ドメイン model。コンパイラが ④ の漏れを `No value passed for parameter` で必ず捕まえるので、`compileKotlinIosSimulatorArm64` まで通して確認する
- **教訓**: SQLDelight の列追加は「.sq と Mapper を直せば終わり」ではない。Repository の named-parameter upsert 呼び出しが単一の見落としポイント。列追加時は上記 6 点セットで grep 点検する
- **発生源**: フェーズ 15-E-1（`brew_recipe` 追加、2026-07-07）
- **横展開点検（2026-07-07）**: 現状 `queries.upsert(` を named 引数で呼ぶ Repository は `LocalCoffeeRepository` / `LocalSavedCafeRepository` の 2 箇所。今回の追加で `LocalCoffeeRepository` は修正済み。`LocalSavedCafeRepository`（saved_cafe）は今回の列追加対象外で漏れなし

### 「JVM green・iOS だけテストコンパイル不能」の具体形 2 種（stdlib assert / data class フィールド追加のテスト側未追随）

- **症状**: フェーズ 16 の `Cafe.userRatingCount` 追加時、`testAndroidHostTest` は全 green なのに `compileTestKotlinIosSimulatorArm64` が data-places で FAILED。原因は今回の変更ではなく、①`PlacesClientImplPhotoMediaTest` が Kotlin stdlib の `assert(...)` を使用（Native では `ExperimentalNativeApi` opt-in が必要でコンパイル不能。JVM では `-ea` なしだと実行すらされず素通り）、②`CafeRepositoryImplSearchTextTest` の `PlaceSummary(...)` 構築がフェーズ 10-a/b のフィールド追加（openNow〜googleRating の 5 個）に未追随のまま放置されていたこと
- **原因の構造**: 2026-07-06 の「interface 拡張時の fake 追随漏れ」と同根 —「本体は green、テストは存在するが iOS でコンパイルすらできていない」状態は実行ログを見ないと気づけない。今回の 2 形はどちらも **JVM では無害なので `testAndroidHostTest` が検出できない**（stdlib `assert` は JVM で no-op、②は JVM テストも壊れるはずだが該当テストが iOS 専用経路でしか顕在化しない位置にあった）。壊れたまま数フェーズ潜伏し、無関係な変更（今回のフィールド追加）の検証で発覚する
- **修正パターン**: ① テストのアサーションは常に `kotlin.test` の `assertTrue` / `assertEquals` を使う（stdlib `assert` 禁止）。② `data class` にフィールドを追加したら `grep -rn "<ClassName>(" shared --include="*Test.kt"` でテスト側の直接構築箇所を洗い出して追随する（デフォルト値があっても named 引数でない構築は壊れる）
- **教訓**: shared のフィールド/メソッド追加時は、対象モジュールだけでなく **`./gradlew compileTestKotlinIosSimulatorArm64`（全モジュール）** を回すと潜伏中の破れも一緒に検出できる（3 秒で終わる安価な sweep）。サブエージェントには compile まで、実行は親（verify-kmp-ios の分担どおり）
- **発生源**: フェーズ 16（`Cafe.userRatingCount` 追加の検証中に発覚、2026-07-07。修正は kmp-engineer が同フェーズ内で実施）
- **横展開点検（2026-07-07）**: ① `grep -rnE '(^|[^a-zA-Z.])assert\(' shared --include='*.kt'`（assertTrue/assertEquals 除外）→ 該当なし（今回の置換で全滅）。② 全 shared モジュールで `compileTestKotlinIosSimulatorArm64` → BUILD SUCCESSFUL（他モジュールに潜伏中の未追随なし）

## 2026-07-08

### 地図の「表示」と「解決」で対象集合の定義がズレると、見えるのにタップで別店/見つからない不整合になる

- **症状**: マップの周辺カフェピン（Apple `MKLocalPointsOfInterestRequest` の `.cafe` 由来）をタップすると、種類の違う近隣店（ランドリー併設カフェ・食事カフェ等）が**全部「近くの唯一の cafe 型の店」に解決**されてしまう（ユーザー報告: 3 つの別ピンがすべて「夢やカフェ」を開く）。その前段では「該当カフェなし」や「近くの別店」も発生（フェーズ 17-B / 17-C）
- **原因の構造**: **表示する集合の定義と、解決する集合の定義が食い違う**のが根本。ピンは Apple の POI 種別（`.cafe`）で表示するのに、解決は Google Places の `includedType=cafe` / `includedPrimaryTypes=[cafe, coffee_shop]` という**別の分類体系の型フィルタ**で候補を絞っていた。Apple が cafe 扱いでも Google では laundry / restaurant 型の店は解決候補にすら入らず、近傍の型一致店へ吸い込まれる。「型で絞ってから最近傍を採る」系の調整（17-B: searchText 型フィルタ → 17-C: searchNearby 最近傍 → 名前一致優先）を 2 回重ねたが、いずれも**型フィルタで候補が欠落する**という真因に触れておらず、同系統の対症療法だった
- **修正パターン**: 座標と名前が分かっている「解決（1 点の同定）」では、**表示側と同じ広さの集合を候補にする**＝型フィルタを外し、名前 + 位置バイアスで検索（`searchByNameNear`、`includedType` を JSON から省略）→ 候補から**タップ座標最近傍**（名前一致優先）を選ぶ。見つからなければ近傍の別店にフォールバックせず「該当なし」にする（自信満々に誤った店を開かない）。「表示集合 ⊇ 解決候補集合」を保て（解決候補が表示より狭いと、見えるのに解決できない/別物に化ける）
- **教訓**: 「一覧を出すフィルタ」と「1 件を同定するフィルタ」を**別物として設計**する。前者は絞り込み（ノイズ削減）が正義だが、後者で同じ絞り込みを流用すると対象が欠落して誤同定・不整合になる。異なるデータ提供者をまたぐ（Apple 表示 ⇄ Google 解決）ときは分類体系が一致しない前提で、同定は型ではなく名前+座標で行う。同系統の対症療法を 2 回試して直らなければ、フィルタ/集合の定義そのものを疑う（Plan Mode Default の「2 回失敗で再調査」の実例）
- **発生源**: フェーズ 17（Apple 検索由来の自前カフェピン導入）→ 17-B/17-C/17-D で 3 段階に判明（2026-07-07〜08）
- **横展開点検（2026-07-08）**: `grep -rn "includedType\|includedPrimaryTypes\|MKPointOfInterestFilter\|pointsOfInterest" shared iosApp`（非テスト）で「表示⇄解決の集合ズレ」箇所を洗い出し。①POI タップ解決（今回修正済）が唯一の表示⇄解決ミスマッチだった。②「このエリアを検索」（`searchNearby` cafe/coffee_shop）は**検索結果をそのまま表示**するため表示=解決で不整合なし（意図的な cafe 絞り込み）。③波及: 解決から型フィルタを外したことで bakery も名前+位置で解決可能になり、iOS 取得を `.cafe` 限定にした 17-B の理由（`MapTabView.swift:1383` コメント）が無効化 → 表示スコープの再検討候補として tasks.md 17-D に記録（今回は据え置き）

### Firestore マッパーは Swift/Kotlin の二重手書き実装。片側の `toDocument` 変更は必ず対向を突き合わせる（追随漏れ = 無言のデータロス）

- **症状**: iOS でコーヒー記録に**タグを付けて保存すると、別端末・再インストール・Android で同期したときタグが空になる**（永久消失）。originating 端末のローカル SQLDelight にはタグが残るため気づきにくい。コンパイルエラーも実行時例外も出ない
- **原因の構造**: Firebase は公式プラットフォーム別 SDK（GitLive 不採用）方針のため、`CoffeeRecord ↔ Firestore` のシリアライズは **iOS 側 `iosApp/.../CoffeeFirestoreMapper.swift` と Android 側 `shared/data-firebase/androidMain/.../CoffeeFirestoreMapper.kt` の独立した手書き二重実装**。Kotlin `toDocument` は `"tags" to record.tags` を必須で書くが、Swift `toDocument` の `doc` 辞書リテラルに `tags` キーが欠落していた。**両側の `fromDocument` は `tags` を読む**ため、書き手（iOS）だけがフィールドを落とすと送信ドキュメントに載らず、受信側は既定の空リストになる。片側実装だけを変更/追加した際の追随漏れで、型システムは非対称を検出できない
- **修正パターン**: Swift `toDocument` の `doc` 辞書に Kotlin と対称に `"tags": record.tags,` を追加（空配列でもキー省略しない＝Kotlin と同じ）。恒久策として **Firestore マッパーは片側を触ったら必ず対向プラットフォームの `toDocument`/`fromDocument` を全フィールド突き合わせる**。フィールドの単一の真は `docs/data-model.md`（§3.2）で、両実装をそこへ照合する
- **教訓**: 「interface に fake 追随漏れ（2026-07-06）」「SQLDelight 列追加の upsert 追随漏れ（2026-07-07）」と同じ **「片側変更 → 対向未追随」ファミリー**の Firestore 版。公式 SDK 二重実装は構造上この追随を常に要求する。`CoffeeRecord` に必須フィールドを足すときは ①ドメイン model ②SQLDelight（.sq/migration/Mapper）③**Firestore mapper の Swift/Kotlin 両方** ④**export DTO / Mapper** ⑤**coffee-editor の Draft 往復（複製経路含む）** を 1 セットで直す（④⑤ は 2026-07-25 の `region` 欠損で追加。当時この列挙が ③ で止まっていたことが再発を許した）
- **発生源**: コードレビュー（2026-07-08）で発覚。`CoffeeFirestoreMapper.swift.toDocument` の `tags` 欠落
- **横展開点検（2026-07-08）**: `CoffeeFirestoreMapper` の `toDocument` トップレベルキーを Swift/Kotlin で突き合わせ → `id/userId/visitedOn/rating/notes/name/brewMethod/tags/photos/createdAt/updatedAt` が両側一致し、`tags` 以外に欠落なし。`SavedCafeFirestoreMapper` は両側対称で問題なし。`BeanProfileFirestoreMapper` は Android 専用 read-only サービスデータで iOS 側に対向実装が無く対象外

### DB/外部由来の文字列から enum を復元する箇所で `enum.valueOf(...)` を使わない（未知値の例外が Flow / 変換全体を巻き込む）

- **症状**: ローカル DB の `coffee_record` 行に**現行 enum に存在しない文字列**（将来の enum リネーム/削除、より新しいクライアントが書いた値、DB 破損）が 1 行でもあると、`BrewMethod.valueOf(...)` が `IllegalArgumentException` を投げ、`observeAll` Flow 全体が落ちてリスト・マップ・分析画面が**同時に死ぬ**
- **原因の構造**: `Mapper.kt` の `Coffee_record.toDomain()` が enum 復元に `valueOf`（未知名で例外）を使用。`toDomain` は `observeAll` の `mapToList` 内で**全行に走る**ため、単一の不正行が変換全体を巻き込む。同じ enum 復元を Firestore デコーダ（`CoffeeFirestoreMapper.kt`）は `entries.firstOrNull { it.name == raw }` で防御しており、**同一プロジェクト内で扱いが非対称**だった
- **修正パターン**: enum 逆引きは `entries.firstOrNull { it.name == raw }` を既定にする。non-null 必須フィールド（`brewMethod`）は妥当なフォールバック値（`BrewMethod.Other`）へ、nullable（`processing`/`roastLevel`）は `null` へフォールバック。**ローカル DB は自分が書いた Source of Truth なので、未知 enum で行を丸ごと drop せずフォールバックで保全する**（Firestore デコーダは他クライアント由来なので行 drop でよいが、ローカルは保全優先）
- **教訓**: `.claude/rules/kotlin-kmp.md` の「コルーチン内で `runCatching` を使わない」と同系の「例外を投げうる API を Flow/変換の内側に置かない」原則。列挙の逆引きは `valueOf`（例外）ではなく `firstOrNull`（null 安全）+ 明示フォールバックを既定にする。再発するなら rules へ昇格候補
- **発生源**: コードレビュー（2026-07-08）で発覚。`Mapper.kt` の `toDomain`
- **横展開点検（2026-07-08）**: `grep -rn "\.valueOf(" shared androidApp` → **該当なし**（今回の 3 箇所置換で全滅。Firestore デコーダ側は元から `firstOrNull` 方式）

### `when (mode)` で特定モードだけを対象にした早期 return（`?: return null`）は、本来「状態の有無」で判定すべきものを mode で判定して値を無言で落とす

- **症状**: セルフ抽出記録（`cafe == null`）を Edit / Duplicate モードで開き、手動でカフェ名を入力して保存しても、入力したカフェが保存されず `cafe = null` になる（無言のデータ欠落。コンパイルエラーも例外も出ない）
- **原因の構造**: `CoffeeEditorViewModel.buildCafe` が `when (mode) { is Mode.Edit, is Mode.Duplicate -> currentInitialRecord?.cafe ?: return null; is Mode.Create -> UUID採番 }` と **mode で分岐**していた。本来 cafe の採否を決めるのは「引き継ぎ元 cafe（`currentInitialRecord?.cafe`）が有るか」という**状態**であって mode ではない。mode で分岐したため「Edit/Duplicate だが引き継ぎ元 cafe が無い（＝セルフ抽出記録の編集/複製）」という組み合わせが `?: return null` に吸い込まれ、Create なら通る UUID 採番パスに到達できなかった
- **修正パターン**: 分岐条件を mode から状態へ移す。`when { selected != null -> ...; initialCafe != null -> ...; else -> UUID採番 }` の状態ベース 3 段判定に一本化し、`mode` 引数自体を削除。`Mode.Create` は `load()` で `currentInitialRecord = null` を明示するため、状態判定に畳んでも既存 Create 挙動は不変（mode 依存は見かけだった）
- **教訓**: `when (mode)` を書く前に「本当に mode 依存か、内部状態（null か否か等）の有無で足りるか」を疑う。特に `?: return null` / `?: return` のような早期 return を特定モード分岐の中に置くと、想定外のモード×状態の組み合わせで値が無言で消える。**分岐軸が実体（状態）とズレていると、網羅的な `when` でも「網羅されていない組み合わせ」が生まれる**（2026-07-08 の「表示と解決で対象集合がズレる」と同型 — 判定軸の取り違え）
- **発生源**: フェーズ 6 既知バグ（2026-07-06 の 15-B 実装中に kmp-engineer が発見・スコープ外で保留）→ 2026-07-08 修正
- **横展開点検（2026-07-08）**: `grep -rln "currentInitialRecord" shared/feature/*/src/commonMain` → `CoffeeEditorViewModel.kt` 1 ファイルのみ（同型の値握りつぶし波及なし）。残る mode 束ね分岐は `buildRecord` の id/createdAt 採番 1 箇所のみで、`?: return` のような早期 return を含まず本パターンに非該当

### 正規化辞書（完全キー一致の名寄せ）を contains ベースの部分一致に導入すると、変換された文字列と素通しの複合語がすれ違う

- **症状**: `OriginNormalizer`（「yirgacheffe」→「エチオピア」の辞書名寄せ）導入後、既存テスト 2 件が fail。入力 "Yirgacheffe" が profile.origin "Ethiopia Yirgacheffe" に contains 一致するはずのシナリオで、一致が 0 件になった
- **原因の構造**: 辞書は**単語単位の完全キー一致**でしか変換しないため、単語入力 "Yirgacheffe" は「エチオピア」へ変換される一方、複合語 "Ethiopia Yirgacheffe" は辞書キーに一致せず素通し（"ethiopia yirgacheffe"）のまま残る。**片方だけ変換された結果、変換前なら成立していた contains 関係が消える**。「両辺に同じ正規化関数を通しているから対称で安全」と考えがちだが、辞書変換は写像先が跳ぶため部分文字列関係を保存しない（trim/lowercase は保存する — ここが従来の正規化との質的な違い）
- **修正パターン**: 導入時に (a) 実データで複合語が発生するか確認（今回 bean-profiles.json 38 件は全て単一国名 origin → 非対応と割り切り）、(b) contains カバレッジ自体は**辞書外の語**（「ニエリ」等）でテストを再構成して維持、(c) 辞書の主目的（単語 → 正規形の一致）を固定する回帰テストを追加。複合語対応が本当に必要ならトークン分割マッチングだが、Simplicity First で必要になるまで入れない
- **教訓**: 名寄せ辞書・エイリアス変換を既存マッチングパイプラインに差し込むときは、**contains / startsWith 等の部分一致を使う箇所とその既存テストを必ず洗い出して実行**する。fail した既存テストは「壊れた」ではなく「新仕様との境界が露出した」なので、直す前に実データでの発生可能性から仕様判断する
- **発生源**: OriginNormalizer 導入（2026-07-08、kmp-engineer が検出し親が仕様判断）。経緯詳細は implementation_note 2026-07-08 OriginNormalizer エントリ
- **横展開点検（2026-07-08）**: ① `grep -rn "OriginNormalizer.normalize" shared`（非テスト）→ 全使用箇所（5 UseCase 7 呼び出し）とも比較の**両辺**に normalize 適用済みで、片側だけ正規化して contains する混在なし。② `grep -rn "\.contains(" shared/domain/.../usecase/ + CoffeeRecordQuery.kt` → contains 使用は BeanProfileMatch / PreferredBeanTraits（両辺正規化済み）と CoffeeRecordQuery（正規化対象外の生 ignoreCase、混在なし）のみ。③ 辞書語を複合語で使う残存テスト grep（Yirgacheffe / イルガチェフェ / キリマンジャロ等）→ CoffeeRecordQueryImplTest の「エチオピア イルガチェフェ」（対象外機能のため影響なし）と意図的な新テストのみ。**該当なし**

## 2026-07-13

### SQLDelight `Schema.migrate(driver, oldVersion, newVersion)` の `oldVersion` は「これから適用する最初の .sqm 番号」（適用済みの N.sqm を飛ばすには N+1 を渡す）

- **症状**: migration 5 のテストで、v4 相当のスキーマを手組みした DB に `Schema.migrate(driver, 4L, 6L)` 相当を呼ぶと、適用済みのはずの `4.sqm` が再実行されて `duplicate column name: brew_recipe` で fail する
- **原因の構造**: SQLDelight は `oldVersion <= N < newVersion` の範囲の `N.sqm` を実行する（`N.sqm` 適用後のスキーマバージョンは N+1、という規約）。「DB は 4.sqm まで適用済み = バージョン 4」と直感で読み替えると 1 つズレる。`4.sqm` まで適用済みの DB は**バージョン 5**であり、`5.sqm` だけを当てるには `migrate(driver, 5L, 6L)` を渡す
- **修正パターン**: migration テストでは「N.sqm だけを適用する」意図を `migrate(driver, N, N+1)` で表現し、テスト冒頭コメントにこのセマンティクスを明記する（`CoffeeRecordMigration5Test.kt` / `CoffeeRecordMigration5IosTest.kt` が実例）。中間バージョンのスキーマは head の `.sq` からは再現できないため、生 DDL で手組みする
- **教訓**: バージョン番号が「状態」なのか「次に適用する差分」なのかを API ごとに確認する。off-by-one で赤くなる場合、テストの手組みスキーマではなくバージョン引数のセマンティクスを先に疑う
- **発生源**: B-4 rating nullable 化の migration 5 テスト実装（2026-07-12、kmp-engineer）。詳細な API 裏取り手順はエージェントメモリ `sqldelight_migration_version_semantics.md`
- **横展開点検（2026-07-13）**: `grep -rn "\.migrate(" --include="*.kt" shared androidApp`（build 除外）→ 呼び出しは migration テスト 2 箇所（androidHostTest / iosTest）のみで、いずれも `migrate(driver, 5L, 6L)` と正しく、セマンティクス解説コメント付き。本番経路はドライバ構築時の自動 migration（`user_version` 管理）で手動呼び出しなし。**該当なし**

## 2026-07-14

### SPM の `upToNextMajorVersion` に控えめな `minimumVersion` を渡すと古いメジャーで解決され、古い API 形状のまま実装してしまう

- **症状**: Google Mobile Ads SDK を SPM 追加した際、`minimumVersion` を低く指定したため v11 系で解決され、Swift 向け `NS_SWIFT_NAME` リネーム（`GADNativeAd` → `NativeAd` 等）が入っていない古い API 形状に合わせてコードを書き始めてしまった（最新ドキュメントの API 名とコンパイルエラーで乖離が発覚）
- **原因の構造**: `upToNextMajorVersion` は「指定メジャー内の最新」までしか上げない。「とりあえず低めの minimum を書いておけば SPM が最新を取る」という直感は**メジャーをまたがない**ため誤り。SDK 側がメジャーバージョンで API リネームを行っていると、ドキュメント（最新版準拠）と手元の解決バージョンで API 形状が食い違う
- **修正パターン**: パッケージ追加前に GitHub Releases で実際の最新メジャーを確認し、`minimumVersion` にその最新メジャー（例: `13.0.0`）を明示してから実装に入る。追加後は `Package.resolved` の解決バージョンを実読みして想定メジャーか確認する
- **教訓**: SPM 依存を追加するときは「バージョン指定 → resolve → `Package.resolved` 確認」までをセットにする。ドキュメントと API 名が合わないときは自分のコードより先に解決バージョンを疑う
- **発生源**: AdMob 広告導入（2026-07-14、ios-engineer）。詳細はエージェントメモリ `admob-native-ads.md`
- **横展開点検（2026-07-14）**: `grep -B2 -A4 "minimumVersion" iosApp/iosApp.xcodeproj/project.pbxproj` + `Package.resolved` 実読み → 直接依存は 2 つのみ。GoogleMobileAds（min 13.0.0 → 解決 13.6.0）/ firebase-ios-sdk（min 12.0.0 → 解決 12.14.0、現行メジャー）とも最新メジャーで解決済み。**該当なし**

### 外部 SDK の「必要なら表示」系 API は、required 判定がコンソール / サーバー構成で決まるならクライアント側の条件ガードで制御できない — 使わない UI 経路は呼び出し自体を消す

- **症状**: 自前の広告プレプロンプト + ATT ダイアログの後に、UMP の英語ダイアログ（"Our App wants to stay free…"）が二重表示。`consentStatus == .required` ガードを入れた 1 回目の修正でも**再発**した
- **原因の構造**: UMP の `loadAndPresentIfRequired` は「required なら出す」API だが、その required 判定は AdMob **コンソール側のメッセージ構成**に依存する。ATT メッセージ（IDFA 説明）が構成されていると、GDPR 圏外でも ATT 未決定なら `consentStatus` が `.required` 扱いになり、ガードを素通りする。さらにフォールバック中の Google テスト用 App ID は**他人（Google デモアプリ）のコンソール構成**を継承するため、自アプリで制御する余地が構造的にない。「条件を狭めて呼ぶ」修正はこの外部状態への従属を解消しない
- **修正パターン**: 自前 UI（プレプロンプト + 直接 ATT）が仕様の正である以上、UMP のメッセージ表示経路は条件ガードではなく**呼び出しを全撤去**する。撤去時は連動プロパティの残存参照も点検する（`canRequestAds` は `requestConsentInfoUpdate` を呼ばない構成では常に false になるため参照禁止 — `AdConsentCoordinator` のコメントに明記）
- **教訓**: 「required / needed なら出す」系 API の判定材料がクライアント外（コンソール・サーバー構成・他者管理のテスト ID）にあるときは、ガード条件では自分の仕様を表現できない。**ガード追加の 1 回目が効かなかった時点で、条件調整の続行ではなく経路撤去へアプローチ系統を変える**
- **発生源**: AdMob 広告導入の ATT フロー（2026-07-14、ユーザーのシミュレータ確認 2 回で発覚 → 同日 UMP 呼び出し全撤去で解消）。経緯詳細は implementation_note 2026-07-14 ATT エントリ
- **横展開点検（2026-07-14）**: `grep -rn "UMP\|UserMessagingPlatform\|canRequestAds" iosApp/iosApp --include="*.swift"` → API 呼び出しの残存なし（`AdConsentCoordinator` の経緯説明コメントのみ）。陳腐化コメント 2 行（`AppState.swift` / `iOSApp.swift` の「UMP 同意更新」言及）は同時に消し込み済み。**該当なし**

### `Group { if let x { View() } }` に `.task` / `.onAppear` を付けると、条件が偽で子ゼロの間はモディファイアの付け先が実体化されず永遠に発火しない

- **症状**: 広告が 4 面中 3 面で表示されない。ビルドは成功、ビューの `body` は評価されている（print で確認）のに、非同期ロードを開始する `.task` が一度も発火せず、ロードが始まってすらいなかった
- **原因の構造**: SwiftUI の `Group` はコンテナではなく**モディファイアを各子ビューに分配する**透過構造。`Group { if let ad { AdView(ad) } }.task { load() }` は「ロード完了後に現れる子」にしか `.task` が付かないため、初期状態（`ad == nil` = 子ゼロ）では付け先が存在せず発火しない。**「ロードが終わったら表示する」ビューのロードトリガーを、その表示条件の内側にしか実体化されないビューに付ける**という自己矛盾がバグの本体（鶏と卵）。List / LazyVStack / VStack の配置場所の問題に見えるが無関係
- **修正パターン**: ① root を `ZStack` 等の**常に実体化される単一コンテナ**に変える（空でも `.task` が発火し、高さ 0 に畳まれる）② List の Section 内では空 Section の余白が残るため、ローダーを画面側 `@State` に持ち上げ、常在ビュー（`List` 自体）に `.task` を付けて「値があるときだけ Section を出す」構造にする
- **教訓**: 非同期ロードのトリガー（`.task` / `.onAppear`）は「ロード結果で中身が変わるビュー」ではなく「常に実体化されるビュー」に付ける。切り分けでは「body 評価ログは出るのに task ログが出ない」が決定的証拠になる（body 評価 ≠ ビュー実体化）。UI 挙動の検証はビルド成功では不足で、親がシミュレータ起動 + `print` ログ採取（`simctl launch --console-pty`）まで行う
- **発生源**: AdMob 広告導入の広告コンポーネント（2026-07-14、ユーザー報告「分析タブ以外表示されない」→ 診断ハーネス + ログで確定）。経緯は implementation_note 2026-07-14 広告コンポーネントエントリ
- **横展開点検（2026-07-14）**: `grep -rn "Group {" iosApp/iosApp --include="*.swift"` で 16 箇所列挙 → 各 Group 直後 45 行に `.task` / `.onAppear` があるのは 3 箇所（`AnalysisView:33` / `CafeDetailView:32` / `PlacePhotoThumbnail:35`）で、**いずれも `else` 節を持ち中身が空になり得ない**ため非該当。**該当なし**

## 2026-07-15

### レイアウト実測駆動の非同期ロードで、再入ガード（`guard !isLoading`）が「最後の要求」を無言で破棄すると過渡値だけが処理されて回復不能になる

- **症状**: 下部固定バナーがタブ切替後も表示されない。ログでは `task fired width=72` → リクエスト → `task fired width=402` → **再入ガードで破棄** → 72×100 のリクエストは「No ad to show」で失敗、以降幅が変化しないため `task(id: width)` が再発火せず回復不能
- **原因の構造**: `GeometryReader` + `.task(id: size.width)` の計測はタブ切替等の過渡状態で**ゴミ幅（72 / 20pt 等）を先に報告**する。ゴミ幅で即ロードを開始すると、直後の正しい幅の要求が `guard !isLoading` に吸われて消える。「re-entrancy guard = 多重リクエスト防止」のつもりが、**「最後に要求された状態が最終的に反映される」保証を壊している**。id ベースの再発火はガードの存在を知らないため、両者の組み合わせで取りこぼしが恒久化する
- **修正パターン**: ① 呼び出し側に**下限ガード**（`width >= minimumRequestableWidth`）で過渡値を弾く ② ローダー側は **pending 方式**（ロード中の新要求は破棄せず保存し、完了（成功 / 失敗どちらでも）後に追いかけて実行）で「最後の要求は必ず処理される」を保証 ③ 既に同一サイズでロード済みなら no-op（無限リロード防止）④ 一度成功した表示は後続の失敗で巻き戻さない
- **教訓**: 「計測値の変化で再実行される処理」に再入ガードを入れるときは、**破棄した要求を誰が再送するのか**を必ず答えられること。答えがなければ pending / 最新値の再キック機構をセットで入れる。過渡値はガードで弾けるが、正しい値の取りこぼしはガードでは防げない
- **発生源**: AdMob アダプティブバナーの `BannerAdLoader`（2026-07-14〜15、ユーザーの Xcode コンソールログで確定）
- **横展開点検（2026-07-15）**: `grep -rn "guard !isLoading\|guard isLoading == false" iosApp shared --include="*.swift" --include="*.kt"` → 2 件。① `BannerAdLoader.swift:66`（本件、pending 方式で修正済み）② `MapTabView.swift:427` は `onChange(of: isLoading)` の**完了イベント検知**（false への変化に反応するフィルタ）で、要求を破棄する再入ガードではなく非該当。**他に該当なし**

### UIKit SDK ビューを `UIViewRepresentable` で包むときはサイズを明示する（intrinsic 任せにすると SwiftUI の提案サイズで伸縮され、SDK のサイズ検証が作動する）

- **症状**: バナー広告が受信成功（`didReceive`）した直後に、こちらの `load()` を経由しない「Invalid ad width or height」失敗が届き、表示が無効化される（受信したのに画面に出ない）
- **原因の構造**: `UIViewRepresentable` はサイズ指定がないと SwiftUI の**提案サイズ**で UIView の frame を設定する（`maxWidth: .infinity` なら伸縮、レイアウト過渡では 0 もあり得る）。Google Mobile Ads の `BannerView` は自身の `adSize` と実 frame の不整合を検知して内部で再検証・再ロードを走らせるため、「受信 → SwiftUI が別サイズに伸縮 → SDK が invalid 判定」のループになる。**サイズに自己主張のある SDK ビューを intrinsic 任せで包んではいけない**
- **修正パターン**: Google 公式 SwiftUI サンプル（googleads-mobile-ios-examples の `BannerViewContainer`）と同じく、representable に **adSize ちょうどの `.frame(width:height:)` を明示**する。インラインアダプティブのように返却サイズが可変の場合は、リクエスト時サイズではなく**受信後の実サイズ**（`bannerView.adSize.size` を didReceive で保存）を使う。センタリング等は外側のコンテナで行い、representable 自体は伸縮させない
- **教訓**: サードパーティ SDK の UIKit ビューを SwiftUI に組み込むときは、**先に公式の SwiftUI サンプルを探して構成を一致させる**（今回も最終的に公式サンプル通りにして解決。3 サイクル目でようやく参照した）。「受信成功したのに表示されない」+「自分のコードを経由しない失敗コールバック」は SDK 内部の検証・再試行を疑う
- **発生源**: `BannerViewRepresentable`（2026-07-15 修正）。経緯は implementation_note 2026-07-15 エントリ
- **横展開点検（2026-07-15）**: `grep -rn "UIViewRepresentable\|UIViewControllerRepresentable" iosApp/iosApp --include="*.swift"` → representable は `BannerViewRepresentable`（修正済み）の 1 箇所のみ。**該当なし**

## 2026-07-16

### 深いネストの ViewBuilder 内に多分岐 if/else の let 代入を書くと、無関係に見える外側 ForEach の KeyPath 解決エラーとして誤誘導されることがある

- **症状**: `Map`/`ForEach`/`Annotation` の深いネスト内に 3 分岐の `if/else` による `let pinOpacity` 代入を追加したところ、原因箇所ではなく**外側の** `ForEach(bridge.visitedCafes, id: \.cafe.placeId)` が「value of type `KotlinBase` has no member `cafe`」というエラーになった（エラー位置と原因箇所が一致しない）
- **原因の構造**: Swift の型チェッカは複雑なクロージャで型推論が破綻すると、SKIE ブリッジ型の KeyPath を具象型（`VisitedCafe`）でなく基底型（`KotlinBase`）に解決してしまい、エラーを実際の原因（直近追加した多分岐 let 代入）ではなく外側の KeyPath に着地させる。SKIE 型 + 深いネスト ViewBuilder + 複数行 `if/else` の組み合わせで再現しやすい
- **修正パターン**: 同じ分岐を 1 文の入れ子三項演算子式に書き換える（`let x: Double = a ? v1 : (b ? v2 : v3)`）。それで型チェッカが正しく推論する
- **教訓**: SwiftUI ViewBuilder 内で「関係なさそうな外側の KeyPath / ForEach」のエラーが突然出たら、外側を疑う前に**直近で追加した多分岐の let 代入を三項演算子化して切り分ける**。エラー位置を信用しない
- **発生源**: マップ「好み一致」チップのタップ対応（2026-07-16、ios-engineer）。再現条件の詳細はエージェントメモリ `ios-engineer/xcodebuild-verification.md`
- **横展開点検（2026-07-16）**: この型はコンパイルエラーとして顕在化するため、ビルド green な現状に潜在該当は存在し得ない（override 無し xcodebuild BUILD SUCCEEDED を親確認済み）。予防観点で `grep -rn "= if " iosApp/iosApp --include="*.swift"`（if 式による let 代入）→ 0 件。**該当なし**

## 2026-07-20

### Automatic signing（cloud signing）下では `xcodebuild archive` は常に Development identity で署名する仕様。archive フェーズに `CODE_SIGN_IDENTITY = "Apple Distribution"` を明示すると（command-line でも pbxproj でも）Automatic signing と衝突して archive 自体が失敗する

- **症状**: `release-testflight.yml`（cloud signing、`-allowProvisioningUpdates`）の archive が「Choose a certificate to revoke. Your account has reached the maximum number of certificates.」で失敗。使い捨て CI ランナーごとに Development 証明書を新規発行し続けたことが原因と誤って判断し、2 回連続で誤った対処をした：① `xcodebuild archive` に `CODE_SIGN_IDENTITY="Apple Distribution"` を command-line で追加 → SPM 依存の全パッケージターゲット（`DEVELOPMENT_TEAM` 未設定）に上書きが伝播し「requires a development team」を大量発生。② command-line 上書きを撤回し、代わりに `project.pbxproj` の iosApp ターゲット **Release 設定のみ** `CODE_SIGN_IDENTITY` を `"Apple Distribution"` に変更 → 「iosApp is automatically signed for development, but a conflicting code signing identity Apple Distribution has been manually specified」で archive 失敗（command-line 上書きと同型のエラーが、上書き元を変えても再発）
- **原因の構造**: `CODE_SIGN_STYLE = Automatic` の場合、`xcodebuild archive` フェーズは**常に Development identity で署名する**（Distribution への再署名は `-exportArchive` 側が `ExportOptions.plist` の `method` に従って行う、cloud signing の標準フロー）。したがって「Release だから Distribution にすべき」という直感は Automatic signing の実際の仕組みと逆で、archive フェーズへの Distribution 明示は上書きの経路（command-line か pbxproj か）に関わらず同じ「conflicting」エラーを引き起こす。1 回目の失敗でエラーメッセージが変わった（衝突の相手が変わった）ことを「前進」と誤読し、同じ「archive を Distribution で署名させる」という誤った仮説のまま経路だけを変えて 2 回目も失敗した
- **修正パターン**: `CODE_SIGN_IDENTITY` は Debug/Release とも `"Apple Development"` のまま変更しない（= 元の設定が最初から正しかった）。証明書上限エラーの真因は Apple アカウント側で Development 証明書が実際に上限に達していたことであり、developer.apple.com で不要な証明書を revoke する運用面の対処が必要（プロジェクト設定の問題ではない）
- **教訓**: エラーメッセージが変わった＝前進、とは限らない。同じ仮説（「archive を Distribution で署名させたい」）のまま対処の**経路だけ**を変える（command-line → pbxproj）のは「同じ系統のアプローチ」の繰り返しであり、CLAUDE.md の「2 回失敗したら根本原因を再調査する」規約が指す典型例。署名エラーは Web 検索や公式ドキュメントで「Automatic signing の archive フェーズは常に Development」という一次情報にあたってから対処すべきで、エラーメッセージの字面（「Release だから Distribution」という思い込み）だけで即席の設定変更を重ねない
- **発生源**: `release-testflight.yml` archive 失敗の修正（2026-07-18〜20、親が直接対応）。コミット: c473cf7（誤り: command-line 上書き）→ 7695687（誤り: pbxproj Release のみ上書き）→ d635a94（訂正: 元の Apple Development に戻す）
- **横展開点検（2026-07-20）**: ① `grep -rn "CODE_SIGN_IDENTITY\|CODE_SIGN_STYLE\|PROVISIONING_PROFILE" .github/workflows/` → 上書きの残存なし。② `grep -n "CODE_SIGN_IDENTITY\|name = Debug\|name = Release" iosApp/iosApp.xcodeproj/project.pbxproj` → Debug/Release とも `"Apple Development"` で一致、Distribution の残存なし。③ `find . -name "*.xcodeproj"` → プロジェクトは `iosApp.xcodeproj` の 1 つのみ（他ターゲット・extension 無し）。**該当なし**

## 2026-07-22

### 遅延コンテナ（`LazyVStack` / `List` 等）の N 番目に埋め込んだ「自己 `.task` でロードする」コンポーネントは、初回表示時に fold 下だと `.task` が一度も発火しない

- **症状**: マップ検索結果を下部ドラッグシート化（既定 peek 180pt）した後、結果一覧内 3 件目の後のインラインバナー広告（§11-2）が表示されなくなった。ビルドは成功、コード上は旧ドロップダウンと同じ `if index == 2 { InlineBannerAdView(...) }`
- **原因の構造**: `InlineBannerAdView` はロードを**自身の** `.background(GeometryReader).task(id: width)` でトリガーする。それが `LazyVStack` の 4 番目（3 行目の後）にあり、シートが既定 peek（180pt）で開くと広告スロットは fold 下 → `LazyVStack` が subview を実体化しない → `.task` が発火せず**一度もロードされない**。旧ドロップダウン（最大 300pt）では 3 行 ≈ 192pt が枠内に入り実体化されていたため出ていた＝コンテナ高を縮めたことによる回帰。**遅延コンテナは可視範囲外の子を作らないので、子自身に付けたライフサイクルトリガー（`.task`/`.onAppear`）は「画面に入るまで」発火しない**
- **修正パターン**: ロードのトリガーを、**常に実体化される親コンテナ**の `.background(GeometryReader).task(id:)` に移す（`CafeDetailView.cafeDetailList` が List 自身の background から先読みする既存の正パターンに揃える）。子コンポーネント側の `.task` はフォールバックとして残し、`isLoaded` 済みなら実体化された瞬間に即描画させる。id は幅＋出現条件（例 `"\(Int(width))-\(results.count >= 3)"`）の合成にして条件成立時に再発火させる
  ```swift
  // シートのルート VStack（常に実体化される）に付ける
  .background(GeometryReader { proxy in
      Color.clear.task(id: "\(Int(proxy.size.width))-\(sb.results.count >= 3)") {
          guard sb.results.count >= 3 else { return }
          let width = proxy.size.width - 32
          guard width >= BannerAdLoader.minimumRequestableWidth else { return }
          searchAdLoader.load(adSize: inlineAdaptiveBanner(width: width, maxHeight: 100))
      }
  })
  ```
- **教訓**: 「fold 下でも実行されてほしい」副作用（広告の先読み、事前計測、必ず 1 回走らせたい初期化）を遅延コンテナの子に `.task`/`.onAppear` で載せない。**遅延スクロールで初めて可視になる位置**に置く前提の副作用（画像のオンデマンドロード等）だけを子に載せる。両者を取り違えると「ビルドは通るが出ない / 走らない」になる
- **発生源**: マップ検索結果の下部シート化（2026-07-22、commit dd83f7f）で回帰、同日 ios-engineer が先読みパターンで修正。関連: 「UIKit SDK ビューはサイズ明示」（2026-07-15、同じ広告面の別バグ）
- **横展開点検（2026-07-22）**: `grep -rn "LazyVStack\|LazyHStack\|LazyVGrid\|LazyHGrid" iosApp/iosApp --include="*.swift"` で全遅延コンテナを列挙し、各コンテナの子に「fold 下でも発火が必要な自己トリガー副作用」が載っていないか点検。`InlineBannerAdView`（広告の先読み必須）の使用は 2 面のみ（`CafeDetailView`＝List 直下で先読み済み・`MapTabView`＝今回修正）で両方対処済み。`PlacePhotoThumbnail`（`.task` で写真ロード）は遅延コンテナ内に多数あるが、**スクロール到達時のオンデマンドロードが意図した正しい挙動**（先読み不要）のため対象外。他に fold 下発火を要する自己トリガーは見当たらず、**該当なし（対処 2 面 + 対象外 1 種を確認）**

### SwiftUI: 自身の `.frame`/位置がドラッグ結果で動く View に `DragGesture` を付けるときは `coordinateSpace: .global` にする（`.local` だと自己発振する）

- **症状**: 自作の下部ドラッグシートで、ハンドルを掴んで上下にリサイズすると高さがブレる・カクつく・指に素直に追従しない（発振）
- **原因の構造**: ハンドル行はシート上端（`.frame(height: currentHeight)`）に乗っており、ドラッグで高さが変わると**ハンドル行自身の画面 Y 位置も動く**。`DragGesture()` の既定 `.local` 座標系の `translation` は「ジェスチャー元 View のローカル座標」で測るため、View が自分のドラッグ結果で動くと、指の画面上位置が同じでもフレーム毎に読み値がズレる。`height = base - translation` がその読み値を再び高さに反映するのでフィードバックループになり発振する。**「入力（translation）が出力（View の位置）に依存し、出力が入力に戻る」構成が地雷**
- **修正パターン**: `DragGesture(minimumDistance: 8, coordinateSpace: .global)` にする。`.global` は画面固定座標なので View 自身の移動に影響されず translation が安定する。あわせて (1) 範囲外ドラッグで translation が過剰蓄積しデッドゾーン化するのを防ぐため `translation` を有効域 `[base - maxHeight, base - minHeight]` にクランプ、(2) タップ toggle と競合する `Button + .simultaneousGesture` はやめ、プレーン View + `.onTapGesture` + `.gesture(DragGesture)`（`minimumDistance` でタップ/ドラッグ分離）+ `.accessibilityAction` に分離する
- **教訓**: ドラッグで自分の位置・サイズが変わる UI（ボトムシート、リサイズ可能パネル、追従ハンドル）の `DragGesture` は**必ず `.global`（または固定 `.named` 空間）**。`.local` は「ドラッグしても自身が動かない」要素（swipe-to-dismiss で `onEnded` の符号だけ見る等）に限る
- **発生源**: マップ検索結果の下部ドラッグシート（2026-07-22、commit 7ecd966 で導入・同日修正）。関連: 同シートの広告先読み lesson（同日）
- **横展開点検（2026-07-22）**: `grep -rn "DragGesture(" iosApp/iosApp --include="*.swift"` → `MapTabView.swift`（今回修正・`.global`）と `ErrorToast.swift`（`onEnded` の `translation` 符号のみ参照する swipe-to-dismiss。ドラッグ中に自身が動かず `onChanged` で自己位置を書き換えないため発振の前提が無く**非該当**）の 2 箇所のみ。他に自作ドラッグリサイズ/追従実装なし。**該当なし（要修正は 1 箇所で対処済み）**

## 2026-07-24

### Places API の `locationBias` は範囲制限ではなく近傍ヒント — 範囲内限定 UI はクライアント側フィルタが要る

- **症状**: マップ「このエリアを検索」でキーワードあり時、表示範囲外のカフェ（遠方の同名チェーン店など）が結果一覧・ピンに混入する、というユーザー報告。
- **原因の構造**: `searchText(query, locationBias)` の `locationBias`（Places API New v1 の `locationBias.circle`）は「**近くを優先するヒント**」であって範囲を制限しない。範囲内に限定したい UI で `locationBias` を使うと範囲外が返る。Places の **Text Search の `locationRestriction` は rectangle のみ対応**（circle 不可）で、サーバー側で厳密に絞るには矩形の受け渡し＋ shared 改修が要る。構造的な API 仕様の誤解パターン（単発ミスではない）。対して Nearby Search（`searchNearby`）は `locationRestriction`（circle）で範囲制限される — この非対称が誤解の温床。
- **修正パターン**: 範囲内限定の一覧/ピン表示は、クライアント側で**表示範囲矩形フィルタ**を掛ける。検索実行時点の `MKCoordinateRegion` をスナップ（`areaSearchRegion`）→ 完了時に `region.center ± span/2` の矩形内座標でフィルタ（座標欠損は除外）。フィルタ済み結果を `displayedResults` として**単一ソース化**し、一覧とピンの双方に同じ配列を流す（別々にフィルタするとズレる）。
- **教訓**: `locationBias` = ヒント / `locationRestriction` = 制限。「表示範囲で検索」系の UI で `locationBias` を使うなら、範囲制限はクライアント（表示矩形フィルタ）かサーバー（Text Search は rectangle restriction）で別途担保する。位置バイアス検索を新規追加するときは「これは範囲を絞るのか優先するだけか」を必ず区別する。
- **発生源**: `MapSearchController`（2026-07-24 のエリア検索キーワード維持変更で顕在化）。設計判断は implementation_note 2026-07-24「エリア検索の表示範囲フィルタ」。
- **横展開点検（sweep）**: `locationBias` / `LocationBias` / `searchText` / `searchByNameNear` の全消費点を grep 点検（`shared` / `iosApp`）。範囲内限定の一覧表示に `locationBias` を使う同型箇所は**該当なし** — 他はテキスト検索（`CafeSearchView` / 検索バー = 全国検索が意図で範囲外は正常）、`MapViewModel.searchByNameNear`（POI タップの placeId 単一解決用・200m・一覧表示しない）、CoffeeEditor 周辺候補（`searchNearby` = `locationRestriction` で元々範囲制限）のみ。

## 2026-07-25

### KMP のファイル分割で public companion メンバを top-level 化すると Swift Bridge を壊す（Kotlin テストでは検出不能）

- **症状**: `CoffeeEditorViewModel.kt`（896 行）を分割リファクタ後、Xcode ビルドで `Value of type 'CoffeeEditorViewModel.Companion' has no member 'defaultDraft'`。KMP 側の `testAndroidHostTest` / `iosSimulatorArm64Test` / `compileTestKotlinIosSimulatorArm64` はすべて green だったのに Swift だけ落ちた。
- **原因の構造**: `defaultDraft()` は **companion object の public 関数**で、Swift Bridge が `CoffeeEditorViewModel.companion.defaultDraft()` として直接参照していた（`CoffeeEditorViewModelBridge.swift:19`）。分割時にこれを別ファイルの **top-level `internal` 関数**へ移したため、(a) companion から消え Swift の名前解決が壊れ、(b) `internal` 化で Objective-C ヘッダに出なくなり二重に非公開化した。**KMP モジュール単体の Kotlin テストは iosApp の Swift コンパイルを一切検証しない**（別ターゲット）ため、公開 API を壊しても Kotlin 側は緑のまま = 検出漏れの構造。「公開 API 無変更」の自己申告が実際は不成立だった。
- **修正パターン**: `defaultDraft()` を companion の**元の位置（public）へ戻す**。クラス内の呼び出し（`UIState` の default 引数・`onAppear`）は companion メンバとしてそのまま解決される。可視性判定の基準は「**元が `public`（companion メンバ含む）だったか**」— `public` だったシンボルは移動先を選ばず**定義位置を保持**する（companion メンバは companion に残す）。`private`/`internal` だったものは移動先で `internal` にしても ObjC ヘッダに出ないので Swift 露出は不変（`toDraft`/`buildRecord` 等は元 private のため top-level internal 化して無問題）。
- **教訓**: `commonMain` の **public API（特に companion メンバ・nested 型）に触れる分割・リネームは、Kotlin テストの green を「Swift も無事」と読み替えない**。検証は (1) 生成ヘッダ `SharedLogic.h` に想定の Swift 名が出るか + (2) **実際の Swift ビルド**（親が `DEVELOPER_DIR=... xcodebuild build -scheme iosApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`）まで必ず親が実施する。サブエージェントは sandbox で Swift ビルド不可のため、この検証は親の専任。関連: implementation_note 2026-07-25「KMP ViewModel の 800 行超分割」。
- **発生源**: `CoffeeEditorViewModel.kt` 分割（2026-07-25、tasks CE-1）。分割方式そのものは正しく、壊したのは可視性判定の一点。
- **横展開点検（sweep）**: `grep -rn "\.companion\." iosApp/iosApp --include="*.swift"` で Swift が依存する **public companion メンバ**を全列挙 → アプリ全体で 2 件のみ: `AnalysisViewModel.companion.SUGGESTED_QUESTIONS`（`AnalysisViewModelBridge.swift:68`）と `CoffeeEditorViewModel.companion.defaultDraft()`（今回修正済み）。前者は無変更で健全。さらに **iosApp スキームのフルビルドが `BUILD SUCCEEDED`** = 今回の分割で他の public API（companion 以外含む）も一切壊していないことを全 Swift 参照で確認済み。**該当なし（要修正は defaultDraft 1 件で対処済み）**。

### `CoffeeRecord` のフィールド追加で export DTO / Mapper だけが追随漏れする（コンパイラも grep も強制しない 5 番目の経路）

- **症状**: 2026-07-22 に追加した `CoffeeRecord.region`（エリア / 農園）が、**JSON エクスポート（要件 §7-4）にだけ出力されない**。SQLDelight・Firestore（両 OS）・エディタ UI は全て追随済みで、アプリ内の表示も同期も正常なため、ユーザーがエクスポートしたファイルを開くまで気づけない無言のデータ欠損。3 日間（07-22〜07-25）気づかれなかった。
- **原因の構造**: `CoffeeRecordExportDto` は `CoffeeRecord` を継承せず**独立した `@Serializable data class`** で、`CoffeeRecordExportMapper.toDto()` が手写しする。したがって (a) DTO にフィールドを足さなくても **Kotlin コンパイラは何も言わない**（`data class` のコンストラクタが不足するわけではない）、(b) 他の 4 経路と違い `.sq` / `Mapper` / `*FirestoreMapper` のようなキーワードで芋づる grep に引っかからない、(c) テストも「その時点のフィールドだけ」を assert していたため緑のまま。**「片側変更 → 対向未追随」ファミリー（2026-07-06 / 07-07 / 07-08）の 4 例目**で、根は 07-08 エントリと同じ。再発を許したのは 07-08 の教訓の列挙が「③ Firestore mapper 両方」で止まり、export を含んでいなかったこと。
- **修正パターン**: `CoffeeRecordExportDto` に `region: String? = null` を `origin` の直後（= domain と同じ並び）へ、`CoffeeRecordExportMapper.toDto()` に `region = record.region` を追加。**恒久策は「全フィールド突合テスト」**: `CoffeeRecordExportMapperTest.fullyPopulatedRecord_allFieldsMapToExportDto` が `CoffeeRecord` の全フィールドを非デフォルト値で埋めて DTO 側と 1 対 1 で `assertEquals` する（新フィールド追加時にここへ値と assertion を足すのが強制フックになる）。ただし**足し忘れ自体はコンパイラが検出できない**限界は残るため、下記の grep をカラム追加時の定番セットに含める。
- **教訓**: ドメインモデルのフィールドは **6 経路**に写る（①domain ②SQLDelight `.sq`+migration+`Mapper`+`LocalCoffeeRepository.save` ③Firestore mapper Kotlin/Swift 両方 ④**export DTO+Mapper** ⑤coffee-editor の Draft 往復・複製経路 ⑥**開発用インポート `scripts/seed/seed-coffees.mjs` の `toDocument`**）。**「フィールドを足したら写る先を数える」を作業の一部にする**。④⑥ はどちらも**手写しの allowlist**（片方は Kotlin `data class`、もう片方は JS のオブジェクトリテラル）で、型もコンパイラも grep も助けてくれないという同じ形。正本は `docs/data-model.md`（§1.1 / §2.1 / §3.2 / §8）で、6 経路すべてをそこへ照合する。同内容を `.claude/rules/kotlin-kmp.md` のチェックリストへ昇格済み。
- **発生源**: `docs/data-model.md` の棚卸し（陳腐化チェック、2026-07-25）で親が検出。修正は tasks カテゴリ 2「data-model.md 棚卸しの是正」。
- **横展開点検（sweep, 2026-07-25）**: `CoffeeRecord` の全 20 フィールドを 6 経路すべてで突き合わせ → **`region` が 2 箇所で漏れていた（④ export DTO/Mapper と ⑥ `seed-coffees.mjs` の `toDocument`。どちらも同日修正）。それ以外のフィールドの漏れは無し**。⑥ は最初の sweep 対象に入れておらず、「`seed-coffees.mjs` は未知キーを素通しするはず」という**未検証の思い込みで一度取りこぼした**（実際は明示 allowlist だった）— 「素通しだから安全」と推測したら必ずコードを開くこと。`--dry-run` で `region` が変換結果に出ることを実測して確認済み。使用した grep: ②`grep -n "region\|origin" shared/data-local/src/commonMain/sqldelight/com/noricoffee/db/CoffeeRecord.sq shared/data-local/src/commonMain/kotlin/com/noricoffee/db/Mapper.kt shared/data-local/src/commonMain/kotlin/com/noricoffee/repository/LocalCoffeeRepository.kt`（列定義 / upsert 列リスト / toDomain / toRow / save の named 引数すべて一致）③`grep -n "region\|origin" shared/data-firebase/src/androidMain/kotlin/com/noricoffee/repository/CoffeeFirestoreMapper.kt iosApp/iosApp/FirebaseRepositories/CoffeeFirestoreMapper.swift`（両 OS の encode / decode 4 箇所すべて一致）④修正対象（唯一の漏れ）⑤`grep -n "region\|origin" shared/feature/coffee-editor/src/commonMain/kotlin/com/noricoffee/feature/coffeeeditor/{CoffeeRecordBuilder,CoffeeEditorMapping}.kt`（`toDraft` / `toDuplicateDraft` 両方に存在）⑥`grep -n "origin\|region" scripts/seed/seed-coffees.mjs`（`toDocument` の allowlist に `region` が無い = 漏れ。修正後 `node seed-coffees.mjs --dry-run --uid <uid> <export.json>` で出力を実測）。あわせて `grep -rl "CoffeeRecordExportDto\|CoffeeRecordExportMapper" shared --include="*.kt" | grep -v /build/` と `grep -n "record\." scripts/seed/seed-coffees.mjs` を「手写し allowlist 2 経路を思い出すための grep」としてカラム追加手順に登録した。

### 背景エージェントの実行中に `git add -A` するとコミットが混ざる（親のコミット衛生）

- **症状**: `kmp-engineer` を background dispatch した直後、親が別ファイル（docs）の作業を終えて `git add -A && git commit` したところ、**まだ実行中だったエージェントの変更（`build-logic/.../kmp.feature.gradle.kts`）が docs のコミットに巻き込まれた**。コミットメッセージはその変更に言及しておらず、`git show --stat` で初めて気付いた。tasks.md のチェックも未了のままだった。
- **原因の構造**: background agent は親と**同じワークツリー**で作業する（`isolation: "worktree"` を指定しない限り）。`git add -A` はワークツリー全体をステージするので、**エージェントの書き込みタイミングと親のコミットが競合する**。親は「自分が触ったファイルだけ」を意識しているが、`-A` はその意図を表現していない。
- **修正パターン**: 背景エージェントが走っている間は **`git add -A` を使わず、親が触ったファイルを明示列挙**する（`git add docs/ README.md` 等）。あるいはエージェントの完了通知を待ってからコミットする。混入に気付いたら、コミットを作り直すよりも**次のコミットで経緯を記録し、混入した変更を独立に再検証**する方が安全（履歴の書き換えは他の参照を壊す）。
- **教訓**: 親の commit 権限（CLAUDE.md「commit / PR は親」）は「何をコミットしたか把握している」ことまで含む。**dispatch 中は `-A` を封じる**。`isolation: "worktree"` で隔離する選択肢もあるが、docs とコードを同時に扱う通常の dispatch では親のワークツリー共有が前提なので、コミット側で規律を持つ方が現実的。
- **発生源**: 2026-07-25 の architecture.md 棚卸し。commit `4cd45e1` に `kmp.feature.gradle.kts` の KDoc 修正が混入。
- **横展開点検（2026-07-25）**: 同セッションの他 4 コミット（`4ae4885` / `bbf51c6` / `48d908f` / `05a4871` / `2efb121`）を `git show --stat` で確認 → **いずれも意図した範囲のみ**（`bbf51c6` / `48d908f` / `05a4871` は同期 dispatch = 完了後にコミットしているため競合なし）。混入は background dispatch を使った 1 件だけだった。**background dispatch を使ったコミットに限って `-A` が危険**という条件が確定した。

## 2026-07-26

### 幅を持つ子 View を `if` で条件生成すると、状態変化のたびに兄弟がシフトする（右寄せコンテナで顕著）

- **症状**: ユーザー報告「コーヒー記録の評価で星を入れると右側にバツボタンが出てきて星がずれる」。星をタップした瞬間に星 5 個が左へ動く。ビルドもテストも通り、機能的には正常動作していた（**目視でしか見つからない類**）
- **原因の構造**: `StarRatingView.editableStars` がクリアボタンを `if rating != nil { Button {...} }` で条件生成していた。ボタンは `.frame(minWidth: 44, minHeight: 44)` を持つため、出現・消滅のたびに親 `HStack` の intrinsic 幅が 52pt（44 + spacing 8）変わる。呼び出し元が `LabeledContent` の**右寄せスロット**なので、幅の増加分がそのまま星の左シフトとして見える。**「条件付き表示」と「レイアウトを条件に依存させる」を区別していないのが根**。左寄せコンテナなら末尾の出入りは兄弟を動かさないので気づかれないが、右寄せ・中央寄せでは即座に露見する
- **修正パターン**: 幅を持つ要素は**常時レイアウトに乗せ**、見た目と操作性だけを切り替える:
  ```swift
  Button { onChange?(nil) } label: { ... }
      .opacity(rating != nil ? 1 : 0)      // 不可視
      .disabled(rating == nil)             // 透明ボタンの誤タップ防止
      .accessibilityHidden(rating == nil)  // VoiceOver に読ませない
  ```
  `.opacity(0)` 単体では**タップも VoiceOver も生きたまま**なので 3 点セットで扱う。`.hidden()` は frame を保つが操作可否の扱いが暗黙になるため、明示的な `.disabled` を選んだ。同じ問題を別方式で解決した先例が `TagChip`（件数バッジのはみ出し分を `badgeReservedInsets` で自身の境界内に先に確保）
- **教訓**: **`if` で View を出し入れする前に「その要素は幅・高さを持つか」「親コンテナの alignment は何か」を見る**。幅を持つなら条件分岐ではなく `opacity` + `disabled` + `accessibilityHidden` で、レイアウトを状態から切り離す。特に `LabeledContent` / `HStack + Spacer` の右寄せスロットは、要素 1 個の出入りが全兄弟の位置に伝わる。Preview には**条件の両側を縦に並べたケース**を置くと、実装時点で左端の不揃いが目で分かる（今回追加済み）
- **発生源**: `Components/StarRatingView.swift` の編集モード（評価の nullable 化 = B-4、2026-07-13 導入時にクリアボタンごと入った）。ユーザーが 2026-07-26 に報告するまで 13 日間気付かれず
- **横展開点検（2026-07-26）**: `grep -rn "minWidth: 44\|width: 44\|minHeight: 44" iosApp/iosApp --include="*.swift"`（31 箇所）を起点に、「幅を持つ要素が `if` で条件生成され、かつ兄弟と水平に並ぶ」箇所を全件目視。同型は 2 件で**どちらも実害なし**: ①`MapFilterChipRow.swift:74`（`if !selectedTags.isEmpty` でクリアボタン）は**横スクロールのチップ列末尾・左寄せ**のため既存チップは動かない ②`MapTabView.swift:714`（`if TastePreferenceExtractor.makeIfAvailable() != nil` で ✨ ボタン）は**条件が端末能力で起動中に変化しない**ため実行時シフトが起きない。他は常時表示か `Spacer()` を挟む構成（`AnalysisQaViews` の Q&A クリア / 再試行、`CoffeeEditorView+Sections` のスライダー行 = `minWidth` 固定で安定）。`TagChip` は上記のとおり先に対処済み。**要修正は `StarRatingView` 1 件のみで対処済み**。判定基準（幅を持つか / alignment が右寄せか / 条件が実行中に変わるか）を `.claude/rules/swift-ios.md` の UI/UX 節へ昇格

## 2026-07-27

### 同じ体系の View 群で「輪郭の有無」が混ざると、サイズ差を打ち消して意図しない序列が生まれる

- **症状**: ユーザー報告「訪問済みよりおすすめの方が目立ちすぎ」。マップ上でおすすめ（curated、34pt）が訪問済み（36pt）より前に出て見える。サイズは訪問済みの方が大きく、色も意味も設計どおりで、コード上は誰も間違っていない
- **原因の構造**: `MapPins.swift` の 6 ピンのうち、**白フチ（`Circle().stroke(Color(.systemBackground), lineWidth: 1.5)`）を持つのが 3 つだけ**だった（curated / 周辺 / なし → 訪問済み・保存済み・好み一致・検索結果）。白フチは地図の情報密度から図形を切り離す効果が非常に大きく、**2pt のサイズ差を軽く上回る**。ピンは 1 ファイルに 6 struct が並んでいるのに、フェーズごと（10-A → 15-A → 17 → 19）に別々の dispatch で追加されたため、後から足したものだけが「地図で見づらい」というその時の問題意識でフチを獲得し、既存には遡及しなかった。**個々の変更はどれも正しく、不揃いは差分レビューには映らない**（1 ファイルを通しで見て初めて分かる）
- **修正パターン**: 強調に使う軸と、可読性のために全員が持つべき処理を分ける。輪郭・影は後者に倒し、**全ピン共通**にする。強弱はサイズと彩度だけで表す。`docs/ui-ux-guidelines.md`「ピンの意匠ルール」へ規則として昇格済み
- **教訓**: **同じ体系の兄弟 View に修飾を足すときは、その修飾が「この 1 つの都合」か「体系全体が持つべき性質」かを判断する**。後者なら同じ変更で兄弟全員に配る。判断を先送りすると、次に誰かが体系の外から見たとき（＝ユーザーが実機で見たとき）にしか露見しない。「地図で見づらいから白フチを足す」は明らかに後者だった。**色の議論に引きずられない**のも要点で、今回ユーザーの当初案は配色変更（分析のロースト ランプ流用）だったが、コントラスト比と Oklab 色差を実測したところ候補色はダーク地図で 1.06:1 と同化する等いずれも成立せず、原因は色ではなく輪郭だった — **意匠の相談ほど、変更前に現状を数値化する**
- **発生源**: `iosApp/iosApp/Features/Map/MapPins.swift`。フェーズ 10-A（訪問済み・検索結果）/ 15-A（保存済み）/ 17（周辺）/ 19（おすすめ）と 4 回に分けて追加された 6 ピン。ユーザー指摘 2026-07-27、対応は tasks「マップピンの主従関係の是正」MP-1 / MP-2
- **横展開点検（2026-07-27）**: ①フチ表現の同型: `grep -rn "stroke(Color(.systemBackground)" iosApp/iosApp --include="*.swift"` → **`MapPins.swift` の 6 ピンのみ**（MP-1 / MP-2 で全件統一済み）。`grep -rn "\.stroke(" iosApp/iosApp --include="*.swift"` の他ヒットは `TastingRadarChart` のグリッド線・データ線 3 箇所で用途が別。②影の不揃い: `grep -rn "\.shadow(" iosApp/iosApp --include="*.swift"` → 意味ピン 4 種が自色 `opacity(0.4)` / `radius: 4` / `y: 2` で揃っているのに対し **`CuratedCafePin` だけ `opacity(0.5)`** が残る（同じ「体系の中で 1 つだけ強い」形。ただし ui-ux-guidelines の curated 定義は「サイズと彩度で強調」であり影は仕様外の暗黙強調）→ フチ統一後の見え方次第で判断するため tasks に MP-3 としてバックログ化。`AppleNearbyCafePin` の `.black.opacity(0.25)` / `radius: 3` は低強調ピンの意図的な例外で規則に明記済み。③チップ体系（`TagChip` / `TagLegendChip`）は `TagLegendChip` の production 使用箇所が 0 のため不揃いの実害なし
