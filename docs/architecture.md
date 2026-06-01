# CoffeeVision アーキテクチャ

## 概要

CoffeeVision は **Kotlin Multiplatform（KMP）+ ネイティブ UI** 構成を採用しています。
ビジネスロジックは Kotlin の共通モジュール（`sharedLogic`）に集約し、UI はプラットフォームごとに最適な技術（iOS は SwiftUI、Android は Compose Multiplatform）で実装します。

---

## 基本原則

| 原則 | 説明 |
|------|------|
| **Single Source of Truth** | ドメインモデル・ユースケース・状態管理は `sharedLogic` の `commonMain` に集約 |
| **Local-first（ローカル優先）** | UI は常にローカル DB（SQLDelight）と Firestore キャッシュを参照。ネットワーク待ちで UI をブロックしない |
| **Native UI** | プラットフォームの作法を尊重し、ネイティブ体験を犠牲にしない |
| **Thin View, Smart ViewModel** | View は表示と入力転送に専念し、状態と副作用は ViewModel に集約 |
| **Testability** | KMP 共通層のロジックは JVM テストで完結させる |

---

## モジュール構成

```
coffeevision/
├── sharedLogic/                       # KMP 共通層（主開発対象）
│   └── src/
│       ├── commonMain/kotlin/         # 全ターゲット共通の Kotlin
│       │   └── com/noricoffee/
│       │       ├── domain/            # ドメインモデル・enum
│       │       ├── repository/        # CafeRepository / VisitRepository ...
│       │       ├── usecase/           # SaveVisitUseCase ...（薄ければ省略可）
│       │       ├── viewmodel/         # 画面ごとの ViewModel + UIState
│       │       ├── db/                # SQLDelight 生成コード + ラッパ
│       │       ├── remote/            # Firestore / Places API クライアント
│       │       └── platform/          # expect 宣言
│       ├── iosMain/kotlin/            # iOS 固有 actual
│       ├── androidMain/kotlin/        # Android 固有 actual
│       └── commonTest/kotlin/         # 共通ユニットテスト
│
├── sharedUI/                          # Compose Multiplatform（当面は Android 向け将来枠）
│
├── iosApp/                            # SwiftUI エントリポイント
│   └── iosApp/
│       ├── App/                       # @main・ルート View
│       ├── Features/                  # 機能ごとの SwiftUI View
│       └── Shared/                    # Bridge ヘルパ・Extension
│
└── androidApp/                        # Android エントリポイント（当面は触らない）
```

---

## レイヤー構成

```
┌──────────────────────────────────────────────────┐
│                  Presentation                    │
│  SwiftUI View（iosApp）/ Compose（androidApp）   │
└──────────────┬───────────────────────────────────┘
               │ subscribes to StateFlow / sends events
               ▼
┌──────────────────────────────────────────────────┐
│                   ViewModel                      │
│        sharedLogic/viewmodel/*ViewModel.kt       │
│  - UIState (data class) を StateFlow で公開      │
│  - 副作用は suspend / Flow で受ける              │
└──────────────┬───────────────────────────────────┘
               │ calls
               ▼
┌──────────────────────────────────────────────────┐
│              UseCase（任意・薄ければ省略）        │
└──────────────┬───────────────────────────────────┘
               │ calls
               ▼
┌──────────────────────────────────────────────────┐
│                  Repository                      │
│   VisitRepository / CafeRepository / ...         │
│   - ローカル（SQLDelight）+ リモート（Firestore） │
│     を束ね、UI には Single Source として見せる   │
└──────────────┬───────────────────────────────────┘
               │
        ┌──────┴───────────────────────┐
        ▼                              ▼
┌────────────────────┐         ┌────────────────────┐
│   Local (DB)       │         │   Remote (Cloud)   │
│   SQLDelight       │         │   Firestore /      │
│                    │         │   Storage / Places │
└────────────────────┘         └────────────────────┘
```

### 各レイヤーの役割

| レイヤー | 役割 | 配置 |
|---------|------|------|
| Presentation | 描画・入力。SwiftUI / Compose | `iosApp/` / `androidApp/` |
| ViewModel | UI 状態の保持と更新、ユーザーアクションのハンドリング | `sharedLogic/.../viewmodel/` |
| UseCase | 複数 Repository をまたぐ手続き（薄ければ省略可） | `sharedLogic/.../usecase/` |
| Repository | データソースの集約。UI に対しては単一のインターフェースを提供 | `sharedLogic/.../repository/` |
| Local | SQLDelight。検索・オフライン参照を高速化する用途 | `sharedLogic/.../db/` |
| Remote | Firestore / Storage / Places API クライアント | `sharedLogic/.../remote/` |

---

## 状態管理

### ViewModel + StateFlow

ViewModel は 1 つの `UIState`（`data class`）を `StateFlow` として公開します。
複数の `StateFlow` を画面ごとに増やさず、**1 画面 = 1 UIState** を原則とします。

```kotlin
package com.noricoffee.viewmodel

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class VisitListViewModel(
    private val visitRepository: VisitRepository,
    private val scope: CoroutineScope,
) {

    data class UIState(
        val visits: List<Visit> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    fun onAppear() {
        scope.launch {
            _state.update { it.copy(isLoading = true) }
            visitRepository.observeAll().collect { visits ->
                _state.update { it.copy(visits = visits, isLoading = false) }
            }
        }
    }

    fun onVisitDeleted(id: String) {
        scope.launch {
            runCatching { visitRepository.delete(id) }
                .onFailure { e -> _state.update { it.copy(error = e.message) } }
        }
    }
}
```

### iOS（SwiftUI + @Observable）

iOS では `@Observable` の薄い ViewModel ラッパが `sharedLogic` の Kotlin ViewModel を内包し、`StateFlow` を Swift の `@Published` 相当の値へブリッジします。

```swift
import Observation
import SharedLogic

@Observable
final class VisitListViewModelBridge {
    private let kotlin: VisitListViewModel
    private(set) var state: VisitListViewModel.UIState

    init(kotlin: VisitListViewModel) {
        self.kotlin = kotlin
        self.state = kotlin.state.value
        // StateFlow の購読は kmp-bridge.md のヘルパで実装する
    }

    func onAppear() { kotlin.onAppear() }
    func onVisitDeleted(id: String) { kotlin.onVisitDeleted(id: id) }
}
```

SwiftUI View は ViewModel を `@State` または `@Bindable` で保持し、状態の読み出しのみを行います。

### Android（当面は対象外）

実装時は `androidx.lifecycle.ViewModel` でラップする想定。共通の `UIState` をそのまま利用できる設計を維持します。

---

## データフロー（書き込み）

```
SwiftUI View
   │  onAddVisitTapped()
   ▼
ViewModel（sharedLogic）
   │  visitRepository.save(visit)
   ▼
VisitRepository
   ├─ SQLDelight.insert(visit)          ← 即座にローカル DB に保存
   └─ FirestoreClient.set(visit)        ← 並行して Firestore へ書き込み
                                          （SDK のオフライン永続化が同期を引き受ける）
   │
   ▼
SQLDelight が emit → Repository.observeAll() が新しい一覧を流す
   │
   ▼
ViewModel が UIState を更新
   │
   ▼
SwiftUI View が再描画
```

- **書き込みは常に「ローカル → リモート」の順序で開始する**（ローカルが Source of Truth）
- **ネットワークエラーで UI をブロックしない**。Firestore の同期失敗時は SDK のリトライに委譲する
- 削除・更新も同じパターンで、UI は常にローカルの最新状態を見る

---

## 依存性の注入（DI）

軽量さを優先し、専用 DI フレームワークは導入しません。

- KMP 共通層では **シンプルなコンストラクタ注入** を基本とする
- アプリ起動時に `AppContainer`（手書きの DI コンテナ）を 1 つ作り、各 ViewModel に必要な依存を渡す
- iOS は `iOSApp` 起動時に `AppContainer` を生成し、SwiftUI の `Environment` 経由で各画面に供給する

```kotlin
// sharedLogic/commonMain
class AppContainer(
    sqlDriver: SqlDriver,
    placesApiKey: String,
    firestore: Firestore,
) {
    private val db = AppDatabase(sqlDriver)

    val visitRepository: VisitRepository = VisitRepositoryImpl(db, firestore)
    val cafeRepository: CafeRepository = CafeRepositoryImpl(/* PlacesClient(placesApiKey) */)

    fun makeVisitListViewModel(scope: CoroutineScope) =
        VisitListViewModel(visitRepository, scope)
}
```

`SqlDriver` などプラットフォーム依存の値は `expect`/`actual` で取得します。詳細は [`kmp-bridge.md`](./kmp-bridge.md) を参照。

---

## 永続化方針

### ローカル（SQLDelight）

- スキーマは `sharedLogic/src/commonMain/sqldelight/com/noricoffee/db/*.sq` に置く
- マイグレーションは SQLDelight のバージョニング機能で管理する
- DB 操作は Repository から呼び出し、ViewModel / View からは直接触らない
- 写真の本体ファイルはアプリのキャッシュ / Documents ディレクトリに置き、DB にはパスのみ保存する

### リモート（Firestore + Storage）

- **Firestore のオフライン永続化を有効にする**（KMP SDK のデフォルト挙動）
- 同期キューを独自実装しない。Firestore SDK が再接続時に自動同期する
- 写真は Firebase Storage にアップロードし、Firestore の `Visit` ドキュメントには Storage URL のみを保存する
- Security Rules で `request.auth.uid == resource.data.userId` を強制する

詳細スキーマは [`data-model.md`](./data-model.md) を参照。

---

## 並行処理（Coroutines）

- `kotlinx.coroutines` を使う
- ViewModel は外部から `CoroutineScope` を受け取る（iOS では `MainScope()` 相当を渡す）
- IO の境界では `Dispatchers.IO`（JVM）または `Dispatchers.Default` を使い、UI 更新の前に `Dispatchers.Main` へ戻す
- `Flow` のキャンセルは購読側スコープのキャンセルに任せる
- iOS への `suspend` / `Flow` のブリッジは [`kmp-bridge.md`](./kmp-bridge.md) を参照

---

## エラーハンドリング

- Repository は `Result<T>` を返さず、**例外を投げる**（Kotlin らしい流儀）
- ViewModel が `runCatching {}` で受け、`UIState.error` に詰めて View に通知する
- 致命的でないネットワーク失敗（Firestore 同期）は SDK のリトライに任せ、UI に出さない

---

## テスト方針

- 共通ロジックは **`commonTest` で `kotlin.test` を使ったユニットテスト** を書く
- ViewModel テストは `runTest`（`kotlinx-coroutines-test`）で `StateFlow` の遷移を検証する
- Repository テストは `FakeFirestore` / インメモリ SQLDelight ドライバを使う
- iOS / Android 固有実装のテストは各プラットフォームのテストソースセットで補完する

```kotlin
@Test
fun visit_list_loads_on_appear() = runTest {
    val repo = FakeVisitRepository(initial = listOf(sampleVisit))
    val vm = VisitListViewModel(repo, this)

    vm.onAppear()
    runCurrent()

    assertEquals(listOf(sampleVisit), vm.state.value.visits)
    assertFalse(vm.state.value.isLoading)
}
```

---

## 外部依存

| 用途 | ライブラリ | 配置 |
|------|----------|------|
| 共通基盤 | Kotlin Multiplatform / kotlinx-coroutines / kotlinx-serialization | `sharedLogic/commonMain` |
| ローカル DB | SQLDelight | `sharedLogic` |
| クラウド DB | Firebase Firestore（KMP SDK） | `sharedLogic` |
| ストレージ | Firebase Storage（KMP SDK） | `sharedLogic` |
| 認証 | Firebase Auth（KMP SDK） | `sharedLogic` |
| カフェ検索 | Google Places API（Ktor で REST 呼び出し） | `sharedLogic` |
| HTTP | Ktor Client | `sharedLogic` |
| ロギング | Napier または kermit | `sharedLogic` |
| iOS UI | SwiftUI（標準） | `iosApp` |
| Android UI | Compose Multiplatform | `sharedUI` / `androidApp`（将来） |

採用ライブラリの最終版は `gradle/libs.versions.toml` を真とする。

---

## 参考リンク

- [Kotlin Multiplatform — JetBrains](https://www.jetbrains.com/help/kotlin-multiplatform-dev/get-started.html)
- [SQLDelight](https://sqldelight.github.io/sqldelight/)
- [Firebase Kotlin Multiplatform SDK](https://github.com/GitLiveApp/firebase-kotlin-sdk)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [コーディング規約](./coding-conventions.md)
- [データモデル](./data-model.md)
- [KMP ブリッジ](./kmp-bridge.md)
