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
| [ ] | B-1: `FavoriteSignals`（階層2）を `BuildCoffeeStatsUseCase` に実装 + テスト（kmp-engineer） | minSampleSize 閾値ガード |
| [ ] | B-2: 対話 Q&A v1（ツール無し・`CoffeeStats` 文脈注入）（ios-engineer） | `CoffeeInsightProvider` に Q&A API 追加を親が確定してから |
| [ ] | B-3: 対話 Q&A v2（tool calling）/ 好みのカフェをマップ連携 | 将来 |

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
| [ ] | `CoffeeEditorView`: 個別 +/× を廃止し、`tasting==nil` 時は「+ テイスティングを追加」1 ボタン → 押下で 5 スライダー一括表示。削除ボタンで nil | Bridge を `onTastingAdded`/`onTastingCleared` + 非 null セッターに追随 |
| [ ] | `CoffeeDetailView` / `AnalysisView` / `CoffeeFirestoreMapper.swift` / `PreviewSamples` を新 API（`tasting: TastingScores?` / 非 null フィールド / `ratedCount: Int`）に追随 | |
| [ ] | 検証: `xcodebuild` 成功。シミュレータ目視はユーザー作業 | |

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

## docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない（最優先 A-1〜A-3 / 整合 A-4〜A-7 はコミット済 `34ec607` / `7c86ab5`）。必要になったフェーズで着手する。判断経緯は精査結果と [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリを参照。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [ ] | B-2 | ViewModel テスト方針の整理。規約（architecture / coding-conventions）は「VM は runTest でテスト」だが主要 VM が未テスト。規約を実態に合わせるか、テストを足すか決める | CI を本格運用するとき / 新規 VM 追加時 |
| [ ] | B-3 | `requirements.md` の「API キーは難読化」を実態（Google Cloud 側のキー制限ベース。Info.plist / BuildConfig は平文）に修正 | リリース準備フェーズ（doc 修正のみで完結、判断不要） |
| [ ] | B-4 | `rating=0`=「未評価」の暗黙 sentinel を仕様化（`Visit.rating` を nullable にするか 0 を明記するか）。`ObserveVisitedCafesUseCase` が 0 を平均除外している | 集計まわりを次に触るとき。現状動作に実害なし |
| [ ] | B-5 | CI（GitHub Actions）を実際の PR でグリーン確認し `tasks.md` フェーズ 0 の `[~]` を `[x]` 化 | 最初の PR を出すタイミングで自然解消 |
| [ ] | C-1 | feature ViewModel の「`shared/core` 暫定置き場 → 後で feature module へ git mv」運用の見直し（最初から feature module を作る案） | 次の feature 追加時に再評価 |
| [ ] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 任意 |
| [ ] | E-1 | アカウント削除時の Apple トークン失効（revoke）。App Store ガイドライン 5.1.1(v) 対応。削除時に Sign in with Apple の authorization code を取得 → `Auth.auth().revokeToken(withAuthorizationCode:)`、Firebase Console で Apple プロバイダの OAuth 鍵（Services ID / Team ID / Key ID / 秘密鍵）登録が必要。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-17 コールバック URL エントリ | App Store 申請前。現状の `deleteAuthUser` は Firebase ユーザー + Firestore データのみ削除 |

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

### 2026-06-16 - Phase 5 設定画面 + マップ上部フィルタタグ化
- 変更点:
  - `iosApp/iosApp/Features/Settings/AppAppearance.swift`（新規）: `enum AppAppearance(system/light/dark)` + `colorScheme: ColorScheme?` + `displayName`
  - `iosApp/iosApp/Features/Settings/SettingsView.swift`（新規）: `NavigationStack { Form }`。テーマ `Picker`（`@AppStorage("appAppearance")`）/ バージョン・ビルド `LabeledContent`（`CFBundleShortVersionString` / `CFBundleVersion`）/ ライセンス `NavigationLink` の 3 セクション + 「完了」ボタン
  - `iosApp/iosApp/Features/Settings/LicensesView.swift`（新規）: 利用 OSS 7 件（Firebase iOS SDK / SQLDelight / Ktor / kotlinx-coroutines・serialization・datetime / SKIE、すべて Apache-2.0）の静的リスト
  - `iosApp/iosApp/iOSApp.swift`: `AppRootView` に `@AppStorage("appAppearance")` + `.preferredColorScheme(...)` を両分岐に付与（TabView・sheet 含むアプリ全体に即時反映）
  - `iosApp/iosApp/Features/Map/MapTabView.swift`: `filterToolbar`（Menu）撤去 → 歯車ボタン（`.sheet(SettingsView)`）に置換。`mapContent` に `.safeAreaInset(edge: .top)` で `FilterChip`（訪問済み / 周辺）行を追加。`FilterChip` private サブビュー新設
- 動作確認:
  - `xcodebuild -sdk iphonesimulator -scheme iosApp build` → BUILD SUCCEEDED（今回変更分の新規 warning ゼロ）
  - KMP / gradle 変更なし（`MapViewModel` の既存 `showVisited` / `showNearby` + `onShowVisitedToggled` / `onShowNearbyToggled` を流用）
  - シミュレータ目視確認はユーザー作業（歯車→設定 sheet / テーマ即時切替 / マップ上部チップでピン表示切替 / 再起動後のテーマ保持 / ライセンス一覧）
- 残課題 / フォローアップ:
  - サインアウト（匿名→記録孤立リスクのため見送り）はアカウントアップグレード（次タスク）実装後に設定画面のアカウントセクションへ追加する
  - ライセンスは名称 + ライセンス名表示まで。全文表示は将来タスク

### 2026-06-16 - Phase 5 エラートースト共通コンポーネント
- 変更点:
  - `iosApp/iosApp/Components/ErrorToast.swift`（新規）: `ToastBanner`（SF Symbol `exclamationmark.triangle.fill` + メッセージ、`.regularMaterial` + 角丸 12pt + shadow、タップ/上スワイプで消去）+ `ErrorToastModifier`（`.overlay(alignment: .top)` / `.task(id: message)` で 4 秒自動消去 / Reduce Motion 対応 / `AccessibilityNotification.Announcement` 投稿）+ `View.errorToast(message:onDismiss:)` + Preview 2 件
  - `VisitListView.swift` / `VisitDetailView.swift`: 末尾の `.alert("エラー", ...)` を `.errorToast` に置換
  - `MapTabView.swift`: `bridge.error` + `bridge.poiLookupError` の 2 alert を撤去 → `activeToast(bridge:)` 集約で 1 トーストに
  - `CafeSearchView.swift`: `bridge.error` + `locationManager.error` の 2 alert を撤去 → `activeToast` 集約。位置情報許可拒否 alert（設定誘導）は据え置き
  - `AppState.swift`: `clearLastError()` 追加。`iOSApp.swift` の `AppRootView` に root レベル `errorToast(message: appState.lastError)` を付与し、従来未表示だった起動同期失敗を露出
  - `VisitEditorView.swift` の保存失敗 / 写真保存失敗 alert は致命的なので変更なし
- 動作確認:
  - `xcodebuild -sdk iphonesimulator -scheme iosApp build` → BUILD SUCCEEDED（今回変更分の新規 warning ゼロ。SourceKit の `No such module` / `systemBackground` 診断はビルドコンテキスト不在による偽陽性で実ビルドは成功）
  - KMP / gradle 変更なし（各 Bridge の既存 `error` / `onErrorDismissed()` を流用）
  - シミュレータ目視確認はユーザー作業（トースト表示/自動消去/手動消去、VoiceOver アナウンス、Reduce Motion、VisitEditor は alert 維持、位置情報許可拒否は alert）
- 残課題 / フォローアップ:
  - 成功トースト（保存完了など）は現状スコープ外。必要なら `errorToast` を一般化した `toast` バリアント追加を検討
  - 複数エラー同時表示はスタックせず優先度 1 件のみ表示する仕様。キュー表示が要るなら別途設計

### 2026-06-16 - docs 精査 & 基盤 doc を Phase 5 実態に同期（最優先パック）
- 変更点:
  - docs 全体精査でアンチパターン / 乖離を洗い出し（A-1〜A-7 / B 系 / C 系）。乖離の構造的原因を `docs/tasks/lessons.md` 2026-06-16 エントリに記録
  - **A-1** `architecture.md`: 「現状（Phase 2.5）」と「目標構成」の二段を **Phase 5 実態の 14 モジュール一段に統合**（namespace 付き）。data-firebase「空殻」修正、段階的移行ステップ表の Phase 3/3.5/4 を完了に、ViewModel / data-places の配置記述・AppContainer スケッチ・framework export 例を実態化
  - **A-2** `implementation_note.md`「現在生きてる方針サマリ」: include 10→14 件、data-firebase 移送済、AppContainer 引数（placesApiKey 追加）、framework export 11 モジュール、feature 暫定置き場→移送済に更新。**写真パスの矛盾（`visits/{visitId}` → flat `photos/{fileName}`）を解消**（過去エントリ L582-583 / L1053 の食い違いも訂正）
  - **A-3** `CLAUDE.md`: モジュール表を 14 モジュール（namespace 付き）に、共通言語行 / アーキテクチャ記述 / チェックリストの「Phase 3 以降で追加予定」「現状は core 経由」を実態化
- 動作確認:
  - docs のみ（コード / ビルド / CI 変更なし）。grep 検証で `visits/{visitId}` 写真パス残存ゼロ / 現状記述の「予定」語ゼロ / `settings.gradle.kts`（14 include）と doc のモジュール一覧一致を確認
- 残課題 / フォローアップ:
  - 🟠整合パック（A-4〜A-7）→ 2026-06-16 完了（コミット `7c86ab5`）
  - 🟠設計判断パック（B 系）/ C-1 / D-1 → 後回し可。本ファイル上部の「docs / 設計判断バックログ（後回し可）」節に移管
