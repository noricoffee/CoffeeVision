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
| [~] | CI 整備: PR ごとに iOS / Android 両方のビルドを必須チェック化 | 2026-06-03 初回追加。Phase 2.5 PR3（2026-06-08）で `:shared:data-local:testAndroidHostTest` + `:androidApp:assembleDebug`（Android ジョブ）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）に差し替え済。ローカル両ジョブ成功確認済。初回 PR で workflow グリーン確認後 [x]。詳細は [`implementation_note.md`](./implementation_note.md) 参照 |
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
| [x] | iOS アプリで Firebase SDK を SPM で追加 | 2026-06-04 / `firebase-ios-sdk` 12.14.0 を `iosApp.xcodeproj` に追加（FirebaseAuth / FirebaseFirestore / FirebaseStorage の 3 products）。FirebaseStorage は 2026-06-10 の方針変更で不要化（SPM からの削除は整理目的の任意タスク、コード未使用のため残置でも実害なし） |
| [x] | iOS アプリで Firebase 初期化 | 2026-06-04 / `iOSApp.swift` で `FirebaseApp.configure()` + `PersistentCacheSettings` を明示有効化 |
| [x] | 匿名サインインの実装（起動時自動） | 2026-06-04 / `AuthRepositoryIosImpl`（completion handler 形式で `AuthRepository` interface に準拠）。iPhone 17 / iOS 26.1 シミュレータで uid 取得まで確認済 |
| [x] | Firestore のオフライン永続化を有効化 | 2026-06-04 / 起動時に `[CoffeeVision] Firestore persistent cache enabled` ログ確認済 |
| [x] | `VisitRepository` の Firestore 書き込みを実装（ローカル → クラウドの順） | 2026-06-04 / 2026-06-05 完成 / `RemoteVisitDataSourceIosImpl` で Visit 本体 + Cafe 埋め込み + 子コレクション 3 種（`coffeeItems` / `foodItems` / `photos`）まで実装。WriteBatch で原子化、observe は親リスナ + 子は都度 `getDocuments`。`IosMainScope` hack は別 commit で解消済 |
| [x] | `IosMainScope` の dispatcher hack を解消（`commonMain` に `CoroutineScope` ファクトリ追加） | 2026-06-05 / `AppContainer` に scope なしのセカンダリコンストラクタを追加、プライマリのデフォルト値は削除。Swift 側は 3 引数版に切り替え、`IosMainScope.swift` を削除。`startSync()` が `Dispatchers.Main` 上で動く正規状態に復帰 |
| [x] | iOS 側で Visit 子コレクション（`coffeeItems` / `foodItems` / `photos`）の Firestore 同期実装 | 2026-06-05 / WriteBatch で「親 set + 新子 set + 差分削除」を 1 commit 原子化。observe は案 A（親リスナ + 子は都度 `getDocuments` 並列）。`sortOrder` は配列 index を upload 時採番、decode 時はソート用途で破棄。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-05 子コレクション同期エントリ |
| [x] | Firestore Security Rules を作成・デプロイ | 2026-06-06 / Firestore のみ。`firestore.rules` / `firebase.json` / `.firebaserc` をリポジトリ管理化し `firebase deploy --only firestore:rules` で反映。厳格度は path uid のみ検証（[`data-model.md`](./data-model.md) §3.3 概略案そのまま）。`storage.rules` はファイル作成済だが **2026-06-10 に Storage 採用見送り決定**（写真は端末ローカル保存方針）。`storage.rules` はリポジトリに残置するが今後デプロイ予定なし |
| [x] | シミュレータ動作確認: 匿名サインイン後の Firestore 書き込み実体確認 | 2026-06-07 / Phase2VerificationView の書き込みボタンから Firebase Console に Visit + 子コレクション（`coffeeItems` / `foodItems` / `photos`）が届くことを目視確認 |

---

## フェーズ 2.5: モジュール分割 (1) — 基盤レイヤー

> [`architecture.md` §段階的移行ステップ](./architecture.md#段階的移行ステップ) に従い、Phase 2 が動く状態で完了したあとに独立 PR で実施する。機能追加と分割を同じ PR に混ぜない。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `build-logic/convention/` プロジェクトを追加し、`kmp.library` / `kmp.feature` / `android.library` Convention Plugin を作成 | 2026-06-08 / Phase 2.5 PR1 で追加。precompiled script plugin 方式（`gradlePlugin { plugins.register(...) }` は不使用、`kotlin-dsl` の自動 plugin id 生成に委譲）。`build-logic/settings.gradle.kts` で `versionCatalogs.from(files("../gradle/libs.versions.toml"))` を宣言 |
| [x] | `core` モジュール切り出し（Result / Logger / Dispatchers / DI 基盤 / テストヘルパ） | 2026-06-08 / PR1 で枠作成、PR2 で AppContainer / VisitRepositoryImpl を移送し `CoreMarker` を削除。Result / Logger / Dispatcher ラッパは未着手（必要が出てきたフェーズで追加） |
| [x] | `domain` モジュール切り出し（ドメインモデル + Repository インターフェース + UseCase） | 2026-06-08 / Phase 2.5 PR1 で完了。Visit / Cafe / CoffeeItem / FoodItem / Photo / 3 enum + AuthRepository / VisitRepository / RemoteVisitDataSource を `git mv` で移送。`sharedLogic` 側は `api(projects.shared.domain)` で再公開 |
| [x] | `data-local` モジュール切り出し（SQLDelight スキーマ + DriverFactory） | 2026-06-08 / Phase 2.5 PR2 で完了。SQLDelight プラグイン / `AppDatabase` 宣言 / Mapper / DriverFactory expect/actual / LocalVisitRepository を `git mv` で移送。`VisitRepositoryImplTest` は `createInMemoryTestSqlDriver` の expect/actual が data-local に閉じている制約から例外的に data-local の commonTest に配置 |
| [x] | `data-firebase` モジュール切り出し（Firestore / Auth Android 実装） | 2026-06-08 / Phase 2.5 PR2 で空殻作成。2026-06-11 Phase 3.5 検証スライスで Android Firebase 実装（`AuthRepositoryAndroidImpl` / `RemoteVisitDataSourceAndroidImpl` / `VisitFirestoreMapper`）を `androidMain` に移送完了。Storage は 2026-06-10 に採用見送り決定（残置） |
| [x] | `AppContainer` の依存配線を新モジュール構成に合わせて整理 | 2026-06-08 / Phase 2.5 PR2 で `shared/core` に移送。`api(projects.shared.dataLocal)` 経由で `AppDatabase` / `LocalVisitRepository` を取り込む構成。Swift 側 `import SharedLogic` は無変更（旧 `sharedLogic` が Reexport 層として export） |
| [x] | 旧 `sharedLogic` モジュールを削除（`settings.gradle.kts` から除外） | 2026-06-08 / Phase 2.5 PR3 dispatch C で完了。`Greeting` / `Platform` 残骸も同時に削除、`sharedUI/build.gradle.kts` を `api(projects.shared.framework)` に切り替え |
| [x] | 分割後ビルド確認: `./gradlew :shared:framework:assembleSharedLogicXCFramework` + `./gradlew :androidApp:assembleDebug` | 2026-06-08 / Phase 2.5 PR3 dispatch C で完了。XCFramework 名は `SharedLogic` に統一（baseName と揃えて mismatch warning 解消）。`.github/workflows/ci.yml` も `:shared:data-local:testAndroidHostTest` + `:shared:framework:assembleSharedLogicXCFramework` に差し替え済 |

---

## フェーズ 3: iOS UI（MVP）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `AppContainer`（Kotlin）を実装し、iOS の `iOSApp.swift` から起動 | 2026-06-04 / Phase 2 で先行実施（Swift で `AppContainer` を組み立て + `startInitialSync()` 呼び出しまで）。Phase 3（2026-06-09）で `AppContainer.makeVisitListViewModel()` 拡張関数を `shared/framework` に追加（core / feature 循環依存回避のため。詳細は [`implementation_note.md`](./implementation_note.md) 参照） |
| [x] | `VisitListViewModel`（Kotlin）と `VisitListViewModelBridge`（Swift）を実装 | 2026-06-09 / Kotlin 側は `shared/feature/visit-list` モジュール（Phase 3.5 同時切り出し）に `VisitListViewModel(visitRepository, scope)` + `UIState(visits, isLoading, error)` + `onAppear(userId) / onVisitDeleted(id) / onErrorDismissed()` を実装。Swift 側は `iosApp/iosApp/Features/VisitList/VisitListViewModelBridge.swift` に `@MainActor @Observable` ブリッジを実装。`for await state in kotlin.state` で `SkieSwiftStateFlow` を購読 |
| [x] | ホーム画面（VisitListView）を実装 | 2026-06-09 / `iosApp/iosApp/Features/VisitList/VisitListView.swift`。`NavigationStack` + 空状態 `ContentUnavailableView` + swipe-to-delete 付き `List` + 行タップで `VisitDetailView` 遷移 + ツールバー `+` で VisitEditor 起動。`Phase2VerificationView` は削除済。2026-06-11 シミュレータ目視確認済 |
| [x] | Visit 詳細画面（VisitDetailView）を実装 | 2026-06-09 / `iosApp/iosApp/Features/VisitDetail/VisitDetailView.swift`（read-only `Form`：ヘッダ / 雰囲気 / メモ / コーヒー / フード / 写真）。`shared/feature/visit-detail` 同時切り出し、`VisitDetailViewModel` は `observeById` を購読。Bridge は `VisitDetailView` 内 `@State` で遷移ごとに生成（VisitList の `AppState` ホルダパターンと意図的に分ける）。2026-06-11 シミュレータ目視確認済（写真は 2026-06-10 写真ピッカー実装で実画像表示に差し替え済）。enum 表示（`BrewMethod` 等）は `.name` 英語小文字のまま → 日本語化は別タスク |
| [x] | Visit 作成 / 編集画面（VisitEditorView）を実装 | 2026-06-09 / `shared/feature/visit-editor` 同時切り出し。`VisitEditorViewModel(mode: Create/Edit(visitId), userId)` + `VisitDraft` を Visit と分離 + `observeById(visitId).first()` で Edit モード初期化。iOS は `VisitEditorView` を sheet で起動（VisitList の `+` / VisitDetail の 鉛筆）。カフェは Phase 4 まで手入力簡易フォーム（placeId は UUID 採番）。`xcodebuild -sdk iphonesimulator` 成功。2026-06-10 シミュレータ目視確認済 |
| [x] | CoffeeItem の追加 / 編集 UI（モーダル） | 2026-06-09 / VisitEditor 縦スライスと同梱。`CoffeeItemEditorView` を `.sheet(item: CoffeeEditingTarget?)` で起動、`initial: CoffeeItem? + onSave` クロージャ API。Picker は SKIE EnumInterop 経由の `BrewMethod.allCases` 等で列挙、enum 日本語化は別タスク。2026-06-10 シミュレータ目視確認済 |
| [x] | FoodItem の追加 / 編集 UI（モーダル） | 2026-06-09 / VisitEditor 縦スライスと同梱。`FoodItemEditorView`（name / rating / notes のみの簡易版）。2026-06-10 シミュレータ目視確認済 |
| [x] | 星評価入力コンポーネント（StarRatingView）を実装 | 2026-06-09 / `iosApp/iosApp/Components/StarRatingView.swift`。`onChange` の有無で read-only / 編集モードを切替。編集モードは 44pt タップ領域 + `accessibilityAdjustableAction` で VoiceOver Stepper 相当 + `.sensoryFeedback(.selection, trigger: rating)`。VisitListView / VisitDetailView の既存星表示を全置換 |
| [x] | 写真ピッカー（PhotosPicker）を組み込み + Documents 配下にファイル保存 | 2026-06-10 実装 / `iosApp/iosApp/Utilities/PhotoFileStore.swift` 新規 + `VisitEditorView` photosSection + `Documents/photos/` フラットディレクトリ配置（visitId 別分離なし）。2026-06-11 シミュレータ目視確認済（PhotosPicker 起動 / 選択 / サムネ表示 / 保存 / キャンセル時 orphan ゼロ / 既存 visit の写真編集 round-trip） |
| [x] | Photo メタデータ（fileName / width / height）を SQLDelight + Firestore に永続化 | 2026-06-10 実装 / `Photo.fileName: String?` 追加（KMP commit `7b306f9` で domain + Photo.sq + migrations/1.sqm + Mapper + VisitDraft.photos）、iOS 側 `VisitFirestoreMapper` に fileName 追加。`Photo.remoteUrl` は常に null（Storage 採用見送りのため将来用フィールド）。2026-06-11 シミュレータ + Firebase Console でメタデータ反映目視確認済 |
| [x] | 各画面のプレビューを実装 | 2026-06-11 / `iosApp/iosApp/PreviewSupport/PreviewSamples.swift` 新規 + 各 View に `#Preview` 計 19 件追加（サブビュー単体 + 本体 Demo + 編集モード）。戦略 B 採用（本体 View は Bridge 依存のまま、Preview は同等構造のダミー Demo）。Xcode Preview Canvas での実描画確認はユーザー作業。`xcodebuild` 成功 |

---

## フェーズ 3.5: モジュール分割 (2) — feature レイヤー & Android 検証

> Phase 3 の iOS UI 実装と並走する。各 feature の SwiftUI 実装が一段落したタイミングで該当 feature モジュールを切り出す。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/framework` モジュール作成（iOS 向け Umbrella）+ XCFramework ビルド確認 | 2026-06-08 / Phase 2.5 PR3 dispatch A で前倒し作成、dispatch C でビルド検証完了。XCFramework 名・内部 framework 名ともに `SharedLogic`、`assembleSharedLogicXCFramework` タスクで生成 |
| [x] | `feature/visit-list` モジュール切り出し（最初の feature module） | 2026-06-09 / Phase 3 着手の縦スライスと同時に分離。`shared/feature/visit-list/build.gradle.kts` で `kmp.feature` Convention Plugin を初適用、`com.noricoffee.feature.visitlist.VisitListViewModel` を配置。`shared/framework` から `api` + `export` 追加、`settings.gradle.kts` に include 追加。`./gradlew :shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` 共に成功 |
| [x] | `feature/visit-detail` モジュール切り出し | 2026-06-09 / VisitDetail 縦スライスと同時に分離。`com.noricoffee.feature.visitdetail.VisitDetailViewModel` を配置、`AppContainer.makeVisitDetailViewModel()` 拡張関数を `shared/framework/AppContainerViewModelFactory.kt` に追加。同 KDoc を「複数 ViewModel ファクトリ前提」に書き換え。`./gradlew :shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` 共に成功 |
| [x] | `feature/visit-editor` モジュール切り出し | 2026-06-09 / VisitEditor 縦スライスと同時に分離。`com.noricoffee.feature.visiteditor.VisitEditorViewModel` 配置、`AppContainer.makeVisitEditorViewModel()` 拡張関数を `AppContainerViewModelFactory.kt` に追加。`shared/framework` に `api` + `export` 追加。`settings.gradle.kts` include 件数 9 → 10。`:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` / `:shared:data-local:testAndroidHostTest`（12 件）成功。2026-06-10 シミュレータ目視確認済 |
| [x] | `androidApp` で `feature/visit-list` を Compose の 1 画面として表示 | 2026-06-11 / `sharedUI/.../VisitListScreen.kt` 新規 + `MainActivity` を `MaterialTheme + VisitListScreen(CoffeeVisionApp.appContainer)` に置き換え。`CoffeeVisionApp` (Application) で `FirebaseApp.initializeApp` + Firestore PersistentCache + `AppContainer` 構築。`LazyColumn` でカフェ名 / visitedOn / rating の簡素表示（削除 / 編集 / 詳細遷移は検証範囲外） |
| [~] | Android 側で `data-firebase` の `observe` 経由 Firestore 読み取りが動くことを確認 | 2026-06-11 / `:androidApp:assembleDebug` 成功。**エミュレータ / 実機での実動作 + Firestore Console での読み取り目視確認はユーザー作業** |

---

## フェーズ 4: Places API（カフェ検索）

> 2026-06-11 着手。5 スライスに分割して進める。詳細設計は [`implementation_note.md`](./implementation_note.md) 2026-06-11 Phase 4 エントリ参照。Places API は **New v1**（`places.googleapis.com/v1/...`）を採用、`X-Goog-FieldMask` で取得フィールド明示。

### Phase 0 未完了の前段タスク

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `local.properties` での API キー管理を整える（Places） | 2026-06-11 / スライス 1 で `placesApiKey=` を追加 + `androidApp/build.gradle.kts` で local.properties 読み取り → `BuildConfig.PLACES_API_KEY` 注入 → `CoffeeVisionApp.onCreate()` で `AppContainer` 構築時に渡す経路を確立。iOS 側 xcconfig 経由はスライス 2 で実施。Firebase 側はファイル配置で完了済 |

### スライス 1: KMP 基盤（data-places + PlacesClient + CafeRepository + AppContainer 配線）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | **モジュール分割**: `data-places` モジュール作成（`kmp.library` Convention Plugin 適用） | 2026-06-11 / Ktor + Places クライアントを集約。namespace `com.noricoffee.dataPlaces` |
| [x] | `gradle/libs.versions.toml`: Ktor 系・kotlinx-serialization の既存宣言で十分か確認 | 2026-06-11 / 既存宣言で十分、追加なし |
| [x] | `shared/data-places/build.gradle.kts`: `kmp.library` + `kotlinSerialization` 適用、commonMain（ktor-client-core / content-negotiation / serialization-kotlinx-json）/ iosMain（darwin engine）/ androidMain（okhttp engine）依存追加 | 2026-06-11 |
| [x] | `commonMain` に `expect fun createPlacesHttpClient(): HttpClient`、`iosMain` / `androidMain` で `actual` 実装 | 2026-06-11 / `internal expect` 採用、外部公開は `createCafeRepository()` ファクトリ経由 |
| [x] | `commonMain` に Places API New v1 用 DTO（`SearchTextRequest` / `SearchTextResponse` / `PlaceDto` / `LocationDto` / `DisplayNameDto` / `PhotoDto`）を `@Serializable` で定義 | 2026-06-11 / `Json.ignoreUnknownKeys = true` + `explicitNulls = false` |
| [x] | `commonMain` に `PlaceSummary` data class（DTO のフラット化）+ `PlacesClient` interface（`suspend fun searchText(query: String): List<PlaceSummary>`）+ `PlacesClientImpl(httpClient, apiKey)` 実装 | 2026-06-11 / `X-Goog-Api-Key` + `X-Goog-FieldMask` + `places:searchText` POST |
| [x] | `shared/domain` に `CafeRepository` interface 追加（`suspend fun searchText(query: String): List<Cafe>`） | 2026-06-11 / `com.noricoffee.repository.CafeRepository` |
| [x] | `shared/data-places/commonMain` に `CafeRepositoryImpl(placesClient)` 実装（`PlaceSummary` → `Cafe` 変換、`photoReferences` = `places.photos[].name` リスト） | 2026-06-11 |
| [x] | `shared/core/AppContainer`: コンストラクタに `placesApiKey: String` 引数追加（プライマリ / セカンダリ両方）。`cafeRepository: CafeRepository` を public 公開 | 2026-06-11 / `placesApiKey` は `authRepository` の次・`scope` の前に挿入。`createCafeRepository(apiKey)` ファクトリ経由で構築 |
| [x] | `shared/framework`: `api(projects.shared.dataPlaces)` + `export(projects.shared.dataPlaces)` 追加 | 2026-06-11 / SKIE 警告（`Ktor_httpHttpStatusCode.description` → `description_` リネーム）が出るが UI 未参照のため放置 |
| [x] | `settings.gradle.kts`: `include(":shared:data-places")` 追加 | 2026-06-11 |
| [x] | `androidApp/build.gradle.kts`: `local.properties` から `placesApiKey` を読み取り → `buildConfigField` で `PLACES_API_KEY` を注入 | 2026-06-11 / `import java.util.Properties` + `buildFeatures { buildConfig = true }` |
| [x] | `CoffeeVisionApp.onCreate()`: `AppContainer(..., placesApiKey = BuildConfig.PLACES_API_KEY)` で構築 | 2026-06-11 |
| [x] | `iOSApp.swift` / `AppState.swift`: 暫定で空文字（`""`）を `placesApiKey` に渡してビルドだけ通す（xcconfig 経由はスライス 2 で実施） | 2026-06-11 / `AppState.swift` でコメント付きの暫定対応 |
| [x] | 検証: `./gradlew :shared:framework:assembleSharedLogicXCFramework`、`./gradlew :androidApp:assembleDebug`、`./gradlew :shared:data-local:testAndroidHostTest`、`xcodebuild -sdk iphonesimulator` 全成功 | 2026-06-11 / data-local test 12 件グリーン、4 ビルド全成功 |

### スライス 2: iOS UI（CafeSearchView + VisitEditor 統合 + xcconfig 連携）

> 2026-06-12 着手。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-12 Phase 4 スライス 2 エントリ参照。Kotlin 側（VM 追加 + VisitEditor API 拡張）→ iOS 側（xcconfig + UI 実装）の順で 2 段に分けて dispatch する。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | iOS の API キー注入（`Configuration/Secrets.xcconfig` + `Base.xcconfig` + Info.plist + Bundle.main 経由） | 2026-06-12 / `Secrets.xcconfig` は `.gitignore` 追加、`?` 付き include で不在時もビルド継続。`Base.xcconfig` は既存 `Config.xcconfig`（bundle ID / `-lsqlite3` リンク等）を `#include "Config.xcconfig"` で継承する形に親が修正 |
| [x] | `shared/core` に `CafeSearchViewModel(cafeRepository, scope)` を追加（`com.noricoffee.feature.cafesearch` パッケージ、スライス 5 で `shared/feature/cafe-search` へ移送予定） | 2026-06-12 / `UIState(query, results, isLoading, error)` + `onQueryChanged` / `onSearchTapped` / `onErrorDismissed`、`searchJob` 再起動パターン |
| [x] | `shared/framework` に `AppContainer.makeCafeSearchViewModel()` 拡張関数を追加 | 2026-06-12 / `AppContainerViewModelFactory.kt` 末尾追記 |
| [x] | `VisitEditorViewModel` に `onPlacesCafeSelected(cafe: Cafe)` 追加 + `_state` に `selectedPlaceId: String?` 追加 + `buildVisit()` 分岐更新 | 2026-06-12 / Create モード時は `selectedPlaceId ?: UUID 採番`、Edit モードは `currentInitialVisit.cafe.placeId` 優先（カフェ差し替えはスライス 3 以降） |
| [x] | iOS `Features/CafeSearch/CafeSearchView.swift` + `CafeSearchViewModelBridge.swift` 実装 | 2026-06-12 / `.searchable` + `.onSubmit(of:.search)` + toolbar 検索ボタン採用（HIG 準拠）+ `ContentUnavailableView` 空状態 + Preview 2 件 |
| [x] | `VisitEditorView` 統合: 「カフェを検索」ボタン → `CafeSearchView` を sheet 起動 → 選択結果で `onPlacesCafeSelected` を呼び `dismiss` | 2026-06-12 / `cafeSection` のカフェ名 TextField 直上にボタン配置、`@State isCafeSearchPresented` 管理。手入力モードも残置 |
| [x] | 検証: `./gradlew :shared:framework:assembleSharedLogicXCFramework`、`./gradlew :androidApp:assembleDebug`、`./gradlew :shared:data-local:testAndroidHostTest`、`xcodebuild -sdk iphonesimulator` 全成功 | 2026-06-12 / `Base.xcconfig` の `Config.xcconfig` 継承修正後の再ビルドで bundle ID = `com.noricoffee.coffeevision` 確認、BUILD SUCCEEDED |

### スライス 3: 位置情報 + Nearby + Detail

> 2026-06-13 着手。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-13 Phase 4 スライス 3 エントリ参照。3-A（KMP 側）→ 3-B（iOS 側）の 2 段で dispatch する。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `PlacesClient` に `searchNearby(latitude, longitude, radiusMeters = 500.0): List<PlaceSummary>` 追加 | 2026-06-13 / `places:searchNearby` POST、`locationRestriction.circle.center` + `radius` + `includedTypes: ["cafe"]` |
| [x] | `PlacesClient` に `getDetails(placeId): PlaceSummary` 追加 | 2026-06-13 / `places/{placeId}` GET、`DETAILS_FIELD_MASK` 別定数（接頭辞 `places.` なし） |
| [x] | `CafeRepository` に対応メソッド追加（`searchNearby` / `getDetails`） | 2026-06-13 / 既存 `toCafe()` 拡張関数を再利用 |
| [x] | `CafeSearchViewModel` に `onNearbySearchRequested(latitude, longitude)` 追加 | 2026-06-13 / `searchJob` 再起動パターン、`UIState.query` は更新しない、`radiusMeters` は VM 内で 500m 固定（SKIE デフォルト引数制約） |
| [x] | iOS `LocationManager`（`Utilities/LocationManager.swift`）新規実装 | 2026-06-13 / `@MainActor @Observable`、`requestLocation()` 1 回限り取得、`CLLocationManagerDelegate` の `nonisolated` 準拠。`error` / `lastLocation` は `private(set)` + `resetLastLocation()` / `clearError()` メソッド経由でリセット |
| [x] | `Info.plist` に `NSLocationWhenInUseUsageDescription` 追加 | 2026-06-13 / 「近くのカフェを検索するために、現在地を一時的に使用します。」 |
| [x] | `CafeSearchView` の toolbar に「現在地検索」ボタン（`location.fill`）追加 | 2026-06-13 / `HStack` で検索ボタンと並べる構成、`.onChange(of: locationManager.lastLocation?.latitude)` で座標を Bridge に転送、許可拒否時と取得失敗時の 2 系統 alert |
| [x] | `CafeSearchViewModelBridge` に `onNearbySearchRequested` 転送追加 | 2026-06-13 / 既存 `onSearchTapped` と同位置 |
| [x] | 検証: `./gradlew :shared:framework:assembleSharedLogicXCFramework`、`./gradlew :androidApp:assembleDebug`、`./gradlew :shared:data-local:testAndroidHostTest`、`xcodebuild -sdk iphonesimulator` 全成功 | 2026-06-13 / スライス 3-A で gradle 系 / スライス 3-B で xcodebuild 確認 |

### スライス 4: 写真都度取得（Photo Media API）

> 2026-06-15 着手・完了。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-15 Phase 4 スライス 4 エントリ参照。`skipHttpRedirect=true` で `photoUri` JSON を取得する方式を採用（`?key=` URL 埋め込み方式は不採用）。永続キャッシュは禁止（規約）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `PlacesClient` に `photoMediaUrl(photoName, maxWidthPx?, maxHeightPx?): String` 追加（Photo Media API のリダイレクト URL を得る） | 2026-06-15 / `PlacesClient` + `CafeRepository` + `CafeRepositoryImpl` 追加、`PhotoMediaResponse` DTO 追加、`PLACES_MEDIA_BASE_URL` 定数導入。MockEngine テスト 4 件 pass。キャッシュなし（規約） |
| [x] | iOS 側 `PlacePhotoLoader`（URLSession + AsyncImage 連携）実装 | 2026-06-15 / `iosApp/iosApp/Utilities/PlacePhotoLoader.swift` 新規（`@MainActor` 状態なしクラス）+ `iosApp/iosApp/Components/PlacePhotoThumbnail.swift` 新規（empty / success / failure 3 phase、SF Symbols `photo` プレースホルダ）+ `AppState.placePhotoLoader` 追加（init で組み立て、uid 不要） |
| [x] | `CafeSearchView` の結果セルに 1 枚目の写真サムネ表示 | 2026-06-15 / `CafeRow` を VStack → HStack（左 56pt サムネ + 右テキスト）に変更、`maxWidthPx = 200`（56pt @3x 想定）、角丸 8pt。`photoReferences.first` 不在時は同サイズ placeholder。Preview 2 件も追随。シミュレータ目視確認はユーザー作業 |

### スライス 5: feature 切り出し（Phase 4 完了直後）

> スライス 4 までに `shared/core/.../feature/` の暫定置き場に 3 つの ViewModel（`CafeSearchViewModel` / `MapViewModel` / `CafeDetailViewModel`）が溜まっているため、本スライスでまとめて専用 feature モジュールに切り出す。`AppContainerViewModelFactory.kt` の関数シグネチャ（`makeCafeSearchViewModel` / `makeMapViewModel` / `makeCafeDetailViewModel`）は変えない（iOS Bridge への影響ゼロ）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | **モジュール分割**: `shared/feature/cafe-search` モジュール切り出し（`CafeSearchViewModel` を `git mv` で移送） | 2026-06-15 / namespace `com.noricoffee.feature.cafesearch`、`kmp.feature` Convention Plugin 適用 |
| [x] | **モジュール分割**: `shared/feature/map` モジュール切り出し（`MapViewModel` + `MapViewModelPoiLookupTest` を `git mv` で移送） | 2026-06-15 / namespace `com.noricoffee.feature.map`、`kotlinx-datetime` + commonTest 依存（`kotlin.test` / `kotlinx.coroutines.test`）追加。テスト 7 件 pass |
| [x] | **モジュール分割**: `shared/feature/cafe-detail` モジュール切り出し（`CafeDetailViewModel` を `git mv` で移送） | 2026-06-15 / namespace `com.noricoffee.feature.cafedetail`、`kotlinx-datetime` 追加（`Visit.visitedOn` sort 用） |
| [x] | `shared/framework`: 3 モジュール分の `api(...)` + `export(...)` を追加、`AppContainerViewModelFactory.kt` は KDoc 整理（関数シグネチャ不変） | 2026-06-15 / Swift `import SharedLogic` 側の ABI は無変化 |
| [x] | `settings.gradle.kts`: 3 件 include 追加（`:shared:feature:cafe-search` / `:shared:feature:map` / `:shared:feature:cafe-detail`） | 2026-06-15 |
| [x] | `shared/core` 側の暫定置き場ディレクトリ（`com/noricoffee/feature/{cafesearch,map,cafedetail}/`）を削除 + `shared/core/build.gradle.kts` から `kotlinx-datetime` を削除 | 2026-06-15 / 暫定置き場の空ディレクトリ削除、`core` 側で `datetime` を使う他コードがないため依存も移送 |

### スライス 6: 画面構成リファクタ（TabBar 化 + マップ + カフェ詳細統合）

> 2026-06-13 着手。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-13「画面構成を TabBar 化（Map / Visits / Search）+ カフェ詳細統合」エントリ参照。6-A（KMP 側）→ 6-B（iOS 側）の 2 段で dispatch する。

#### 6-A: KMP 側（ドメイン + ViewModel + AppContainer factory）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/domain` に `VisitedCafe(cafe, lastVisitedAt, visitCount, averageRating)` 集計モデル追加 | 2026-06-14 / `shared/domain/.../model/VisitedCafe.kt` |
| [x] | `shared/domain` に `ObserveVisitedCafesUseCase` 追加（`VisitRepository.observeAll(userId).map { group by place_id }`） | 2026-06-14 / `placeId` 集約 + `lastVisitedAt desc` ソート、`rating=0` は未評価扱いで平均から除外、全 0 なら null |
| [x] | `shared/core/.../feature/map/MapViewModel` 追加（`StateFlow<MapUiState>` で訪問済みカフェ + 周辺 Places を公開、フィルタトグル受け） | 2026-06-14 / `init` で `observeVisitedCafesUseCase(userId)` 購読、`onLocationUpdated(lat,lng)` は `searchJob` 再起動パターン |
| [x] | `shared/core/.../feature/cafedetail/CafeDetailViewModel(placeId)` 追加（`VisitRepository.observeAll` を place_id でフィルタ + Cafe スナップショット公開） | 2026-06-14 / 過去 Visit あれば最新 `visit.cafe`、なければ `initialCafe`。`isLoading` は初回 emit まで true |
| [x] | `shared/framework/AppContainerViewModelFactory.kt` に `makeMapViewModel()` / `makeCafeDetailViewModel(placeId)` 拡張関数追加 | 2026-06-14 / `makeMapViewModel(userId)` / `makeCafeDetailViewModel(placeId, initialCafe, userId)` の 2 拡張関数 |
| [x] | `commonTest` で `ObserveVisitedCafesUseCase` の集計ロジックをテスト | 2026-06-14 / 9 件追加（空 / 単一 / グループ化 / ソート / lastVisitedAt / 最新スナップショット採用 / rating=0 除外 / 全 0 で null / 複数 placeId） |
| [x] | 検証: `./gradlew :shared:framework:assembleSharedLogicXCFramework :androidApp:assembleDebug :shared:domain:test :shared:core:test :shared:data-local:testAndroidHostTest` 全成功 | 2026-06-14 / 全成功（`shared:core/build.gradle.kts` に `kotlinx-datetime` 明示追加。`domain` が `implementation` 持ちで Android JVM 側に届かなかったため） |

#### 6-B: iOS 側（RootTabView + MapTabView + CafeDetailView + 既存 View 改修）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `iosApp/iosApp/RootTabView.swift` 新設（`TabView` + 3 タブ定義、`Tab` / `Tab(role: .search)`） | 2026-06-14 / iOS 26 新 API。Search タブの NavigationStack に `navigationDestination(for: CafeDetailRoute.self)` |
| [x] | `iosApp/iosApp/Features/Map/MapTabView.swift` + `MapViewModelBridge.swift` 新設（MapKit `Map` + 2 種 Annotation + フィルタトグル Menu） | 2026-06-14 / 訪問済み = ブラウン `cup.and.saucer.fill`、周辺 = グレー `mappin`。`CafeDetailRoute` は同ファイルに定義 |
| [x] | `iosApp/iosApp/Features/CafeDetail/CafeDetailView.swift` + `CafeDetailViewModelBridge.swift` 新設（カフェ情報 + 過去 Visit 一覧 + `+ Visit を追加` ボタン） | 2026-06-14 / sheet で VisitEditor 起動、`initialCafe` pre-filled。空状態は中央 + ツールバーの両方に追加ボタン |
| [x] | `iOSApp.swift`: `RootView` の表示先を `VisitListView` → `RootTabView` に切替 | 2026-06-14 / `RootView` → `AppRootView` にリネーム、起動条件に `mapBridge != nil` を追加 |
| [x] | `AppState.swift`: `mapBridge` を追加（visitListBridge と同等の lazy 管理）、`makeCafeDetailViewModel(placeId)` の factory パス確認 | 2026-06-14 / `bootstrap()` で uid 確定後に `makeMapViewModel(userId:)` を 1 度だけ生成。CafeDetail は View 内 `@State` で都度生成 |
| [x] | `VisitListView.swift`: toolbar `+` と `isPresentingEditor` sheet を撤去 | 2026-06-14 / 自身の `NavigationStack` も撤去（Tab 配下に NavigationStack あり）。空状態文言をマップ / 検索タブ誘導に変更 |
| [x] | `CafeSearchView.swift`: `onCafeSelected` を Optional 化、未指定時は `NavigationLink` で CafeDetailView へ push する分岐追加 | 2026-06-14 / ルートモード用 `init(appState:)` を追加。VisitEditor からの sheet 経路は `VisitEditorView` 側で `NavigationStack { CafeSearchView(...) }` ラップ必須（ルート化の副作用） |
| [x] | `LocationManager` の利用追加（マップ初期カメラ位置の現在地中心化、未許可時は訪問済みカフェ bounding box） | 2026-06-14 / 取得は AsyncStream ポーリング（0.1s × 30 回）。fallback 順は 現在地 → 訪問済み bounding box → 東京駅デフォルト |
| [x] | 検証: `xcodebuild -sdk iphonesimulator` 成功、シミュレータで TabBar 表示 / マップピン / ピンタップ → CafeDetail → + → VisitEditor / Search タブで検索結果タップ → CafeDetail のフロー目視確認 | 2026-06-14 / BUILD SUCCEEDED。シミュレータ目視確認はユーザー作業 |

### スライス 7: マップ画面 Apple Maps POI タップで Visit 追加

> 2026-06-15 着手。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-15「マップ画面に Apple Maps POI タップで Visit 追加する動線」エントリ参照。7-A（KMP）→ 7-B（iOS）の 2 段で dispatch する。

#### 7-A: KMP 側（searchText に locationBias 追加 + MapViewModel POI lookup API）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/data-places/.../PlacesClient.searchText` に `locationBias: LocationBias?` 引数を追加（`SearchTextRequest` DTO に `locationBias.circle.center` + `radius` を追加） | 2026-06-15 / SKIE 用に 2 オーバーロード公開。`LocationBiasDto` は既存 `CircleDto` / `LatLngDto` を再利用。`PlacesClientImpl.searchTextInternal` で集約 |
| [x] | `shared/domain/.../repository/CafeRepository.searchText` に対応引数を追加 | 2026-06-15 / `LocationBias` は `com.noricoffee.domain` 直下に新規追加 |
| [x] | `shared/data-places/.../CafeRepositoryImpl.searchText` を追随 | 2026-06-15 |
| [x] | `shared/core/.../feature/map/MapViewModel` に `onPoiTapped(name, latitude, longitude)` / `onPoiLookupConsumed()` 追加、`UIState` に `isLookingUpPoi` / `poiLookupResult` / `poiLookupError` を追加 | 2026-06-15 / `onPoiLookupErrorDismissed()` も追加。`poiLookupJob` の再起動パターン |
| [x] | `commonTest` で `searchText` の locationBias リクエスト形成 + `onPoiTapped` の状態遷移をテスト | 2026-06-15 / data-places 4 件 + core 7 件 全 pass |
| [x] | 検証: `./gradlew :shared:framework:assembleSharedLogicXCFramework :androidApp:assembleDebug :shared:domain:test :shared:core:test :shared:data-local:testAndroidHostTest` 全成功 | 2026-06-15 / 全成功 |

#### 7-B: iOS 側（MapTabView selection 連携 + Bridge 拡張）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `MapTabView`: `Map(position:selection:)` に切替、`MapFeature?` の `@State` を持つ | 2026-06-15 / iOS 17+ API、`#if compiler(>=5.3) && $NonescapableTypes` ガード経由で iOS 26 SDK で解決 |
| [x] | `MapTabView`: `.onChange(of: selection)` で `.cafe` / `.restaurant` / `.bakery` のみ受け入れ、`bridge.onPoiTapped(name, lat, lng)` を呼ぶ | 2026-06-15 / カテゴリ外は selection nil リセット、`poiSelectionChanged` に分離 |
| [x] | `MapTabView`: `navigationPath: NavigationPath` を持ち、`bridge.poiLookupResult` の購読で `CafeDetailRoute` を append | 2026-06-15 / プログラマティック push。NavigationStack を `MapTabView` 内に閉じる構造に変更（`RootTabView` 側の外側 NavigationStack を撤去） |
| [x] | `MapTabView`: `isLookingUpPoi` 中は ProgressView オーバーレイ、`poiLookupError` で alert | 2026-06-15 / `.ultraThinMaterial` 背景。`error` / `poiLookupError` の 2 alert 共存（同時発火は稀） |
| [x] | `MapViewModelBridge`: `onPoiTapped` / `onPoiLookupConsumed` 転送 + `isLookingUpPoi` / `poiLookupResult` / `poiLookupError` の Swift プロパティ追加 | 2026-06-15 / `onPoiLookupErrorDismissed` も追加 |
| [x] | 検証: `xcodebuild -sdk iphonesimulator` 成功 | 2026-06-15 / BUILD SUCCEEDED。シミュレータ目視確認はユーザー作業 |

---

## フェーズ 5: 仕上げ

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 設定画面（テーマ切り替え / バージョン表示 / ライセンス表示） | 2026-06-16 実装完了 / `iosApp/iosApp/Features/Settings/{AppAppearance,SettingsView,LicensesView}.swift` 新規 + `iOSApp.swift`（`AppRootView` に `@AppStorage("appAppearance")` + `.preferredColorScheme`）+ `MapTabView.swift`（Menu フィルタ撤去 → マップを `.ignoresSafeArea()` で全画面化 + ナビバー非表示、`ZStack(alignment: .top)` で歯車フローティングボタン（→ `.sheet(SettingsView)`）と `FilterChip` 行をマップに重ねる）。テーマ = システム/ライト/ダークの 3 値を `@AppStorage` で永続化しアプリ全体に即時反映。ライセンスは OSS 7 件（Apache-2.0）の静的リスト。**サインアウトは見送り**（匿名のみ→記録孤立リスク、アカウントアップグレード後のフォローアップ）。`xcodebuild -sdk iphonesimulator` BUILD SUCCEEDED（新規 warning ゼロ）。KMP 変更なし。**シミュレータ目視確認はユーザー作業**。事前設計は [`implementation_note.md`](./implementation_note.md) 2026-06-16 エントリ参照 |
| [x] | アカウントアップグレード（匿名 → Apple）の UI | 2026-06-17 実装完了 / **Sign in with Apple のみ**採用（Google は見送り）。link で uid 不変＝データ引き継ぎ。KMP: `AuthAccount` + `AuthRepository.linkWithApple/observeAccount` + `shared/feature/account/AccountViewModel`（テスト 11 件）。iOS: `AccountView` + `AccountViewModelBridge` + `AppleSignInCoordinator`（`ASAuthorization` を async ラップ・rawNonce 自前管理）+ `SettingsView` にアカウント節 + entitlements に Sign in with Apple。`./gradlew` KMP 全検証 + `xcodebuild -sdk iphonesimulator` 共に成功（親で再確認）。**実機での Apple サインイン動作確認・Firebase Console での Apple プロバイダ有効化・Apple Developer の App ID 設定はユーザー作業**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-17 エントリ |
| [x] | アカウント削除フロー | 2026-06-17 実装完了 / `DeleteAccountUseCase`（全 Visit を local+remote 削除 → `deleteAuthUser`）+ iOS で `PhotoFileStore.deleteAllPhotos()` → `AppState.resetAndRebootstrap()` で新規匿名再起動。確認ダイアログ 2 段。`requiresRecentLogin` 再認証は将来課題（コメント済）。アップグレードと同 PR |
| [x] | サインアウト（設定画面で見送り分を回収） | 2026-06-17 実装完了 / アップグレード済みアカウントのみ表示。`signOut()` → `resetAndRebootstrap()` で新規匿名。再 Apple サインインで元データ再同期。ローカルデータは uid フィルタで自然に隠れるため写真消去なし |
| [x] | エラーバナー / トースト共通コンポーネント | 2026-06-16 実装完了 / `iosApp/iosApp/Components/ErrorToast.swift`（新規・`View.errorToast(message:onDismiss:)`、上部スライドイン + 4 秒自動消去 + タップ/上スワイプ手動消去、`AccessibilityNotification.Announcement` で VoiceOver 対応、`accessibilityReduceMotion` 対応）。非致命エラー（VisitList / VisitDetail / Map の error+poiLookupError / CafeSearch の error+位置取得失敗 / 起動同期失敗 `lastError`）をトースト化。複数エラー源は `activeToast` で集約。致命（VisitEditor 保存失敗）とアクション可能（位置情報許可拒否→設定誘導）は `.alert` 据え置き。`AppState.clearLastError()` 追加で未表示だった `lastError` を露出。KMP 変更なし。`xcodebuild -sdk iphonesimulator` BUILD SUCCEEDED（新規 warning ゼロ）。**シミュレータ目視確認はユーザー作業**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-16 errorToast エントリ参照 |
| [ ] | アクセシビリティ通し検証（VoiceOver / Dynamic Type / Reduce Motion） | |
| [x] | App Icon / Launch Screen / アプリ表示名の整備 | 2026-06-16 実装完了 / 表示名 = `CoffeeVision`（`Info.plist` の `CFBundleDisplayName`、bundle ID / `PRODUCT_NAME` 不変）。アイコンは `iosApp/scripts/generate_app_icon.swift`（AppKit + SF Symbol `cup.and.saucer.fill`）で light/dark/tinted の 1024×1024 を生成し `AppIcon.appiconset` に紐付け。Launch Screen は `UILaunchScreen` 辞書方式（`LaunchBackground` colorset + `LaunchLogo` imageset のカップ+ワードマーク透過 PNG）、`INFOPLIST_KEY_UILaunchScreen_Generation` は削除。`xcodebuild -sdk iphonesimulator` BUILD SUCCEEDED（新規 warning ゼロ）。KMP 変更なし。**シミュレータ目視確認はユーザー作業**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-16 App Icon エントリ参照 |
| [x] | App Store Connect 用メタデータ準備 | 2026-06-17 / [`app-store-metadata.md`](./app-store-metadata.md) 新規作成。アプリ基本情報 / 説明文 / キーワード / スクショ計画 / プライバシー申告（位置情報・写真・ユーザーコンテンツ・匿名 uid の収集マッピング）/ 年齢制限 / 審査メモ / 提出前チェックリストを整備。**プライバシーポリシー URL・サポート URL の作成、サブタイトル/カテゴリ確定、スクショ撮影、審査連絡先記入はユーザー作業**（チェックリストに明記） |

---

## フェーズ 5.2: アカウント削除時の Apple トークン失効（E-1）

> 2026-06-24 着手。App Store ガイドライン 5.1.1(v)「Sign in with Apple を使い、かつアカウント削除を提供するアプリは、削除時に Apple トークンの失効も行う」対応。**iOS 単独タスク（KMP / commonMain 変更なし）**。`Auth.auth().revokeToken(withAuthorizationCode:)` には Apple の authorization code（一度きり・約 5 分有効・保存不可）が必要なため、削除時に Apple サインインをやり直して取得する。この再サインインは既存 `deleteAuthUser` の `requiresRecentLogin`（再認証要求）課題も同時に解決する。設計判断は [`implementation_note.md`](./implementation_note.md) 2026-06-24 エントリ。

### 確定フロー（Apple 連携アカウントのみ。匿名アカウントは従来通り revoke なし）

1. Apple 再サインイン → `(idToken, rawNonce, authorizationCode)` 取得
2. `currentUser.reauthenticate(with:)` で再認証（`requiresRecentLogin` 解消）
3. `Auth.auth().revokeToken(withAuthorizationCode:)` で Apple トークン失効
4. 既存 KMP `DeleteAccountUseCase`（記録削除 → `currentUser.delete()`）を従来通り実行
5. `PhotoFileStore.deleteAllPhotos()` + `AppState.resetAndRebootstrap()`

### iOS（ios-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `AppleSignInCoordinator.signIn(anchor:)` の戻り値を `(idToken, rawNonce, authorizationCode)` に拡張。`didCompleteWithAuthorization` で `ASAuthorizationAppleIDCredential.authorizationCode`（Data → UTF-8 String）を取り出す | 2026-06-24 / 既存アップグレード経路（`startAppleSignIn`）はタプル分解を `(_,_,_)` 化のみで挙動不変。code 取得失敗時は error throw |
| [x] | reauthenticate + revoke を行う Swift ヘルパ（ステートレス推奨。`Auth.auth().currentUser?.reauthenticate(with:)` → `Auth.auth().revokeToken(withAuthorizationCode:)`）を追加 | 2026-06-24 / `AuthRepositoryIosImpl.reauthenticateAndRevokeAppleToken(idToken:rawNonce:authorizationCode:)` 非 protocol メソッド。配線追加なし |
| [x] | `AccountView.handleDeleteAccount`: Apple 連携（`!isAnonymous && providerLabel == "apple.com"`）のときのみ「再サインイン → reauth → revoke」を KMP 削除 UseCase 呼び出しの前段に実行。匿名は従来フロー。ユーザーキャンセルは無音中断、reauth/revoke 失敗はエラー表示して削除中断（コンプライアンス上 revoke 必須） | 2026-06-24 / `AccountViewModelBridge.isProcessing` を computed 化（`isKmpProcessing \|\| isPreflighting`）+ preflight 4 メソッドで状態制御 |
| [x] | 検証: `xcodebuild -sdk iphonesimulator` 成功（新規 warning ゼロ） | 2026-06-24 / BUILD SUCCEEDED・新規 warning ゼロ。KMP 変更なし。**E-1 フロー全体の動作確認はシミュレータ不可（Apple サインイン制限）→ 実機が必須** |
| [ ] | **（ユーザー作業・revoke 機能の前提）** Apple Developer で ① Sign in with Apple 用 Key（.p8）作成（Key ID / Team ID 控え）② Services ID 作成（Return URL = `https://coffeevision-a54aa.firebaseapp.com/__/auth/handler`）→ Firebase Console の Apple プロバイダ（OAuth コードフロー設定）に **Services ID / Apple Team ID / Key ID / 秘密鍵**の 4 つを登録。Console は 4 項目を 1 セットで検証するため Services ID も必須。**これが無いと `revokeToken` はサーバ側で失敗する** | E-1 の機能成立に必須。シミュレータでは Apple サインイン自体が制限されるため実機確認推奨 |

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

## フェーズ 7: コーヒー記録主体への再設計（Visit → CoffeeRecord）

> 2026-06-19 着手。アプリの集約ルートを「カフェ訪問（`Visit`）」から「**コーヒー記録（`CoffeeRecord`）**」へ転換。カフェは任意（null = セルフ抽出）。`ambiance` / `FoodItem` は廃止（メモに吸収）。**クリーンブレイク**（データ移行なし、テスト端末はアプリ削除→再インストール）。確定仕様は [`data-model.md`](./data-model.md)（2026-06-19 全面改訂版）、経緯は [`implementation_note.md`](./implementation_note.md) 2026-06-19 エントリ。3 ロール体制で Phase 1（KMP commonMain + data-local）→ Phase 2（data-firebase Android）/ Phase 3（iOS）の順に dispatch。

### Phase 0: docs（親）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `data-model.md` を CoffeeRecord 主体に全面改訂（Kotlin / SQLDelight / Firestore の 3 表現） | 2026-06-19 |
| [x] | `architecture.md` / `CLAUDE.md` のモジュール名・リポジトリ名を更新（改訂バナー追加、履歴表は残置） | 2026-06-19 |
| [x] | `tasks.md` にフェーズ 7 を追加、`implementation_note.md` に判断記録 | 2026-06-19 |

### Phase 1: KMP commonMain + data-local（kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/domain`: `CoffeeRecord` 新設、`Visit` / `CoffeeItem` / `FoodItem` 削除。`cafe: Cafe?`、コーヒー属性昇格 | 2026-06-19 |
| [x] | `shared/domain`: `CoffeeRepository` / `RemoteCoffeeDataSource` 新設（旧 Visit 系を置換）。`ObserveVisitedCafesUseCase`（cafe != null フィルタ）/ `DeleteAccountUseCase` 追随。`VisitedCafe` は名前維持で集計元変更 | 2026-06-19 |
| [x] | `shared/core`: `CoffeeRepositoryImpl` / `AppContainer`（`coffeeRepository`、引数 `remoteCoffeeDataSource`） | 2026-06-19 |
| [x] | `shared/data-local`: `CoffeeRecord.sq` 新設 + `Photo.sq` FK 変更、`Visit/CoffeeItem/FoodItem.sq` 削除、`LocalCoffeeRepository` + `Mapper`。テスト改訂（null cafe 往復ケース追加） | 2026-06-19 / testAndroidHostTest 18 件緑。JdbcSqliteDriver は PRAGMA foreign_keys=ON 必要（lessons.md） |
| [x] | feature リネーム: `coffee-list` / `coffee-detail` / `coffee-editor`（ViewModel + UIState を CoffeeRecord 化）。`cafe-detail` / `map` 追随 | 2026-06-19 / 旧 visit-* ディレクトリ git rm 済 |
| [x] | `shared/framework`: export/api を coffee-* に、`AppContainerViewModelFactory` のファクトリ改名・配線。`settings.gradle.kts` のモジュール名更新 | 2026-06-19 / makeCoffee*ViewModel |
| [x] | 検証: `:shared:domain:compile*` / `:shared:data-local:allTests` / `:shared:framework:assembleSharedLogicXCFramework` 成功（iOS 着手の前提） | 2026-06-19 / 全成功 |

### Phase 2: data-firebase（androidMain, kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CoffeeFirestoreMapper` + `RemoteCoffeeDataSourceAndroidImpl`（`coffees` コレクション + photos 埋め込み、子取得・差分 delete 撤廃） | 2026-06-19 / observe リスナ1本・set/delete 各1回に簡素化 |
| [x] | `androidApp` / `sharedUI` の Visit 参照を追随。検証: `:androidApp:assembleDebug` 成功 | 2026-06-19 / VisitListScreen→CoffeeListScreen。Firestore 実機往復確認はユーザー作業 |

### Phase 3: iOS UI（ios-engineer, Phase 1 完了後）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `FirebaseRepositories`: `CoffeeFirestoreMapper.swift` + `RemoteCoffeeDataSourceIosImpl.swift`（coffees + photos 埋め込みで簡素化） | 2026-06-19 / SKIE 実装側は `__upload`/`__remove` + `SkieSwiftFlow<[CoffeeRecord]>`（lessons.md） |
| [x] | `AppState.swift`: `coffeeListBridge`、`RemoteCoffeeDataSourceIosImpl`、AppContainer init 追随 | 2026-06-19 |
| [x] | `RootTabView`: 「訪問」→「コーヒー」タブ + **FAB でコーヒー記録追加**（TabBarFrameReader パターン流用、競合時は右下標準配置にフォールバック） | 2026-06-19 / TabBarFrameReader 採用（MapTabView 現在地 FAB と同パターン、検索タブ上に配置）。toolbar + は撤去 |
| [x] | `Coffee{List,Detail,Editor}View` + Bridge（VisitEditor は子アイテム編集を本体フォームに統合、cafe 任意化）。`CoffeeItemEditorView` / `FoodItemEditorView` 削除 | 2026-06-19 |
| [x] | `CafeDetailView` / `MapTabView` 追随、`PreviewSamples` を CoffeeRecord 化（cafe あり/null 両方） | 2026-06-19 |
| [~] | 検証: `xcodebuild -sdk iphonesimulator` 成功。シミュレータ手動確認（アプリ削除→再インストール前提） | 2026-06-19 / 親が override フラグ無しで BUILD SUCCEEDED 再確認済。**シミュレータ目視確認はユーザー作業**（FAB→セルフ抽出保存→一覧 / カフェ詳細→記録 / マップピン / 詳細編集削除 / Firestore coffees。DB 作り直しのためアプリ削除→再インストール必須） |

---

## フェーズ 8: 分析タブ（コーヒー傾向分析）

> 2026-06-19 着手。これまでの `CoffeeRecord` 群を分析する「分析」タブを追加する。3 階層構成（階層1 記述統計 / 階層2 傾向抽出 = KMP 共通、階層3 自然言語解釈 = iOS Foundation Models）。確定仕様は [`requirements.md`](./requirements.md) §9、集計モデルは [`data-model.md`](./data-model.md) §1.6、設計判断は [`implementation_note.md`](./implementation_note.md) 2026-06-19 分析機能エントリ。**設計原則: 集計は KMP で決定論的に正確に、その集約済みサマリ（`CoffeeStats`）だけを Foundation Models に渡す**。Foundation Models は iOS 専用のため Android は分析タブ非表示。

### Phase 0: docs（親）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `requirements.md` §9 + 画面一覧に分析タブを追加 | 2026-06-19 |
| [x] | `data-model.md` §1.6 `CoffeeStats` 集計モデル + `CoffeeInsightProvider` インターフェースを定義 | 2026-06-19 |
| [x] | `tasks.md` フェーズ 8 追加 + `implementation_note.md` に設計判断を記録 | 2026-06-19 |

### Phase A-1: 階層1 集計（kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/domain`: `CoffeeStats` / `RatingBucket` / `CategoryStat` / `MonthlyStat` / `CafeStat` / `RecordDigest` / `FavoriteSignals` / `CoffeeInsight` / `CoffeeInsightProvider` を追加 | 2026-06-19 / `model/CoffeeStats.kt`。`favoriteSignals` は空（`minSampleSize=3`）|
| [x] | `shared/domain`: `BuildCoffeeStatsUseCase`（`List<CoffeeRecord>` → `CoffeeStats`）+ `ObserveCoffeeStatsUseCase`（`CoffeeRepository.observeAll(userId).map { ... }`） | 2026-06-19 / `usecase/`。定数 `ORIGIN_RANKING_LIMIT=10` / `TOP_CAFES_LIMIT=10` / `RECENT_HIGHLIGHTS_LIMIT=5` / `HIGHLIGHTS_MIN_RATING=4.0` を companion 公開 |
| [x] | `commonTest`: 集計ロジックのユニットテスト（空 / 単一 / 未評価除外 / カテゴリ集計 / 月次 / topCafes が cafe==null 除外 / 平均の null 条件） | 2026-06-19 / `BuildCoffeeStatsUseCaseTest` 31 件 |
| [x] | 検証: `:shared:domain:test`（または `:shared:data-local:testAndroidHostTest`）成功 | 2026-06-19 / `:shared:domain:testAndroidHostTest` 43 件 pass（新規31+既存12）、`compileKotlinIosSimulatorArm64` / `assembleSharedLogicXCFramework` 成功 |

### Phase A-2: AnalysisViewModel（kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | **モジュール分割**: `shared/feature/analysis` モジュール作成（`kmp.feature` 適用、namespace `com.noricoffee.feature.analysis`） | 2026-06-19 / `settings.gradle.kts` include 追加 |
| [x] | `AnalysisViewModel(observeCoffeeStatsUseCase, insightProvider: CoffeeInsightProvider?, userId, scope)` + `AnalysisUiState(stats, isLoading, insight, insightStatus, error)` | 2026-06-19 / `InsightStatus` = sealed interface（Unsupported/Idle/Loading/Loaded/Failed）。`insightProvider==null` は Unsupported。`onAppear()` 引数なし |
| [x] | `shared/framework`: `api` / `export` + `AppContainer.makeAnalysisViewModel()` 拡張関数追加。`AppContainer` に `coffeeInsightProvider: CoffeeInsightProvider?` 注入経路を追加（既定 null、iOS が実装を注入） | 2026-06-19 / `AppContainer` コンストラクタ 3 系統（6/5/4 引数）。Android・現状 iOS は 4 引数で無変更、iOS は A-4 で 5 引数化 |
| [x] | 検証: `:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` 成功 | 2026-06-19 / 両成功。XCFramework ヘッダに `AnalysisViewModel` / `makeAnalysisViewModel` / `InsightStatus` 出力確認。domain/data-local テスト計 62 件リグレッションなし |

### Phase A-3: 分析タブ UI（ios-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `RootTabView` に「分析」タブ追加（SF Symbols `chart.bar` 等）。`AnalysisView` + `AnalysisViewModelBridge` 新設 | 2026-06-19 / `chart.bar.xaxis`、タブ順=マップ/コーヒー/分析/検索（search 右端固定）。Bridge は insight 系も読むが描画は stats のみ |
| [x] | 階層1 の可視化（Swift Charts で産地分布 / 焙煎度 / 月次推移 / 評価ヒストグラム、よく行く店リスト、サマリ数値） | 2026-06-19 / 棒（ヒストグラム/カテゴリ）/ 横棒（産地）/ 折れ線（月次）/ リスト（店）。`ScrollView`+`LazyVStack`、enum 日本語化ヘルパ内包、accessibilityLabel 付与 |
| [x] | 空状態（記録 0 件）の `ContentUnavailableView` | 2026-06-19 / `stats==nil` または `totalCount==0`、isLoading は ProgressView で分離 |
| [~] | 検証: `xcodebuild -sdk iphonesimulator` 成功。シミュレータ目視はユーザー作業 | 2026-06-19 / BUILD SUCCEEDED・新規 warning ゼロ。**シミュレータ目視（タブ表示/各グラフ/空状態/VoiceOver 数値読み上げ）はユーザー作業** |

### Phase A-4: Foundation Models 要約（親が契約確定 → ios-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | iOS `CoffeeInsightProvider` 実装（`shared/domain` インターフェース準拠の Swift クラス）。`CoffeeStats` をコンパクトなテキストに整形 → `LanguageModelSession` で 2–3 文要約（`@Generable` で headline/body 構造化） | 2026-06-19 / `CoffeeInsightProviderIosImpl`。SKIE protocol witness `__summarize(stats:completionHandler:)`。`buildPrompt` は KMP 集計済み事実を文章化（LLM に計算させない）。`@Generable` は private struct（SwiftUI `body` 競合回避） |
| [x] | `AppState` / `AppContainer` 構築で `CoffeeInsightProvider` を注入。`AnalysisView` に要約カード + ローディング / 非対応フォールバック表示 | 2026-06-19 / `makeIfAvailable()`（`SystemLanguageModel.availability` で不可なら nil）→ 5 引数コンストラクタへ。`insightCardSection` は `Unsupported`=非表示 / `Loading` / `Loaded` / `Failed`（retry）を `is` 分岐 |
| [x] | 小さな PoC で Foundation Models 呼び出しの round-trip を先に確認してから本実装に組み込む | 2026-06-19 / PoC でビルド通過確認後に本実装 |
| [~] | 検証: `xcodebuild -sdk iphonesimulator` 成功。実機 / Apple Intelligence 有効端末での要約確認はユーザー作業 | 2026-06-19 / BUILD SUCCEEDED・新規 warning ゼロ。**Apple Intelligence 有効な実機での要約生成確認はユーザー作業** |

### Phase B（後続）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | B-1: `FavoriteSignals`（階層2）を `BuildCoffeeStatsUseCase` に実装 + 機構別単体テスト（kmp-engineer） | 2026-06-19/06-21 / 経験ベイズ収縮＋ピアソン相関。`BuildCoffeeStatsUseCaseTest` に収縮・相関・タイ・閾値の単体テスト |

### Phase B-1b: 好み判定のペルソナ比較検証（kmp-engineer）

> 2026-06-22 着手。`FavoriteSignals` の正しさを「1 ケース」でなく**複数の合成ペルソナを横断**して検証する。機構単体テストでは見えない 2 軸 ——**検出力（仕込んだ好みを拾えるか）** と **特異度（好みが無いとき黙れるか＝偽陽性抑制）**—— を可視化する。**既存 production コード・仕様（data-model §1.6）は変更しない。テスト追加のみ。** 検証戦略は [`implementation_note.md`](./implementation_note.md) 2026-06-22 ペルソナ比較検証エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: ペルソナ比較検証の戦略（ペルソナ定義・検証 2 軸・偽陽性測定方針）を docs に固定 | 2026-06-22 / implementation_note 2026-06-22 Phase B-1b エントリ |
| [x] | KMP（kmp-engineer）: 固定シードのペルソナ生成ヘルパ + P1–P7 の決定論的 ground-truth assert（`shared/domain` commonTest 新規ファイル） | 2026-06-22 / `FavoriteSignalsPersonaTest`。新規 8＋既存 47＝55 件 green。検出力 P1–P4・P7 OK |
| [x] | KMP（kmp-engineer）: 無相関ペルソナ（P5）の偽陽性率を多シードで**測定**し実測値をレポート（hard-fail は catastrophic 閾値のみ） | 2026-06-22 / 150 シード。`dominantTastingAxis` 40.0% / カテゴリ信号 **100.0%** |
| [x] | 親: 偽陽性率の実測値を評価 → 必要なら Phase B-1c（多重比較ガード: 動的閾値 or 信頼区間下限）へ | 2026-06-22 / カテゴリ 100% は構造的弱点。B-1c 推奨。進行判断はユーザー待ち（implementation_note 参照）|

### Phase B-1c: 好み判定の特異度ガード（偽陽性抑制）※ユーザー判断待ち

> 2026-06-22 起票。B-1b の実測でカテゴリ信号の偽陽性率 100%・tasting 軸 40% が判明。「最大群が globalMean を超えたら信号化」は閾値ガードにならない（最良は大抵平均超え）。**effect-size 閾値（`shrunkMean - globalMean > δ`）を第一候補**に特異度を上げ、ペルソナ検証で偽陽性率の改善と検出力維持（P1–P4 を割らない）を再測定する。進める/δ値/範囲はユーザー判断。設計ログは [`implementation_note.md`](./implementation_note.md) 2026-06-22 B-1b エントリ末尾。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親 → ユーザー: B-1c に進むか / δ 値 / どこまでやるかを決定 | 2026-06-22 / **effect-size 閾値で対処**を承認（AskUserQuestion）|
| [x] | 親: カテゴリ effect-size δ ＋ tasting 軸 n 連動 floor の仕様を data-model §1.6 に固定 | 2026-06-22 / 公開 API 不変。確定値は sweep 待ち |
| [x] | KMP（kmp-engineer）: `BuildCoffeeStatsUseCase` に `CATEGORY_MIN_EFFECT`（δ）と `CORRELATION_ABS_FLOOR_C`（n 連動）を実装 + 既存ユニットテスト追随 | 2026-06-22 / δ=0.20・c=1.97。既存テスト追随ゼロ。111 件 green・XCFramework OK・API 不変 |
| [x] | KMP（kmp-engineer）: `FavoriteSignalsPersonaTest` で δ・floor 候補を sweep → 偽陽性率と検出力（P1–P4・P7）の表をレポート | 2026-06-22 / δ5×c3×150 シード。tasting 22%(c=1.97)/8.7%(c=2.30)、検出力維持 |
| [x] | 親: sweep 結果から δ・floor の最終値を確定 → data-model §1.6 を実値に更新 | 2026-06-22 / δ=0.20・c=1.97 を ship。**カテゴリは固定 δ で解けないと判明**（既知の限界として記載）|

### Phase B-1d: カテゴリ信号の n 連動ゲート（未着手 / 任意）※ユーザー判断待ち

> 2026-06-22 起票。B-1c でカテゴリ偽陽性が固定 δ では下がらないと判明（winner's curse はばらつき連動）。**まず現実的な不均等分布の null ペルソナで「実データでも問題か」を実測**し、問題が残るなら n 連動の信頼区間ゲート（`gap > z·globalStd/√n` 等、軽量・決定論・on-device 可）を入れる。やらない場合はカテゴリ信号を「弱い傾向（LLM 断定禁止）」として現状維持。設計ログは [`implementation_note.md`](./implementation_note.md) 2026-06-22 B-1c エントリ末尾。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親 → ユーザー: B-1d に進むか / 現状維持か | 2026-06-22 / **まず不均等分布で実測**を承認（AskUserQuestion）|
| [x] | KMP（kmp-engineer）: 現実的な不均等分布の null ペルソナを追加し、カテゴリ偽陽性率を再測定（均等割当と比較） | 2026-06-22 / 均等100%→heavy-skew 86.7%。候補21→8 でも 13.3pt のみ低下 |
| [x] | 親: 実測結果を評価 → n 連動カテゴリゲートに進むか / δ=0.20 を確定とするか判断 | 2026-06-22 / **stays high。n 連動 z ゲートへ進む**（仕様 data-model §1.6 更新済）|
| [x] | KMP（kmp-engineer）: カテゴリゲートを `mean - globalMean > CATEGORY_Z·globalStd/√n`（z 連動）に置換 + δ=0.20 を AND 下限に。選定キーは shrunkMean 維持。既存テスト追随 | 2026-06-22 / 検出系 4 テストを n=10 増量。113 件 green・XCFramework OK・API 不変 |
| [x] | KMP（kmp-engineer）: `FavoriteSignalsPersonaTest` で `CATEGORY_Z` を sweep（均等/mild/heavy-skew × 検出力 P2–P4・P1・P7）→ 表をレポート | 2026-06-22 / z=1.5/2.0/2.5/3.0。heavy-skew 9.3%(z=2.0) |
| [x] | 親: sweep から `CATEGORY_Z` 最終値を確定 → data-model §1.6 を実値に更新 | 2026-06-22 / **CATEGORY_Z=2.0 確定**（95% CI・検出力維持）|

### Phase B-2: 対話 Q&A v1（単発・digest 文脈注入）

> 2026-06-21 着手。分析タブに自然言語 Q&A を追加する。**単発（1 問 1 答・ステートレス）/ `CoffeeStats` digest のみ文脈注入 / 逐次表示なし**。確定仕様は [`requirements.md`](./requirements.md) §9-4、インターフェース・設計判断は [`data-model.md`](./data-model.md) §1.6「対話 Q&A v1」、bridge は [`kmp-bridge.md`](./kmp-bridge.md) protocol witness 表、設計ログは [`implementation_note.md`](./implementation_note.md) 2026-06-21 Q&A v1 エントリ。tool calling（生レコード参照）は B-3 に分離。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: `CoffeeInsightProvider.answer(question, stats): String` の契約 + `AnalysisViewModel` の Q&A 状態仕様を docs に固定 | 2026-06-21 / requirements §9-4・data-model §1.6・kmp-bridge・implementation_note |
| [x] | KMP（kmp-engineer）: `CoffeeInsightProvider` に `@Throws suspend fun answer(question, stats): String` を追加 | 2026-06-21 / `summarize` と同列。XCFramework に `answer(question:stats:completionHandler:)` 出力確認 |
| [x] | KMP（kmp-engineer）: `AnalysisViewModel` に Q&A 状態を追加（`QaStatus` sealed: Unsupported/Idle/Asking/Answered/Failed、`qaQuestion`/`qaAnswer`、`onQuestionAsked(question)`/`onQaCleared()`、候補質問 `SUGGESTED_QUESTIONS`） | 2026-06-21 / `insight` と同じ Job 再起動・null=Unsupported パターン。`error` 共用。状態遷移テスト 10 件 green |
| [x] | iOS（ios-engineer）: `CoffeeInsightProviderIosImpl.__answer(question:stats:completionHandler:)` 実装 | 2026-06-21 / `__summarize` と同型。`generateAnswer` で `buildPrompt` 流用 + 質問付与、grounding 5 か条 instructions、`session.respond(to:)` プレーンテキスト |
| [x] | iOS（ios-engineer）: `AnalysisView` に Q&A UI（入力欄 + 送信 + 候補チップ + 回答カード + Asking スピナ + Failed リトライ）。`Unsupported` は非表示 | 2026-06-21 / `QaSectionContainer` で `qaStatus` の `is` 分岐。`suggestedQuestions` は `Array(...SUGGESTED_QUESTIONS)`。Bridge に qa 系公開 |
| [~] | 検証: `xcodebuild` 成功 + Apple Intelligence 有効端末での round-trip はユーザー目視 | 2026-06-21 / BUILD SUCCEEDED・新規 warning ゼロ。**Apple Intelligence 有効実機での round-trip / 非対応端末で非表示 / 候補チップ / クリア / 再試行はユーザー目視** |

### Phase B-3: 対話 Q&A v2（tool calling / 生レコード参照）

> 2026-06-21 着手。digest で答えられない**個別レコード単位**の問いに対応するため、Foundation Models の `Tool` で KMP の生レコード照会（`CoffeeRecordQuery.searchRecords`）を呼ぶ。**単一の柔軟な検索 tool / filter は全 String・Double で KMP が寛容マッチ / digest 併用ハイブリッド / 既存インターフェース・VM・UI は不変の加算的変更**。確定仕様は [`requirements.md`](./requirements.md) §9-4b、インターフェース・設計判断は [`data-model.md`](./data-model.md) §1.6「対話 Q&A v2」、bridge（Swift→Kotlin calling direction / 遅延アタッチ）は [`kmp-bridge.md`](./kmp-bridge.md)、設計ログは [`implementation_note.md`](./implementation_note.md) 2026-06-21 Q&A v2 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: `CoffeeRecordQuery.searchRecords(filter)` の契約 + filter/summary モデル + 配線（遅延アタッチ）方針を docs に固定 | 2026-06-21 / requirements §9-4b・data-model §1.6・kmp-bridge・implementation_note |
| [x] | KMP（kmp-engineer）: `CoffeeRecordQuery` interface + `CoffeeRecordFilter`/`CoffeeRecordSummary` + `CoffeeRecordQueryImpl`（userId 内部解決・全件読み→filter→sort→limit）+ `AppContainer.coffeeRecordQuery` 公開 + commonTest | 2026-06-21 / shared/domain model/。limit clamp 10/100、寛容マッチ、rating=0 除外。commonTest 30 件 green |
| [x] | KMP（kmp-engineer）: XCFramework に `searchRecords(filter:) async throws -> [CoffeeRecordSummary]` が出力されるか確認 | 2026-06-21 / SKIE calling direction（witness 不要）。swiftinterface / ObjC ヘッダで確認済 |
| [x] | iOS（ios-engineer）: PoC で `recordQuery.searchRecords(...)` の SKIE async round-trip を本実装前に確認 | 2026-06-21 / Tool.call から `try await` 呼び出し・`KotlinDouble(value:)` ラップ・`Tool.Output==String` をビルドで確認 |
| [x] | iOS（ios-engineer）: `SearchCoffeeRecordsTool: Tool`（`@Generable Arguments` → `CoffeeRecordFilter`、結果を compact 行に整形）+ `generateAnswer` を tool セッション化（recordQuery 未アタッチ時は digest-only フォールバック） | 2026-06-21 / digest 併用ハイブリッド。`@preconcurrency` import で Sendable 警告抑制。ローカライズは複製（共通化は将来） |
| [x] | iOS（ios-engineer）: `AppState` で `attachRecordQuery(container.coffeeRecordQuery)` 配線 | 2026-06-21 / `makeIfAvailable()` を具象型 `CoffeeInsightProviderIosImpl?` 返しに変更し container 構築後に attach |
| [x] | 検証: KMP テスト green + `xcodebuild` 成功。Apple Intelligence 有効端末で tool 経由 round-trip をユーザー目視 | 2026-06-21 / KMP 43 件 green・`xcodebuild` BUILD SUCCEEDED・新規 warning ゼロ。**ユーザー実機確認 OK**（「ブルーボトル/フグレンで飲んだのは？」で tool 呼び出し→ヒット→回答を確認） |
| - | 実機検証で発覚し修正した点（同日） | ①平均評価 0.0 表示（`KotlinDouble?` を `String(format:)` に直渡し）→ `.doubleValue` 8 箇所補完 ②Q&A が tool を呼ばない（instructions の逃げ道 / digest 非網羅性の誤認）→ instructions 強化 ③フィールド誤分類（カフェ名を origin へ）→ KMP テキスト検索を横断寛容化。詳細は lessons.md / implementation_note 2026-06-21 |

### Phase B-4: 味覚プロファイル一致カフェのマップ連携（要件 9-5 / コンテンツベース v1）

> 2026-06-22 着手。`FavoriteSignals` のカテゴリ好みに一致する高評価記録（rating ≥ 4.0）があるカフェを「あなた好みの一杯があった店」としてマップで強調＋理由表示する。**推薦は `CafeRecommendationProvider`（interface）の裏に置き、将来の協調フィルタリング（9-6）はリモート実装の差し替えで追加**できる設計。確定仕様は [`requirements.md`](./requirements.md) 9-5、モデル・一致ルール・境界設計は [`data-model.md`](./data-model.md) §1.7、設計ログ・将来方向は [`implementation_note.md`](./implementation_note.md) 2026-06-22 B-4 / Future Direction エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: 一致ルール・新規モデル・プロバイダ境界・将来方向を docs に固定 | 2026-06-22 / requirements 9-5/9-6・data-model §1.7・implementation_note |
| [x] | KMP（kmp-engineer）: `RecommendedCafe`/`RecommendationReason`(sealed)/`PreferenceMatchAxis`/`CafeRecommendationProvider` + `ObserveTasteMatchedCafesUseCase`（ローカル実装）+ 単体テスト | 2026-06-22 / `:shared:domain` 129 件 green（新規 16）。`dominantTastingAxis` 不使用 |
| [x] | KMP（kmp-engineer）: `MapViewModel.UIState` に `recommendedCafes` + 一致 placeId 集合を追加（購読）+ `AppContainer`/`framework` 配線 | 2026-06-22 / map 7 件 green・XCFramework OK・加算的 |
| [x] | 親: kmp-engineer レポートの公開 API 差分を `kmp-bridge.md` に固定（SKIE 越えの新型） | 2026-06-22 / `onEnum(of:)`・case 全小文字・UIState 追加を記載 |
| [x] | iOS（ios-engineer）: `MapViewModelBridge` 追随 + `MapTabView` に区別ピン（アクセント色＋`heart.fill`）+ タップで理由シート + 凡例バッジ | 2026-06-22 / `RecommendationMatchSheet`。通常ピン不変。`xcodebuild` BUILD SUCCEEDED・warning ゼロ |
| [~] | 検証: KMP テスト green + `xcodebuild` 成功。シミュレータ目視（一致ピン強調 / 理由シート / データ不足時は強調なし / VoiceOver）はユーザー作業 | 2026-06-22 / KMP 129+7 green・`xcodebuild` BUILD SUCCEEDED。**目視はユーザー作業** |
| [ ] | （将来 9-6）協調フィルタリング: `CafeRecommendationProvider` のサーバ（GCP）リモート実装。横断データ基盤＋同意フローが本体 | Future Direction。未着手 |

---

## 開発支援: ダミーデータ Scheme

> 2026-06-19。分析タブ等の確認用に、専用 Xcode Scheme で起動したときだけ約 30 件のダミー `CoffeeRecord` が入るようにする。**ローカル DB のみ**（Firestore 非汚染）/ 固定 ID で冪等 / DEBUG 限定。設計判断は [`implementation_note.md`](./implementation_note.md) 2026-06-19 ダミーデータ Scheme エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | KMP: `shared/core` に `DummyCoffeeData`（固定 ID `dummy-0001`..`dummy-0030`、産地/焙煎度/抽出方法/評価/日付/カフェ有無を分散した約 30 件を生成） | 2026-06-19 / `com.noricoffee.dev.DummyCoffeeData`。`visitedOn` は `Clock.System.todayIn` から逆算（常に直近12ヶ月）。cafe 有り20件（5カフェ使い回し）/ null 10件、rating=0.0 を 2 件 |
| [x] | KMP: `AppContainer` に local-only の `seedDummyData(userId)` / `clearDummyData(userId)`（`localCoffeeRepository` 経由、Firestore に流さない） | 2026-06-19 / `@Throws suspend`。SKIE → Swift `try await ...(userId:)` |
| [x] | iOS: 共有 Scheme「iosApp (Dummy Data)」を作成（環境変数 `SEED_DUMMY_DATA=1`） | 2026-06-19 / `xcshareddata/xcschemes/` に `iosApp.xcscheme`（通常）+ `iosApp (Dummy Data).xcscheme` を明示作成・コミット。Build Config = Debug |
| [x] | iOS: `AppState.bootstrap` で `#if DEBUG` かつ uid 確定後、`SEED_DUMMY_DATA==1` なら seed / それ以外は clear | 2026-06-19 / `seedOrClearDummyData(userId:)` ヘルパ、bridge 生成前。失敗は `print` のみ（通常起動の clear で赤バナーを出さない） |
| [~] | 検証: `:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` / `xcodebuild` 成功。ダミー Scheme で 30 件・通常 Scheme で 0 件はユーザー目視 | 2026-06-19 / KMP 全ビルド + 両 Scheme `xcodebuild` BUILD SUCCEEDED、`-list` で両 Scheme 認識。**シミュレータ目視（ダミー30件 / 通常0件）はユーザー作業** |

---

## フェーズ 9: テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）

> 2026-06-20 着手。Blue Bottle「Elements of Coffee Tasting」由来の 5 要素を `CoffeeRecord.tasting: TastingScores` として追加。各要素 **1〜10 の強度（任意・未入力=null）**。総合評価 `rating`（0.5 刻み）とは別軸。分析タブに各要素の平均も反映。確定仕様は [`data-model.md`](./data-model.md) §1.1a / §1.6、設計判断は [`implementation_note.md`](./implementation_note.md) 2026-06-20 エントリ。**クリーンブレイク**（DB 列追加、マイグレーション無し。テスト端末はアプリ削除→再インストール）。

### Phase 0: docs（親）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `data-model.md`: `TastingScores`（§1.1a）+ `CoffeeRecord.tasting` + SQLDelight 5 列 + Firestore `tasting` マップ + `CoffeeStats.tastingAverages`（§1.6） | 2026-06-20 |
| [x] | `requirements.md` §3 / §9 にテイスティング要素を追加、変更履歴 | 2026-06-20 |
| [x] | `tasks.md` フェーズ 9 追加 + `implementation_note.md` 設計判断 | 2026-06-20 |

### Phase 1: KMP（kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/domain`: `TastingScores`（5 要素 `Int?`）+ `CoffeeRecord.tasting: TastingScores` | 2026-06-20 / `TastingScores.kt` + `CoffeeRecord` 引数追加 |
| [x] | `shared/data-local`: `CoffeeRecord.sq` に 5 列（INTEGER nullable）+ `upsert` 更新、`Mapper` 往復、テスト（部分入力・全 null の往復ケース） | 2026-06-20 / SQLDelight は INTEGER→`Long?` 生成のため Mapper で `toInt`/`toLong` 変換。往復テスト 2 件追加 |
| [x] | `shared/core`: `BuildCoffeeStatsUseCase` に `tastingAverages`（各要素 null 除外平均 + ratedCount）+ テスト。`CoffeeStats` に `TastingAverages` / `TastingRatedCount` | 2026-06-20 / 新規 3 テスト |
| [x] | `shared/core`: `DummyCoffeeData` の 30 件に tasting を分散付与（一部要素 null も混ぜる） | 2026-06-20 / 約 22 件に設定（部分入力含む） |
| [x] | `shared/feature/coffee-editor`: `CoffeeEditorViewModel` の draft に tasting + 各要素セッター + バリデーション（設定値は 1..10） | 2026-06-20 / 個別 5 本（`onSweetnessChanged(Int?)` 等）+ バルク `onTastingChanged(TastingScores)`。範囲外は `coerceIn(1,10)` クランプ |
| [x] | `shared/data-firebase`（androidMain）: `CoffeeFirestoreMapper` に `tasting` マップ（非 null のみ書き出し / 全 null は省略 / decode 補完） | 2026-06-20 / `tastingToMap`/`tastingFromMap` |
| [x] | 検証: `:shared:domain:test` / `:shared:data-local:testAndroidHostTest` / `:shared:core:test` / `:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` 全成功 | 2026-06-20 / domain 34 / data-local 21 / account 12 green、XCFramework + androidApp 成功。ヘッダに `TastingScores`/`tastingAverages`/セッター確認 |

### Phase 2: iOS（ios-engineer, Phase 1 完了後）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CoffeeEditorView`: テイスティング 5 要素のスライダー入力 UI（1..10、未設定トグル/クリア可）+ Bridge 追随 | 2026-06-20 / `+`/`×` ボタンで未設定↔設定、ON 時のみスライダー（初期値 5）。`accessibilityAdjustableAction` 対応。Form 順=カフェ→コーヒー→テイスティング→記録→写真 |
| [x] | `CoffeeDetailView`: 5 要素の表示（設定済みのみ or 未設定明示） | 2026-06-20 / `TastingScoreBar`（バー+数値）、設定済みのみ表示。全未設定はセクション非表示 |
| [x] | `FirebaseRepositories/CoffeeFirestoreMapper.swift`: `tasting` マップの read/write 追随 | 2026-06-20 / `tastingToMap`/`tastingFromMap`、Android と対称（非null のみ/全null省略/欠如補完） |
| [x] | `AnalysisView`: テイスティング 5 要素の平均を可視化（棒 or レーダー風）+ `CoffeeInsightProviderIosImpl` の prompt に平均を追加 | 2026-06-20 / 横棒グラフ（母数>0 のみ、`chartXScale 0...10`）。prompt に平均 1 行追記 |
| [x] | `PreviewSamples` / 各 `#Preview` に tasting を追随 | 2026-06-20 / `CoffeeRecord` 3 件 + `CoffeeStats` 追随 |
| [~] | 検証: `xcodebuild -sdk iphonesimulator` 成功。シミュレータ目視はユーザー作業 | 2026-06-20 / BUILD SUCCEEDED・新規 warning ゼロ。**シミュレータ目視（入力/未設定切替/詳細/分析グラフ/round-trip/VoiceOver）はユーザー作業。DB 列追加のためアプリ削除→再インストール必須** |

---

## フェーズ 9.1: テイスティングを all-or-nothing 化（5 要素必須）

> 2026-06-20。フェーズ 9 の「各要素独立 nullable」を「テイスティングを付けるなら 5 要素必須」に変更。型で partial を表現不可能にする（`TastingScores` の 5 フィールドを非 null、`CoffeeRecord.tasting` を nullable）。UX は `+` で 5 スライダー一括表示・削除で null。確定仕様は [`data-model.md`](./data-model.md) §1.1a、判断は [`implementation_note.md`](./implementation_note.md) 2026-06-20 all-or-nothing エントリ。**クリーンブレイク**（再インストール）。

### Phase 1: KMP（kmp-engineer）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared/domain`: `TastingScores` の 5 フィールドを `Int?` → `Int`（非 null）、`CoffeeRecord.tasting` を `TastingScores?` に | 2026-06-20 |
| [x] | `shared/data-local`: `Mapper` を「5 列全セット→`TastingScores` / それ以外→null」に。`upsert` は `tasting?.x` を渡す。テスト（あり/なし往復） | 2026-06-20 / 5 列は nullable のまま。LocalCoffeeRepositoryTest 13 件 |
| [x] | `shared/core`: `BuildCoffeeStatsUseCase` を `tasting != null` の記録のみ集計に。`TastingAverages.ratedCount` を単一 `Int` 化、`TastingRatedCount` 削除。テスト追随 | 2026-06-20 |
| [x] | `shared/core`: `DummyCoffeeData` を「tasting あり（5要素）/ null」の二択に（部分入力を排除） | 2026-06-20 / 部分入力を 5 要素補完 or null 化 |
| [x] | `shared/feature/coffee-editor`: セッターを非 null Int 化 + `onTastingAdded()`（デフォルト 5 で生成）/ `onTastingCleared()`（null）追加。draft 初期化追随 | 2026-06-20 / `onTastingChanged(TastingScores)` は削除。個別セッターは tasting==null で no-op |
| [x] | `shared/data-firebase`（androidMain）: `CoffeeFirestoreMapper` を「tasting!=null で 5 要素マップ / null 省略」に | 2026-06-20 |
| [x] | 検証: domain/data-local/core テスト + XCFramework + androidApp assembleDebug 全成功 | 2026-06-20 / 全 green、ヘッダで非null/optional/ratedCount:Int/TastingRatedCount削除を確認 |

### Phase 2: iOS（ios-engineer, Phase 1 完了後）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CoffeeEditorView`: 個別 +/× を廃止し、`tasting==nil` 時は「+ テイスティングを追加」1 ボタン → 押下で 5 スライダー一括表示。削除ボタンで nil | 2026-06-20 / Bridge を `onTastingAdded`/`onTastingCleared` + 非 null `Int32` セッターに追随。`accessibilityAdjustableAction` 維持 |
| [x] | `CoffeeDetailView` / `AnalysisView` / `CoffeeFirestoreMapper.swift` / `PreviewSamples` を新 API（`tasting: TastingScores?` / 非 null フィールド / `ratedCount: Int`）に追随 | 2026-06-20 / Detail は `if let tasting` で 5 要素表示。Mapper は tasting!=nil で 5 要素マップ / read は 5 要素揃えば `TastingScores` 否なら nil |
| [x] | 検証: `xcodebuild` 成功。シミュレータ目視はユーザー作業 | 2026-06-20 / 親が BUILD SUCCEEDED 確認（新規 warning ゼロ）。**シミュレータ目視（+で5スライダー一括/削除/詳細/分析/round-trip）はユーザー作業。DB は再インストール必須** |

---

## フェーズ 10: マップ拡充

> 起票 2026-06-29。マップの視認性・情報密度・フィルタリングを強化する。

### 10-A: ピンデザイン改善

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 訪問済みピンのサイズ・カラー・アイコンを再設計（視認性向上。ズームレベルに応じたクラスタリング検討） | 2026-06-29 / 32pt→36pt 拡大・shadow 追加・訪問回数バッジ（2回以上で右上バッジ・9+上限）。クラスタリングは MapKit SwiftUI API 未対応のため将来課題。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-29 エントリ |
| [x] | 好み一致ピン（B-4 `heart.fill`）との差別化を確認し、3 種（訪問済み / 周辺 / 好み一致）のビジュアル体系を整理 | 2026-06-29 / 3 種: 訪問済み（36pt 茶 + カップ + 回数バッジ）/ 好み一致（38pt アクセント + ハート・既存）/ Apple Maps 標準 POI（変更なし） |

### 10-B: カフェ詳細画面の情報拡充

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | Places API New v1 の追加フィールド取得: 営業時間 (`currentOpeningHours`)・電話番号 (`nationalPhoneNumber`)・Google Maps URL (`googleMapsUri`)・価格帯 (`priceLevel`)・評価 (`rating`) | 2026-06-29 / `FIELD_MASK` / `DETAILS_FIELD_MASK` に追加。`Dto.kt`・`PlaceSummary.kt` を更新 |
| [x] | Places API「メニュー」: `websiteUri` + 関連 url をカフェ詳細に表示（Places API はメニューを直接返さないため、公式 URL をリンクとして掲載） | 2026-06-29 / `CafeDetailView` に「外部リンク」セクション追加（公式サイト / Google Maps）|
| [x] | `CafeDetailView` に営業時間・電話番号・価格帯・外部リンク（Google Maps / Website）のセクションを追加 | 2026-06-29 / 営業状態（緑/赤 dot）・Google 評価・価格帯（¥〜¥¥¥¥）・電話（`tel:` Link）・外部リンクセクション・営業時間セクション。**シミュレータ目視はユーザー作業** |
| [x] | `PlaceSummary` / `Cafe` ドメインモデルに上記フィールドを追加（optional）。`data-model.md` 更新 | 2026-06-29 / `Cafe` に 5 フィールド追加（デフォルト値付き）。SQLDelight スキーマは変更なし（Places API 結果のみで利用）|

### 10-C: 検索結果カフェをマップにオーバーレイ表示

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 検索タブで検索実行後、結果カフェをマップタブのピンとして表示できる仕組みを設計（AppState 経由 or MapViewModel に検索結果フィード） | 2026-06-29 / AppState 経由（`updateMapSearchResults`/`clearMapSearchResults`）で MapViewModelBridge に委譲。明示ボタン方式（自動反映なし） |
| [x] | `MapViewModel.UIState` に `searchResultPlaces: List<Cafe>` を追加し、検索結果ピン（別色 / 別アイコン）として描画 | 2026-06-29 / 青 32pt Circle + `mappin.and.ellipse`。タップで CafeDetailView へ push |
| [x] | `CafeSearchView` で「マップに表示」アクションを追加（検索結果をマップタブへ転送）またはマップタブで自動反映 | 2026-06-29 / ルートモードかつ結果あり時のみ toolbar left に「マップに表示」ボタン表示。クエリ変化時に自動クリア。**シミュレータ目視はユーザー作業** |

### 10-D: お気に入りタグフィルター

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CoffeeRecord` / `VisitedCafe` にユーザー定義タグ（`List<String>`）を追加。`data-model.md` 更新 | 2026-06-29 / `CoffeeRecord.tags: List<String> = emptyList()`。クリーンブレイク（DB 削除→再インストール必須） |
| [x] | KMP: タグの CRUD（`CoffeeEditorViewModel` でタグ追加・削除）+ SQLDelight スキーマ更新 | 2026-06-29 / `onTagAdded/onTagRemoved`。JSON 文字列で保存（`photoRefsSerializer` 流用） |
| [x] | `MapViewModel` にタグフィルター状態を追加（選択タグにマッチする訪問済みカフェのみ表示） | 2026-06-29 / `UIState.selectedTags/availableTags`。`onTagFilterToggled/Cleared()`。`coffeeRepository` を DI |
| [x] | `MapTabView` のフィルタ行にタグ選択 UI（チップ or ドロップダウン）を追加 | 2026-06-30 / フィルタ行を `ScrollView(.horizontal)` でラップ。タグチップ + クリアボタン |
| [x] | `CoffeeEditorView` にタグ入力 UI を追加 | 2026-06-30 / テイスティングセクション後に「タグ」セクション。入力 TextField + 追加ボタン + 削除 xmark |

---

## フェーズ 11: コーヒー記録テンプレート / カスタムフィールド ※保留

> 起票 2026-06-29。2026-06-29 全保留。優先度が上がった時点で再検討。

### 11-A: 記録テンプレート

| 状態 | タスク | 備考 |
|------|------|------|
| [-] | テンプレートのデータモデルを設計（`RecordTemplate`: name / defaultBeans / defaultBrewMethod / defaultTastingEnabled / customFields 等）。`data-model.md` に追記 | |
| [-] | KMP: `RecordTemplate` ドメインモデル + `TemplateRepository` + SQLDelight スキーマ | |
| [-] | `CoffeeEditorViewModel` にテンプレートから draft を初期化するフロー追加（`onTemplateSelected(template)`） | |
| [-] | iOS: テンプレート選択 UI（`CoffeeEditorView` 上部のシート、またはコーヒー記録追加 FAB タップ時に選択） | |
| [-] | iOS: テンプレート管理画面（作成・編集・削除・並び替え） | 設定タブまたは独立タブ |

### 11-B: カスタムフィールド

| 状態 | タスク | 備考 |
|------|------|------|
| [-] | カスタムフィールドのデータモデルを設計（`CustomField`: id / title / type(text/number/select) / value）。`data-model.md` に追記 | |
| [-] | KMP: `CustomField` ドメインモデル + `CoffeeRecord.customFields: List<CustomField>` 追加 + SQLDelight（JSON 列 or 別テーブル）+ Firestore スキーマ更新 | |
| [-] | `CoffeeEditorViewModel` にカスタムフィールド CRUD メソッドを追加 | |
| [-] | iOS: `CoffeeEditorView` にカスタムフィールドセクション（フィールドタイトル・値を動的に追加/削除） | |
| [-] | iOS: `CoffeeDetailView` にカスタムフィールドの表示 | |
| [-] | カスタムフィールドの定義を「ユーザー定義フィールドマスタ」として保存し、次回以降の記録でも再利用できる設計にするか検討 | ユーザー判断待ち |

---

## フェーズ 12: コミュニティ / データ共有基盤

> 起票 2026-06-29。個人の記録を（同意を得た上で）集合知として活用し、①全ユーザーの好み傾向分析、②コーヒー豆ナレッジベースとの突合、③協調フィルタリングによるカフェ推薦、を実現する。B-4（好み一致カフェ・ローカル実装）の将来版（9-6 協調フィルタリング）と連動する。**サーバー側インフラが必要なため、設計・同意フロー・プライバシー申告の確定が着手の前提。**

### 12-A: データ共有同意フロー（前提）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | プライバシーポリシー更新（記録データをサービス改善に使用する旨の明記） | App Store 提出前に必須 / ユーザー作業 |
| [x] | アプリ内同意 UI 設計・実装（初回起動時にオンボーディング画面で同意取得） | 2026-06-30 完了。`DataConsentOnboardingView`（初回起動シート）+ SettingsView トグル。URL プレースホルダーは App Store 提出前に差し替え必要 |
| [x] | `AuthRepository` / `AuthAccount` に `analyticsConsent: Boolean` フラグを追加。`users/{uid}` Firestore ドキュメントへ保存 | 2026-06-30 完了（KMP: kmp-engineer / iOS: 親が直接実装） |
| [x] | Firestore Security Rules 更新（`users/{uid}` ルートドキュメント明示 + 将来の集計コレクション向けは 12-B 以降） | 2026-06-30 完了。2026-07-01 デプロイ済み |

### 12-B: コーヒー豆ナレッジベース（サーバー管理データ）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 豆ナレッジベースのデータモデル設計（`BeanProfile`: origin / variety / processings / flavorNotes / description）。`data-model.md` に追記 | 2026-06-30 / `§1.8 BeanProfile` 追記。`beanProfileId` 紐付けなし・ファジーマッチ方式を採用。`referenceRating` は除外（スコアリングに使わないため） |
| [x] | Firestore `beanProfiles` コレクション設計・Security Rules 更新 | 2026-06-30 / `firestore.rules` + `data-model.md §3.1/3.2/3.3` 更新完了。初期データ投入はユーザー作業（Firebase Console / Admin SDK） |
| [x] | KMP: `BeanProfile` ドメインモデル + `BeanProfileRepository` インターフェース + `BeanProfileMatchUseCase` + Android Firestore 実装 + `AppContainer` 統合 | 2026-06-30 / `shared/domain:testAndroidHostTest` 7件 green。`androidApp:assembleDebug` / `compileKotlinIosSimulatorArm64` 成功。`fetchBeanSuggestions` 拡張関数を `AppContainerViewModelFactory.kt` に追加 |
| [x] | `CoffeeRecord.beanProfileId` で紐付ける設計にするか、`origin`+`process` のファジーマッチにするか方針確定 | 2026-06-30 / **ファジーマッチ採用**（origin trim/lowercase + processings enum 名）。`CoffeeRecord` に ID フィールドは追加しない |
| [x] | iOS: `BeanProfileRepositoryIosImpl` + `CoffeeEditorView` origin/variety サジェスト UI | 2026-06-30 / `BeanProfileRepositoryIosImpl.swift` 新規（Firestore one-shot get + メモリキャッシュ）。`AppState.swift` を 6引数 AppContainer に更新。`CoffeeEditorView` に origin VStack 展開サジェスト追加。**BUILD SUCCEEDED（warning 増加なし）。実機での動作確認はユーザー作業（Firestore beanProfiles データ投入後）** |

### 12-C: 個人好みと豆ナレッジの突合・言語化

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `FavoriteSignals` と `BeanProfile.flavorNotes` を突合し「あなたが好みやすい豆の特徴」を導出するロジック設計 | 2026-07-01 / `PreferredBeanTraitsUseCase`（origin ファジーマッチ + flavorNotes 頻度集計 top-5）。`ObserveCoffeeStatsUseCase` に `BeanProfileRepository?` 注入で統計 Flow に突合結果を付加 |
| [x] | KMP: 突合ロジック実装（`PreferredBeanTraitsUseCase`）+ `CoffeeStats` への追加 | 2026-07-01 / `domain:testAndroidHostTest` 全件 green（+5件）。`CoffeeInsightProvider` に `summarizeBeanTraits` 追加。`AnalysisViewModel.UIState` に `beanTraitsInsight` / `beanTraitsInsightStatus` 追加。詳細は [`implementation_note.md`](./implementation_note.md) 2026-07-01 エントリ |
| [x] | iOS: 分析タブに「好みの豆の傾向」セクションを追加（Foundation Models で言語化） | 2026-07-01 / `CoffeeInsightProviderIosImpl` に `__summarizeBeanTraits` 追加。`AnalysisView` に `preferredBeanTraitsSection` 追加（FM 可用時: 言語化テキスト / 不可時: フレーバータグ表示）。BUILD SUCCEEDED（新規 warning ゼロ）。**実機確認はユーザー作業（Apple Intelligence 対応端末 + Firestore beanProfiles データ投入後）** |

### 12-D: 協調フィルタリング（B-4 将来版 / 9-6）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | サーバーサイド基盤設計（GCP Cloud Run / Cloud Functions + Firestore 集計パイプライン） | インフラ選定・コスト見積もりが前提 |
| [ ] | ユーザー間好み類似度計算ロジック設計（コサイン類似度 / ピアソン相関 on `FavoriteSignals` ベクトル） | |
| [ ] | `CafeRecommendationProvider` のサーバーリモート実装（既存ローカル実装と差し替え可能な設計は B-4 で済み）| B-4 の将来 9-6 エントリと連動 |
| [ ] | iOS: マップ上の好み一致ピン（B-4）を協調フィルタリング結果に差し替え（フラグ制御で A/B 切替可能な設計） | |
| [ ] | 全体データを使った「このカフェを好む人は○○傾向」などのコミュニティ統計を分析タブに追加 | |

---

## フェーズ 13: 自然言語好み検索（逆方向変換応用）

> 起票 2026-06-29。iOSDC LT 逆方向 PoC（`TastePreferenceExtractor`）を実用機能として昇格させる。「こんなコーヒーが飲みたい」という自然言語を 5 軸スコア（甘味/ボディ/酸味/風味/後味）+ 属性（焙煎度/抽出法等）に変換し、**記録検索・カフェ推薦・カフェ検索**に活用する。Foundation Models を使う部分は iOS 限定。KMP 側は変換後の数値プロファイルで動作するため非 AI 端末でも機能する。実装の前提として `TastePreferenceExtractor` を `#if DEBUG` から本番昇格する。

### 13-A: 基盤（`TastePreferenceExtractor` 本番昇格 + フィルタ拡張）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `TastePreferenceExtractor` を `#if DEBUG` から外し、`CoffeeInsightProviderIosImpl` と同じく `SystemLanguageModel.availability` ガードに切り替える（非対応端末は UI を非表示） | 確認済：元々 `#if DEBUG` なし。`makeIfAvailable()` パターンで実装済み |
| [x] | KMP: `CoffeeRecordFilter` にテイスティングスコア範囲条件（`tastingMin` / `tastingMax`: `TastingScores?`）を追加し、`CoffeeRecordQueryImpl` の絞り込みロジックを拡張。`commonTest` 追加 | 2026-06-30 / `shared:domain:testAndroidHostTest` 48 件 green（+5件）。`tastingMin/Max` 指定時に `tasting==null` のレコードを除外。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-30 エントリ |
| [x] | iOS: `TastePreference`（逆変換結果）→ `CoffeeRecordFilter` に変換するマッピングヘルパを実装（5 軸スコアを範囲条件に変換、属性は `roastLevel` に変換） | 2026-06-30 / `TastePreference+Filter.swift` 新規。±2 margin で `TastingScores` min/max を生成。`roast=="unknown"` → `roastLevel: nil` |

### 13-B: コーヒー記録の自然言語検索（Q&A との統合）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | Q&A（B-2/B-3）の `generateAnswer` で「こんな味の記録を探して」系の質問を検出したとき、`TastePreferenceExtractor` で変換 → `CoffeeRecordFilter`（テイスティング範囲）で `searchRecords` を呼ぶ拡張 tool を追加 | 2026-06-30 / `SearchByTasteProfileTool.swift` 新規。`CoffeeInsightProviderIosImpl.generateAnswer` に `SearchCoffeeRecordsTool` と並列で登録。キーワード検索 vs テイスティング類似検索は LLM が判断 |
| [x] | iOS: 分析タブに「好みで記録を探す」専用 UI を追加（自由テキスト入力 → 5 軸カード表示 → 条件に合う記録一覧）。Q&A とは独立した導線 | 2026-06-30 / `TastePreferenceConversionView` を本番 UI に昇格（タイトル変更・`coffeeRecordQuery` DI・検索結果表示）。`AnalysisView` の導線を Foundation Models 非対応端末では非表示 + ラベル更新。**xcodebuild BUILD SUCCEEDED（新規 warning ゼロ）。実機での動作確認はユーザー作業** |

### 13-C: マップ上のカフェ推薦への応用

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 設計: ViewModel レベルで絞り込む方針を確定。`MapViewModel.UIState` に `tasteMatchedPlaceIds`・`activeTastingMin/Max` を追加 | 2026-06-30 / `CafeRecommendationProvider` は変更せず、`MapViewModel` 側でテイストフィルタを管理する設計を採用 |
| [x] | KMP: `MapViewModel` に `onTasteProfileChanged(TastingScores?, TastingScores?)` + `applyTasteFilter()` を追加。`UIState.tasteMatchedPlaceIds` でマッチカフェ集合を公開 | 2026-06-30 / `testAndroidHostTest` 全件 green |
| [x] | iOS: マップタブフィルタ行に「好みで絞り込む」チップ追加（Foundation Models 非対応端末は非表示）→ `TasteMapFilterSheet` でテキスト入力 → 変換 → フィルタ適用。非マッチピンを opacity 0.25 に半透明化 | 2026-06-30 / BUILD SUCCEEDED。**実機確認はユーザー作業（Apple Intelligence 対応端末が必要）** |

### 13-D: カフェ検索タブへの統合

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 設計: フェーズ10で検索タブ廃止済みのため、マップ上部検索バーへの統合として実装。補完クエリ方式（A 案）を採用 | 2026-06-30 / Places API の限界は承知の上で「新カフェ発見の補助機能」として実装 |
| [x] | iOS: マップ検索バーに「✨」ボタン追加（Foundation Models 非対応端末は非表示）→ `TasteSearchSheet` でテキスト入力 → `TastePreference.searchKeywords` で補完クエリ生成 → 検索クエリに付加して Places API 検索実行 | 2026-06-30 / BUILD SUCCEEDED。**実機確認はユーザー作業** |

---

## フェーズ 14: マップ検索の使い勝手改善（表示範囲ピン表示）

> 起票 2026-07-01。現状のマップ検索は「テキスト検索 → ドロップダウンのリスト → 1 件選択で単一ピン + カード」で、複数候補が同時にピン表示されない。Google Maps 風に **表示範囲内のカフェ候補を一括ピン表示**できるようにして発見体験を改善する。
>
> **product 決定（2026-07-01 / ユーザー確認済）**:
> - エリア検索の起動 = **「このエリアを検索」ボタン**（地図をパン/ズーム後に上部に出現。自動再検索はしない＝ Places API の課金/発火頻度を制御）
> - テキスト検索の結果 = **全件ピン + ドロップダウンリスト併用**（ピンで位置感、リストで一覧比較）
>
> **既存部品（再利用）**: `CafeRepository.searchNearby(lat,lng,radius)`（`includedPrimaryTypes=[cafe,coffee_shop]` / `rankPreference=DISTANCE` / **最大 20 件**）、`CafeSearchViewModel.onNearbySearchRequested`、`MapViewModel.onSearchResultsUpdated/Cleared`（`searchResultPlaces` → 青ピン描画）、`.onMapCameraChange` の表示範囲 → 中心座標 + 半径算出（`appState.mapSearchCenter`）。
>
> **制約**: Places API (New) の Nearby/Text は 1 回あたり最大 20 件。密集エリアでは 20 件で頭打ち（仕様上の上限。UI に「さらに拡大して検索」等の含意は持たせない）。

### 14-A: KMP — 半径指定のエリア検索

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CafeSearchViewModel` に半径を渡せるエリア検索を追加。SKIE がデフォルト引数を出さないため `onNearbySearchRequested(latitude, longitude, radiusMeters)` のオーバーロードを新設し `CafeRepository.searchNearby(lat,lng,radiusMeters)` に委譲（既存の 2 引数版は残す） | 2026-07-01 完了（kmp-engineer）。`cafe-search:testAndroidHostTest` green（新規 3 件）+ `compileKotlinIosSimulatorArm64` 成功。既存 2 引数版は後方互換で維持。Bridge に `onNearbySearchRequested(latitude:longitude:radiusMeters:)` 追加は 14-C で iOS 側対応 |

### 14-B: iOS — テキスト検索結果を全件ピン表示

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `performMapSearch` の結果到着後、`mapBridge.onSearchResultsUpdated(sb.results)` で**全候補**をピン表示（現状は選択 1 件のみ）。ドロップダウンリストは併存 | 2026-07-01 完了。検索完了検知を `searchBridge.isLoading` の false 遷移 → `handleSearchCompletion` に一本化（テキスト/エリア共通）。`hasSearched && error==nil` で push |
| [x] | `selectSearchResult` を「全ピンを残したまま該当カフェのカードを出す」挙動に変更（現状は `onSearchResultsUpdated([cafe])` で 1 件に潰している）。ピン集合＝全結果 / 選択＝カード の関心分離 | 2026-07-01 完了。カード×/「詳細を見る」からも `onSearchResultsCleared()` を削除しピンを残す（Google Maps 的挙動）。検索バー×のみ全消去 |

### 14-C: iOS —「このエリアを検索」ボタン（エリア検索）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 検索バー下に floating pill「このエリアを検索」を追加。地図の中心が前回検索位置から一定以上動いた / ズーム変化したときに出現、検索後は次のパンまで非表示 | 2026-07-01 完了。`shouldShowAreaSearchButton`: 中心移動 > アンカー半径の 30% OR 半径比 1.5x 逸脱。初回カメラ確定時はベースライン採用のみ（起動直後は非表示）。しきい値の経緯は implementation_note 2026-07-01 |
| [x] | ボタンタップ → `searchBridge.onNearbySearchRequested(center.lat, center.lng, center.radiusMeters)`（14-A）→ 結果を `mapBridge.onSearchResultsUpdated(results)` で全ピン表示。ローディング表示あり | 2026-07-01 完了。`isAreaSearchInFlight` で完了経路を判別。検索中はボタンをスピナー化、完了後アンカー更新+非表示 |
| [x] | 0 件時のフィードバック（「このエリアにカフェが見つかりませんでした」）とエラー時のトースト | 2026-07-01 完了。`activeToast` の優先順位チェーンに `searchBridge.error`（失敗）と `areaSearchEmptyMessage`（0 件、4 秒自動消去）を追加。既存 `ErrorToast` 再利用 |
| [x] | 追従修正: 検索結果リストと「このエリアを検索」ボタンの重なりを解消し「検索モード」化 | 2026-07-01 完了。`@FocusState` + `showingSearchResults` で `isSearchMode` 判定。検索モード中は `filterChipRow`（訪問済み/タグ等）を非表示、結果リストを検索バー直下の同一 VStack に流し込み（固定オフセット `height:120` 撤廃）。×/空クエリ/結果選択でブラウズ復帰。BUILD SUCCEEDED |
| [x] | 追従修正: 「このエリアを検索」ボタンを「検索モード＋パン後のみ」表示に変更 | 2026-07-01 完了。ブラウズ中は非表示、検索モードでパン/ズーム後に検索バー直下へ表示（`isSearchMode && showAreaSearchButton`）。パン検知はモード非依存で継続、表示側で `isSearchMode` を掛ける。BUILD SUCCEEDED |

### 14-D: 検証

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `shared:feature:cafe-search` の commonTest green + `assembleSharedLogicXCFramework` 成功（KMP） | 2026-07-01 / commonTest green、`compileKotlinIosSimulatorArm64` 成功（framework ファクトリ変更不要のため umbrella 再ビルドは不要と判断） |
| [x] | iOS: xcodebuild BUILD SUCCEEDED（新規 warning ゼロ） | 2026-07-01 / `DEVELOPER_DIR=Xcode-beta` で実ビルド成功。SourceKit の `No such module SharedLogic` はインデックス由来ノイズ（実ビルドは通過） |
| [ ] | 実機/シミュレータで「このエリアを検索」→ 複数ピン、パン後のボタン再出現、テキスト検索の全件ピン + リストを目視確認 | **ユーザー作業**（実 Places API キー必要） |

---

## docs 棚卸し（2026-07-02）

> 2026-07-02 の docs 全体精査で検出した「実装と docs の齟齬」のうち、重大 4 件を修正する。精査の詳細は本セクション起票時の親セッションログ参照。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `data-model.md` をフェーズ 10 / 12-C に追随（`CoffeeRecord.tags` / `Cafe` 追加 5 フィールド / `CoffeeStats.preferredBeanTraits` + `PreferredBeanTraits` / `CoffeeInsightProvider.summarizeBeanTraits`。SQLDelight / Firestore 表現も追随） | 2026-07-02 / `Cafe` の 5 フィールドは「永続化しない表示用」の注記付きで追記（実装事実: Mapper / スキーマとも書き出しなし） |
| [x] | `kmp-bridge.md` の「data-firebase は export 対象に含めない」記述を実体（export に含める）に修正し architecture.md と整合 | 2026-07-02 / `shared/framework/build.gradle.kts` を真とする旨も明記 |
| [x] | `app-store-metadata.md` を CoffeeRecord 主体モデルへ全面改訂（説明文 / スクショ計画 / 審査メモ / プライバシー申告。Sign in with Apple・analyticsConsent・分析タブを反映） | 2026-07-02 / 原稿は引き続き下書き扱い（サブタイトル / カテゴリ / メールアドレス申告要否はユーザー確定が必要）。詳細は同ファイル変更履歴 |
| [x] | `implementation_note.md`「現在生きてる方針サマリ」を現状（CoffeeRecord / 4 タブ / AppContainer 6 引数 / 12-A〜14 の生きてる方針）に更新 | 2026-07-02 / サマリに「最終棚卸し」日付を導入。経緯は implementation_note 2026-07-02 エントリ |

| [x] | `coding-conventions.md` / `kmp-bridge.md` の旧モデル例文を CoffeeRecord 系へ更新（削除済み型の例・`case hadDrip` typo・「追加予定」等の陳腐化記述・runCatching を教える例文の是正を含む） | 2026-07-02 / §1.7 は try/catch + `CancellationException` 再スローのパターンに書き換え（2026-06-24 方針の昇格）。ViewModel 構造例に所有 viewModelScope + `clear()`、Bridge 例に `deinit { kotlin.clear() }` を反映。architecture.md のエラーハンドリング節・状態管理サンプルの runCatching も是正 |
| [x] | CLAUDE.md / `architecture.md` の feature 列挙に `account` / `analysis` を追加、CLAUDE.md の data-firebase 旧クラス名を現行名に修正 | 2026-07-02 |

> 精査で検出した残りの低優先残件（ui-ux-guidelines の Visit 系旧用語・FAB 等の新 UI パターン未記載、backlog ID「B-4」と Phase B-4 の名前衝突、implementation_note のエントリ形式ゆれ、tasks.md フェーズ 6 の実装済み項目整理など）は未着手。必要になったら下の設計判断バックログへ起票する。

---

## iosApp コードレビュー指摘対応（2026-07-03）

> 2026-07-03 の iosApp 全件コードレビューで検出した高優先 5 件（#1〜#5）の修正。すべて Swift / iosApp 完結。レビュー全文は親セッションログ参照。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | #1 CafeDetailView: `.onDisappear { bridge?.cancel() }` を撤去し、observation を Bridge deinit まで生かす（push→pop 後の凍結バグ。kmp-bridge.md 2026-06-25 の既知パターン） | 2026-07-03 完了。呼び出し元が消えた `cancel()` も削除。既知パターン再発の教訓は lessons.md 2026-07-03 |
| [x] | #2 AccountView: `observeProcessingCompletion` のポーリング競合を解消（`isProcessing` の true 遷移を待ってから false を待つ。ロジックは Bridge 側へ移動） | 2026-07-03 完了。`AccountViewModelBridge.awaitProcessingCompletion()`（二相待ち）。残存する理論上の穴と根治条件は implementation_note 2026-07-03 |
| [x] | #3 AppState: `bootstrap()` に再入ガードを追加（`resetAndRebootstrap` と AppRootView `.task` の二重実行防止） | 2026-07-03 完了。`guard status != .signingIn` |
| [x] | #4 AppState: 初回同意オンボーディングチェックが `.task` キャンセルで消える timing バグの解消（`uid` / `status` の公開を bootstrap 完了後に遅延） | 2026-07-03 完了。「観測される状態の公開は bootstrap 末尾」原則は implementation_note 2026-07-03 |
| [x] | #5 CoffeeListView: スワイプ削除の写真物理削除を「レコード削除が state に反映された後」に移動（順序逆転バグ + View 内業務ロジックの Bridge への移動） | 2026-07-03 完了。`pendingPhotoDeletions` 方式（孤児ファイル < 写真消失の安全側）。implementation_note 2026-07-03 |
| [ ] | 実機 / シミュレータで目視確認: CafeDetail push→pop 後の一覧更新、サインアウト/削除時のオーバーレイと完了処理、初回同意シート表示、スワイプ削除失敗時の写真残存 | **ユーザー作業**。ビルドは 2026-07-03 に BUILD SUCCEEDED 済（新規 warning ゼロ） |

---

## shared コードレビュー指摘対応（2026-07-03）

> 2026-07-03 の shared/ 全モジュールコードレビューで検出した高優先 3 件の修正。すべて KMP / shared 完結（iosApp 変更なし。公開 API は非破壊）。仕様は `data-model.md` §2.2 注記 / §4.2 と `architecture.md` データフロー（読み取り）に確定済み。レビュー全文は親セッションログ参照。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | #1 リモート削除のローカル伝播: `CoffeeRepositoryImpl.startSync` にスナップショット reconciliation を追加（スナップショットに無い id のローカル行を削除。`DummyCoffeeData.ids` はローカル専用のため除外） | 2026-07-03 完了。テスト 2 件追加（削除伝播 / ダミー除外）、`testAndroidHostTest` 10 件 green + iosSimulatorArm64 コンパイル確認 |
| [x] | #2 エディタの cafe 座標欠落: `CoffeeEditorViewModel` が Places 選択済み `Cafe` を丸ごと内部保持（`selectedCafe`）し、保存時に placeId / latitude / longitude / photoReferences を引き継ぐ。`onAppear` で選択状態をリセット | 2026-07-03 完了。cafe 組み立てを `buildCafe()` に集約。テスト 5 件新設（`CoffeeEditorViewModelTest`、feature/coffee-editor 初の commonTest）。iOS 側変更なし（`selectedPlaceId` は派生値として互換維持）。既存レコードの座標は次回保存時まで null のまま（最新値勝ち仕様） |
| [x] | #3 FOREIGN KEY 有効化: 本番 `DatabaseDriverFactory`（android / ios）で FK 制約を有効化し `ON DELETE CASCADE` を機能させる。孤児 photo 行を掃除する migration `2.sqm` を追加。iOS の `TestSqlDriver` も FK ON に揃える | 2026-07-03 完了。`testAndroidHostTest` / `verifySqlDelightMigration` green。iosSimulatorArm64Test は親セッションで `DEVELOPER_DIR=Xcode-beta` 指定により実行し、cascade テスト green + FK OFF に戻すと FAILED になる赤→緑を確認（= 従来 iOS では cascade テストが成立していなかった仮説を実証） |
| [ ] | シミュレータ / 実機で目視確認: 記録作成 → マップに訪問済みピンが立つ / Firestore コンソールで記録削除 → ローカル一覧から消える | **ユーザー作業** |

---

## サブエージェント定義の改善（2026-07-04）

> `.claude/agents/*.md` の陳腐化解消（旧 sharedLogic 記述 / 実在しない Gradle タスク名）+ lessons 未反映の再発防止ルールの取り込み + 2026 年時点の公式機能（`memory` / `skills` プリロード / frontmatter `hooks`）の採用。判断の詳細は [`implementation_note.md`](./implementation_note.md) 2026-07-04 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 書き込みスコープ強制フック `.claude/hooks/validate-write-scope.sh` を新設（PreToolUse で Edit/Write の対象パスを許可リスト照合、違反は exit 2） | 2026-07-04 完了。単体テスト 13 ケース green（スコープ内外 / agent-memory / リポジトリ外 / パストラバーサル） |
| [x] | `ios-engineer.md` 改訂: `skills` プリロード（ios-developer / mobile-ios-design）、`memory: project`、hooks、OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED 禁止、`.swiftinterface` 裏取り、横断点検ルール | 2026-07-04 完了 |
| [x] | `kmp-engineer.md` 改訂: 書き込みスコープ・モジュール配置表を現行構成（分割完了後）に更新、検証コマンド修正（`testAndroidHostTest` / iOS 実ターゲットコンパイル必須 / sandbox 制約明記）、`skills` プリロード（kotlin-coroutines-flows）、`memory: project`、hooks | 2026-07-04 完了 |
| [x] | CLAUDE.md「サブエージェントが守ること」にメモリ / フック / Skill プリロードの位置づけを追記 | 2026-07-04 完了 |
| [x] | ios-engineer への軽量 dispatch で起動確認 | 2026-07-04 完了。判明: ①現行ハーネスでは `skills` プリロードが本文展開されない → 両定義に「展開されていなければ Skill ツールで起動」のフォールバックを追記 ②メモリがユーザースコープ（`~/.claude/`）に書かれた → 定義でリポジトリ内 `.claude/agent-memory/<name>/` を正と明示し、初期メモリを移動 ③スコープ記述の `iosApp/iosApp/Bridge/` が実在しない → 実体（`Features/*/​*ViewModelBridge.swift` + `FlowBridge.swift`）に修正 |
| [ ] | 次回の実 dispatch で観察: メモリ運用（リポジトリ内パスへの追記）が定着すること / ハーネス更新後に `skills` プリロードが効くようになったらフォールバック文を削除 | 運用検証 |

---

## CLAUDE.md のスリム化と .claude/rules/ 分割（2026-07-04）

> CLAUDE.md 240 行 → 131 行。公式推奨（1 ファイル 200 行以下 / 長いほど遵守率低下）への追随と、docs 二重管理箇所（モジュール表・規約抜粋・チェックリスト）の解消。判断の詳細は [`implementation_note.md`](./implementation_note.md) 2026-07-04（rules 分割）エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 言語別規約を `.claude/rules/` のパススコープ規則へ分割（`kotlin-kmp.md`: shared/** 等 / `swift-ios.md`: iosApp/** 等。対象ファイルを触るときだけロード） | 2026-07-04 完了。rules は「要点 + docs 正本への参照」の薄い構成で三重管理を回避 |
| [x] | モジュール構成 11 行表を削除し「一覧は `settings.gradle.kts`・役割は `architecture.md` を真とする」参照に一本化（陳腐化面の消去） | 2026-07-04 完了。lessons 2026-06-16 / 2026-07-02 の陳腐化実績箇所 |
| [x] | テンプレ由来の基礎ルール 6 節 + タスク管理 + 核となる原則を内容維持で縦断圧縮。lessons の親運用ルール（OVERRIDE フラグ再検証 / iOS テストの DEVELOPER_DIR 実行 / 横断 doc 同時更新 / 横断点検やり切り）を CLAUDE.md へ昇格 | 2026-07-04 完了。旧ファイルとの棚卸しで消失ルールゼロを確認 |
| [x] | サブエージェントへの rules 伝播を実測確認（kmp-engineer が `shared/domain/build.gradle.kts` を Read した直後に kotlin-kmp.md 全文が自動注入されることを確認。起動時ではなく遅延注入） | 2026-07-04 完了。skills プリロードと異なり rules は現行ハーネスで機能する |
| [ ] | `/memory` でロード確認（CLAUDE.md 常時 + `shared/**` のファイルを開いた際に kotlin-kmp.md が載ること） | **ユーザー作業**（セッション内で `/memory` 実行） |

---

## docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない（最優先 A-1〜A-3 / 整合 A-4〜A-7 はコミット済 `34ec607` / `7c86ab5`）。必要になったフェーズで着手する。判断経緯は精査結果と [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリを参照。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [ ] | B-2 | ViewModel テスト方針の整理。規約（architecture / coding-conventions）は「VM は runTest でテスト」だが主要 VM が未テスト。規約を実態に合わせるか、テストを足すか決める | CI を本格運用するとき / 新規 VM 追加時 |
| [x] | B-3 | `requirements.md` の「API キーは難読化」を実態（Google Cloud 側のキー制限ベース。Info.plist / BuildConfig は平文）に修正 | 2026-07-01 完了。requirements→CoffeeRecord 全面改訂と同時に非機能要件の記述を修正 |
| [ ] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を仕様化（`CoffeeRecord.rating` を nullable にするか 0 を明記するか）。`VisitedCafe` 集計が 0 を平均除外している | 集計まわりを次に触るとき。現状動作に実害なし。requirements §未決事項にも起票済み |
| [ ] | B-5 | CI（GitHub Actions）を実際の PR でグリーン確認し `tasks.md` フェーズ 0 の `[~]` を `[x]` 化 | 最初の PR を出すタイミングで自然解消 |
| [ ] | C-1 | feature ViewModel の「`shared/core` 暫定置き場 → 後で feature module へ git mv」運用の見直し（最初から feature module を作る案） | 次の feature 追加時に再評価 |
| [ ] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 任意 |
| [ ] | D-2 | `architecture.md`「データフロー（書き込み）」節が旧 Visit モデル / 旧構成（プラットフォーム別 VisitRepository 実装）のまま。現行の CoffeeRepositoryImpl 合成構成に書き直す（読み取り側は 2026-07-03 の shared レビュー対応で修正済） | docs を次に棚卸しするとき |
| [~] | E-1 | アカウント削除時の Apple トークン失効（revoke）。App Store ガイドライン 5.1.1(v) 対応。**2026-06-24 着手 → 専用セクション「フェーズ 5.2」に移管**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-17 コールバック URL エントリ | App Store 申請前。現状の `deleteAuthUser` は Firebase ユーザー + Firestore データのみ削除 |
