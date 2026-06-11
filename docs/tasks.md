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
