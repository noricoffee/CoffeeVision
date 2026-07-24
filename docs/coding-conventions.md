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
| パッケージ | 全小文字 | `com.noricoffee.feature.coffeelist` |
| クラス / インターフェース / オブジェクト | UpperCamelCase | `CoffeeRepository`, `BrewMethod` |
| 関数・プロパティ | lowerCamelCase | `saveRecord()`, `isLoading` |
| 定数（`const val` / `companion`） | UPPER_SNAKE_CASE | `const val MAX_PHOTOS = 10` |
| ローカル変数 | lowerCamelCase | `val newRecord = ...` |
| Enum 値 | UpperCamelCase | `BrewMethod.HandDrip` |
| ファイル名 | クラス名と一致 | `CoffeeRepository.kt` |

### ドメイン固有の命名

| 要素 | 規則 | 例 |
|------|------|----|
| ドメインモデル | `data class` 単一型 | `CoffeeRecord`, `Cafe`, `Photo`, `BeanProfile` |
| ViewModel | `<画面名>ViewModel` | `CoffeeListViewModel`, `CoffeeEditorViewModel` |
| UIState | ViewModel 内のネスト型 | `CoffeeListViewModel.UIState` |
| Repository | `<エンティティ>Repository`（IF） + `Impl` 接尾辞（実装） | `CoffeeRepository` / `CoffeeRepositoryImpl` |
| UseCase | `<動詞 + 目的語>UseCase` | `BuildCoffeeStatsUseCase`, `ObserveVisitedCafesUseCase` |
| Remote クライアント | `<サービス>Client` | `PlacesClient` |

---

## 1.2 ファイル構成

### 1 ファイル = 1 公開型を基本とする

```kotlin
// Good — CoffeeRepository.kt
interface CoffeeRepository { ... }
class CoffeeRepositoryImpl(...) : CoffeeRepository { ... }

// Bad — Models.kt に複数のドメインモデルを詰め込む
data class CoffeeRecord(...)
data class Cafe(...)
data class Photo(...)
```

### ViewModel ファイルの構造

```kotlin
class CoffeeListViewModel(
    private val coffeeRepository: CoffeeRepository,
    scope: CoroutineScope,
) {
    // 1. 所有スコープ（注入 scope の Job を親にした SupervisorJob 子スコープ。
    //    launch はすべてこちらで行い、Bridge の deinit から clear() で畳む）
    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    // 2. UIState（ネスト型）
    data class UIState(
        val records: List<CoffeeRecord> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    // 3. State の公開
    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 4. ユーザーアクションハンドラ（on○○ 形式）
    fun onAppear() { ... }
    fun onRefreshTriggered() { ... }
    fun onRecordDeleted(id: String) { ... }

    // 5. ライフサイクル
    fun clear() { viewModelScope.cancel() }

    // 6. 内部ヘルパ（private）
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
// Good（抜粋。全フィールドは data-model.md §1.1 を真とする）
data class CoffeeRecord(
    val id: String,
    val cafe: Cafe?,               // null = セルフ抽出
    val visitedOn: LocalDate,
    val rating: Double,            // 0.5 刻み。0.0 = 未評価 sentinel
    val name: String,
    val brewMethod: BrewMethod,
    val roastLevel: RoastLevel?,
    val tasting: TastingScores?,   // all-or-nothing
    val tags: List<String>,
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
fun List<CoffeeRecord>.recent(limit: Int = 20): List<CoffeeRecord> =
    sortedByDescending { it.visitedOn }.take(limit)
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
- ViewModel は注入された scope を直接使わず、**所有 `viewModelScope`（注入 scope の Job を親にした SupervisorJob 子スコープ）で `launch` し、`clear()` で畳む**（§1.2 の構造例参照。iOS Bridge の `deinit` から呼ぶ。経緯は `implementation_note.md` 2026-06-24）
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
- ViewModel が try / catch で受け、`UIState.error` に詰める
- **コルーチン内で `runCatching {}` は使わない**（2026-06-24 確定）。`CancellationException` まで握りつぶし、画面破棄・サインアウト等の協調キャンセルがエラー扱いになるため。`CancellationException` を先行 catch でフラグをリセットして**再スロー**し、`Exception` でユーザー向けエラーを表示する
- カスタム例外は意味のある単位でのみ定義する（過剰に増やさない）

```kotlin
// Good — 呼び出し側（ViewModel）
fun onSaveTapped() {
    viewModelScope.launch {
        _state.update { it.copy(isSaving = true) }
        try {
            coffeeRepository.save(currentRecord)
            _state.update { it.copy(isSaving = false, saved = true) }
        } catch (e: CancellationException) {
            _state.update { it.copy(isSaving = false) }
            throw e   // 協調キャンセルを遮断しない
        } catch (e: Exception) {
            _state.update { it.copy(isSaving = false, error = e.message) }
        }
    }
}

// Bad — CancellationException も握りつぶす
fun onSaveTapped() {
    viewModelScope.launch {
        runCatching { coffeeRepository.save(currentRecord) }
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
fun saves_record_locally_and_remotely() = runTest {
    val fakeLocal = FakeCoffeeRepository()
    val fakeRemote = FakeRemoteCoffeeDataSource()
    val repo = CoffeeRepositoryImpl(fakeLocal, fakeRemote)

    repo.save(sampleRecord)

    assertEquals(listOf(sampleRecord), fakeLocal.all())
    assertEquals(sampleRecord, fakeRemote.uploaded.single())
}
```

> 所有 `viewModelScope` を持つ ViewModel を `runTest` でテストする場合は、テスト末尾（`finally`）で `vm.clear()` を呼ぶこと（`TestScope` の子として生き残り `UncompletedCoroutinesError` になるため。`tasks/lessons.md` 参照）。

---

## 1.11 コメント

- コードを読めば分かることはコメントしない
- **なぜ**そうしているかを補足する場合にコメントを書く
- TODO / FIXME は issue 番号か日付を必ず添える

```kotlin
// Good
// SKIE は Swift 側で enum を camelCase に変換するため、Firestore には Kotlin の元名（name）で書き出す
data["brewMethod"] = item.brewMethod.name

// Bad
// brewMethod を文字列化
data["brewMethod"] = item.brewMethod.name
```

---

## 1.12 kotlinx.serialization（JSON）

API クライアント / エクスポートの `Json` 設定は **`encodeDefaults = true` + `explicitNulls = false`** を基本にする:

- `encodeDefaults = false`（既定）だとデフォルト値を持つフィールドが JSON から**静かに脱落**する（Places の `includedPrimaryTypes` 欠落・export の `version` 欠落で実証。implementation_note 2026-06-23 / 2026-07-07）
- `explicitNulls = false` により、省略可能なリクエストフィールドは `val includedType: String? = "cafe"` のように nullable + デフォルト値で表現でき、null 渡しでキーごと省略できる（フェーズ 17-D のパターン）

---

# 2. Swift（iosApp）

## 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| 型 | UpperCamelCase | `CoffeeListView`, `CoffeeListViewModelBridge` |
| 関数・プロパティ・変数 | lowerCamelCase | `fetchRecords()`, `isLoading` |
| 定数 | lowerCamelCase | `let maxPhotos = 10` |
| Enum case | lowerCamelCase | `case handDrip` |

### CoffeeVision 固有の命名

| 要素 | 規則 | 例 |
|------|------|----|
| SwiftUI View | `<画面名>View` | `CoffeeListView`, `CoffeeEditorView` |
| ViewModel ブリッジ | `<画面名>ViewModelBridge` | `CoffeeListViewModelBridge` |
| Kotlin 型の Swift 側エイリアス | 元の名前を尊重 | `SharedLogic.CoffeeRecord` |

---

## 2.2 ファイル構成

### 1 ファイル = 1 公開型

```
iosApp/iosApp/
├── App/
│   ├── iOSApp.swift                 // @main・Firebase 初期化
│   └── AppState.swift               // bootstrap・AppContainer 構築・タブ常駐 Bridge 保持
├── Features/
│   ├── CoffeeList/
│   │   ├── CoffeeListView.swift
│   │   └── CoffeeListViewModelBridge.swift
│   ├── CoffeeEditor/
│   │   ├── CoffeeEditorView.swift
│   │   └── CoffeeEditorViewModelBridge.swift
│   └── ...
├── Components/                      // 2 画面以上で共用する汎用 View（StarRatingView 等）
├── FirebaseRepositories/            // shared/domain の Repository インターフェースを Swift で実装
│   ├── RemoteCoffeeDataSourceIosImpl.swift
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
struct CoffeeListView: View {

    // 1. ViewModel
    @State private var viewModel: CoffeeListViewModelBridge

    init(viewModel: CoffeeListViewModelBridge) {
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
- 例外: 高頻度テキスト入力（検索欄等）の表示値は Kotlin `StateFlow` に直結せず、**View ローカル `@State` を表示の真実の源**にして `.onChange` で Kotlin へ一方向転送する（`set → Kotlin → SKIE emit → 再描画` の非同期ラウンドトリップによる入力ラグ防止）
- 各 View にプレビューを実装する（ダミー Demo 方式。下記「プレビュー」参照）

```swift
// Good
Button("追加") {
    viewModel.onAddRecordTapped()
}

// Bad
Button("追加") {
    if viewModel.records.count < 100 {
        viewModel.onAddRecordTapped()
    }
}
```

### プレビュー

本体 View は `AppState` / Kotlin VM に依存する Bridge を要求するため、**Preview では本物の Bridge を構築しない**。`#Preview` ブロック内に「同等構造のダミー Demo View」を直接書き、ダミーデータは `PreviewSupport/PreviewSamples.swift` の `static let` に集約して Preview 間で共有する（戦略 B。経緯は implementation_note 2026-06-11）。本体の構造が変わったら Preview 側も追従する（コード重複は割り切り）。`*ViewModelBridge` に `static let preview` を生やす方式は**採用していない**。

---

## 2.4 KMP（shared/* 共通層）の利用

- `iosApp` は `SharedLogic`（`shared/framework` 由来の XCFramework。framework 名・import 名ともに `SharedLogic`）だけを参照する。個別の shared モジュールを直接参照しない
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
final class CoffeeListViewModelBridge { ... }

CoffeeListView(...)
    .task { await viewModel.onAppear() }
```

### `@Observable` / `@MainActor` の実装パターン

- `@Observable` は `lazy var` 非対応（マクロの init accessor が他 stored property を参照できない）。遅延生成は `private(set) var x: T?` + bootstrap 成功後の 1 回生成で表現する。`init` 内では全 stored property 初期化前の `self` アクセスも不可（依存はローカル変数に受けてから順に代入）
- 外部からのリセットが必要なプロパティは `private(set)` + リセットメソッド公開（例: `resetLastLocation()` / `clearError()`）。View からの直接代入はさせない
- `@MainActor` クラスを CoreLocation 等の delegate に準拠させる場合、delegate メソッドは**すべて `nonisolated` 宣言**し、内部の `@MainActor` プロパティ更新は `Task { @MainActor in ... }` で戻す（コールバックは背景スレッドから呼ばれるため）

---

## 2.6 コメント

Kotlin 側と同じ方針。**WHY** のみ書き、WHAT は書かない。

---

# 3. 共通

## 3.1 Lint / Formatter

- Kotlin: `ktlint` または IDE の標準フォーマッタ
- Swift: Xcode 標準フォーマッタ（4 スペースインデント）
- CI での format チェックは未導入（導入するときに `docs/tasks.md` へ起票する）

## 3.2 コミットメッセージ

- 1 行目: 50 文字以内の要約。`動詞 + 目的語` 形式（例: `Add CoffeeRepository skeleton`）
- 本文があれば 1 行空けて 72 文字で折り返し
- 言語は **英語または日本語のいずれかに統一**（混在しない）

## 3.3 ブランチ運用

- `main`: リリース可能な状態を維持
- `feature/<内容>`: 機能追加
- `fix/<内容>`: バグ修正
- `chore/<内容>`: 雑務（依存更新など）

## 3.4 ファイルサイズと責務分割

- **1 ファイル / 1 型が肥大化したら責務ごとに分割する**。目安は **コードファイル（`.swift` / `.kt`）800 行超**で分割を検討する（PostToolUse フック [`.claude/hooks/check-file-size.sh`](../.claude/hooks/check-file-size.sh) が Write/Edit 時に警告を出す。閾値はスクリプト内 `THRESHOLD` で調整可）。
- 行数は機械的な目安であり絶対条件ではない。本質は「複数の独立責務が 1 つの型に同居していないか」。1 ファイル = 1 公開型の原則（[§1.2](#12-ファイル構成) / [§2.2](#22-ファイル構成)）と併せて判断する。
- 分割の型（iOS の例。実例は `MapTabView` 分割 M-0〜M-4、lessons / implementation_note 2026-07-24）:
  - **サブ View の独立構造体化**: 巨大 SwiftUI View 内の `@ViewBuilder` メソッドを `struct XxxView: View` へ切り出し、状態は init 引数 / `@Binding` で渡す
  - **状態・サービスの `@Observable` 隔離**: 検索・データ取得など独立した状態機械を `@Observable final class` へ分離（SwiftUI 固有の `@FocusState` / `cameraPosition` はコールバックで分離）
  - **`extension` 分離**: 純粋関数的なヘルパー群を別ファイルの `extension` へ（別ファイルの extension からは `private` が見えない → 参照するメンバは internal 化）
- 大きくなってから一気に割るとリグレッションを招きやすい。**フェーズ分割（低リスクな純粋移動 → リーフ抽出 → 状態隔離）で段階的に**進め、各段でビルド・動作確認する。

---

## 参考リンク

- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [アーキテクチャ方針](./architecture.md)
- [KMP ブリッジ](./kmp-bridge.md)
