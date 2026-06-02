# KMP ブリッジガイド（Swift ⇄ Kotlin）

## 概要

CoffeeVision は **Kotlin Multiplatform（KMP）+ SwiftUI** の構成です。
`shared/*` モジュール群（現状は `sharedLogic` 一枚、移行後は `shared/core` / `shared/domain` / `shared/feature/*` / `shared/data-*` / `shared/framework`）を iOS 側から扱う際の相互運用ルール・回避策・お作法をまとめます。

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

## SKIE の利用（推奨）

[**SKIE**](https://skie.touchlab.co/) は Touchlab が提供する Kotlin/Native → Swift トランスパイラ拡張で、`suspend` を Swift の `async` に、`Flow` を `AsyncSequence` に、`sealed class` を Swift の `enum` に変換してくれます。

> 採用判断は `gradle/libs.versions.toml` を更新するタイミングで最終確定する。SKIE を入れない場合は本ドキュメント末尾の「SKIE を使わない場合」を参照。

### Gradle への追加（採用時）

```kotlin
// shared/framework/build.gradle.kts（移行後）/ sharedLogic/build.gradle.kts（現状）
plugins {
    id("co.touchlab.skie") version "<latest>"
}
```

### SKIE 適用後の見え方

| Kotlin | Swift（SKIE 適用後） |
|--------|---------------------|
| `suspend fun save(visit: Visit)` | `func save(visit: Visit) async throws` |
| `fun observe(): Flow<List<Visit>>` | `func observe() -> AsyncStream<[Visit]>` 相当 |
| `sealed class Result { object Loading; data class Success(...) }` | `enum Result { case loading; case success(...) }`（Swift の `switch` で網羅性チェックが効く） |

---

## ViewModel ブリッジパターン

Kotlin の ViewModel（`StateFlow` を公開）を SwiftUI から扱うには、`@Observable` でラップした **ブリッジクラス** を作ります。

### 推奨パターン（SKIE 利用 + @MainActor）

```swift
import Observation
import SharedLogic

@MainActor
@Observable
final class VisitListViewModelBridge {

    private let kotlin: VisitListViewModel
    private var observationTask: Task<Void, Never>?

    // SwiftUI が観測するプロパティ
    private(set) var visits: [Visit] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    init(kotlin: VisitListViewModel) {
        self.kotlin = kotlin
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

    func onDisappear() {
        observationTask?.cancel()
        observationTask = nil
    }

    func onVisitDeleted(id: String) {
        kotlin.onVisitDeleted(id: id)
    }

    private func apply(_ state: VisitListViewModel.UIState) {
        self.visits = state.visits as? [Visit] ?? []
        self.isLoading = state.isLoading
        self.error = state.error
    }
}
```

### View 側の使い方

```swift
struct VisitListView: View {
    @State var viewModel: VisitListViewModelBridge

    var body: some View {
        List(viewModel.visits, id: \.id) { visit in
            VisitRow(visit: visit)
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .alert("エラー", isPresented: .init(
            get: { viewModel.error != nil },
            set: { _ in viewModel.error = nil }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }
}
```

---

## CoroutineScope の橋渡し

Kotlin の ViewModel は `CoroutineScope` を外部から受け取る設計（[`architecture.md`](./architecture.md) 参照）。
iOS では `MainScope()` を Kotlin 側で生成して渡すか、`AppContainer` 内で隠蔽します。

```kotlin
// shared/core/commonMain（移行後）/ sharedLogic/commonMain（現状）
class AppContainer(...) {
    private val scope = MainScope()  // SupervisorJob + Dispatchers.Main

    fun makeVisitListViewModel() = VisitListViewModel(visitRepository, scope)
}
```

Swift 側はこの `AppContainer` のファクトリメソッドを呼ぶだけで、`CoroutineScope` を意識しないで済みます。

```swift
let viewModel = appContainer.makeVisitListViewModel()
let bridge = VisitListViewModelBridge(kotlin: viewModel)
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

`DatabaseDriverFactory` のような DB 関連の `expect`/`actual` は `shared/data-local` に置きます（移行後）。現状は `sharedLogic` 一枚なので `sharedLogic/src/.../platform/` に集約しています。

```
# 移行後
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
- リリースビルド / CI: `./gradlew :shared:framework:assembleSharedFrameworkXCFramework` で XCFramework を生成

### iosApp からの参照ルール

`iosApp` は **`SharedFramework` という単一の Framework だけを参照** します。
個別の shared モジュール（`shared/domain` / `shared/feature/visit-list` 等）を直接参照しないでください — 依存が複雑化し、Kotlin 側の `api` / `implementation` 制御が効かなくなります。

```swift
import SharedFramework

let container = AppContainer(...)
let bridge = VisitListViewModelBridge(kotlin: container.makeVisitListViewModel())
```

### 例外: `data-firebase`

`data-firebase` は `androidMain` のみソースを持つ（iOS Firebase 実装は `iosApp` 側 Swift）ため、`shared/framework` の `export` 対象には含めません。
`domain` の Repository インターフェースだけが iOS 側から見えていれば十分です。

---

## Firebase は公式プラットフォーム別 SDK を使う

CoffeeVision では Firebase に **公式の per-platform SDK** を採用します。
GitLive 製の Kotlin Multiplatform Firebase SDK（`dev.gitlive.firebase.*`）は採用しません。

| プラットフォーム | SDK | 配置 |
|------|-----|------|
| iOS | `FirebaseFirestore` / `FirebaseAuth` / `FirebaseStorage`（SPM or CocoaPods） | `iosApp/iosApp/FirebaseRepositories/` に Swift 実装 |
| Android | Firebase BoM + `firebase-firestore-ktx` / `firebase-auth-ktx` / `firebase-storage-ktx` | `shared/data-firebase/androidMain`（現状は `sharedLogic/androidMain`） |

そのため、`commonMain` から Firestore / Auth / Storage を直接呼ぶことはできません。
**Repository インターフェースを `commonMain` に置き、実装をプラットフォーム別に分ける**設計にします。

### 設計パターン（移行後の配置）

```
shared/domain/src/commonMain/kotlin/com/noricoffee/domain/repository/
    VisitRepository.kt            ← interface のみ
    AuthRepository.kt             ← interface のみ

shared/data-firebase/src/androidMain/kotlin/com/noricoffee/data/firebase/
    VisitRepositoryAndroidImpl.kt ← firebase-firestore-ktx を使う
    AuthRepositoryAndroidImpl.kt  ← firebase-auth-ktx を使う

iosApp/iosApp/FirebaseRepositories/
    VisitRepositoryIosImpl.swift  ← FirebaseFirestore (Swift) を使う
    AuthRepositoryIosImpl.swift   ← FirebaseAuth を使う
```

> Phase 1 時点では `commonMain` / `androidMain` の参照先がいずれも `sharedLogic` 配下です。Phase 2.5 で `shared/domain` と `shared/data-firebase` に分離します（[`tasks.md`](./tasks.md) Phase 2.5 参照）。

iOS 側は **Swift で Kotlin の interface を直接実装** できます（Kotlin → Swift で interface はプロトコル相当として見えるため）。
`AppContainer` 構築時に、Swift 側で作った Repository 実装を Kotlin の `AppContainer` コンストラクタに渡します。

```swift
// iosApp 起動時
let visitRepo = VisitRepositoryIosImpl()      // Swift 実装
let authRepo  = AuthRepositoryIosImpl()       // Swift 実装

let container = AppContainer(
    sqlDriver: makeIosSqlDriver(),
    placesApiKey: Config.placesApiKey,
    visitRepository: visitRepo,
    authRepository: authRepo
)
```

```kotlin
// Android（Application#onCreate など）
val visitRepo = VisitRepositoryAndroidImpl(/* Firestore.getInstance() などを内部で参照 */)
val authRepo = AuthRepositoryAndroidImpl()

val container = AppContainer(
    sqlDriver = makeAndroidSqlDriver(this),
    placesApiKey = BuildConfig.PLACES_API_KEY,
    visitRepository = visitRepo,
    authRepository = authRepo,
)
```

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

Kotlin の `List<Visit>` は Swift 側で `NSArray`（または SKIE 環境では `[Visit]`）として現れます。

```swift
// SKIE なし
let visits: [Visit] = (state.visits as? [Visit]) ?? []

// SKIE あり（型がそのまま [Visit] になる）
let visits = state.visits
```

`Map<String, Cafe>` も同様に `NSDictionary` → `[String: Cafe]` のキャストが必要になることがあります。

---

## Identifiable 化

Kotlin の `data class` は `id` プロパティを持っていても、Swift の `Identifiable` には自動準拠しません。
Swift 側の Extension で準拠させます。

```swift
extension Visit: Identifiable {}  // id プロパティが Hashable ならこれだけで OK
extension CoffeeItem: Identifiable {}
extension FoodItem: Identifiable {}
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
// shared/core/iosMain（移行後）/ sharedLogic/iosMain（現状）— Swift から呼ぶためのラッパ
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
func save(_ visit: Visit) async throws {
    try await withCheckedThrowingContinuation { cont in
        viewModel.save(visit: visit) { error in
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
- [ ] `Task` を `onDisappear` でキャンセルしているか
- [ ] Kotlin の `List` を Swift の `[T]` にキャストしたか
- [ ] エラーは `NSError` または SKIE 経由の型で適切に分岐しているか

---

## 参考リンク

- [SKIE — Touchlab](https://skie.touchlab.co/)
- [Kotlin/Native Interop with Swift/Objective-C](https://kotlinlang.org/docs/native-objc-interop.html)
- [Firebase for iOS（公式 / Swift Package Manager）](https://firebase.google.com/docs/ios/setup)
- [Firebase for Android（公式 / firebase-bom）](https://firebase.google.com/docs/android/setup)
- [アーキテクチャ方針](./architecture.md)
