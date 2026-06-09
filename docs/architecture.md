# CoffeeVision アーキテクチャ

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

### 現状（Phase 2.5 完了時点）

2026-06-08 Phase 2.5 完了をもって、旧 `sharedLogic` 一枚モジュールを基盤レイヤーに分割しました。

```
coffeevision/
├── build-logic/
│   └── convention/                       # Convention Plugin（precompiled script plugin）
│       └── src/main/kotlin/
│           ├── kmp.library.gradle.kts
│           ├── kmp.feature.gradle.kts    # Phase 3 の feature 切り出し用、現状未使用
│           └── android.library.gradle.kts
│
├── shared/
│   ├── core/                             # AppContainer / VisitRepositoryImpl
│   ├── domain/                           # ドメインモデル + Repository インターフェース
│   ├── data-local/                       # SQLDelight スキーマ / Mapper / DriverFactory / LocalVisitRepository
│   ├── data-firebase/                    # Android Firebase 実装（Firestore / Auth）の置き場（PR2 で空殻作成、Android 実装の本格移送は着手時）
│   └── framework/                        # iOS 向け Umbrella。`SharedLogic.xcframework` を出力
│
├── sharedUI/                             # Compose Multiplatform（Android 検証用、未本格化）
├── iosApp/                               # SwiftUI エントリポイント + Swift Firebase 実装
└── androidApp/                           # Android エントリポイント（検証ターゲット）
```

- iOS 向けには `shared/framework` が `shared/{core,domain,data-local,data-firebase}` を `api` + `export(...)` で再公開し、`SharedLogic.framework`（XCFramework 名も `SharedLogic`）として配布
- 残課題: `shared/data-places`（Phase 4）と `shared/feature/*`（Phase 3 / Phase 3.5）はまだ未着手。`shared/data-firebase` も Android 実装は空殻状態

---

### 目標構成（KMP モジュール分割アーキテクチャの実証）

CoffeeVision は **iOS のみリリース** を想定していますが、KMP のモジュール分割アーキテクチャを実証することを設計目的の 1 つに位置づけています。
Android ターゲットは「リリース対象」ではなく **「共通レイヤーが両プラットフォームで成立することを示す検証ターゲット」** として維持します。

分割の主目的は以下の 3 点です。

1. **`feature` モジュール単位で並行開発・独立テストできる**
2. **`data` 層の実装差し替えが他レイヤーを壊さない**（特に Firebase の iOS = Swift / Android = Kotlin という非対称性を吸収する）
3. **アーキテクチャ判断がコードベースの構造そのものから読み取れる**（モジュール境界と責務の対応を明示的にする）

```
coffeevision/
├── build-logic/
│   └── convention/                       # KMP / Android 共通設定の Convention Plugin
│       └── src/main/kotlin/
│           ├── kmp.library.gradle.kts    # KMP ライブラリ共通（targets / compilerOptions）
│           ├── kmp.feature.gradle.kts    # feature 共通（domain + core 自動依存）
│           └── android.library.gradle.kts
│
├── shared/
│   ├── framework/                        # 【iOS 向け Umbrella】XCFramework のソース
│   │                                     # 全 feature / data / domain を export するだけの薄い層
│   │
│   ├── core/                             # Result, Logger, Dispatchers, DI 基盤, テストヘルパ
│   │
│   ├── domain/                           # Visit / Cafe / 各 enum / *Repository インターフェース / UseCase
│   │
│   ├── data-local/                       # SQLDelight スキーマ + DriverFactory (expect/actual)
│   ├── data-places/                      # Ktor + Google Places API クライアント
│   ├── data-firebase/                    # Firestore / Auth の Android 実装
│   │                                     # （iOS 実装は iosApp 側 Swift で書き、domain の I/F に準拠）
│   │
│   └── feature/
│       ├── visit-list/                   # VisitListViewModel + UIState
│       ├── visit-detail/                 # VisitDetailViewModel + UIState
│       ├── visit-editor/                 # VisitEditorViewModel + UIState
│       └── cafe-search/                  # CafeSearchViewModel + UIState
│
├── iosApp/
│   └── iosApp/
│       ├── App/                          # @main・AppContainer 構築・Firebase 初期化
│       ├── Features/                     # SwiftUI View + ViewModelBridge（feature ごと）
│       ├── FirebaseRepositories/         # domain の Repository インターフェースの iOS 実装（Swift）
│       └── Bridge/                       # Flow / suspend / sealed のヘルパ
│
└── androidApp/                           # 検証ターゲット（リリース対象外、最小実装で維持）
    └── src/main/kotlin/
        ├── App.kt                        # Application・AppContainer 構築・Firebase 初期化
        └── ui/                           # Compose Navigation + Visit 一覧 1 画面のみ
```

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
|  | `androidApp` | Compose Navigation + Visit 一覧 1 画面（**検証用最小実装**） | `feature/visit-list`, `data/*`, `domain`, `core` |

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
- **data-firebase の iOS 実装は `iosApp` 側 Swift**：domain の `VisitRepository` プロトコル準拠の Swift クラスを書く（[`kmp-bridge.md`](./kmp-bridge.md) 参照）

---

### iOS 配布戦略：Umbrella Framework

KMP は iOS 向けに **1 つの Framework として出力する** のが原則です（複数 framework 出力は `internal` 可視性が壊れ依存解決が破綻するため避ける）。
このため `shared/framework` モジュールを **「全 shared モジュールを `api` 依存で再エクスポートするだけ」** の薄い層として用意します。

```kotlin
// shared/framework/build.gradle.kts（抜粋・Phase 2.5 時点の実装）
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

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
            xcf.add(this)
        }
    }
    sourceSets.commonMain.dependencies {
        api(projects.shared.core)
        api(projects.shared.domain)
        api(projects.shared.dataLocal)
        api(projects.shared.dataFirebase)
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
// build-logic/convention/src/main/kotlin/kmp.library.gradle.kts
plugins {
    id("org.jetbrains.kotlin.multiplatform")
}
kotlin {
    androidTarget()
    iosX64(); iosArm64(); iosSimulatorArm64()
    jvmToolchain(17)
    compilerOptions { freeCompilerArgs.add("-Xexpect-actual-classes") }
}
```

```kotlin
// build-logic/convention/src/main/kotlin/kmp.feature.gradle.kts
plugins {
    id("kmp.library")
}
kotlin.sourceSets.commonMain.dependencies {
    api(projects.shared.domain)
    api(projects.shared.core)
    implementation(libs.kotlinx.coroutines.core)
}
```

各モジュールの `build.gradle.kts` は `plugins { id("kmp.feature") }` だけで済むようになります。

---

### 段階的移行ステップ

「機能が動く状態」を維持しながら分割を進めるため、**Phase 2 でまず Firestore を縦に動かしてから分割** する順序を採ります。
各ステップは **独立した PR** にし、機能追加と分割を同じ PR に混ぜません。

| 実施タイミング | 分割内容 | 状態 |
|--------------|---------|------|
| **Phase 2 完了直後（Phase 2.5）** | `build-logic/convention/` を整備し、`core` / `domain` / `data-local` / `data-firebase` を分離。`AppContainer` の依存配線を整理。`shared/framework` umbrella を作成し、旧 `sharedLogic` を削除 | **完了（2026-06-08）** |
| **Phase 3 開始時** | `feature/visit-list` を最初の feature module として切り出し | 未着手 |
| **Phase 3 進行中** | `feature/visit-detail` / `feature/visit-editor` を順次切り出し | 未着手 |
| **Phase 3 完了と並行** | `androidApp` で `feature/visit-list` を Compose の 1 画面として表示。Firestore 読み取りまで動くことを確認 | 未着手 |
| **Phase 4 開始時** | `data-places` を切り出し | 未着手 |
| **Phase 4 完了直後** | `feature/cafe-search` を切り出し | 未着手 |
| **継続** | CI で iOS / Android 両方のビルドを必須チェックにする | 設定済（Phase 2.5 で `:shared:data-local:testAndroidHostTest` + `:shared:framework:assembleSharedLogicXCFramework` に追随済） |

**注意点:**
- 分割直後に必ず `./gradlew :shared:framework:assembleSharedLogicXCFramework` と `./gradlew :androidApp:assembleDebug` が通ることを確認する
- パッケージ名 `com.noricoffee.*` は維持し、モジュール境界とパッケージ境界を一致させる（例: `feature/visit-list` は `com.noricoffee.feature.visitlist`）

---

### アーキテクチャ検証ルール（Android ターゲットの維持方針）

本プロジェクトは iOS のみリリースを想定していますが、KMP のモジュール分割アーキテクチャが両プラットフォームで成立することを実証するため、
Android ターゲットを **「常にビルドが通り、共通 ViewModel を最小 UI で動かせる状態」** で維持します。

- **CI**: PR 単位で iOS / Android 両方のビルドを実行。`./gradlew :shared:framework:assembleSharedLogicXCFramework` と `./gradlew :androidApp:assembleDebug` を必須チェックにする
- **Android UI スコープ**: `feature/visit-list` を Compose で表示する 1 画面のみ。編集・検索・写真撮影は実装しない
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
│                    │         │       Places       │
└────────────────────┘         └────────────────────┘
```

### 各レイヤーの役割

| レイヤー | 役割 | 配置 |
|---------|------|------|
| Presentation | 描画・入力。SwiftUI / Compose | `iosApp/` / `androidApp/` |
| ViewModel | UI 状態の保持と更新、ユーザーアクションのハンドリング | `shared/feature/*/viewmodel/`（Phase 3 で切り出し予定、現状は `shared/core` に集約） |
| UseCase | 複数 Repository をまたぐ手続き（薄ければ省略可） | `shared/domain/usecase/` |
| Repository | データソースの集約。UI に対しては単一のインターフェースを提供 | インターフェース: `shared/domain/repository/` / 合成実装: `shared/core/repository/` |
| Local | SQLDelight。検索・オフライン参照を高速化する用途 | `shared/data-local/` |
| Remote (Places) | Google Places API クライアント（Ktor） | `shared/data-places/`（Phase 4 で切り出し予定） |
| Remote (Firebase) | Firestore / Auth は **公式プラットフォーム別 SDK** を使う。Android 実装は `shared/data-firebase/androidMain`、iOS 実装は `iosApp` 側の Swift で書き、Repository インターフェースを `shared/domain` に置いて差し替える。写真本体はクラウドに同期せず端末ローカルのみに保存（Storage 採用見送り） | インターフェース: `shared/domain` / Android 実装: `shared/data-firebase/androidMain` / iOS 実装: `iosApp/FirebaseRepositories/` |

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

iOS では `@Observable` の薄い ViewModel ラッパが `shared/feature/*`（Phase 3 切り出し後）の Kotlin ViewModel を内包し、`StateFlow` を Swift の `@Published` 相当の値へブリッジします。

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

## データフロー（読み取り）

UI は `VisitRepository.observeAll(userId)` 等の **ローカル DB に対する Flow** を購読します。
リモート（Firestore）からの変更は `VisitRepositoryImpl` が `RemoteVisitDataSource.observeChanges` を購読し、受信した Visit をローカル DB に upsert することで反映します。

```
RemoteVisitDataSource.observeChanges()  ──┐
                                          ▼
                              VisitRepositoryImpl.startSync()
                                          │
                                          ▼
                              LocalVisitRepository.save()
                                          │
                                          ▼
                                   SQLDelight emit
                                          │
                                          ▼
                              VisitRepository.observeAll()  ◀── UI が購読
```

これにより「Firestore キャッシュとローカル DB の二重キャッシュ」を避け、**ローカル DB を唯一の Source of Truth** として扱います。

---

## データフロー（書き込み）

```
SwiftUI View
   │  onAddVisitTapped()
   ▼
ViewModel（shared/feature/*）
   │  visitRepository.save(visit)
   ▼
VisitRepository（shared/domain のインターフェース）
   │   実装はプラットフォーム別:
   │     - Android: VisitRepositoryAndroidImpl（shared/data-firebase/androidMain, firebase-firestore-ktx）
   │     - iOS:     VisitRepositoryIosImpl（iosApp 側 Swift, FirebaseFirestore SPM）
   │
   ├─ SQLDelight.insert(visit)          ← 即座にローカル DB に保存
   └─ Firestore.set(visit)              ← 並行して Firestore へ書き込み
                                          （各プラットフォームの公式 SDK のオフライン永続化が同期を引き受ける）
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
// shared/core/commonMain（実装スケッチ）
class AppContainer(
    sqlDriver: SqlDriver,
    // Firebase 実装はプラットフォーム別 SDK を使うため、外部から受け取る
    private val remoteVisitDataSource: RemoteVisitDataSource,
    val authRepository: AuthRepository,
    val scope: CoroutineScope = MainScope(),
) {
    private val db = AppDatabase(sqlDriver)

    private val localVisitRepository = LocalVisitRepository(db)

    // VisitRepositoryImpl が local + remote を合成して、UI には 1 本だけを見せる
    val visitRepository: VisitRepository =
        VisitRepositoryImpl(local = localVisitRepository, remote = remoteVisitDataSource)

    // 起動時の匿名サインイン → uid 確定 → リモート → ローカル同期購読 を 1 メソッドで起こす
    @Throws(Exception::class)
    suspend fun startInitialSync(): String { /* ... */ }

    // ViewModel ファクトリ（makeVisitListViewModel 等）は Phase 3 で追加
    // CafeRepository（Places）は Phase 4 で追加
}
```

- `SqlDriver` などプラットフォーム依存の値は `expect`/`actual` で取得します。詳細は [`kmp-bridge.md`](./kmp-bridge.md) を参照。
- Firebase を扱う Repository（`VisitRepository` / `AuthRepository` など）は **`commonMain` ではインターフェースのみ定義**し、実装は以下のように分けます。
    - **Android**: `shared/data-firebase/androidMain` に `firebase-firestore-ktx` 等を使った実装を置き、`AppContainer` 生成時に Activity / Application から渡す
    - **iOS**: `iosApp` 側の Swift コードで `FirebaseFirestore`（SPM 配信）を使った実装クラスを書き、Kotlin の `VisitRepository` インターフェースに準拠させて `AppContainer` 構築時に渡す

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
- **写真本体は Firestore / Storage に同期せず、端末ローカル（Documents）のみに保存する**。Firestore の `photos` サブコレクションには `fileName` / `width` / `height` などのメタデータのみを書く（Storage は採用見送り。バックアップは iCloud Backup に委ねる）
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
| 共通基盤 | Kotlin Multiplatform / kotlinx-coroutines / kotlinx-serialization | `shared/core` / `shared/domain` |
| ローカル DB | SQLDelight | `shared/data-local` |
| クラウド DB | Firebase Firestore（公式 SDK：iOS は SPM、Android は `firebase-firestore-ktx`） | iOS: `iosApp` / Android: `shared/data-firebase/androidMain` |
| 認証 | Firebase Auth（公式 SDK） | 同上 |
| カフェ検索 | Google Places API（Ktor で REST 呼び出し） | `shared/data-places`（Phase 4） |
| HTTP | Ktor Client | `shared/data-places`（Phase 4） |
| ロギング | Napier または kermit | `shared/core` |
| iOS UI | SwiftUI（標準） | `iosApp` |
| Android UI | Compose Multiplatform | `sharedUI` / `androidApp`（将来） |

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
