# CoffeeVision タスク一覧

このファイルは実装タスクのフェーズ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。

---

## 凡例

| 記号 | 意味 |
|------|------|
| `[ ]` | 未着手 |
| `[~]` | 進行中 |
| `[x]` | 完了 |
| `[-]` | 取り下げ |

---

## フェーズ 0: プロジェクト準備

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | KMP プロジェクトの初期化（`sharedLogic` / `sharedUI` / `iosApp` / `androidApp`） | 既存のスケルトン |
| [x] | ドキュメント整備（CLAUDE.md / docs 一式） | 2026-06-02 |
| [x] | `gradle/libs.versions.toml` に必要ライブラリを追加（SQLDelight / Firebase / Ktor / kotlinx-datetime / kotlinx-serialization） | 2026-06-02 / Firebase は公式（プラットフォーム別）を採用 |
| [~] | CI 整備: PR ごとに iOS / Android 両方のビルドを必須チェック化 | 2026-06-03 / `.github/workflows/ci.yml` 追加（Android: `:sharedLogic:testAndroidHostTest` + `:androidApp:assembleDebug` / iOS: `:sharedLogic:linkReleaseFrameworkIos{Arm64,SimulatorArm64}`）。ローカル両ジョブ成功確認済。初回 PR で workflow グリーン確認後 [x]。`:shared:framework:assembleSharedFrameworkXCFramework` への差し替えはフェーズ 3.5 で実施。詳細は [`implementation_note.md`](./implementation_note.md) 参照 |
| [x] | SKIE の採用判断（採用するなら `sharedLogic` の Gradle に追加） | 2026-06-04 / 採用 / SKIE 0.10.12（Kotlin 2.3.21 互換）を `sharedLogic` に組み込み。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-04 エントリ参照 |
| [ ] | `local.properties` での API キー管理を整える（Places / Firebase） | リポジトリにコミットしない / Phase 4（Places）着手時に整備 |
| [x] | `.gitignore` に `GoogleService-Info.plist` / `google-services.json` を追加するか、Decrypt 運用にするかを決定 | 2026-06-04 / `.gitignore` に追加してコミットしない方針で決定。CI 復元手段はリリース準備時に検討 |

---

## フェーズ 1: ドメインモデルとローカル DB

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `domain/` 配下に Visit / Cafe / CoffeeItem / FoodItem / Photo を実装 | 2026-06-02 / [`data-model.md`](./data-model.md) §1 |
| [x] | BrewMethod / ProcessingMethod / RoastLevel の enum を実装 | 2026-06-02 |
| [x] | SQLDelight プラグインを `sharedLogic/build.gradle.kts` に追加 | 2026-06-02 / `databases.create("AppDatabase")` を `com.noricoffee.db` で宣言 |
| [x] | `commonMain/sqldelight/com/noricoffee/db/` にスキーマファイル（4 つ）を作成 | 2026-06-02 / [`data-model.md`](./data-model.md) §2 通り |
| [x] | `DatabaseDriverFactory`（`expect`/`actual`）を実装 | 2026-06-02 / iOS は `NativeSqliteDriver` |
| [x] | ドメインモデル ⇔ DB 行のマッパを実装 | 2026-06-02 / `db/Mapper.kt` |
| [x] | `VisitRepository` の `commonTest` を書く（インメモリドライバ） | 2026-06-02 / `LocalVisitRepositoryTest` 5 件グリーン |

---

## フェーズ 2: 認証と Firestore 接続

> 2026-06-04 着手。iOS 先行 → Android 検証の順で進める。Firebase SDK は **公式（iOS は SPM、Android は Firebase BoM）**。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | Firebase プロジェクト作成・`GoogleService-Info.plist` / `google-services.json` 配置 | 2026-06-04 / iOS は `iosApp/iosApp/GoogleService-Info.plist`、Android は `androidApp/google-services.json`。匿名 Auth 有効化と Firestore（asia-northeast1, 本番モード）作成も完了。両ファイルは `.gitignore` 済 |
| [x] | KMP 共通層に `AuthRepository` インターフェースを追加 | 2026-06-04 / `sharedLogic/commonMain` に追加。`signInAnonymouslyIfNeeded()` + `observeUserId()`、`@Throws(Exception::class)` 付与 |
| [x] | `VisitRepository` の local + remote 合成方針を確定 | 2026-06-04 / `RemoteVisitDataSource` interface + `VisitRepositoryImpl`（`commonMain`）で合成する案を採用。判断記録は [`implementation_note.md`](./implementation_note.md) 2026-06-04 エントリ |
| [x] | iOS アプリで Firebase SDK を SPM で追加 | 2026-06-04 / `firebase-ios-sdk` 12.14.0 を `iosApp.xcodeproj` に追加（FirebaseAuth / FirebaseFirestore / FirebaseStorage の 3 products） |
| [x] | iOS アプリで Firebase 初期化 | 2026-06-04 / `iOSApp.swift` で `FirebaseApp.configure()` + `PersistentCacheSettings` を明示有効化 |
| [x] | 匿名サインインの実装（起動時自動） | 2026-06-04 / `AuthRepositoryIosImpl`（completion handler 形式で `AuthRepository` interface に準拠）。iPhone 17 / iOS 26.1 シミュレータで uid 取得まで確認済 |
| [x] | Firestore のオフライン永続化を有効化 | 2026-06-04 / 起動時に `[CoffeeVision] Firestore persistent cache enabled` ログ確認済 |
| [~] | `VisitRepository` の Firestore 書き込みを実装（ローカル → クラウドの順） | 2026-06-04 / `RemoteVisitDataSourceIosImpl` で Visit 本体 + Cafe 埋め込み分のみ実装。子コレクションは別行に分離。`IosMainScope` の dispatcher 欠如により `startSync()` のリモート購読がリアルタイムには動かない見込み（[`implementation_note.md`](./implementation_note.md) 2026-06-04 IosMainScope エントリ参照） |
| [ ] | `IosMainScope` の dispatcher hack を解消（`commonMain` に `CoroutineScope` ファクトリ追加） | `AppContainer(scope: CoroutineScope)` のデフォルト `MainScope()` を Swift から呼べない問題への正規対応。`kmp-engineer` に dispatch 予定 |
| [ ] | iOS 側で Visit 子コレクション（`coffeeItems` / `foodItems` / `photos`）の Firestore 同期実装 | 親ドキュメント書き込み後、サブコレクションの upload / observe を追加。`RemoteVisitDataSourceIosImpl` の TODO 解消 |
| [ ] | Firestore Security Rules を作成・デプロイ | `request.auth.uid == resource.data.userId` を強制。[`data-model.md`](./data-model.md) §3.3 のルールを Firebase Console に設定 |
| [ ] | シミュレータ動作確認: 匿名サインイン後の Firestore 書き込み実体確認 | Security Rules 設定後、Phase2VerificationView の書き込みボタンで Firebase Console にデータが届くことを目視 |

---

## フェーズ 2.5: モジュール分割 (1) — 基盤レイヤー

> [`architecture.md` §段階的移行ステップ](./architecture.md#段階的移行ステップ) に従い、Phase 2 が動く状態で完了したあとに独立 PR で実施する。機能追加と分割を同じ PR に混ぜない。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `build-logic/convention/` プロジェクトを追加し、`kmp.library` / `kmp.feature` / `android.library` Convention Plugin を作成 | `libs.versions.toml` を convention 側から参照できるように |
| [ ] | `core` モジュール切り出し（Result / Logger / Dispatchers / DI 基盤 / テストヘルパ） | sharedLogic からの移動 |
| [ ] | `domain` モジュール切り出し（ドメインモデル + Repository インターフェース + UseCase） | sharedLogic からの移動 |
| [ ] | `data-local` モジュール切り出し（SQLDelight スキーマ + DriverFactory） | sharedLogic からの移動 |
| [ ] | `data-firebase` モジュール切り出し（Firestore / Auth / Storage Android 実装） | androidMain のみソースを持つ |
| [ ] | `AppContainer` の依存配線を新モジュール構成に合わせて整理 | iOS / Android 両方 |
| [ ] | 旧 `sharedLogic` モジュールを削除（`settings.gradle.kts` から除外） | 分割完了後 |
| [ ] | 分割後ビルド確認: `./gradlew :shared:framework:assembleSharedFrameworkXCFramework` + `./gradlew :androidApp:assembleDebug` | CI が通ること。あわせて `.github/workflows/ci.yml` の iOS link コマンドを `:shared:framework:assembleSharedFrameworkXCFramework` に差し替える |

---

## フェーズ 3: iOS UI（MVP）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `AppContainer`（Kotlin）を実装し、iOS の `iOSApp.swift` から起動 | 2026-06-04 / Phase 2 で先行実施（Swift で `AppContainer` を組み立て + `startInitialSync()` 呼び出しまで）。ViewModel ファクトリの追加は Phase 3 の各 ViewModel タスクと一緒に実施 |
| [ ] | `VisitListViewModel`（Kotlin）と `VisitListViewModelBridge`（Swift）を実装 | |
| [ ] | ホーム画面（VisitListView）を実装 | |
| [ ] | Visit 詳細画面（VisitDetailView）を実装 | |
| [ ] | Visit 作成 / 編集画面（VisitEditorView）を実装 | |
| [ ] | CoffeeItem の追加 / 編集 UI（モーダル） | |
| [ ] | FoodItem の追加 / 編集 UI（モーダル） | |
| [ ] | 星評価入力コンポーネント（StarRatingView）を実装 | |
| [ ] | 写真ピッカー（PhotosPicker）を組み込み | |
| [ ] | ローカル保存後、Storage に非同期アップロードする処理 | |
| [ ] | 各画面のプレビューを実装 | |

---

## フェーズ 3.5: モジュール分割 (2) — feature レイヤー & Android 検証

> Phase 3 の iOS UI 実装と並走する。各 feature の SwiftUI 実装が一段落したタイミングで該当 feature モジュールを切り出す。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `shared/framework` モジュール作成（iOS 向け Umbrella）+ XCFramework ビルド確認 | Phase 3 開始時 / `./gradlew :shared:framework:assembleSharedFrameworkXCFramework` |
| [ ] | `feature/visit-list` モジュール切り出し（最初の feature module） | Phase 3 開始時 |
| [ ] | `feature/visit-detail` モジュール切り出し | Phase 3 進行中 |
| [ ] | `feature/visit-editor` モジュール切り出し | Phase 3 進行中 |
| [ ] | `androidApp` で `feature/visit-list` を Compose の 1 画面として表示 | Phase 3 完了と並行（検証ターゲット） |
| [ ] | Android 側で `data-firebase` の `observe` 経由 Firestore 読み取りが動くことを確認 | 検証ターゲット |

---

## フェーズ 4: Places API（カフェ検索）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | **モジュール分割**: `data-places` モジュール切り出し（Phase 4 開始時） | Ktor + Places クライアントをここに集約 |
| [ ] | Ktor Client + Kotlinx Serialization のセットアップ | `data-places` モジュール内 |
| [ ] | `PlacesClient`（Text Search / Nearby Search / Place Details） | `data-places` モジュール内 |
| [ ] | `CafeRepository` 経由で ViewModel から呼び出せるようにする | I/F は `domain` モジュールに |
| [ ] | カフェ検索画面（CafeSearchView） | テキスト検索 |
| [ ] | 現在地検索（CoreLocation 連携。位置情報の利用許可ダイアログ対応） | |
| [ ] | Places API 規約に従い、写真は都度取得する実装にする | キャッシュしない |
| [ ] | **モジュール分割**: `feature/cafe-search` モジュール切り出し（Phase 4 完了直後） | |

---

## フェーズ 5: 仕上げ

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 設定画面（テーマ切り替え / バージョン表示 / サインアウト） | |
| [ ] | アカウントアップグレード（匿名 → メール / SNS）の UI | |
| [ ] | アカウント削除フロー | |
| [ ] | エラーバナー / トースト共通コンポーネント | |
| [ ] | アクセシビリティ通し検証（VoiceOver / Dynamic Type / Reduce Motion） | |
| [ ] | App Icon / Launch Screen / アプリ表示名の整備 | |
| [ ] | App Store Connect 用メタデータ準備 | |

---

## フェーズ 6（任意 / 後続）

| 状態 | タスク | 備考 |
|------|------|------|
| [-] | Android アプリ実装着手（`sharedUI` の Compose Multiplatform 利用） | Phase 3.5 で `feature/visit-list` を Compose 表示する検証実装に置き換えたため取り下げ（Android はリリース対象外） |
| [ ] | 検索（キーワード）の高速化（SQLDelight FTS） | |
| [ ] | エクスポート（JSON）機能 | |
| [ ] | 同一カフェの集計表示 | |
| [ ] | Widget / ホーム画面ショートカット | |

---

## レビューセクション（PR / 振り返り用テンプレート）

新しい PR をマージしたら、以下をコピーして追記してください。

```
### YYYY-MM-DD - <タイトル>
- 変更点:
- 動作確認:
- 残課題 / フォローアップ:
```

### 2026-06-02 - Phase 1 完了（ドメインモデル + ローカル DB + VisitRepository）
- 変更点:
  - `sharedLogic/src/commonMain/kotlin/com/noricoffee/domain/`: Visit / Cafe / CoffeeItem / FoodItem / Photo / BrewMethod / ProcessingMethod / RoastLevel を追加
  - `sharedLogic/src/commonMain/sqldelight/com/noricoffee/db/`: Visit.sq / CoffeeItem.sq / FoodItem.sq / Photo.sq を追加（INDEX + `selectAll` / `selectById` / `selectByCafe` / `upsert` / `deleteByVisit` / `deleteById`）
  - `platform/DatabaseDriverFactory`: `expect class` を `commonMain` に置き、`iosMain` は `NativeSqliteDriver`、`androidMain` は `AndroidSqliteDriver(context)` で actual
  - `db/Mapper.kt`: SQLDelight 生成行 ⇔ ドメインモデルの相互変換（`photoReferences` は kotlinx.serialization の JSON 文字列、enum は `name` 文字列、`Instant` は epoch millis、`LocalDate` は ISO-8601）
  - `repository/VisitRepository.kt` インターフェースと `LocalVisitRepository`（SQLDelight のみの単体実装）を追加。Phase 2 で Firestore を合成する想定
  - `commonTest` 用に `expect fun createInMemoryTestSqlDriver()` を導入し、`androidHostTest` 側は `JdbcSqliteDriver(IN_MEMORY)`、`iosTest` 側は `NativeSqliteDriver(... inMemory = true)` を actual で提供
  - `LocalVisitRepositoryTest`: 保存・観測・カフェ別フィルタ・更新（子の差し替え）・削除（カスケード）を検証
  - `sharedLogic/build.gradle.kts`: `sqldelight-driver-sqlite` を `commonTest` から `androidHostTest` に移動、`-Xexpect-actual-classes` を free compiler args に追加（Beta 警告抑止）
- 動作確認:
  - `./gradlew :sharedLogic:compileCommonMainKotlinMetadata` 成功
  - `./gradlew :sharedLogic:compileKotlinIosSimulatorArm64 :sharedLogic:compileAndroidMain` 成功
  - `./gradlew :sharedLogic:compileTestKotlinIosSimulatorArm64` 成功（iOS テストのコンパイルのみ）
  - `./gradlew :sharedLogic:testAndroidHostTest` 5 件成功 / 0 失敗（`LocalVisitRepositoryTest`）
- 残課題 / フォローアップ:
  - SQLDelight の生成クラス名が `coffee_item` 表 → `Coffee_item`（snake_case 残り）になる仕様のため、Mapper でアンダースコア付きフィールド名を直接参照している。気になるなら将来 `groupSpec` 等で名前変換を入れる検討
  - 子テーブル（coffee_item / food_item / photo）への単独書き込みは `observeAll` を発火させない（visit 行が変わったときだけ emit）。MVP では書き込みが常に `save(visit)` 経由で visit 行も更新するため問題ないが、Phase 3 以降で個別書き込みを増やす場合は `combine` などを検討
  - iOS の `iosTest` は実機 / シミュレータ起動が要るためコンパイルのみ確認。`./gradlew :sharedLogic:iosSimulatorArm64Test` の実行は Phase 2 以降に合わせて回す
  - VisitRepository のリモート（Firestore）実装は Phase 2 でプラットフォーム別に追加（`LocalVisitRepository` を内部に持つ Decorator か、`androidMain` / iOS Swift で並列実装）

### 2026-06-02 - ライブラリ追加（Phase 0 / Phase 1 一部）
- 変更点:
  - `gradle/libs.versions.toml`: kotlinx-coroutines 1.10.2 / kotlinx-serialization 1.8.0 / kotlinx-datetime 0.6.2 / SQLDelight 2.1.0 / Ktor 3.0.3 / Firebase BoM 33.7.0 / google-services 4.4.2 を追加
  - `sharedLogic/build.gradle.kts`: `kotlinSerialization` / `sqldelight` プラグインを適用、commonMain / iosMain（darwin・native-driver）/ androidMain（okhttp・Firebase BoM + Firestore / Auth / Storage）/ commonTest（coroutines-test・sqlite-driver）の依存を追加、`sqldelight { databases { create("AppDatabase") { packageName = "com.noricoffee.db" } } }` を宣言
- 動作確認:
  - `./gradlew :sharedLogic:compileCommonMainKotlinMetadata` 成功（SQLDelight は `.sq` 未配置のため `NO-SOURCE`）
  - `./gradlew :sharedLogic:compileKotlinIosSimulatorArm64 :sharedLogic:compileAndroidMain` 成功
- 残課題 / フォローアップ:
  - ~~Firebase を **公式プラットフォーム別 SDK** に変更したため、`docs/architecture.md` の "Firebase Firestore KMP SDK" 表記と `docs/kmp-bridge.md` の GitLive 前提箇所を見直すこと~~ → 2026-06-02 反映済み（Repository インターフェース + プラットフォーム別実装の方針を `kmp-bridge.md` に追記）
  - iOS 側の Firebase 初期化は Xcode（SPM / CocoaPods）で別途設定が必要（Phase 2）
  - `androidApp/build.gradle.kts` に `com.google.gms.google-services` プラグインを適用するのは Phase 2（`google-services.json` 配置時）に行う
  - ~~SKIE の採用判断は未着手~~ → 2026-06-04 採用済み（0.10.12）
