# CoffeeVision

訪れたカフェでのコーヒー・フード体験を記録・振り返るためのモバイルアプリ。
**Kotlin Multiplatform（KMP）+ ネイティブ UI** で構成され、ビジネスロジックを Kotlin で共通化しつつ、UI は各プラットフォームの作法を尊重したネイティブ実装を採用しています。

## プラットフォーム方針

| プラットフォーム | 位置づけ | UI 実装 |
|--------------|--------|--------|
| **iOS** | リリース対象 | SwiftUI + `@Observable` ViewModel ラッパ |
| **Android** | 共通レイヤーの検証ターゲット（リリース対象外） | Compose Multiplatform（Visit 一覧 1 画面のみ） |

Android ターゲットは、KMP の共通レイヤー（`feature` / `domain` / `data`）が両プラットフォームで成立することを実証するために維持しています。
**CI で iOS / Android 両方のビルドを必須チェック**にしており、共通レイヤーの完全性を継続的に担保します。

---

## アーキテクチャ概要

```
SwiftUI / Compose  ─ Native UI
        ↓
    feature/*       ─ ViewModel + UIState（KMP 共通）
        ↓
     domain         ─ Repository インターフェース・ドメインモデル（KMP 共通）
        ↓
  data-local / data-places / data-firebase
        ↓
      core          ─ Result / Logger / Dispatchers
```

詳細は [`docs/architecture.md`](./docs/architecture.md) を参照してください。

---

## 主要な技術選定と根拠

### 1. ViewModel を含めて KMP で共通化

ドメイン層だけでなく ViewModel + `UIState` まで `sharedLogic` に置き、両プラットフォームで同じ状態管理を共有します。
UI は各プラットフォームでネイティブ実装（iOS: SwiftUI、Android: Compose）し、薄いブリッジ層で `StateFlow` を購読する形にしています。

### 2. Firebase は公式プラットフォーム別 SDK を採用

GitLive 製 KMP Firebase SDK ではなく、**公式 SDK**（iOS: Swift Package Manager 経由、Android: `firebase-bom`）を採用しています。

- 公式 SDK の機能追従が早く、長期保守の安定性が高い
- Firestore のオフライン永続化 / Security Rules の挙動が公式ドキュメントと一致する
- 代償として、Firebase Repository の **iOS 実装は `iosApp` 側 Swift / Android 実装は `sharedLogic/androidMain` Kotlin** という非対称構成になる
- この非対称性を `domain/` の Repository インターフェースで吸収する

### 3. Umbrella Framework + XCFramework 配布

KMP は iOS 向けに 1 つの Framework として出力するのが原則のため、`shared/framework` モジュールを「全 shared モジュールを `api` で再エクスポートするだけ」の薄い層として用意し、XCFramework として配布します。
これにより `iosApp` から個別の shared モジュールを直接参照する必要がなく、依存関係が単純化されます。

### 4. Convention Plugin によるビルド設定の集約

モジュール数が増えた際の `build.gradle.kts` のコピペを避けるため、`build-logic/convention/` に Gradle Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）を配置します。
各モジュールは `plugins { id("kmp.feature") }` だけで共通設定を継承します。

### 5. SQLDelight ローカル DB + Firestore 同期

UI は常にローカル DB（SQLDelight）を参照し、Firestore の同期は公式 SDK のオフライン永続化に委ねます。
独自の同期キューは実装せず、書き込みは「ローカル → クラウド」の順で開始します。

---

## モジュール構成

```
coffeevision/
├── build-logic/convention/        # KMP / Android 共通設定の Convention Plugin
├── shared/
│   ├── framework/                 # iOS 向け Umbrella（XCFramework 出力元）
│   ├── core/                      # Result / Logger / Dispatchers / DI 基盤
│   ├── domain/                    # ドメインモデル + Repository インターフェース
│   ├── data-local/                # SQLDelight
│   ├── data-places/               # Google Places API クライアント（Ktor）
│   ├── data-firebase/             # Firestore / Auth / Storage（Android 実装）
│   └── feature/
│       ├── visit-list/            # VisitListViewModel + UIState
│       ├── visit-detail/
│       ├── visit-editor/
│       └── cafe-search/
├── iosApp/                        # SwiftUI + Firebase Swift 実装
└── androidApp/                    # Compose（検証用最小 UI）
```

> 現在は Phase 1 の途中で、上記の分割は段階的に進行中です。
> 現状の状態と移行計画は [`docs/architecture.md` §段階的移行ステップ](./docs/architecture.md#段階的移行ステップ) を参照してください。

---

## ビルド / 実行

### iOS

```bash
./gradlew :shared:framework:assembleSharedFrameworkXCFramework
open iosApp/iosApp.xcodeproj
```

Xcode でターゲット `iosApp` を選択し、シミュレータまたは実機で実行します。
事前に `iosApp/iosApp/GoogleService-Info.plist` を配置してください（リポジトリには含めない）。

### Android（検証ターゲット）

```bash
./gradlew :androidApp:assembleDebug
./gradlew :androidApp:installDebug
```

事前に `androidApp/google-services.json` を配置してください。

---

## テスト

```bash
# 共通ロジック（JVM 実行）
./gradlew :shared:domain:testAndroidHostTest
./gradlew :shared:data-local:testAndroidHostTest

# iOS シミュレータでの実行
./gradlew :shared:framework:iosSimulatorArm64Test
```

---

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [`docs/architecture.md`](./docs/architecture.md) | アーキテクチャ全体と段階的移行計画 |
| [`docs/coding-conventions.md`](./docs/coding-conventions.md) | Kotlin / Swift コーディング規約 |
| [`docs/ui-ux-guidelines.md`](./docs/ui-ux-guidelines.md) | iOS UI/UX ガイドライン（HIG ベース） |
| [`docs/data-model.md`](./docs/data-model.md) | Visit / CoffeeItem / FoodItem のドメインモデル |
| [`docs/kmp-bridge.md`](./docs/kmp-bridge.md) | Swift ⇄ Kotlin ブリッジ規約 |
| [`docs/requirements.md`](./docs/requirements.md) | 機能要件・非機能要件 |
| [`docs/tasks.md`](./docs/tasks.md) | フェーズ別タスク管理 |

---

## ライセンス

（未定 — リリース前に追加）
