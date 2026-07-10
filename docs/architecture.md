# CoffeeVision アーキテクチャ

> 2026-06-19 に集約ルートを `Visit`（カフェ訪問）から `CoffeeRecord`（コーヒー 1 杯）へ再設計済み（クリーンブレイク。旧名との対応・経緯は git 履歴と `implementation_note.md` 2026-06-19 エントリ参照）。本ドキュメントの例文・スニペットは現行の `Coffee*` 系に更新済み。最新のデータ表現は [`data-model.md`](./data-model.md) を真とする。

## 概要

CoffeeVision は **Kotlin Multiplatform（KMP）+ ネイティブ UI** 構成を採用しています。
ビジネスロジックは Kotlin の共通モジュール群（`shared/*`）に集約し、UI はプラットフォームごとに最適な技術（iOS は SwiftUI、Android は Compose Multiplatform）で実装します。

---

## 基本原則

| 原則 | 説明 |
|------|------|
| **Single Source of Truth** | ドメインモデル・ユースケース・状態管理は `shared/*` の `commonMain` に集約 |
| **Local-first（ローカル優先）** | UI は常にローカル DB（SQLDelight）と Firestore キャッシュを参照。ネットワーク待ちで UI をブロックしない |
| **Native UI** | プラットフォームの作法を尊重し、ネイティブ体験を犠牲にしない |
| **Thin View, Smart ViewModel** | View は表示と入力転送に専念し、状態と副作用は ViewModel に集約 |
| **Testability** | KMP 共通層のロジックは JVM テストで完結させる |

---

## モジュール構成

### 現状（Phase 5 時点）

旧 `sharedLogic` 一枚モジュールを Phase 2.5（2026-06-08）で基盤レイヤーに分割し、その後 Phase 3 / 3.5 / 4 で `feature/*` と `data-places` を順次切り出した。構成は **基盤層（`core` / `domain` / `data-*`）+ feature 層（1 画面 = 1 モジュール、画面追加ごとに増える）+ `framework`（iOS Umbrella）+ アプリ層** という固定パターン。**モジュールの正確な一覧と件数は `settings.gradle.kts` を真とする**（このツリーは構造を示すための代表例で、feature の網羅列挙はしない）。

```
coffeevision/
├── build-logic/
│   └── convention/                       # Convention Plugin（precompiled script plugin）
│       └── src/main/kotlin/
│           ├── kmp.library.gradle.kts    # KMP ライブラリ共通（targets / compilerOptions）
│           ├── kmp.feature.gradle.kts    # feature 共通（domain + core 自動依存）
│           └── android.library.gradle.kts
│
├── shared/
│   ├── core/                             # [com.noricoffee.core] AppContainer / CoffeeRepositoryImpl（local+remote 合成）
│   ├── domain/                           # [com.noricoffee.domain] ドメインモデル / enum / *Repository I/F / UseCase / VisitedCafe
│   ├── data-local/                       # [com.noricoffee.dataLocal] SQLDelight スキーマ / Mapper / DriverFactory / LocalCoffeeRepository
│   ├── data-places/                      # [com.noricoffee.dataPlaces] Ktor + Google Places API クライアント（PlacesClient / CafeRepositoryImpl）
│   ├── data-firebase/                    # [com.noricoffee.dataFirebase] Firestore / Auth の Android 実装（iOS 実装は iosApp 側 Swift）
│   ├── framework/                        # [com.noricoffee.framework] iOS 向け Umbrella。`SharedLogic.xcframework` を出力 + ViewModel ファクトリ
│   └── feature/
│       └── <feature-name>/               # [com.noricoffee.feature.<name>] 1 画面 = 1 モジュール（<Name>ViewModel + UIState）
│                                         #   画面追加ごとに増える。正確な一覧は settings.gradle.kts を真とする
│                                         #   現状: coffee-list / coffee-detail / coffee-editor / cafe-search / map / cafe-detail / account / analysis
│
├── sharedUI/                             # Compose Multiplatform（Android 検証用、feature/coffee-list を 1 画面表示）
├── iosApp/
│   └── iosApp/
│       ├── App/                          # @main・AppContainer 構築・Firebase 初期化
│       ├── Features/                     # SwiftUI View + ViewModelBridge（feature ごと）
│       ├── FirebaseRepositories/         # domain の Repository インターフェースの iOS 実装（Swift）+ FlowBridge.swift（Flow ヘルパ）
│       └── Utilities/ ほか               # PhotoFileStore / LocationManager 等（ViewModelBridge は Features/<Name>/ 配下に同居）
│
└── androidApp/                           # Android エントリポイント（検証ターゲット、リリース対象外、最小実装で維持）
    └── src/main/kotlin/
        ├── CoffeeVisionApp.kt            # Application・AppContainer 構築・Firebase 初期化
        └── ...                           # Compose Navigation + コーヒー一覧 1 画面のみ
```

- iOS 向けには `shared/framework` が **全 shared モジュール（基盤層 + 全 feature）** を `api` + `export(...)` で再公開し、`SharedLogic.framework`（XCFramework 名も `SharedLogic`）として配布。feature を追加したらこの export にも 1 行追加する
- `shared/data-firebase` は `androidMain` に Android 実装（`AuthRepositoryAndroidImpl` / `RemoteCoffeeDataSourceAndroidImpl` / `CoffeeFirestoreMapper`）を持つ。iOS 実装は `iosApp` 側 Swift で `domain` の I/F に準拠

#### この分割の設計目的（KMP モジュール分割アーキテクチャの実証）

CoffeeVision は **iOS のみリリース** を想定しているが、KMP のモジュール分割アーキテクチャを実証することを設計目的の 1 つに位置づけている。
Android ターゲットは「リリース対象」ではなく **「共通レイヤーが両プラットフォームで成立することを示す検証ターゲット」** として維持する。

分割の主目的は以下の 3 点：

1. **`feature` モジュール単位で並行開発・独立テストできる**
2. **`data` 層の実装差し替えが他レイヤーを壊さない**（特に Firebase の iOS = Swift / Android = Kotlin という非対称性を吸収する）
3. **アーキテクチャ判断がコードベースの構造そのものから読み取れる**（モジュール境界と責務の対応を明示的にする）

---

### モジュールの責務

| カテゴリ | モジュール | 中身 | 依存可能先 |
|---------|----------|------|----------|
| **基盤** | `core` | Result 型 / Logger / Dispatchers / DI 基盤 / Fake / TestDispatcher | （なし） |
| **ドメイン** | `domain` | ドメインモデル（`data class`）/ enum / Repository インターフェース / UseCase | `core` |
| **データ** | `data-local` | SQLDelight スキーマ・DAO・`DatabaseDriverFactory` (expect/actual) | `core`, `domain` |
|  | `data-places` | Places API クライアント（Ktor） | `core`, `domain` |
|  | `data-firebase` | `androidMain` のみソースを持つ Firestore / Auth 実装 | `core`, `domain` |
| **機能** | `feature/*` | ViewModel + `UIState`（Kotlin）／画面ごとに 1 モジュール | `core`, `domain`（**他 feature 不可**） |
| **配布** | `framework` | iOS 向け umbrella。全 feature/data/domain を `api` で再 export | 全 shared モジュール |
| **アプリ** | `iosApp` | SwiftUI View + Bridge + Firebase Swift 実装 + DI 配線 | `framework`（XCFramework）|
|  | `androidApp` | Compose Navigation + コーヒー一覧 1 画面（**検証用最小実装**） | `feature/coffee-list`, `data/*`, `domain`, `core` |

---

### 依存方向ルール

依存は **一方通行** で、Gradle の `api` / `implementation` および Convention Plugin で強制します。

```
app (iosApp / androidApp)
   │
   ├─ (iOS) shared/framework  ──┐
   │                            │ api 依存
   └─ (Android) 直接参照 ───────┤
                                ▼
                          feature/* （★ feature 同士の相互依存は禁止）
                                │
                                ▼
                            domain
                                │
                          ┌─────┼─────┐
                          ▼     ▼     ▼
                     data-local  data-places  data-firebase
                          │     │     │
                          └─────┼─────┘
                                ▼
                              core
```

- **feature 同士は依存禁止**：画面遷移は `iosApp` / `androidApp` の Navigation 層で繋ぐ
- **domain はインターフェースのみ**：`data-*` モジュールが実装し、`AppContainer` が注入する
- **data-firebase の iOS 実装は `iosApp` 側 Swift**：domain の Repository インターフェース（`RemoteCoffeeDataSource` / `AuthRepository` / `BeanProfileRepository`）準拠の Swift クラスを書く（[`kmp-bridge.md`](./kmp-bridge.md) 参照）

---

### iOS 配布戦略：Umbrella Framework

KMP は iOS 向けに **1 つの Framework として出力する** のが原則です（複数 framework 出力は `internal` 可視性が壊れ依存解決が破綻するため避ける）。
このため `shared/framework` モジュールを **「全 shared モジュールを `api` 依存で再エクスポートするだけ」** の薄い層として用意します。

```kotlin
// shared/framework/build.gradle.kts（抜粋）
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

// 全 shared モジュール（基盤層 + 全 feature）を api + export で再公開する。
// 下記は代表例。feature は画面追加ごとに増えるので、実体は settings.gradle.kts の全モジュールを列挙する。
kotlin {
    val xcf = XCFramework("SharedLogic")
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "SharedLogic"   // Swift 側 `import SharedLogic` を維持するため
            isStatic = true
            linkerOpts("-lsqlite3")    // sqliter が iOS システム SQLite に動的リンクするため
            export(projects.shared.core)
            export(projects.shared.domain)
            export(projects.shared.dataLocal)
            export(projects.shared.dataFirebase)
            export(projects.shared.dataPlaces)
            export(projects.shared.feature.coffeeList)
            // 以下、全 feature モジュールを同様に export（一覧は settings.gradle.kts を真とする）
            xcf.add(this)
        }
    }
    sourceSets.commonMain.dependencies {
        api(projects.shared.core)
        api(projects.shared.domain)
        api(projects.shared.dataLocal)
        api(projects.shared.dataFirebase)
        api(projects.shared.dataPlaces)
        api(projects.shared.feature.coffeeList)
        // 以下、全 feature モジュールを同様に api（export と両方必要。片方だけだと型が Swift に出ない）
    }
}
```

- 配布形態は **XCFramework**（`./gradlew :shared:framework:assembleSharedLogicXCFramework`）
- `iosApp` は SPM 経由でも直接参照でも可。**`iosApp` から個別の shared モジュールを参照しない**（依存が複雑化するため）
- `data-firebase` は Android 実装専用だが、`commonMain` の Repository インターフェース再公開のため `export` 対象に含める
- **XCFramework 名と `baseName` は揃える**：揃えないと「Framework Renaming is not supported yet」warning が出る。Swift 側の `import` 名は `baseName` 側に固定されるため、既存命名を維持する方を優先して XCFramework 名側を合わせている
- **`api(...)` だけでは Obj-C ヘッダに class が出ない**：klib 取り込みは保証されるが Swift 側で「Cannot find type in scope」になる。`framework { ... export(...) }` の **追加の明示が必須**（Phase 2.5 PR2 で確認した知見、`docs/tasks/lessons.md` 参照）

---

### Convention Plugin（`build-logic`）

モジュールが 10 を超えると `build.gradle.kts` のコピペが破綻するため、`build-logic/convention/` に Gradle Convention Plugin を置き、KMP 共通設定を集約します。

```kotlin
// build-logic/convention/src/main/kotlin/kmp.library.gradle.kts（抜粋。実体を真とする）
plugins {
    id("org.jetbrains.kotlin.multiplatform")
    id("com.android.kotlin.multiplatform.library")
}
kotlin {
    compilerOptions { freeCompilerArgs.add("-Xexpect-actual-classes") }
    iosArm64()
    iosSimulatorArm64()
    androidLibrary {
        // namespace は各モジュールで個別設定。jvmTarget は 11
        compilerOptions { jvmTarget = JvmTarget.JVM_11 }
    }
}
// 注: `jvmToolchain(17)` は付けない（toolchain 強制は JDK ダウンロード要求で開発機運用と衝突）。
// SKIE / SQLDelight など「特定モジュールだけ要るプラグイン」はここで適用しない。
```

```kotlin
// build-logic/convention/src/main/kotlin/kmp.feature.gradle.kts（抜粋）
plugins {
    id("kmp.library")
}
kotlin.sourceSets.getByName("commonMain").dependencies {
    api(project(":shared:core"))
    api(project(":shared:domain"))
}
```

各 feature の `build.gradle.kts` は `plugins { id("kmp.feature") }` を起点に、必要な依存だけを追加します。**自動配線されるのは `core` / `domain` のみ**で、`kotlinx-coroutines-core`（全 feature 必須）・`kotlinx-datetime`（`LocalDate` 等を直接参照する場合）・commonTest 依存は各 feature が手動追加する（commonTest を持つ feature が増えたら Plugin への組み込みを再検討）。

---

### モジュール分割の運用ルール

段階的移行（旧 `sharedLogic` → 現行構成）は Phase 2.5〜4（2026-06-08〜06-15）で**完了済み**（経緯は git 履歴と `tasks.md` の該当フェーズサマリ参照）。以後、新しいモジュール（主に feature）を追加するときは以下を守る:

- 分割・追加は機能追加と別 PR / 別コミットにする
- 追加直後に必ず `./gradlew :shared:framework:assembleSharedLogicXCFramework` と `./gradlew :androidApp:assembleDebug` が通ることを確認する
- パッケージ名 `com.noricoffee.*` を維持し、モジュール境界とパッケージ境界を一致させる（例: `feature/coffee-list` は `com.noricoffee.feature.coffeelist`）
- `shared/framework` の `api(...)` / `export(...)` と `AppContainerViewModelFactory.kt` のファクトリ追記を忘れない（ファクトリを `shared/core` でなく framework の拡張関数に置くのは、`feature → core` の api 依存と衝突する循環参照を避けるため）

---

### アーキテクチャ検証ルール（Android ターゲットの維持方針）

本プロジェクトは iOS のみリリースを想定していますが、KMP のモジュール分割アーキテクチャが両プラットフォームで成立することを実証するため、
Android ターゲットを **「常にビルドが通り、共通 ViewModel を最小 UI で動かせる状態」** で維持します。

- **CI**: PR 単位で iOS / Android 両方のビルドを実行。`./gradlew :shared:framework:assembleSharedLogicXCFramework` と `./gradlew :androidApp:assembleDebug` を必須チェックにする
- **Android UI スコープ**: `feature/coffee-list` を Compose で表示する 1 画面のみ。編集・検索・写真撮影は実装しない
- **共通レイヤーの完全性**: `data-firebase` の Android 実装は読み取り（`observe`）まで実装し、iOS 側 Swift 実装と同じインターフェース契約を満たすことを示す
- **依存追従**: Kotlin / KMP / AGP / Compose は年 2〜3 回のメジャー追従までを許容範囲とする。Android 検証が壊れた場合は最優先で復旧する
- **README**: アーキテクチャ図 + 主要な設計判断（公式 Firebase SDK 採用、Umbrella Framework 戦略、Convention Plugin 採用理由、Android = 検証ターゲット）を明記する

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
│      shared/feature/*/viewmodel/*ViewModel.kt    │
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
│   CoffeeRepository / CafeRepository / ...        │
│   - ローカル（SQLDelight）+ リモート（Firestore） │
│     を束ね、UI には Single Source として見せる   │
└──────────────┬───────────────────────────────────┘
               │
        ┌──────┴───────────────────────┐
        ▼                              ▼
┌────────────────────┐         ┌────────────────────┐
│   Local (DB)       │         │   Remote (Cloud)   │
│   SQLDelight       │         │   Firestore /      │
│                    │         │       Places       │
└────────────────────┘         └────────────────────┘
```

### 各レイヤーの役割

| レイヤー | 役割 | 配置 |
|---------|------|------|
| Presentation | 描画・入力。SwiftUI / Compose | `iosApp/` / `androidApp/` |
| ViewModel | UI 状態の保持と更新、ユーザーアクションのハンドリング | `shared/feature/*`（coffee-list / coffee-detail / coffee-editor / cafe-search / map / cafe-detail / account / analysis に配置済） |
| UseCase | 複数 Repository をまたぐ手続き（薄ければ省略可） | `shared/domain/usecase/` |
| Repository | データソースの集約。UI に対しては単一のインターフェースを提供 | インターフェース: `shared/domain/repository/` / 合成実装: `shared/core/repository/` |
| Local | SQLDelight。検索・オフライン参照を高速化する用途 | `shared/data-local/` |
| Remote (Places) | Google Places API クライアント（Ktor） | `shared/data-places/`（配置済） |
| Remote (Firebase) | Firestore / Auth は **公式プラットフォーム別 SDK** を使う。Android 実装は `shared/data-firebase/androidMain`、iOS 実装は `iosApp` 側の Swift で書き、Repository インターフェースを `shared/domain` に置いて差し替える。写真本体はクラウドに同期せず端末ローカルのみに保存（Storage 採用見送り） | インターフェース: `shared/domain` / Android 実装: `shared/data-firebase/androidMain` / iOS 実装: `iosApp/FirebaseRepositories/` |

---

## 状態管理

### ViewModel + StateFlow

ViewModel は 1 つの `UIState`（`data class`）を `StateFlow` として公開します。
複数の `StateFlow` を画面ごとに増やさず、**1 画面 = 1 UIState** を原則とします。

```kotlin
// shared/feature/coffee-list/.../CoffeeListViewModel.kt（実物の要約。構造規約は coding-conventions.md §1.2）
package com.noricoffee.feature.coffeelist

class CoffeeListViewModel(
    private val coffeeRepository: CoffeeRepository,
    scope: CoroutineScope,
) {
    // 注入 scope の Job を親にした所有スコープ。clear() で畳む（coding-conventions.md §1.2）
    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    data class UIState(
        val coffees: List<CoffeeRecord> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    private var observeJob: Job? = null
    private var currentUserId: String? = null

    fun onAppear(userId: String) {
        currentUserId = userId
        observeJob?.cancel()   // 再表示時の二重購読防止
        observeJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            coffeeRepository.observeAll(userId).collect { coffees ->
                _state.update { it.copy(coffees = coffees, isLoading = false) }
            }
        }
    }

    fun onCoffeeDeleted(id: String) {
        val userId = currentUserId ?: return   // onAppear 前の削除は uid 未確定として黙殺
        viewModelScope.launch {
            try {
                coffeeRepository.delete(userId, id)
            } catch (e: CancellationException) {
                throw e   // 協調キャンセルを遮断しない（coding-conventions.md §1.7）
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "delete failed") }
            }
        }
    }

    fun clear() {   // iOS Bridge の deinit から呼ぶ
        viewModelScope.cancel()
    }
}
```

### iOS（SwiftUI + @Observable）

iOS では `@Observable` の薄い ViewModel ラッパが `shared/feature/*` の Kotlin ViewModel を内包し、`StateFlow` を Swift の `@Published` 相当の値へブリッジします。

```swift
import Observation
import SharedLogic

@MainActor
@Observable
final class CoffeeListViewModelBridge {
    private let kotlin: CoffeeListViewModel
    private(set) var coffees: [CoffeeRecord] = []
    // StateFlow の購読（Task + for await）は kmp-bridge.md のパターンで実装する

    init(kotlin: CoffeeListViewModel) {
        self.kotlin = kotlin
    }

    deinit { kotlin.clear() }   // KMP 側 viewModelScope を畳む（coding-conventions.md §1.2）

    func onAppear(userId: String) { kotlin.onAppear(userId: userId) }
    func onCoffeeDeleted(id: String) { kotlin.onCoffeeDeleted(id: id) }
}
```

Bridge の生存スコープは、タブ常駐画面 = `AppState` で 1 つ保持 / push・sheet 画面 = View 内 `@State` で遷移ごと生成、の 2 系統（**タブ常駐 View の `onDisappear` で observation を止めない**。詳細は `.claude/rules/swift-ios.md` と `tasks/lessons.md` 2026-06-25 エントリ）。

SwiftUI View は ViewModel を `@State` または `@Bindable` で保持し、状態の読み出しのみを行います。

### Android（当面は対象外）

実装時は `androidx.lifecycle.ViewModel` でラップする想定。共通の `UIState` をそのまま利用できる設計を維持します。

---

## データフロー（読み取り）

UI は `CoffeeRepository.observeAll(userId)` 等の **ローカル DB に対する Flow** を購読します。
リモート（Firestore）からの変更は `CoffeeRepositoryImpl` が `RemoteCoffeeDataSource.observeChanges` を購読し、受信した全件スナップショットをローカル DB に **reconcile**（upsert + スナップショットに無い id の削除）することで反映します（削除伝播の仕様は [`data-model.md`](./data-model.md) §4.2 参照）。

```
RemoteCoffeeDataSource.observeChanges()  ──┐
                                           ▼
                              CoffeeRepositoryImpl.startSync()
                                           │  upsert + 欠落 id の削除（reconciliation）
                                           ▼
                              LocalCoffeeRepository.save() / delete()
                                           │
                                           ▼
                                    SQLDelight emit
                                           │
                                           ▼
                              CoffeeRepository.observeAll()  ◀── UI が購読
```

これにより「Firestore キャッシュとローカル DB の二重キャッシュ」を避け、**ローカル DB を唯一の Source of Truth** として扱います。

---

## データフロー（書き込み）

合成ロジックは **プラットフォーム共通の `CoffeeRepositoryImpl`（`shared/core`）** が担い、プラットフォーム別に書くのは `RemoteCoffeeDataSource` の実装だけ（Android = Kotlin / iOS = Swift）。

```
SwiftUI View → Bridge
   │  onSaveTapped()
   ▼
ViewModel（shared/feature/*）
   │  coffeeRepository.save(userId, record)
   ▼
CoffeeRepository（shared/domain のインターフェース）
   ＝ CoffeeRepositoryImpl（shared/core、local + remote の合成。プラットフォーム共通）
   │
   ├─ ① LocalCoffeeRepository.save(record)        ← 先にローカル DB（Source of Truth）
   └─ ② RemoteCoffeeDataSource.upload(record)     ← 次に Firestore
   │        実装はプラットフォーム別:
   │          - Android: RemoteCoffeeDataSourceAndroidImpl（shared/data-firebase/androidMain）
   │          - iOS:     RemoteCoffeeDataSourceIosImpl（iosApp 側 Swift, FirebaseFirestore SPM）
   │        リモート失敗の扱いは WritePolicy（下記）
   ▼
SQLDelight が emit → CoffeeRepository.observeAll() が新しい一覧を流す
   ▼
ViewModel が UIState を更新 → View が再描画
```

- **書き込みは常に「ローカル → リモート」の順序**（ローカルが Source of Truth。リモートの結果を待たずに UI へ反映される）
- **リモート失敗の扱いは `CoffeeRepositoryImpl.WritePolicy`**: 既定 `PropagateRemoteFailure`（例外を呼び出し元へ伝播し ViewModel がエラー表示）/ `IgnoreRemoteFailure`（Firestore SDK のオフライン永続化・リトライに委譲して握りつぶす）
- オフライン時の再送は Firestore SDK のオフライン永続化が引き受ける（独自の同期キューは書かない）
- 削除・更新も同じパターンで、UI は常にローカルの最新状態を見る

---

## 依存性の注入（DI）

軽量さを優先し、専用 DI フレームワークは導入しません。

- KMP 共通層では **シンプルなコンストラクタ注入** を基本とする
- アプリ起動時に `AppContainer`（手書きの DI コンテナ）を 1 つ作り、各 ViewModel に必要な依存を渡す
- iOS は `iOSApp` 起動時に `AppContainer` を生成し、SwiftUI の `Environment` 経由で各画面に供給する

```kotlin
// shared/core/commonMain（構造スケッチ。引数・公開プロパティの完全な一覧は AppContainer.kt を真とする）
class AppContainer(
    sqlDriver: SqlDriver,
    // Firebase 実装はプラットフォーム別 SDK を使うため、外部から受け取る
    private val remoteCoffeeDataSource: RemoteCoffeeDataSource,
    val authRepository: AuthRepository,
    val placesApiKey: String,      // Places API キー（Android=BuildConfig / iOS=Info.plist 経由で注入）
    /* coffeeInsightProvider / beanProfileRepository 等 */
    val scope: CoroutineScope,     // scope 引数ありのプライマリはテスト専用。通常は scope なしセカンダリ（iOS / Android の 2 系統）を使う
) {
    private val db = AppDatabase(sqlDriver)

    private val localCoffeeRepository = LocalCoffeeRepository(db)

    // CoffeeRepositoryImpl が local + remote を合成して、UI には 1 本だけを見せる
    val coffeeRepository: CoffeeRepository =
        CoffeeRepositoryImpl(local = localCoffeeRepository, remote = remoteCoffeeDataSource)

    // Places API（カフェ検索）リポジトリ
    val cafeRepository: CafeRepository = createCafeRepository(placesApiKey)

    // 起動時の匿名サインイン → uid 確定 → リモート → ローカル同期購読 を 1 メソッドで起こす
    @Throws(Exception::class)
    suspend fun startInitialSync(): String { /* ... */ }

    // ViewModel ファクトリ（makeCoffeeListViewModel 等）は shared/framework の拡張関数として配置
    //（core → feature の循環依存を避けるため。kmp-bridge.md / implementation_note.md 参照）
}
```

- `SqlDriver` などプラットフォーム依存の値は `expect`/`actual` で取得します。詳細は [`kmp-bridge.md`](./kmp-bridge.md) を参照。
- Firebase を扱うインターフェース（`RemoteCoffeeDataSource` / `AuthRepository` / `BeanProfileRepository`）は **`commonMain` で定義のみ**し、実装は以下のように分けます。
    - **Android**: `shared/data-firebase/androidMain` に Firebase Android SDK を使った実装を置き、`AppContainer` 生成時に Application から渡す
    - **iOS**: `iosApp` 側の Swift コードで `FirebaseFirestore`（SPM 配信）を使った実装クラスを書き、Kotlin のインターフェースに準拠させて `AppContainer` 構築時に渡す

---

## 永続化方針

### ローカル（SQLDelight）

- スキーマは `shared/data-local/src/commonMain/sqldelight/com/noricoffee/db/*.sq` に置く
- マイグレーションは SQLDelight のバージョニング機能で管理する
- DB 操作は Repository から呼び出し、ViewModel / View からは直接触らない
- 写真の本体ファイルはアプリの **Documents** ディレクトリに置き、DB には **相対ファイル名のみ** を保存する（iOS の Documents URL は起動ごとに変わるため絶対パス禁止）

### リモート（Firestore）

- **Firebase は公式のプラットフォーム別 SDK を採用する**
    - iOS: `FirebaseFirestore` / `FirebaseAuth` を Xcode の SPM（または CocoaPods）で `iosApp` に追加
    - Android: `gradle/libs.versions.toml` で Firebase BoM + `firebase-firestore-ktx` / `firebase-auth-ktx` を宣言し、`shared/data-firebase/androidMain` で利用
    - GitLive 製の Firebase KMP SDK（`dev.gitlive.firebase.*`）は採用しない
- **Firestore のオフライン永続化を有効にする**（公式 SDK のデフォルト挙動。iOS / Android それぞれで初期化時に確認）
- 同期キューを独自実装しない。Firestore SDK が再接続時に自動同期する
- **写真本体は Firestore / Storage に同期せず、端末ローカル（Documents）のみに保存する**。Firestore の `photos` 埋め込み配列には `fileName` / `width` / `height` などのメタデータのみを書く（Storage は採用見送り。バックアップは iCloud Backup に委ねる）
- Security Rules は **path uid 検証**（`users/{uid}` 配下は `request.auth.uid == uid` のときのみ read/write）。ルールは `firestore.rules` としてリポジトリ管理 + `firebase deploy` 運用

詳細スキーマは [`data-model.md`](./data-model.md) を参照。

---

## 並行処理（Coroutines）

- `kotlinx.coroutines` を使う
- ViewModel は外部から `CoroutineScope`（`AppContainer` の `MainScope`）を受け取り、その Job を親にした**所有 `viewModelScope`** で `launch` して `clear()` で畳む（[`coding-conventions.md`](./coding-conventions.md) §1.2）
- `commonMain` では `Dispatchers.Default` を使う（`Dispatchers.IO` は JVM / Android 専用で commonMain から参照不可）。UI 更新は `Dispatchers.Main` 上で行う
- `Flow` のキャンセルは購読側スコープのキャンセルに任せる。コルーチン内で `runCatching` は使わない（同 §1.7）
- iOS への `suspend` / `Flow` のブリッジは [`kmp-bridge.md`](./kmp-bridge.md) を参照

---

## エラーハンドリング

- Repository は `Result<T>` を返さず、**例外を投げる**（Kotlin らしい流儀）
- ViewModel が try / catch で受け、`UIState.error` に詰めて View に通知する。**コルーチン内で `runCatching {}` は使わない**（`CancellationException` を握りつぶすため。`CancellationException` は先行 catch で再スローする。詳細は [`coding-conventions.md`](./coding-conventions.md) §1.7）
- 致命的でないネットワーク失敗（Firestore 同期）は SDK のリトライに任せ、UI に出さない

---

## テスト方針

- 共通ロジックは **`commonTest` で `kotlin.test` を使ったユニットテスト** を書く
- ViewModel テストは `runTest`（`kotlinx-coroutines-test`）で `StateFlow` の遷移を検証する
- Repository テストは `FakeFirestore` / インメモリ SQLDelight ドライバを使う
- iOS / Android 固有実装のテストは各プラットフォームのテストソースセットで補完する

```kotlin
@Test
fun coffee_list_loads_on_appear() = runTest {
    val repo = FakeCoffeeRepository(initial = listOf(sampleRecord))
    val vm = CoffeeListViewModel(repo, this)
    try {
        vm.onAppear(userId = "user-1")
        runCurrent()

        assertEquals(listOf(sampleRecord), vm.state.value.coffees)
        assertFalse(vm.state.value.isLoading)
    } finally {
        vm.clear()   // 所有 viewModelScope を畳まないと UncompletedCoroutinesError（lessons 2026-06-25）
    }
}
```

---

## 外部依存

| 用途 | ライブラリ | 配置 |
|------|----------|------|
| 共通基盤 | Kotlin Multiplatform / kotlinx-coroutines / kotlinx-serialization / kotlinx-datetime | `shared/*` |
| ローカル DB | SQLDelight | `shared/data-local` |
| クラウド DB | Firebase Firestore（公式 SDK：iOS は SPM、Android は Firebase BoM） | iOS: `iosApp` / Android: `shared/data-firebase/androidMain` |
| 認証 | Firebase Auth（公式 SDK） | 同上 |
| カフェ検索 | Google Places API New v1（Ktor で REST 呼び出し） | `shared/data-places` |
| HTTP | Ktor Client（iOS = Darwin / Android = OkHttp エンジン） | `shared/data-places` |
| Swift interop | SKIE（suspend / Flow / sealed の Swift 露出改善） | `shared/framework` |
| オンデバイス LLM | Foundation Models（iOS 専用。分析タブの言語化のみ） | `iosApp` |
| iOS UI | SwiftUI（標準） | `iosApp` |
| Android UI | Compose Multiplatform（検証用 1 画面のみ） | `sharedUI` / `androidApp` |

採用ライブラリの最終版は `gradle/libs.versions.toml` を真とする。

---

## 参考リンク

- [Kotlin Multiplatform — JetBrains](https://www.jetbrains.com/help/kotlin-multiplatform-dev/get-started.html)
- [SQLDelight](https://sqldelight.github.io/sqldelight/)
- [Firebase for iOS（公式 / Swift Package Manager）](https://firebase.google.com/docs/ios/setup)
- [Firebase for Android（公式 / firebase-bom）](https://firebase.google.com/docs/android/setup)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [コーディング規約](./coding-conventions.md)
- [データモデル](./data-model.md)
- [KMP ブリッジ](./kmp-bridge.md)
