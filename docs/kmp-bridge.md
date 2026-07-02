# KMP ブリッジガイド（Swift ⇄ Kotlin）

## 概要

CoffeeVision は **Kotlin Multiplatform（KMP）+ SwiftUI** の構成です。
`shared/*` モジュール群（基盤層 `core` / `domain` / `data-local` / `data-places` / `data-firebase` + `feature/*` + `framework`。正確な一覧は `settings.gradle.kts` を真とする）を iOS 側から扱う際の相互運用ルール・回避策・お作法をまとめます。

対象: `iosApp/iosApp/Bridge/` を実装する人、Kotlin → Swift で型が崩れたときのトラブルシュート時

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

- **`enum class PreferenceMatchAxis { Origin, RoastLevel, BrewMethod }` の Swift case 名は camelCase**: `.origin` / `.roastLevel` / `.brewMethod`（SKIE 標準変換。先頭のみ小文字化）。`@frozen` なので `switch` は `default` なし全網羅にする。**case 名の真は `.swiftinterface`**（Obj-C ヘッダ `.h` の表記は異なることがある。2026-06-22 B-4 で実地確認）。
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

`observeUserId() -> any Kotlinx_coroutines_coreFlow` のような Flow 戻り値の interface を Swift で実装するには、Kotlin の Flow インスタンスを Swift 側で生成する必要があります。基本パターン:

1. **`MutableStateFlow` を Swift から構築 → 値を流し込む**: SKIE 経由で `MutableStateFlow(initialValue:)` を Swift から呼び、Firestore リスナや AsyncStream のイベントごとに `setValue` で更新する
2. **Kotlin 側に AsyncStream → Flow の薄いブリッジヘルパを置く**（`iosMain`）: 詰まったらこちらに退避

実装 PoC の結果に応じて、上記のどちらを正規パターンにするかを `implementation_note.md` に記録すること。

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

    deinit {
        // Kotlin 側の所有 viewModelScope を畳む（スレッドセーフ。
        // 遷移アニメ中にも発火する onDisappear ではなく必ず deinit で呼ぶ）
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

```swift
struct CoffeeListView: View {
    @State var viewModel: CoffeeListViewModelBridge

    var body: some View {
        List(viewModel.records, id: \.id) { record in
            CoffeeRecordRow(record: record)
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .alert("エラー", isPresented: .init(
            get: { viewModel.error != nil },
            set: { _ in viewModel.onErrorDismissed() }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            viewModel.onAppear()
        }
    }
}
```

---

## CoroutineScope の橋渡し

Kotlin の ViewModel は `CoroutineScope` を外部から受け取る設計（[`architecture.md`](./architecture.md) 参照）。
iOS では `MainScope()` を Kotlin 側で生成して渡すか、`AppContainer` 内で隠蔽します。

```kotlin
// shared/framework/AppContainerViewModelFactory.kt（拡張関数。core → feature の循環依存回避）
fun AppContainer.makeCoffeeListViewModel(userId: String) =
    CoffeeListViewModel(coffeeRepository, userId, scope)
```

Swift 側はこの `AppContainer` のファクトリ拡張関数を呼ぶだけで、`CoroutineScope` を意識しないで済みます（各 ViewModel は渡された scope を親に所有 `viewModelScope` を内部生成する）。

```swift
let viewModel = appContainer.makeCoffeeListViewModel(userId: userId)
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
├── commonMain/kotlin/com/noricoffee/data/local/
│   └── DatabaseDriverFactory.kt        # expect class DatabaseDriverFactory { fun create(): SqlDriver }
├── iosMain/kotlin/com/noricoffee/data/local/
│   └── DatabaseDriverFactory.ios.kt    # actual
└── androidMain/kotlin/com/noricoffee/data/local/
    └── DatabaseDriverFactory.android.kt
```

### 例: SqlDriver

```kotlin
// commonMain
expect class DatabaseDriverFactory {
    fun create(): SqlDriver
}

// iosMain
actual class DatabaseDriverFactory {
    actual fun create(): SqlDriver =
        NativeSqliteDriver(AppDatabase.Schema, "coffeevision.db")
}

// androidMain
actual class DatabaseDriverFactory(private val context: Context) {
    actual fun create(): SqlDriver =
        AndroidSqliteDriver(AppDatabase.Schema, context, "coffeevision.db")
}
```

`actual` のシグネチャがプラットフォーム間で揃わない（Android はコンテキスト必須）場合は、各プラットフォームの App 初期化コードで対処します。

---

## Umbrella Framework + XCFramework（iOS 配布戦略）

KMP は iOS 向けに **1 つの Framework として出力する** のが原則です（複数 framework 出力は `internal` 可視性が壊れ依存解決が破綻するため避ける）。
このため `shared/framework` モジュールを **「全 shared モジュール（`feature/*` / `data-*` / `domain` / `core`）を `api` 依存で再エクスポートするだけ」** の薄い層として用意し、ここから XCFramework を生成します。

### 配布形態

- ローカル開発: `./gradlew :shared:framework:embedAndSignAppleFrameworkForXcode` を Xcode の Build Phase に組み込む
- リリースビルド / CI: `./gradlew :shared:framework:assembleSharedLogicXCFramework` で XCFramework を生成

### iosApp からの参照ルール

`iosApp` は **`SharedLogic` という単一の Framework だけを参照** します（モジュール名は `shared/framework` だが、内部 framework 名・XCFramework 名・Swift `import` 名はすべて `SharedLogic`。詳細は `architecture.md` §iOS 配布戦略 / `tasks/lessons.md` の命名統一エントリ参照）。
個別の shared モジュール（`shared/domain` / `shared/feature/visit-list` 等）を直接参照しないでください — 依存が複雑化し、Kotlin 側の `api` / `implementation` 制御が効かなくなります。

```swift
import SharedLogic

let container = AppContainer(...)
let bridge = CoffeeListViewModelBridge(kotlin: container.makeCoffeeListViewModel(userId: userId))
```

### 補足: `data-firebase` も `export` 対象に含める

`data-firebase` は `androidMain` にのみ実装ソースを持ちます（iOS Firebase 実装は `iosApp` 側 Swift）が、`shared/framework` の `api` + `export` 対象には **他モジュールと同様に含めます**（`commonMain` の再公開のため。[`architecture.md`](./architecture.md) §iOS 配布戦略と同方針、実体は `shared/framework/build.gradle.kts` を真とする）。
iOS が実装・利用する Repository インターフェース自体は `shared/domain` にあるため export の実利は薄いものの、「全 shared モジュールを一律 re-export する」規則を崩さない方を優先しています。

---

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
// iosApp 起動時（AppState）。coffeeInsightProvider を注入する 6 引数セカンダリコンストラクタ
let container = AppContainer(
    sqlDriver: DatabaseDriverFactory().create(),
    remoteCoffeeDataSource: RemoteCoffeeDataSourceIosImpl(),   // Swift 実装
    authRepository: AuthRepositoryIosImpl(),                   // Swift 実装
    placesApiKey: placesApiKey,
    coffeeInsightProvider: CoffeeInsightProviderIosImpl.makeIfAvailable(),  // 非対応端末は nil
    beanProfileRepository: BeanProfileRepositoryIosImpl()      // Swift 実装
)
```

```kotlin
// Android（Application#onCreate など）。coffeeInsightProvider なしの 5 引数セカンダリコンストラクタ
val container = AppContainer(
    sqlDriver = DatabaseDriverFactory(this).create(),
    remoteCoffeeDataSource = RemoteCoffeeDataSourceAndroidImpl(),
    authRepository = AuthRepositoryAndroidImpl(),
    placesApiKey = BuildConfig.PLACES_API_KEY,
    beanProfileRepository = BeanProfileRepositoryAndroidImpl(),
)
```

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

---

## Identifiable 化

Kotlin の `data class` は `id` プロパティを持っていても、Swift の `Identifiable` には自動準拠しません。
Swift 側の Extension で準拠させます。

```swift
extension CoffeeRecord: Identifiable {}  // id プロパティが Hashable ならこれだけで OK
extension Photo_: Identifiable {}        // SQLDelight 生成行型と同名衝突するため Swift 側では Photo_
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
| `Flow` が iterable でない | SKIE 採用済みか確認。未採用なら下記「SKIE を使わない場合」のヘルパを使う |
| 起動時クラッシュ（`kotlin.IllegalStateException: Default value of CoroutineScope`） | `MainScope()` が iOS Main looper を取れていない。`Dispatchers.Main` の actual 実装を確認 |

---

## SKIE を使わない場合

SKIE を採用しない場合は、`Shared/Bridge/` に以下のヘルパを置きます。

### Flow → AsyncStream

```kotlin
// shared/core/iosMain — Swift から呼ぶためのラッパ
class FlowWrapper<T : Any>(private val flow: Flow<T>) {
    fun watch(block: (T) -> Unit): Closeable {
        val job = MainScope().launch {
            flow.collect { block(it) }
        }
        return Closeable { job.cancel() }
    }
}
```

```swift
// iosApp/Shared/Bridge/FlowWrapper+AsyncStream.swift
extension FlowWrapper {
    func stream() -> AsyncStream<T> {
        AsyncStream { continuation in
            let closeable = self.watch { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in closeable.close() }
        }
    }
}
```

### suspend → async

Kotlin/Native の生 SDK では `suspend` 関数は **completion handler** 形式で Swift に出ます。
Swift 側で `withCheckedThrowingContinuation` を使ってラップします。

```swift
func save(_ record: CoffeeRecord) async throws {
    try await withCheckedThrowingContinuation { cont in
        viewModel.save(record: record) { error in
            if let error { cont.resume(throwing: error) }
            else { cont.resume() }
        }
    }
}
```

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
