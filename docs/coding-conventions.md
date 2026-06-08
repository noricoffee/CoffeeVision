# CoffeeVision コーディング規約

## 概要

本ドキュメントは CoffeeVision プロジェクトにおける **Kotlin（KMP 共通層）** と **Swift（iOS）** のコーディング規約を定めます。
一貫したコードスタイルを維持し、可読性・保守性・テスタビリティを高めることを目的とします。

参照: [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html) / [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

---

# 1. Kotlin（shared/* 共通層）

## 1.1 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| パッケージ | 全小文字 | `com.noricoffee.viewmodel` |
| クラス / インターフェース / オブジェクト | UpperCamelCase | `VisitRepository`, `BrewMethod` |
| 関数・プロパティ | lowerCamelCase | `saveVisit()`, `isLoading` |
| 定数（`const val` / `companion`） | UPPER_SNAKE_CASE | `const val MAX_PHOTOS = 10` |
| ローカル変数 | lowerCamelCase | `val newVisit = ...` |
| Enum 値 | UpperCamelCase | `BrewMethod.HandDrip` |
| ファイル名 | クラス名と一致 | `VisitRepository.kt` |

### ドメイン固有の命名

| 要素 | 規則 | 例 |
|------|------|----|
| ドメインモデル | `data class` 単一型 | `Visit`, `Cafe`, `CoffeeItem`, `FoodItem` |
| ViewModel | `<画面名>ViewModel` | `VisitListViewModel`, `VisitEditorViewModel` |
| UIState | ViewModel 内のネスト型 | `VisitListViewModel.UIState` |
| Repository | `<エンティティ>Repository`（IF） + `Impl` 接尾辞（実装） | `VisitRepository` / `VisitRepositoryImpl` |
| UseCase | `<動詞 + 目的語>UseCase` | `SaveVisitUseCase`, `SearchCafesUseCase` |
| Remote クライアント | `<サービス>Client` | `PlacesClient`, `FirestoreClient` |

---

## 1.2 ファイル構成

### 1 ファイル = 1 公開型を基本とする

```kotlin
// Good — VisitRepository.kt
interface VisitRepository { ... }
class VisitRepositoryImpl(...) : VisitRepository { ... }

// Bad — Models.kt に複数のドメインモデルを詰め込む
data class Visit(...)
data class Cafe(...)
data class CoffeeItem(...)
```

### ViewModel ファイルの構造

```kotlin
class VisitListViewModel(
    private val visitRepository: VisitRepository,
    private val scope: CoroutineScope,
) {
    // 1. UIState（ネスト型）
    data class UIState(
        val visits: List<Visit> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    // 2. State の公開
    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 3. ユーザーアクションハンドラ（on○○ 形式）
    fun onAppear() { ... }
    fun onRefreshTriggered() { ... }
    fun onVisitDeleted(id: String) { ... }

    // 4. 内部ヘルパ（private）
    private fun reload() { ... }
}
```

---

## 1.3 ドメインモデル

- すべて `data class` で定義する
- 不変（`val` プロパティのみ）にする
- ドメイン enum は `enum class` または `sealed interface` で表現する
- 各モデルファイルはドメインロジックを持たない純粋なデータ構造とする（バリデーション等はファクトリ関数か Repository 側に置く）

```kotlin
// Good
data class CoffeeItem(
    val id: String,
    val name: String,
    val brewMethod: BrewMethod,
    val origin: String?,
    val variety: String?,
    val processing: ProcessingMethod?,
    val roastLevel: RoastLevel?,
    val cup: String?,
    val rating: Int,
    val notes: String?,
)

enum class BrewMethod {
    Espresso, HandDrip, NelDrip, FrenchPress, AeroPress, Syphon, ColdBrew, Other
}
```

---

## 1.4 関数

- 1 関数 1 責務。20 行を超えるなら分割を検討
- パラメータが 3 つを超えるなら `data class` での集約を検討
- デフォルト引数を積極的に使い、オーバーロードは避ける
- 拡張関数は **同パッケージ内** か、汎用ユーティリティとして明示的に切り出すかのどちらかにする

```kotlin
// Good
fun List<Visit>.recent(limit: Int = 20): List<Visit> =
    sortedByDescending { it.visitedAt }.take(limit)
```

---

## 1.5 `when` / `if`

- `when` で全 case を網羅する。`else` は **どうしても不可能なときのみ**
- `sealed interface` / `enum class` を使い、コンパイラに網羅性を強制させる
- `if-else` の連鎖が 3 段を超えたら `when` への置換を検討

```kotlin
// Good — 網羅性が保たれる
sealed interface SyncStatus {
    object Synced : SyncStatus
    object Pending : SyncStatus
    data class Failed(val reason: String) : SyncStatus
}

fun label(status: SyncStatus): String = when (status) {
    SyncStatus.Synced -> "同期済み"
    SyncStatus.Pending -> "同期中"
    is SyncStatus.Failed -> "失敗: ${status.reason}"
}
```

---

## 1.6 並行処理

- `kotlinx.coroutines` を使う。`Thread` を直接使わない
- `suspend` 関数は **呼び出し元の Dispatcher を尊重** する（関数内で `withContext` を使ってブロッキング処理を逃がす）
- `Flow` は冷たいまま公開し、`StateFlow` / `SharedFlow` は ViewModel 内でのみ生成する
- グローバルな `GlobalScope` は禁止

```kotlin
// Good
suspend fun fetchCafes(query: String): List<Cafe> = withContext(Dispatchers.Default) {
    placesClient.search(query)
}
```

---

## 1.7 例外とエラー

- Repository は `Result<T>` を返さず、**例外を投げる**
- ViewModel が `runCatching {}` で受け、`UIState.error` に詰める
- カスタム例外は意味のある単位でのみ定義する（過剰に増やさない）

```kotlin
// Good
suspend fun save(visit: Visit) {
    db.visitQueries.insert(visit.toRow())
    firestore.collection("visits").document(visit.id).set(visit)
}

// 呼び出し側（ViewModel）
fun onSaveTapped() {
    scope.launch {
        runCatching { visitRepository.save(currentVisit) }
            .onSuccess { _state.update { it.copy(saved = true) } }
            .onFailure { e -> _state.update { it.copy(error = e.message) } }
    }
}
```

---

## 1.8 イミュータビリティ

- 配列ではなく `List` を使う
- 公開プロパティは `val` を優先する。`var` を使うのは ViewModel 内の `MutableStateFlow` 等に限定
- `data class` のコピーには `copy()` を使う

---

## 1.9 expect / actual

- `expect` 宣言は所属するレイヤーのモジュール内に置く（DB 系 `DatabaseDriverFactory` は `shared/data-local`、Dispatcher / プラットフォーム情報は `shared/core` の `platform/` パッケージ）
- `actual` 実装は `iosMain` / `androidMain` に同名ファイルを置く
- できる限り **`expect` ではなく抽象インターフェースとコンストラクタ注入** を選ぶ（テスタビリティのため）
- 詳細は [`kmp-bridge.md`](./kmp-bridge.md) を参照

---

## 1.10 テスト

- テストファイルは `<対象型名>Test.kt`
- `kotlin.test` の `@Test` / `assertEquals` を使う
- 副作用は Fake で差し替え、モックライブラリは導入しない
- ViewModel テストは `runTest`（`kotlinx-coroutines-test`）で書く

```kotlin
@Test
fun saves_visit_locally_and_remotely() = runTest {
    val fakeDb = FakeVisitDao()
    val fakeRemote = FakeFirestore()
    val repo = VisitRepositoryImpl(fakeDb, fakeRemote)

    repo.save(sampleVisit)

    assertEquals(listOf(sampleVisit), fakeDb.all())
    assertEquals(sampleVisit, fakeRemote.get("visits", sampleVisit.id))
}
```

---

## 1.11 コメント

- コードを読めば分かることはコメントしない
- **なぜ**そうしているかを補足する場合にコメントを書く
- TODO / FIXME は issue 番号か日付を必ず添える

```kotlin
// Good
// Firestore SDK の 1MB 上限を避けるため、写真本体は Storage に逃がす
photos.forEach { storage.upload(it) }

// Bad
// 写真をアップロードする
photos.forEach { storage.upload(it) }
```

---

# 2. Swift（iosApp）

## 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| 型 | UpperCamelCase | `VisitListView`, `VisitListViewModelBridge` |
| 関数・プロパティ・変数 | lowerCamelCase | `fetchVisits()`, `isLoading` |
| 定数 | lowerCamelCase | `let maxPhotos = 10` |
| Enum case | lowerCamelCase | `case hadDrip` |

### CoffeeVision 固有の命名

| 要素 | 規則 | 例 |
|------|------|----|
| SwiftUI View | `<画面名>View` | `VisitListView`, `VisitEditorView` |
| ViewModel ブリッジ | `<画面名>ViewModelBridge` | `VisitListViewModelBridge` |
| Kotlin 型の Swift 側エイリアス | 元の名前を尊重 | `SharedLogic.Visit` |

---

## 2.2 ファイル構成

### 1 ファイル = 1 公開型

```
iosApp/iosApp/
├── App/
│   ├── iOSApp.swift                 // @main・Firebase 初期化
│   └── AppContainer.swift           // shared/core の AppContainer をラップ
├── Features/
│   ├── VisitList/
│   │   ├── VisitListView.swift
│   │   └── VisitListViewModelBridge.swift
│   ├── VisitEditor/
│   │   ├── VisitEditorView.swift
│   │   └── VisitEditorViewModelBridge.swift
│   └── ...
├── Components/                      // 2 画面以上で共用する汎用 View（StarRatingView 等）
├── FirebaseRepositories/            // shared/domain の Repository インターフェースを Swift で実装
│   ├── VisitRepositoryIosImpl.swift
│   └── AuthRepositoryIosImpl.swift
├── Bridge/                          // Flow / suspend / sealed を Swift から扱うヘルパ
└── Extensions/
```

### `Components/` への配置基準

- 単一機能（Feature）内でしか使わない View は `Features/<Feature>/` 内に `private struct` として置く
- **2 画面以上で使われる**、または **単体で入力 UI として再利用できる汎用 View**（評価入力、写真サムネ表示、ローディング表示など）は `Components/` に切り出す
- `Components/` 配下の View はドメインモデル（`shared/domain` の型）に依存してよいが、`AppState` や ViewModel Bridge には依存しないこと（再利用可能性を保つため）

### View ファイルの構造

```swift
struct VisitListView: View {

    // 1. ViewModel
    @State private var viewModel: VisitListViewModelBridge

    init(viewModel: VisitListViewModelBridge) {
        self._viewModel = State(initialValue: viewModel)
    }

    // 2. body
    var body: some View { ... }

    // 3. private サブビュー
    private var loadingOverlay: some View { ... }
}
```

---

## 2.3 SwiftUI 規約

- View はレイアウトと `viewModel.on○○()` の呼び出しのみを担う
- ビジネスロジックを View に書かない
- `@State` は View 内に閉じる値のみ。共有状態は ViewModel に寄せる
- 各 View にプレビューを実装する（ダミー Bridge を使う）

```swift
// Good
Button("追加") {
    viewModel.onAddVisitTapped()
}

// Bad
Button("追加") {
    if viewModel.state.visits.count < 100 {
        viewModel.onAddVisitTapped()
    }
}
```

### プレビュー

```swift
#Preview {
    VisitListView(viewModel: .preview)
}
```

`*ViewModelBridge` に `static let preview` を生やしてダミー実装を返します。

---

## 2.4 KMP（shared/* 共通層）の利用

- `iosApp` は `SharedFramework`（`shared/framework` 由来の XCFramework）だけを参照する。個別の shared モジュールを直接参照しない
- Kotlin の `suspend` / `Flow` は直接呼ばず、`Bridge/` のヘルパを通す
- Kotlin で投げる例外は Swift では `NSError` として届く。受け側で型を見て分岐する
- Firebase Repository の iOS 実装は `FirebaseRepositories/` 配下に置き、`shared/domain` のインターフェースに準拠させる
- 詳細は [`kmp-bridge.md`](./kmp-bridge.md) を参照

---

## 2.5 並行処理

- Swift Concurrency（`async`/`await`）を使う
- ViewModel ブリッジは `@MainActor` を付与し、UI 更新を Main で完結させる
- `Task { ... }` を View の `body` 内で生成するときは `.task` モディファイアを優先する

```swift
@MainActor
@Observable
final class VisitListViewModelBridge { ... }

VisitListView(...)
    .task { await viewModel.onAppear() }
```

---

## 2.6 コメント

Kotlin 側と同じ方針。**WHY** のみ書き、WHAT は書かない。

---

# 3. 共通

## 3.1 Lint / Formatter

- Kotlin: `ktlint` または IDE の標準フォーマッタ
- Swift: Xcode 標準フォーマッタ（4 スペースインデント）
- CI で format チェックを将来導入する（タスク参照: `docs/tasks.md`）

## 3.2 コミットメッセージ

- 1 行目: 50 文字以内の要約。`動詞 + 目的語` 形式（例: `Add VisitRepository skeleton`）
- 本文があれば 1 行空けて 72 文字で折り返し
- 言語は **英語または日本語のいずれかに統一**（混在しない）

## 3.3 ブランチ運用

- `main`: リリース可能な状態を維持
- `feature/<内容>`: 機能追加
- `fix/<内容>`: バグ修正
- `chore/<内容>`: 雑務（依存更新など）

---

## 参考リンク

- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [アーキテクチャ方針](./architecture.md)
- [KMP ブリッジ](./kmp-bridge.md)
