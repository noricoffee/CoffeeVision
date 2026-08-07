# KMP ブリッジガイド（Swift ⇄ Kotlin）

> **この doc に書くこと / 書かないこと**（2026-07-25 の棚卸しで確定。573 → 455 行に縮約した際の基準）
> - **書く**: Kotlin ⇄ Swift の**型の見え方**、SKIE の適用範囲と限界（特に**呼び出し方向**）、Swift 側で Kotlin interface を実装するときの生シグネチャ、ブリッジの実装パターンとその落とし穴
> - **書かない**: ①**採用しなかった選択肢の実装手順**（SKIE 未採用時のヘルパ等 — 分岐が増えるだけで、必要になったら書き直す方が早い）②**配布戦略・Gradle 設定**（→ [`architecture.md`](./architecture.md)「iOS 配布戦略」）③**SwiftUI の一般的な書き方**（→ [`ui-ux-guidelines.md`](./ui-ux-guidelines.md) / `.claude/rules/swift-ios.md`）④**実ファイルが正本のシグネチャ列挙**（`AppContainer.kt` / `*.gradle.kts` / `expect`・`actual`）

## 概要

CoffeeVision は **Kotlin Multiplatform（KMP）+ SwiftUI** の構成です。
`shared/*` モジュール群（基盤層 `core` / `domain` / `data-local` / `data-places` / `data-firebase` + `feature/*` + `framework`。正確な一覧は `settings.gradle.kts` を真とする）を iOS 側から扱う際の相互運用ルール・回避策・お作法をまとめます。

対象: ViewModel ブリッジ（`iosApp/iosApp/Features/<Name>/<Name>ViewModelBridge.swift`）や共通 Flow ブリッジ（`iosApp/iosApp/FirebaseRepositories/FlowBridge.swift`）を実装する人、Kotlin → Swift で型が崩れたときのトラブルシュート時

---

## Kotlin → Swift で型がどう見えるか

| Kotlin | Swift（既定） | 補足 |
|--------|--------------|------|
| `class` / `data class` | `class`（参照型） | Swift では `struct` ではなく `class` |
| `enum class` | Objective-C enum 相当の `class`。`enumValues` で列挙 | `switch` の網羅性は失われる |
| `sealed interface` / `sealed class` | 親 `class` + 子 `class`。Swift 側では `if let _ = x as? Child` で分岐 | パターンマッチが厄介 |
| `List<T>` | `NSArray` 互換 | キャストして `Array<T>` 化する |
| `Map<K, V>` | `NSDictionary` 互換 | 同上 |
| `Long` | `Int64` | OK |
| `nullable T?` | `Optional<T>` | OK |
| `Unit` | `Void` | OK |
| `Result<T>` | 扱いづらい | 例外として throw する設計を優先 |
| `suspend fun` | `async` + completion handler（生 SDK）/ `async/await`（SKIE 経由） | **SKIE 推奨** |
| `Flow<T>` | コールバック型（生 SDK）/ `AsyncSequence`（SKIE 経由） | **SKIE 推奨** |
| `StateFlow<T>` | 同上 | 同上 |
| `Exception` | `NSError` | Swift では `try / catch (let e as NSError)` |

---

## SKIE の利用（採用済み）

[**SKIE**](https://skie.touchlab.co/) は Touchlab が提供する Kotlin/Native → Swift トランスパイラ拡張で、`suspend` を Swift の `async` に、`Flow` を `AsyncSequence` に、`sealed class` を Swift の `enum` に変換してくれます。

> **採用済み: SKIE 0.10.12（Kotlin 2.3.21 互換）**。2026-06-04 に旧 `sharedLogic` モジュールへ組み込み、Phase 2.5 PR3（2026-06-08）で `shared/framework` umbrella に追随済。デフォルト機能（SuspendInterop / FlowInterop / SealedInterop）のみ有効化、独自設定なし。

### Gradle 設定（実プロジェクト記述）

```kotlin
// gradle/libs.versions.toml
[versions]
skie = "0.10.12"
[plugins]
skie = { id = "co.touchlab.skie", version.ref = "skie" }

// shared/framework/build.gradle.kts（umbrella 側に SKIE を適用）
plugins {
    alias(libs.plugins.skie)
}
```

### SKIE 適用後の見え方（呼び出し側）

| Kotlin | Swift（SKIE 適用後・呼び出し側） |
|--------|---------------------|
| `suspend fun save(record: CoffeeRecord)` | `func save(record: CoffeeRecord) async throws` |
| `fun observe(): Flow<List<CoffeeRecord>>` | `SkieSwiftFlow<List<CoffeeRecord>>`（`AsyncSequence` 準拠）→ `for await x in flow` |
| `sealed class Result { object Loading; data class Success(...) }` | `enum Result { case loading; case success(...) }`（Swift の `switch` で網羅性チェックが効く） |
| `enum class BrewMethod { HandDrip, FullCity, ... }` | `@frozen enum BrewMethod: Hashable, CaseIterable { case handDrip, fullCity, ... }` — case 名は **camelCase 変換**。全列挙は `.allCases`（CaseIterable）、Obj-C ヘッダの `.entries` は Swift 側からは使わない。`.name` プロパティで Kotlin 側の元名（`"HandDrip"`）を取得可能 |

#### ⚠ デフォルト引数は Swift に伝播しない

SKIE 0.10.12 は `DefaultArgumentInterop` を有効化しておらず、Kotlin のデフォルト引数は Obj-C initializer では**全パラメーター必須**になる。data class（`Cafe` / `CoffeeRecord` / `CoffeeRecordFilter` 等）や `AppContainer` にフィールド・引数をデフォルト値付きで追加したら、**Swift の全呼び出し箇所へ新引数の明示追加が必要**（フェーズ 10-B / 10-D / 13-A-3 / 12-B / 15-A で反復確認済みのルール）。関数のデフォルト引数を Swift に見せたい場合はオーバーロードを手で切る（例: `searchText` のバイアス有無 2 本、`onNearbySearchRequested` の半径付き）。SKIE の `defaultArgumentInterop` 有効化で解消できる可能性はあるが未検証・未採用。

あわせて、SKIE は `operator fun invoke` を Swift の `callAsFunction` に変換しない。UseCase の呼び出しは `.invoke(userId:)` のように明示する（15-E-2 で確認）。

#### `sealed interface RecommendationReason`（B-4 / 9-5）の Swift 表現

`shared/domain` の `sealed interface RecommendationReason`（味覚一致カフェの推薦理由）は SKIE の SealedInterop で **`onEnum(of:)` による switch** に変換される（**Swift が「使う」側＝ calling direction**、protocol witness 不要）:

```swift
// reason: RecommendationReason
switch onEnum(of: reason) {
case .tasteProfileMatch(let match):   // match: RecommendationReasonTasteProfileMatch
    let axis = match.axis              // PreferenceMatchAxis
    let label = match.matchedLabel     // String（"Ethiopia" 等の表示ラベル）
    let name = match.exampleRecordName // String（代表コーヒー名）
    let rating = match.exampleRating   // Double（native。0.0 バグ回避の .doubleValue は不要）
}
```

- **`enum class PreferenceMatchAxis { Origin, RoastLevel, BrewMethod, Processing }` の Swift case 名は camelCase**: `.origin` / `.roastLevel` / `.brewMethod` / `.processing`（SKIE 標準変換。先頭のみ小文字化。`Processing` は 2026-07-20 に 4 軸目として追加）。`@frozen` なので `switch` は `default` なし全網羅にする（軸を増やしたら iOS の `preferenceMatchAxisLabel` / `axisIcon` の追随が必須）。**case 名の真は `.swiftinterface`**（Obj-C ヘッダ `.h` の表記は異なることがある。2026-06-22 B-4 で実地確認）。
- `MapViewModel.UIState` には `recommendedCafes: [RecommendedCafe]` と `recommendedPlaceIds: Set<String>`（ピン強調用）が加わる（既存フィールドは不変・加算的）。iOS は `makeMapViewModel(userId:)` ファクトリ経由で生成するため、`MapViewModel` のコンストラクタ引数追加（`cafeRecommendationProvider`）は Bridge 側に影響しない。

### ⚠ 重要: SKIE は「呼び出し方向限定」

SKIE の SuspendInterop / FlowInterop は **Swift から Kotlin の `suspend` 関数や `Flow` を「呼び出す」側**にしか効きません。
**Swift 側で Kotlin の interface を「実装する」場合**は、生成された Obj-C プロトコル準拠の素のシグネチャを実装する必要があります:

| Kotlin interface 定義 | Swift 側で「実装する」ときのシグネチャ |
|----------------------|------------------------------|
| `suspend fun signInAnonymouslyIfNeeded(): String` | `func signInAnonymouslyIfNeeded(completionHandler: @escaping (String?, Error?) -> Void)` |
| `suspend fun upload(record: CoffeeRecord)` | `func upload(record: CoffeeRecord, completionHandler: @escaping (Error?) -> Void)` |
| `suspend fun answer(question: String, stats: CoffeeStats): String` | `func answer(question:stats:completionHandler:)`（実装側は `__answer(...)`、completion は `(String?, Error?)`） |
| `fun observeUserId(): Flow<String?>` | `func observeUserId() -> any Kotlinx_coroutines_coreFlow`（Kotlin Flow を返す。Swift の `AsyncStream` を直接返せない） |

呼び出し側（ViewModel ブリッジ等）の Swift コードは `async throws` / `for await` をそのまま使えますが、`FirebaseRepositories/` 配下のプラットフォーム実装クラスは上記の生シグネチャを実装します。

> **Foundation Models の Q&A（`CoffeeInsightProvider.answer`、Phase B-2）** は `summarize` と同じ protocol witness パターン（実装側 `__answer(question:stats:completionHandler:)`）で iOS が実装する。**逐次表示（`streamResponse` → `Flow`）は採用しない**: Kotlin interface が `Flow<String>` を返す形にすると「Swift 側で Flow を作る」上記ハードパス（`MutableStateFlow` を Swift から構築して流し込む）が必要になり v1 には過剰。`answer` は suspend 一発で最終回答 `String` を返し、UI は回答到着まで ProgressView を出す。逐次表示が要れば Phase 2 で `MutableStateFlow` ブリッジ方式を検討する。

> **対話 Q&A v2（`CoffeeRecordQuery.searchRecords`、Phase B-3 / 9-4b）** は上記の Q&A とブリッジ方向が逆で、**Swift が Kotlin を「呼び出す」側**（calling direction）になる。`shared/domain` の `CoffeeRecordQuery` を iOS は実装せず、Foundation Models の `Tool.call` の中から呼ぶだけなので、SKIE がそのまま `func searchRecords(filter: CoffeeRecordFilter) async throws -> [CoffeeRecordSummary]` を生成する（**protocol witness 不要**。`__` プレフィックスも不要）。`@Generable Arguments`（LLM 生成）→ `CoffeeRecordFilter` への変換は Swift 側 `Tool.call` が担い、`userId` は KMP 実装が内部で解決するため Swift は filter だけ渡す。
>
> **配線の注意（依存サイクル）**: `CoffeeInsightProviderIosImpl` は `AppState` で `AppContainer` より先に生成され container のコンストラクタ引数になる一方、`coffeeRecordQuery` は container 内のリポジトリから組み立てる。両者を構築時に結べないため、provider に `attachRecordQuery(_:)` を設けて container 構築後に後付けする（`searchRecords` は `answer` 呼び出し時 = 初期化完了後にしか使わないため安全）。

#### Swift から `Flow` を「作って」返す方法

`observeUserId() -> any Kotlinx_coroutines_coreFlow` のような Flow 戻り値の interface を Swift で実装するには、Kotlin の Flow インスタンスを Swift 側で生成する必要があります。

**正規パターンは `FlowBridge.swift` の `CallbackFlow<T>` / `CallbackFlowOptional<T>`**（`Kotlinx_coroutines_coreFlow` に準拠した Swift クラス。2026-06 に確立し、`RemoteCoffeeDataSourceIosImpl` / `RemoteSavedCafeDataSourceIosImpl` / `AuthRepositoryIosImpl` の全 Flow 戻り値で使用中）:

- `CallbackFlow<T: AnyObject>`: collect 開始時に `onStart` で上流（Firestore リスナ等）を起動し、コールバックから emit。コルーチン cancel → `deinit` の `onCancel` で `listener.remove()` 等を解放
- `CallbackFlowOptional<T: AnyObject>`: nil を流せる版（サインアウト時の `AuthAccount?` nil emit 用）
- 新しい Flow 戻り値 interface を Swift 実装するときは、独自に `MutableStateFlow` 等を組み立てず、まずこの 2 ヘルパを再利用する

---

## Swift 6 の並行性境界（2026-08-07 移行）

`iosApp` は **Swift 6 言語モード + 既定 MainActor 分離**（設定は `iosApp/Configuration/Base.xcconfig`）。一方 **`SharedLogic.framework` は `-language-mode 5` でビルドされる**（SKIE が生成する Swift ソースを Kotlin/Native がコンパイルするため。`.swiftinterface` の `swift-module-flags` で確認できる）。この非対称性が境界の性質を決める。

- **アプリを Swift 6 にしても SKIE 生成コードは壊れない。** `-enable-library-evolution` 付きの `.swiftinterface` が Swift 5 セマンティクスで再構築されるため。影響を受けるのは**アプリ側から Kotlin 型を使う箇所**だけ
- **Kotlin 由来の型はすべて Sendable 非適合。** `SkieSwiftFlow` / `SkieSwiftFlowIterator` を含む（SKIE 本体に Sendable 適合を追加する予定はない → [touchlab/SKIE Discussion #48](https://github.com/touchlab/SKIE/discussions/48)）。ドメイン型で Sendable なのは Kotlin `enum` に対応する型のみ

### Kotlin interface の実装クラスは `nonisolated` にする

既定 MainActor 分離では宣言に何も書かないと `@MainActor` になるが、**Kotlin ランタイムはこれらを任意スレッドから呼ぶ**ため実態と食い違う。`FirebaseRepositories/` 配下と `CoffeeInsightProviderIosImpl`、`FlowBridge` の `CallbackFlow` / `CallbackFlowOptional` は `nonisolated final class` を明示する。

**`nonisolated` にすると、そのクラスの可変状態は無保護の共有可変状態になる。** メモリキャッシュを持つ実装（`BeanProfileRepositoryIosImpl` / `CuratedCafeRepositoryIosImpl` / `CoffeeInsightProviderIosImpl`）は `OSAllocatedUnfairLock` で包み、クラスに `@unchecked Sendable` を付けて「ロックが唯一のアクセス経路である」ことを手動で保証する。

```swift
nonisolated final class BeanProfileRepositoryIosImpl: NSObject, BeanProfileRepository, @unchecked Sendable {
    private let cache = OSAllocatedUnfairLock<[BeanProfile]?>(initialState: nil)
```

### `@preconcurrency import SharedLogic` を使ってよい条件

**`@Sendable` クロージャの引数型に Kotlin 型が直接現れる場合だけ。** Kotlin interface の `completionHandler` がこれに当たり、関数シグネチャ自体の要件なのでプロパティ単位の対処が構造的に効かない。

プロパティ 1 個が非 Sendable なだけなら **`nonisolated(unsafe)` を優先する**（`AppState.container` / `PlacePhotoLoader.repository`）。`@preconcurrency import` はファイル内の SharedLogic 由来の型すべてについて検査を外すため、そのファイルはその後の変更でデータ競合を持ち込んでもコンパイラが黙る。

---

## ViewModel ブリッジパターン

Kotlin の ViewModel（`StateFlow` を公開）を SwiftUI から扱うには、`@Observable` でラップした **ブリッジクラス** を作ります。

### 推奨パターン（SKIE 利用 + @MainActor）

```swift
import Observation
import SharedLogic

@MainActor
@Observable
final class CoffeeListViewModelBridge {

    private let kotlin: CoffeeListViewModel
    private var observationTask: Task<Void, Never>?

    // SwiftUI が観測するプロパティ
    private(set) var records: [CoffeeRecord] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    init(kotlin: CoffeeListViewModel) {
        self.kotlin = kotlin
    }

    isolated deinit {
        // Kotlin 側の所有 viewModelScope を畳む（スレッドセーフ。
        // 遷移アニメ中にも発火する onDisappear ではなく必ず deinit で呼ぶ）
        //
        // `isolated`（SE-0371）: 既定 MainActor 分離下でも deinit だけは nonisolated に
        // なるため、MainActor 分離された非 Sendable プロパティ（kotlin）に触れない。
        // ブリッジは SwiftUI / AppState から MainActor 上でのみ保持・破棄されるので、
        // deinit を MainActor へホップさせても実害がない（2026-08-07 の Swift 6 移行）。
        kotlin.clear()
    }

    func onAppear() {
        kotlin.onAppear()
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            // SKIE により Flow が AsyncSequence 化されている前提
            for await state in kotlin.state {
                self?.apply(state)
            }
        }
    }

    func onRecordDeleted(id: String) {
        kotlin.onRecordDeleted(id: id)
    }

    private func apply(_ state: CoffeeListViewModel.UIState) {
        self.records = state.records
        self.isLoading = state.isLoading
        self.error = state.error
    }
}
```

> **observation の停止タイミングに注意**: タブ常駐画面の View で `.onDisappear { observationTask?.cancel() }` をすると、タブ往復や push → 戻る で observation が止まったまま再開されないバグになる（2026-06-25 の実例）。observation は Bridge の `deinit`（= View 破棄）まで生かすのが基本。

### View 側の使い方

View は Bridge を `@State` で保持し、**`.task { viewModel.onAppear() }` で observation を起こす**。エラーは `viewModel.error != nil` を `isPresented` に束ねた `.alert` で出し、閉じるときに `onErrorDismissed()` を呼び返す（UIState 側の error をクリアする）。

- **`.onAppear` ではなく `.task`** を使う（Bridge の `onAppear()` が Task を張るため、View のライフサイクルに合わせて自動キャンセルされる方が安全）
- Bridge の生存スコープは 2 系統: **タブ常駐画面 = `AppState` で 1 つ保持** / **push・sheet 画面 = View 内 `@State` で遷移ごと生成**（`.claude/rules/swift-ios.md`）

## CoroutineScope の橋渡し

Kotlin の ViewModel は `CoroutineScope` を外部から受け取る設計（[`architecture.md`](./architecture.md) 参照）。
iOS では `MainScope()` を Kotlin 側で生成して渡すか、`AppContainer` 内で隠蔽します。

```kotlin
// shared/framework/AppContainerViewModelFactory.kt（拡張関数。core → feature の循環依存回避）
fun AppContainer.makeCoffeeListViewModel(): CoffeeListViewModel =
    CoffeeListViewModel(coffeeRepository, scope)
```

`userId` はファクトリ引数ではなく `onAppear(userId:)` で渡す（サインイン完了のタイミングと画面生成を切り離すため）。

Swift 側はこの `AppContainer` のファクトリ拡張関数を呼ぶだけで、`CoroutineScope` を意識しないで済みます（各 ViewModel は渡された scope を親に所有 `viewModelScope` を内部生成する）。

```swift
let viewModel = appContainer.makeCoffeeListViewModel()
let bridge = CoffeeListViewModelBridge(kotlin: viewModel)
```

---

## expect / actual

### 使うのは「プラットフォーム API そのもの」だけにする

`expect`/`actual` は便利ですが、テスタビリティを下げます。**プラットフォーム API を直接叩く処理だけ** に絞ります。

| 用途 | `expect`/`actual` を使う？ |
|------|-----------------------|
| SQLDelight の `SqlDriver` 生成 | ◯（プラットフォーム固有のドライバが必要） |
| `Dispatchers.Main` の確保 | ◯ |
| プラットフォーム情報（OS バージョン等） | ◯ |
| ファイル I/O のラッパ | △（インターフェース + 注入の方が望ましい） |
| ロジック | ✕（共通化できる） |

### ファイル配置

`DatabaseDriverFactory` のような DB 関連の `expect`/`actual` は `shared/data-local` に置きます。

```
shared/data-local/src/
├── commonMain/kotlin/com/noricoffee/platform/
│   └── DatabaseDriverFactory.kt        # expect class DatabaseDriverFactory { fun create(): SqlDriver }
├── iosMain/kotlin/com/noricoffee/platform/
│   └── DatabaseDriverFactory.ios.kt    # actual
└── androidMain/kotlin/com/noricoffee/platform/
    └── DatabaseDriverFactory.android.kt
```

### 例: SqlDriver

`expect class DatabaseDriverFactory { fun create(): SqlDriver }` を `commonMain` に置き、iOS は `NativeSqliteDriver`、Android は `AndroidSqliteDriver` を返す（実体は `shared/data-local/src/*/kotlin/com/noricoffee/platform/` を真とする）。

- **`actual` のシグネチャは揃わなくてよい**: Android だけコンストラクタに `Context` が必要。**この非対称はアプリ初期化コード側で吸収する**（iOS は引数なし生成、Android は Application から Context を渡す）
- FK 制約の有効化はドライバ生成時の設定（[`data-model.md`](./data-model.md) §2.2）。プラットフォームごとに書き方が違うので、両方に入れ忘れない

## Umbrella Framework + XCFramework（iOS 配布戦略）

**戦略と Gradle 設定の正本は [`architecture.md`](./architecture.md)「iOS 配布戦略：Umbrella Framework」**（KMP は 1 framework 出力が原則 / `api` と `export` の両方が必要 / `baseName` と XCFramework 名を揃える）。ブリッジを書く側が知っておくことだけ再掲する:

- **`iosApp` は `SharedLogic` 単一 framework だけを参照する**。個別の shared モジュール（`shared/domain` / `shared/feature/coffee-list` 等）を直接参照しない（依存が複雑化し、Kotlin 側の `api` / `implementation` 制御が効かなくなる）
- ローカル開発は `embedAndSignAppleFrameworkForXcode`（Xcode の Build Phase）、CI / リリースは `assembleSharedLogicXCFramework`
- **SKIE は umbrella（`shared/framework`）に適用する**。個別モジュールに適用しても Swift 側には効かない
- `data-firebase` は `androidMain` にしか実装がないが、「全 shared モジュールを一律 re-export する」規則を崩さないため `export` 対象に含める

## Firebase は公式プラットフォーム別 SDK を使う

CoffeeVision では Firebase に **公式の per-platform SDK** を採用します。
GitLive 製の Kotlin Multiplatform Firebase SDK（`dev.gitlive.firebase.*`）は採用しません。

| プラットフォーム | SDK | 配置 |
|------|-----|------|
| iOS | `FirebaseFirestore` / `FirebaseAuth`（SPM or CocoaPods） | `iosApp/iosApp/FirebaseRepositories/` に Swift 実装 |
| Android | Firebase BoM + `firebase-firestore-ktx` / `firebase-auth-ktx` | `shared/data-firebase/androidMain` |

> 写真本体はクラウドに同期せず端末ローカル（Documents）のみに保存する方針のため、Storage SDK は採用しない（[`requirements.md`](./requirements.md) §7-2 / [`architecture.md`](./architecture.md) §永続化方針）。

そのため、`commonMain` から Firestore / Auth を直接呼ぶことはできません。
**Repository インターフェースを `commonMain` に置き、実装をプラットフォーム別に分ける**設計にします。

### 設計パターン

```
shared/domain/src/commonMain/kotlin/com/noricoffee/repository/
    CoffeeRepository.kt                  ← interface のみ（RemoteCoffeeDataSource も同居）
    AuthRepository.kt                    ← interface のみ

shared/data-firebase/src/androidMain/kotlin/com/noricoffee/repository/
    RemoteCoffeeDataSourceAndroidImpl.kt ← firebase-firestore-ktx を使う
    AuthRepositoryAndroidImpl.kt         ← firebase-auth-ktx を使う

iosApp/iosApp/FirebaseRepositories/
    RemoteCoffeeDataSourceIosImpl.swift  ← FirebaseFirestore (Swift) を使う
    AuthRepositoryIosImpl.swift          ← FirebaseAuth を使う
```

> Phase 2.5（2026-06-08）で `shared/domain` と `shared/data-firebase` に分離、2026-06-11 に Android Firebase 実装を `shared/data-firebase/androidMain` へ移送完了。

### Repository 合成パターン

`CoffeeRepository` は `commonMain` で **2 段構成** にします：

1. `RemoteCoffeeDataSource`（interface, `commonMain`） — Firestore リスナを `Flow` で公開し、`upload(record)` / `remove(userId, id)` を持つ薄いアダプタ
2. `CoffeeRepositoryImpl`（class, `shared/core`） — `LocalCoffeeRepository`（SQLDelight）と `RemoteCoffeeDataSource` を合成し、UI には `CoffeeRepository` 1 本だけを見せる

各プラットフォームが書くのは `RemoteCoffeeDataSource` の実装のみ。合成ロジック（ローカル → リモートの書き込み順序、`startSync(userId, scope)` でリモート変更をローカル DB へ反映）は共通層で 1 度だけ書きます。

```
iOS Swift / Android Kotlin
    │  RemoteCoffeeDataSource を実装（Firestore SDK 直叩き）
    ▼
RemoteCoffeeDataSource (commonMain interface)
    │
    ├─ CoffeeRepositoryImpl.save()  : ローカル → リモートの順で書く
    └─ CoffeeRepositoryImpl.startSync(): リモート変更を購読してローカル DB に upsert
            │
            ▼
    CoffeeRepository (UI から見える唯一の API)
```

書き込み時のリモート失敗扱いは `WritePolicy.PropagateRemoteFailure`（既定）と `WritePolicy.IgnoreRemoteFailure` で切り替え可能。後者は Firestore のオフライン永続化による再送に委ねる選択肢です。

詳細仕様と判断経緯は [`implementation_note.md`](./implementation_note.md) を参照してください。

iOS 側は **Swift で Kotlin の interface を直接実装** できます（Kotlin → Swift で interface はプロトコル相当として見えるため）。
`AppContainer` 構築時に、Swift 側で作った Repository 実装を Kotlin の `AppContainer` コンストラクタに渡します。

```swift
// iosApp 起動時（AppState）。Swift 実装を Kotlin の AppContainer に渡す
let container = AppContainer(
    sqlDriver: DatabaseDriverFactory().create(),
    remoteCoffeeDataSource: RemoteCoffeeDataSourceIosImpl(),        // Swift 実装
    remoteSavedCafeDataSource: RemoteSavedCafeDataSourceIosImpl(),  // Swift 実装
    authRepository: AuthRepositoryIosImpl(),                        // Swift 実装
    placesApiKey: placesApiKey,
    coffeeInsightProvider: CoffeeInsightProviderIosImpl.makeIfAvailable(),  // 非対応端末は nil
    beanProfileRepository: BeanProfileRepositoryIosImpl(),
    curatedCafeRepository: CuratedCafeRepositoryIosImpl()
)
```

Android も同じセカンダリコンストラクタを Kotlin 実装（`*AndroidImpl`）で埋めるだけ（`coffeeInsightProvider` のみ省略 = null）。

> 引数の正確なシグネチャは `shared/core/.../AppContainer.kt` を真とする（scope 引数ありのプライマリはテスト専用）。

### なぜ `expect`/`actual` ではなく interface + DI なのか

- `expect`/`actual` だと iOS 実装も Kotlin で書く必要があり、Kotlin/Native から Objective-C 経由で FirebaseFirestore を呼ぶことになる（cinterop が必要で重い）
- Swift 側で FirebaseFirestore を直接扱った方が、Firestore の Codable / SwiftConcurrency 対応をそのまま活かせる
- テスト時は `commonTest` に Fake 実装を置けば差し替えが効く

### Firestore 初期化と永続化

- iOS: `iosApp` の `@main App` 内で `FirebaseApp.configure()` を呼ぶ。Firestore のオフライン永続化はデフォルト ON
- Android: Firebase BoM 経由の `firebase-firestore-ktx` を導入し、`androidApp/build.gradle.kts` に `com.google.gms.google-services` プラグインを適用、`google-services.json` を `androidApp/` に配置（Phase 2 で実施）

---

## 例外ハンドリング

### Kotlin で投げた例外を Swift で受ける

Kotlin が `suspend` 関数で投げる例外は Swift では `NSError` として届きます（SKIE 採用時は `throws` 化される）。

```swift
do {
    try await viewModel.save()
} catch let error as NSError {
    // error.domain / error.userInfo を確認
    self.error = error.localizedDescription
}
```

### 受け取りやすい例外型を Kotlin 側で定義する

Kotlin 側で自前の例外型を `@Throws` 付きで宣言すると、SKIE が型安全に Swift に持ち出してくれます。

```kotlin
class CafeNotFoundException(message: String) : Exception(message)

@Throws(CafeNotFoundException::class)
suspend fun fetchCafe(id: String): Cafe { ... }
```

Swift 側でも `catch let e as SharedLogic.CafeNotFoundException` の形で受けられます。

---

## Collection（`List`/`Map`）の扱い

Kotlin の `List<CoffeeRecord>` は Swift 側で `NSArray`（または SKIE 環境では `[CoffeeRecord]`）として現れます。

```swift
// SKIE なし
let records: [CoffeeRecord] = (state.records as? [CoffeeRecord]) ?? []

// SKIE あり（型がそのまま [CoffeeRecord] になる。as? キャストを書くと "always succeeds" 警告）
let records = state.records
```

`Map<String, Cafe>` も同様に `NSDictionary` → `[String: Cafe]` のキャストが必要になることがあります。

### 定数カタログの共有（`CoffeeOriginCatalog`）

産地の国ドロップダウン（[`data-model.md`](./data-model.md) §1.3a）は、選択肢の**単一の真実点を `shared/domain` に置き**、iOS ピッカーが SKIE 経由で読む。Kotlin の `object` + `val countries: List<String>` + `const val` はそのまま Swift から参照できる。

```swift
// SKIE あり: object は共有インスタンス、List<String> は [String] として現れる
let countries = CoffeeOriginCatalog.shared.countries        // [String]
let blend = CoffeeOriginCatalog.shared.BLEND                // "ブレンド"
let other = CoffeeOriginCatalog.shared.OTHER               // "その他"
```

iOS 側でリストを二重管理しないこと（正規化 `OriginNormalizer` とのカバレッジ整合は KMP のテストで担保する）。

---

## Identifiable 化

Kotlin の `data class` は `id` プロパティを持っていても、Swift の `Identifiable` には自動準拠しません。
Swift 側の Extension で準拠させます。

```swift
extension CoffeeRecord: @retroactive Identifiable {}  // 他モジュールの型への準拠は @retroactive が必要（Swift 6）
extension Photo_: @retroactive Identifiable {}        // SQLDelight 生成行型と同名衝突するため Swift 側では Photo_
```

---

## メモリ管理の注意

- Kotlin/Native のオブジェクトは ARC ではなくランタイム独自の参照カウントで管理される（New Memory Model 前提）
- Swift 側で Kotlin オブジェクトを `weak` に保持できないケースがあるため、ブリッジでは強参照を基本とし、ライフサイクルは `onAppear`/`onDisappear` で明示的に管理する
- `Task` の中で `self` をキャプチャするときは `[weak self]` を忘れない

---

## デバッグ Tips

| 症状 | 対処 |
|------|------|
| Swift 側で `SharedLogic` の型が見えない | Xcode で `Product > Clean Build Folder` → Gradle の `embedAndSignAppleFrameworkForXcode` を再実行 |
| `suspend` 関数が見えない | `@Throws` を Kotlin 側に追加。SKIE 採用済みか確認 |
| `Flow` が iterable でない | SKIE が umbrella（`shared/framework`）に適用されているか確認。`shared/*` 個別モジュールへの適用では効かない |
| 起動時クラッシュ（`kotlin.IllegalStateException: Default value of CoroutineScope`） | `MainScope()` が iOS Main looper を取れていない。`Dispatchers.Main` の actual 実装を確認 |

---

## チェックリスト

### Kotlin 側

- [ ] Swift から呼ぶ `suspend` 関数に `@Throws` を付けたか
- [ ] `sealed interface` を使うときは Swift 側の分岐方法を意識したか（SKIE 採用か）
- [ ] `expect`/`actual` を使ったが、テスト用に同じ抽象を切ったか
- [ ] `CoroutineScope` は外部から注入する設計か

### Swift 側

- [ ] ViewModel ブリッジに `@MainActor` を付けたか
- [ ] Bridge の `deinit` で `kotlin.clear()` を呼んでいるか（observation を `onDisappear` で止めていないか）
- [ ] Kotlin の `List` を Swift の `[T]` にキャストしたか
- [ ] エラーは `NSError` または SKIE 経由の型で適切に分岐しているか

---

## 参考リンク

- [SKIE — Touchlab](https://skie.touchlab.co/)
- [Kotlin/Native Interop with Swift/Objective-C](https://kotlinlang.org/docs/native-objc-interop.html)
- [Firebase for iOS（公式 / Swift Package Manager）](https://firebase.google.com/docs/ios/setup)
- [Firebase for Android（公式 / firebase-bom）](https://firebase.google.com/docs/android/setup)
- [アーキテクチャ方針](./architecture.md)
