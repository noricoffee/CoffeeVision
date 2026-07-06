# 実装ノート（Implementation Note）

要件未満の実装上の決定・トレードオフ・経緯を残す作業ログ。重い ADR ではなく、**書きやすさ優先**。

---

## 運用ルール

### 書き込み権限

- **親（メインセッション）のみ**。サブエージェントは読み取り専用
- サブエージェントが返したレポートの「親への依頼」を親が吸収して反映する

### 書くこと

- `requirements.md` に上げるほどではないが残しておきたい実装判断
- ある実装が他レイヤー・他機能・他プラットフォームに与える影響
- 採用・不採用したトレードオフ
- その決定に至った経緯

### 書かないこと（他 doc に振る）

| 内容 | 行き先 |
|------|--------|
| 機能要件・画面要件 | `requirements.md` |
| アーキテクチャ全体方針（安定したもの） | `architecture.md` |
| Kotlin / Swift コーディング規約 | `coding-conventions.md` |
| iOS UI / UX ガイドライン | `ui-ux-guidelines.md` |
| データモデル定義 | `data-model.md` |
| Swift ⇄ Kotlin ブリッジルール（安定したもの） | `kmp-bridge.md` |
| フェーズ別タスク・進捗 | `tasks.md` |
| 失敗から学んだ **汎用** パターン | `tasks/lessons.md` |

迷ったらまず本ノートに書く。安定したら昇格させる（下記）。

### 編集ポリシー

- **追記が原則だが、編集・削除も可**。append-only ではない
- 単純な訂正（書き間違い / 翌日に方針変更など）は元エントリを直接書き換えてよい
- 重要な方針転換は、元エントリを残しつつ新エントリで `[YYYY-MM-DD: 旧タイトル]` を参照する形にする
- 完全に陳腐化したエントリは削除してよい（`tasks.md` のチェック完了同様、痕跡を残す価値が低いものは消す）

### 昇格パス（他 doc への移送）

ノートのエントリは「育つ」もの。以下を満たしたら、対応する正規 doc に移送し、本ノートのエントリは削除する：

| 条件 | 昇格先の例 |
|------|-----------|
| 同種の決定が 3 件以上溜まり、ルール化できる | `coding-conventions.md` / `kmp-bridge.md` |
| 単発でもアーキテクチャ全体に効く方針として安定した | `architecture.md` |
| 機能要件として扱った方が良いと分かった | `requirements.md` |
| 「次回も避けたい失敗パターン」として汎用化できた | `tasks/lessons.md` |

**昇格時は本ノートから当該エントリを削除する**（重複させない）。削除前に「現在生きてる方針サマリ」も更新する。

---

## 現在生きてる方針サマリ（手動メンテ）

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。（最終棚卸し: 2026-07-04）

- ドメインは **CoffeeRecord 主体**（2026-06-19 クリーンブレイク）: 1 杯 = 1 記録、`cafe: Cafe?`（null = セルフ抽出）、`rating` は 0.5 刻み `Double`（0.0 = 未評価 sentinel）、`tasting` は all-or-nothing（`TastingScores?`）、`tags: List<String>`。モデル・DB・Firestore 表現は `data-model.md` を真とする
- CI（GitHub Actions）は `:shared:data-local:testAndroidHostTest` + `:androidApp:assembleDebug`（Android ジョブ。ダミー `google-services.json` を CI 内で生成）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成
- `CoffeeRepository` は `commonMain` で 2 段構成（`RemoteCoffeeDataSource` interface + `CoffeeRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteCoffeeDataSource` だけを書く。書き込みはローカル → リモート順、リモート失敗の扱いは `WritePolicy`（既定 `PropagateRemoteFailure`）
- Firestore は `users/{uid}/coffees/{id}` の単一ドキュメント（`cafe` 任意埋め込み + `photos` 埋め込み配列 + `tasting` マップ + `tags` 配列。子サブコレクションなし）+ `users/{uid}` ルート（`analyticsConsent`）+ `beanProfiles`（サービス管理・read-only）。nullable はキー省略。`Photo.localPath` は書かず `fileName`（`Documents/photos/` フラット配置）で復元、`remoteUrl` は常に null（Storage 不採用・写真は端末ローカルのみ）
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる
- `AppContainer` は scope 引数ありのプライマリ（7 引数）が**テスト専用**。通常は scope なしセカンダリ 2 系統 — iOS = 6 引数（`coffeeInsightProvider` 注入）/ Android = 5 引数（provider 省略 = null）。公開プロパティは `coffeeRepository` / `cafeRepository` / `authRepository` / `coffeeInsightProvider` / `beanProfileRepository` / `beanProfileMatchUseCase` / `coffeeRecordQuery`、開発用に `seedDummyData` / `clearDummyData`（DEBUG + ダミーデータ Scheme 限定）
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一。共通ライブラリの Android namespace は各モジュール個別（`com.noricoffee.<module>` 系）で applicationId と分離
- SKIE 0.10.12 を `shared/framework` umbrella に適用。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する（`__answer(...)` 等の protocol witness）。Swift で `Flow` を作るには `MutableStateFlow` 直接構築が第一候補。SQLDelight 生成行型と同名のドメインモデルは Swift 側で末尾アンダースコア付きになる（現状 `Photo` → `Photo_`。`coffee_record` からは `Coffee_record` が生成されるため `CoffeeRecord` は衝突しない）
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。path uid 検証 + `users/{uid}` ルート明示 + `beanProfiles` read-only（2026-07-01 デプロイ済）。`storage.rules` は残置のみ未デプロイ
- `build-logic/convention/` の Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）は precompiled script plugin 方式（`gradlePlugin { register }` 不使用）。`build-logic/settings.gradle.kts` で version catalog を明示共有。`kmp.library` は `jvmToolchain(N)` を付けず `compilerOptions.jvmTarget` のみ指定
- `shared/core` には `AppContainer` / `CoffeeRepositoryImpl` / `DummyCoffeeData`（dev 用）。`shared/data-local` が SQLDelight の単独管理者（`LocalCoffeeRepository` / Mapper / DriverFactory expect/actual。合成リポジトリのテストは expect/actual ドライバの制約で data-local の commonTest に妥協配置）。`shared/data-firebase/androidMain` に Android Firebase 実装（`AuthRepositoryAndroidImpl` / `RemoteCoffeeDataSourceAndroidImpl` / `CoffeeFirestoreMapper` / `BeanProfileRepositoryAndroidImpl`）、iOS 実装は `iosApp` Swift
- iOS 向け umbrella は `shared/framework`（baseName / XCFramework 名とも `SharedLogic`、Swift は `import SharedLogic`）。全 shared モジュールを `api` + `export` で再公開 + `linkerOpts("-lsqlite3")`。**feature を追加したら api / export に 1 行ずつ追記**。モジュールの正確な一覧は `settings.gradle.kts` を真とする（現状 feature は coffee-list / coffee-detail / coffee-editor / cafe-search / map / cafe-detail / account / analysis の 8 個）
- `AppContainer` の ViewModel ファクトリ（`makeCoffeeListViewModel()` 等）は **`shared/framework` の拡張関数**（`AppContainerViewModelFactory.kt`）として配置（`core → feature` の循環依存回避）。feature 追加ごとに追記する
- ViewModel は注入 scope の Job を親にした**所有 `viewModelScope`（SupervisorJob 子スコープ）+ `clear()`** を持つ（2026-06-24。push/pop 画面の collector 増殖リーク対策）。Bridge は `deinit` で `kotlin.clear()` を呼ぶ。**KMP のコルーチン内で `runCatching` は使わない**。→ いずれも 2026-07-02 に `coding-conventions.md`（§1.2 / §1.6 / §1.7）へ昇格済み。経緯は本ノート 2026-06-24 エントリ
- iOS Bridge は `@MainActor @Observable` + `Task { for await state in kotlin.state { apply(state) } }` パターン。生存スコープは、タブ常駐画面（coffee-list / map / analysis 等）= `AppState` で 1 つ保持、push / sheet 画面（coffee-detail / coffee-editor / cafe-detail）= View 内 `@State` で遷移ごとに生成・`deinit` 回収。**タブ常駐 View の `onDisappear` で observation を止めない**（2026-06-25 の検索停止バグ再発防止）
- iOS のルートは **4 タブ（マップ / コーヒー / 分析 / 設定）**。検索タブは廃止（iOS 27 で `Tab(role: .search)` の右端固定が廃止されたため）し、**マップ上部の埋め込み検索バー**（テキスト検索はマップ中心の位置バイアス付き）+「このエリアを検索」ボタン + 検索モードに移行。コーヒー記録の作成はコーヒータブの FAB とカフェ詳細の「コーヒーを記録」の 2 導線
- Places API は **New v1** + `X-Goog-FieldMask` で取得フィールド明示。API キーは `AppContainer` コンストラクタ注入（Android = local.properties → BuildConfig、iOS = xcconfig → Info.plist → Bundle.main）。Nearby は `includedPrimaryTypes = [cafe, coffee_shop]`・1 回最大 20 件。Places 写真は永続キャッシュ禁止（規約）で都度取得
- iOS の xcconfig は `Base.xcconfig`（base）→ 先頭 `#include "Config.xcconfig"`（必須）+ `#include? "Secrets.xcconfig"`（任意・gitignore 済）の 3 段構造。**フォールバック宣言（`PLACES_API_KEY =` 等）は `#include?` より前に置く**（後ろだと実キーを空で上書き）
- 分析は 3 階層分離: 階層1・2 は KMP で決定論（`CoffeeStats` / `FavoriteSignals`。収縮平均 + n 連動 z ゲート `CATEGORY_Z = 2.0` + 相関 floor で「弱い傾向」だけを信号化、断定しない）、階層3 は iOS Foundation Models（`CoffeeInsightProvider`。可否は注入時判定、null = 非対応端末で graceful degradation）。Q&A は v1 = `CoffeeStats` digest 注入（単発・ステートレス）/ v2 = `Tool` から `CoffeeRecordQuery.searchRecords`（計算は KMP・LLM は解釈と整形のみ）
- `BeanProfile`（12-B）はサーバ管理 read-only の豆ナレッジ。`CoffeeRecord` と ID 紐付けせず origin / processings のファジーマッチ。取得は one-shot get + メモリキャッシュ。12-C で `FavoriteSignals` と突合した `preferredBeanTraits` を `CoffeeStats` に付加し、Foundation Models で言語化
- データ利用同意（12-A）: `users/{uid}.analyticsConsent`。初回起動オンボーディングで取得し設定トグルで変更可。ドキュメント不在は false 扱い

---

## エントリ形式

タイトル + 本文だけで十分。`影響` / `トレードオフ` / `経緯` は必要なときだけ書く。

```markdown
### YYYY-MM-DD: 短いタイトル

- 領域: iOS / KMP / Shared / Build / Docs / etc
- 関連: `path/to/file.kt`（任意）

本文を自由に書く。3 行で済めば 3 行で良い。

必要なら以下を付ける（任意・順不同）:
- 影響: ...
- トレードオフ: ...
- 経緯: ...
```

---

## エントリ

<!-- 新しい決定は本セクションの末尾に追記する。陳腐化・昇格時は削除可 -->

### 2026-06-09: AppContainer の ViewModel ファクトリは `shared/framework` の拡張関数として配置

- 領域: KMP / Build
- 関連: `shared/framework/.../AppContainerViewModelFactory.kt`

`AppContainer`（`shared/core`）から feature の ViewModel を生成すると `kmp.feature` の自動配線（`feature → core` の `api` 依存）と衝突して循環依存になるため、全 shared モジュールを `api` で持つ最上位の `shared/framework` に拡張関数（`makeCoffeeListViewModel()` 等）として置く。Kotlin/Native は同モジュール内のレシーバ付き拡張関数を Obj-C category として出力するため、Swift からはインスタンスメソッドの形で呼べる。feature 追加ごとに本ファイルへ追記する運用。

不採用: `core` に直接置く（即 `CircularReferenceException`）/ `AppContainer` 自体を `framework` へ移動（既存参照が広範に壊れる）/ feature → core を `implementation` に下げる（feature から core の型が見えなくなる）。

### 2026-06-09: @Observable クラスは lazy var をサポートしない → Optional + bootstrap 時生成

- 領域: iOS
- 関連: `iosApp/iosApp/AppState.swift`

`@Observable` マクロが生成する init accessor は他 stored property を参照できず、`lazy var` はコンパイルエラーになる。Bridge ホルダは `private(set) var xxx: Bridge?` で宣言し、`bootstrap()` 成功後（uid 確定後）に nil ガード付きで 1 度だけ生成するパターンに統一。以後のタブ常駐 Bridge も同パターン。

関連する `@Observable` の制約（2026-06-15 発見）: `init` 内で「全 stored property 初期化前の self アクセス」が禁止されるため、`container` をローカル変数に受けてから順に代入する必要がある。

### 2026-06-11: SwiftUI Preview は「戦略 B（ダミー Demo）」+ PreviewSamples 集約

- 領域: iOS
- 関連: `iosApp/iosApp/PreviewSupport/PreviewSamples.swift`

本体 View は `AppState` / Kotlin VM を要求する Bridge に強く依存するため、Preview で本物の Bridge を構築せず、`#Preview` ブロック内に「同等構造のダミー Demo」を書く方針。ダミーデータは `PreviewSamples.swift` に `static let` で集約して Preview 間で共有。本体の構造が変わった際は Preview 側の追従が必要（コード重複は割り切り。`private struct Content` 抽出リファクタで解消可能だが MVP では見送り）。

### 2026-06-11: Phase 4 — Places API (New) v1 採用と API キー注入経路

- 領域: KMP / iOS / Android / Build
- 関連: `shared/data-places/**`, `iosApp/Configuration/**`, `androidApp/build.gradle.kts`

- **Places API (New) v1 採用**（`places.googleapis.com/v1/...`、`X-Goog-Api-Key` + `X-Goog-FieldMask` ヘッダ必須）。Legacy 不採用の理由は、新規プロジェクトは New 推奨で料金体系も New に集約、FieldMask で課金対象フィールドを明示できるため
- **API キーは `AppContainer` コンストラクタ注入**。Android = `local.properties` → `buildConfigField` → BuildConfig、iOS = `Secrets.xcconfig`（gitignore 済）→ Info.plist → `Bundle.main`。KMP コアはキーの出所を知らず、テストではダミーキーを渡せる。不採用: KMP から `local.properties` 直読み（runtime から読めない）/ 環境変数（iOS 実機ビルドで効かない）/ ソース hardcode（失効リスク）
- **KMP `internal` は同一 Gradle モジュール内に閉じる**: `internal expect fun createPlacesHttpClient()` は `api` 依存の別モジュールから呼べない。`PlacesModule.kt` に公開ファクトリ `createCafeRepository(apiKey)` を置き、HttpClient のエンジン選択（Darwin / OkHttp）と構築詳細を `data-places` 内に隠蔽する設計を採用
- Ktor を `framework` に export すると `Ktor_httpHttpStatusCode.description` が Swift の `description()` と衝突し SKIE が `description_` にリネームする警告が出る（ビルドは通る。UI から未参照のため放置）
- キー未設定でもビルドは通る（実 API 呼び出しで 401 になるだけ）。CI で実キー不要にする原則

### 2026-06-13: @Observable ユーティリティの状態リセットと nonisolated delegate

- 領域: iOS
- 関連: `iosApp/iosApp/Utilities/LocationManager.swift`

- `@Observable` ユーティリティの外部リセットが必要なプロパティは `private(set)` + リセットメソッド公開（`resetLastLocation()` / `clearError()`）。View からの直接代入は不可
- `@MainActor` クラスを CoreLocation delegate に準拠させる場合、コールバックは背景スレッドから呼ばれるため**デリゲートメソッドすべてを `nonisolated` 宣言**し、内部の `@MainActor` プロパティ更新は `Task { @MainActor in ... }` で戻す。他フレームワークの Delegate 連携でも踏襲

### 2026-06-13: VisitedCafe 集計のトレードオフ

- 領域: KMP / Shared
- 関連: `shared/domain/.../usecase/ObserveVisitedCafesUseCase.kt`

マップ / カフェ詳細向けの `VisitedCafe`（placeId 単位の集計モデル）で確定した判断:

- **`cafe` スナップショットは「最新記録勝ち」**: 同 placeId で店名・住所が変わっていた場合、最新記録のものに上書きされる。記録自体には当時のスナップショットが残る
- `lastVisitedAt` は `visitedOn`（LocalDate）を UTC 0:00 の Instant に変換した**ソート専用値**。表示には `visitedOn` を直接使うこと
- `rating == 0` は未評価として `averageRating` 算出から除外（全件 0 なら null）

### 2026-06-15: Apple Maps POI タップ → Google Places 照合動線

- 領域: iOS / KMP / Places
- 関連: `iosApp/.../Features/Map/MapTabView.swift`, `shared/data-places/.../PlacesClient.kt`

iOS 17+ の `Map(selection:)` + `MapFeature` で Apple Maps 標準 POI のタップを検知し、Google Places に照合して CafeDetail へ進める動線。

- **照合方式**: `searchText(name, locationBias = circle(POI座標, 500m))` で名前一致 + 近接をサーバ側評価。不採用: クライアント距離フィルタ（同名チェーンで劣化）/ `searchNearby` + name フィルタ（name 絞り込み不可）
- **`MapFeature.featureIdentifier` は使わない**: Apple 内部 ID で Google placeId と非互換。照合結果の Google placeId を使うことで集計・詳細画面と整合
- ヒットなし / エラーは alert。同名近接店舗の誤マッチは CafeDetail 上で気付ける UX で許容。POI 1 タップ = `searchText` 1 回課金
- SKIE がデフォルト引数を出さないため `searchText` は「バイアスなし / あり」の 2 オーバーロードで公開

### 2026-06-15: Places 写真の都度取得（Photo Media API）

- 領域: KMP / iOS / Places
- 関連: `shared/data-places/.../PlacesClient.kt`, `iosApp/.../Utilities/PlacePhotoLoader.swift`

- **`skipHttpRedirect=true` で `photoUri`（時限署名 URL）を JSON 取得**し AsyncImage に渡す。不採用: `?key=API_KEY` の 302 リダイレクト方式（キーが画像 URL に埋まりログ等から露出、ヘッダ認証との一貫性も崩れる）
- **永続キャッシュなし**（Places 規約）。AsyncImage 内部の標準 HTTP キャッシュのみ許容、`photoUri` レスポンスも保持しない
- `PlacePhotoLoader` は状態を持たない URL ファクトリ（`@MainActor`、`@Observable` 不要）
- Swift 側の注意: Kotlin `Int?` は `KotlinInt?` で公開（`KotlinInt(int:)` ラップが必要）。`AsyncImagePhase` は struct のため `@unknown default` が必要（`default` 禁止規約の例外）

### 2026-06-15: `kmp.feature` Convention Plugin の自動配線と手動追加

- 領域: Build / KMP
- 関連: `build-logic/convention/src/main/kotlin/kmp.feature.gradle.kts`

Convention Plugin が自動配線するのは `api(":shared:domain")` + `api(":shared:core")` のみ。各 feature で必要に応じて手動追加するもの: `kotlinx-coroutines-core`（全 feature 必須）/ `kotlinx-datetime`（`LocalDate` / `Instant` を直接参照する feature。`domain` の `implementation` 経由ではコンパイルが通らない）/ `commonTest` 依存（`kotlin.test` + `kotlinx.coroutines.test`）。commonTest を持つ feature が増えたら Plugin への組み込みを再検討。

### 2026-06-16: エラートースト共通コンポーネント（errorToast）

- 領域: iOS
- 関連: `iosApp/iosApp/Components/ErrorToast.swift`

`ui-ux-guidelines.md` の方針（非致命 = トースト / 致命 = alert）を実装。使い分け: 非致命（同期・検索・位置取得・POI lookup 失敗）→ `View.errorToast(message:onDismiss:)`、致命（保存失敗）とアクション可能（位置情報許可拒否 → 設定誘導）→ `.alert` 据え置き。

- **複数エラー源は `activeToast`（優先順位付き単一値）に集約してから 1 つだけ付ける**。`.overlay(alignment: .top)` のため 2 つ付けると衝突する。優先度は ViewModel 由来 > 補助エラー
- 自動消去は `.task(id: message)`（message 変化で前タスク自動キャンセル）。VoiceOver には `AccessibilityNotification.Announcement` を投稿

### 2026-06-16: App Icon / Launch Screen / 表示名

- 領域: iOS
- 関連: `iosApp/scripts/generate_app_icon.swift`, `iosApp/iosApp/Assets.xcassets/`

表示名 = `CoffeeVision`（`CFBundleDisplayName`。bundle ID / `PRODUCT_NAME` は不変）。アイコンは **AppKit + SF Symbol（`cup.and.saucer.fill`）をレンダリングする Swift スクリプト生成**方式。デザイン変更時はリポジトリルートから `swift iosApp/scripts/generate_app_icon.swift` で再生成して PNG を上書きコミット（light / dark / tinted の 3 variant）。Launch Screen は storyboard を使わず Info.plist の `UILaunchScreen` 辞書方式（`INFOPLIST_KEY_UILaunchScreen_Generation` は競合するため削除済み）。ワードマークは文字を焼き込んだ透過 PNG（`UILaunchScreen` はテキストラベルを置けないため）。

### 2026-06-17: アカウント機能 — Apple 連携 / サインアウト / 削除 / トークン失効（revoke）

- 領域: KMP + iOS
- 関連: `shared/feature/account/`, `shared/domain/.../{AuthAccount,AuthRepository,DeleteAccountUseCase}.kt`, `iosApp/.../{AccountView,AppleSignInCoordinator,AuthRepositoryIosImpl}.swift`

（2026-06-17 設計 + Dispatch B 追補 + 2026-06-24 E-1 revoke 実装を統合）

- **プロバイダは Sign in with Apple のみ**（Google 見送り: GoogleSignIn SDK 追加回避、Apple は審査上必須で `AuthenticationServices` のみ = 追加依存ゼロ）。資格情報取得と Firebase 操作は iOS Swift、KMP は `AuthRepository` の抽象操作と ViewModel / UseCase のみ
- **アップグレード = `link` で uid 不変**（Firestore / ローカル DB / 写真がそのまま引き継がれ、uid 再配線不要）。匿名のときだけ提示
- **サインアウト / 削除 = uid が変わる → `resetAndRebootstrap()`（新規匿名サインインでブリッジ再構築）に収束**。サインアウト後の既存ローカルデータは uid フィルタで自然に隠れるため残置。削除時のみ実データ消去（`DeleteAccountUseCase` が「全記録削除 → Auth ユーザー削除」の順序を強制。**写真ファイル削除は端末ローカルのため iOS 責務**）
- **`SignInWithAppleButton`（SwiftUI 組み込み）は rawNonce を外部公開しない**ため Firebase の nonce 検証に使えない。`ASAuthorizationController` を async ラップした `AppleSignInCoordinator`（CryptoKit で nonce + SHA256）を自作
- `observeAccount()`（`AuthAccount` を流す）を新設。サインアウト時の nil emit のため `FlowBridge.swift` に `CallbackFlowOptional<T>` を追加
- ネイティブ Apple フローは Web リダイレクトが発生しないため、**コールバック URL / Services ID 登録は「サインインだけなら」不要**（プロバイダ有効化のみで足りる）
- **revoke（E-1、2026-06-24 実装）**: App Store ガイドライン 5.1.1(v) 対応。`revokeToken(withAuthorizationCode:)` に必要な authorization code は一度きり・約 5 分有効・保存禁止のため、**削除時に Apple サインインをやり直して取得** → `reauthenticate`（旧課題 `requiresRecentLogin` も同時解消）→ revoke → KMP 削除、の順で Swift がオーケストレーション。キャンセル = 無音中断、reauth / revoke 失敗 = 削除中断（revoke できないなら削除しない）
- **前提（ユーザー作業・App Store 審査前必須）**: revoke は Firebase がサーバサイドで Apple の revoke エンドポイントを叩くため、Firebase Console → Apple プロバイダに **OAuth コードフロー設定（Services ID / Team ID / Key ID / .p8 秘密鍵）**の登録が必要。未設定だと revoke は常に失敗 → 削除不能になる。Apple プロトコル上 Services ID はネイティブ revoke に不要だが、**Console が 4 項目を 1 セットで検証するため実運用上は Services ID 作成・入力が必須**

### 2026-06-19: マップ現在地 FAB の recenter はフラグ方式

- 領域: iOS
- 関連: `iosApp/.../Features/Map/MapTabView.swift`

FAB タップで `pendingRecenter = true` → `requestLocation()` → `.onChange(of: lastLocation?.latitude)` で 1 回だけセンタリング。`resetLastLocation()`（nil 化）を使わないことで、`lastLocation` を参照する他の経路への副作用をゼロにした。`.denied` / `.restricted` は FAB を `.disabled` + 減光。旧実装の `TabBarFrameReader`（検索タブの幾何検出で FAB を配置する UIKit ハック）は 2026-06-30 の検索タブ廃止で削除済み — 現在は `overlay(alignment: .bottomTrailing)` + padding 固定。

### 2026-06-19: コーヒー記録主体への再設計（Visit → CoffeeRecord、Phase 7）

- 領域: 全レイヤー。確定仕様は [`data-model.md`](./data-model.md) 2026-06-19 全面改訂版

**集約ルートを `Visit`（カフェ訪問）から `CoffeeRecord`（コーヒー 1 杯）へ転換**。`CoffeeItem` / `FoodItem` を廃止し、旧 `CoffeeItem` の属性（name / brewMethod / origin / variety / processing / roastLevel / cup）を `CoffeeRecord` へ昇格、旧 `Visit` の visitedOn / rating / notes / photos を移管。`ambiance` / `FoodItem` は自由メモ `notes` に吸収。カフェは nullable（null = セルフ抽出）。**クリーンブレイク**（未リリースのため移行コードなし。テスト端末はアプリ削除 → 再インストール）。

トレードオフ / 影響:
- **`VisitedCafe` は名前を維持**し集計元だけ変更（iOS 参照が広く、意味変更のみに留めた。改名は将来の任意タスク）
- **Firestore は `coffees` 単一ドキュメント + `photos` 埋め込み配列**（旧: 子サブコレクション 3 種）。observe の子 N+1 取得と WriteBatch 差分 delete が消え、両プラットフォームの Remote 実装が大幅簡素化。大量写真の要件が出たらサブコレクションへ戻す
- **feature モジュールをリネーム**（`visit-*` → `coffee-*`）。`shared/framework` の `export(...)` と `api(...)` の**両方**を更新する必要あり（片方だと型が Swift に出ない）
- null cafe の扱い: `selectByCafe` は SQL 等値マッチで自然除外（セルフ抽出はマップ / カフェ詳細に出ない = 意図通り）。`ObserveVisitedCafesUseCase` は明示 `cafe != null` フィルタ

### 2026-06-19: コーヒー評価を 0.5 刻み Double に（ハーフスター）

- 領域: 全レイヤー

`CoffeeRecord.rating` を `Int`(1..5) → `Double`(0.5..5.0、0.0 = 未評価) に変更。0.5 の倍数は IEEE 754 で厳密表現できるため DB(REAL) / Firestore(number) 往復と等値判定が安全。バリデーションは `rating < 0.5 || rating > 5.0 || (rating * 2) % 1.0 != 0.0`。Firestore の旧 Int 保存ドキュメントは Android = `(Number).toDouble()`、iOS = `Double ?? NSNumber.doubleValue` で受けて後方互換。iOS 入力は星を左右 2 分割した透明タップ領域（`StarTapCell`）で 0.5 刻み、`accessibilityAdjustableAction` 対応。

### 2026-06-19: 分析機能の 3 階層分離と Foundation Models の使いどころ

- 領域: Shared / KMP / iOS
- 関連: `docs/requirements.md` §9, `docs/data-model.md` §1.6

**核となる原則 — 集計は KMP、解釈は LLM**。階層1（記述統計）/ 階層2（傾向抽出）は KMP 共通層で決定論的に算出（`CoffeeStats` / `BuildCoffeeStatsUseCase`）、階層3（自然言語の要約・Q&A）だけ iOS Foundation Models で、**入力は集約済み `CoffeeStats` のみ**（生レコードは渡さない）。理由: ①正確性（平均を LLM に計算させない）②オンデバイス LLM のコンテキスト窓 ③再現性・テスト容易性 ④3 ロール体制に綺麗に割れる。

- プラットフォーム非対称は `CoffeeInsightProvider` interface（domain）で吸収: iOS = `LanguageModelSession` 実装、Android = null 注入（分析タブ非表示）。Apple Intelligence 非対応端末も同じ null フォールバック
- 対話 Q&A は段階化: v1（B-2）= digest 文脈注入のみ、v2（B-3 / 9-4b）= tool calling。tool → KMP 照会 bridge は要 PoC のためリスク分割

### 2026-06-19: AnalysisViewModel の insightStatus 設計と AppContainer コンストラクタ 3 系統

- 領域: KMP / iOS Bridge
- 関連: `shared/feature/analysis/.../AnalysisViewModel.kt`, `shared/core/.../AppContainer.kt`

- **統計と要約は独立ロード状態**: 統計は Flow で即時反映、要約は後追い。要約が失敗・非対応でも統計画面は完全機能する
- `InsightStatus` は `sealed interface` + `data object`（Unsupported / Idle / Loading / Loaded / Failed）。SKIE SealedInterop で Swift に protocol + 実装として届き `is` 分岐。`provider == null` は初期値 `Unsupported`
- `AppContainer` コンストラクタは 3 系統（プライマリ = テスト用 scope 注入 / セカンダリ A = iOS・provider 注入 / セカンダリ B = Android・provider null）。SKIE がデフォルト引数を Swift に出さない制約への対処（scope 隠蔽パターンの踏襲）

### 2026-06-19: 分析タブ iOS UI（Swift Charts）

- 領域: iOS
- 関連: `iosApp/.../Features/Analysis/`

縦棒（評価 / 焙煎度 / 抽出方法）・横棒（産地 = 日本語名が長い）・折れ線（月次推移）・ランキングリスト（よく行く店）を `ScrollView` + `LazyVStack` のカード方式で。空状態は `stats == nil` or `totalCount == 0` で `ContentUnavailableView`。enum の日本語化ヘルパは `AnalysisView` に内包（全画面で enum 日本語化する際の共通化候補）。`CoffeeStats` の `Identifiable` 適合は `id: Int32`（KMP `Int` = Swift `Int32`）。

### 2026-06-19: Foundation Models による傾向要約（階層3 / A-4）

- 領域: iOS / KMP Bridge
- 関連: `iosApp/.../Features/Analysis/CoffeeInsightProviderIosImpl.swift`

- SKIE protocol witness（`__summarize(stats:completionHandler:)` の completion handler 形式）で Kotlin interface を実装。内部で `LanguageModelSession.respond(to:generating:)` → completion 変換
- `@Generable` 構造化出力 `CoffeeInsightOutput(headline, body)`。**SwiftUI `View.body` との名前競合を避けるため private struct に閉じる**
- prompt は KMP 集計済みの事実のみを日本語整形（数値計算は LLM にさせない）。session はリクエストごと生成（ステートレス）
- **可否判定は注入時 1 回**: `makeIfAvailable()` が `SystemLanguageModel.default.availability == .available` のときだけ実装を返す。nil → `InsightStatus.Unsupported` → 要約カード非表示（KMP 変更ゼロで graceful degradation）
- follow-up（実害小・未対応）: availability の動的再チェック / 統計更新ごとの再生成デバウンス / unavailable 理由別の案内 UI

### 2026-06-19: ダミーデータ Scheme（開発支援）

- 領域: KMP / iOS / Build
- 関連: `shared/core/.../dev/DummyCoffeeData.kt`, `iosApp/iosApp.xcodeproj/xcshareddata/xcschemes/`

専用 Xcode Scheme（`iosApp (Dummy Data)`、env `SEED_DUMMY_DATA=1`）で起動したときだけ約 30 件のダミー `CoffeeRecord` を投入。

- **投入先はローカル DB のみ**（private `localCoffeeRepository` 経由。Firestore に流さない。`startSync` は remote→local upsert のみでローカルのダミーは消えない）
- **固定 ID（`dummy-0001`..`0030`）で冪等**。通常 Scheme 起動時は clear（実データ = UUID には触れない）。Release ビルドは seed / clear とも無効
- `visitedOn` は今日基準の動的算出（常に直近 12 ヶ月で月次グラフが映える）。rating=0.0 を 2 件含め未評価除外パスも確認可能
- seed / clear の失敗は `print` のみ（通常起動毎に clear が走るためユーザー可視エラーにしない）

### 2026-06-20: テイスティング 5 要素は all-or-nothing（`TastingScores?`）

- 領域: 全レイヤー
- 関連: `docs/data-model.md` §1.1a / §1.6

Blue Bottle「Elements of Coffee Tasting」由来の**甘味 / ボディ / 酸味 / 風味 / 後味**を `CoffeeRecord.tasting` として追加。スケールは 1〜10 の**強度**（良し悪しではない。総合評価 `rating` とは別軸）。

- **型で partial を表現不可能に**: `TastingScores` の 5 フィールドは非 null `Int`、`CoffeeRecord.tasting` が `TastingScores?`。「null = 未記入 / 非 null = 5 要素すべてあり」を型が保証し、バリデーションのエラー経路が不要
- 経緯: 当初は各要素独立 nullable で実装したが、テイスティングは 5 軸セットで初めて比較・平均できるため all-or-nothing に即日変更（クリーンブレイクで作り直し）
- SQLDelight は 5 列 nullable のまま（Mapper が all-set のときだけ組み立て）。Firestore は非 null のとき 5 要素マップ、null は省略
- UX: `+` ボタンで `TastingScores(5,5,5,5,5)` を生成し 5 スライダーを一括表示。削除で null に戻す
- **転換点メモ**: TestFlight 配布開始後は DB 列変更すべてに SQLDelight マイグレーションが必須になる

### 2026-06-21: 対話 Q&A v1（単発・digest 文脈注入）

- 領域: Shared → KMP → iOS

`CoffeeInsightProvider` に `@Throws suspend fun answer(question, stats): String` を 1 本追加するだけの加算的変更。可否ゲートは要約と共有。

- **あえて削ったもの**: チャットスレッド型（履歴 + session ライフサイクル管理が重い）→ 1 問 1 答・ステートレス / tool・生レコード参照 → v2 へ / 逐次表示（`Flow<String>` は「Swift 側で Flow を作る」ハードパスになる）→ suspend 一発
- instructions でグラウンディング（統計の範囲でのみ答える / 不明は「記録からは分かりません」/ 再計算しない）
- `QaStatus` sealed（Unsupported / Idle / Asking / Answered / Failed）は insight と同じ状態機械パターン。`suggestedQuestions` は `Array(companion.SUGGESTED_QUESTIONS)` で取得（`as? [String]` は warning）
- `error` フィールドを insight 系と共用するため同時発火時に上書きされうる（稀・状態で判別可能なので許容）

### 2026-06-21: 対話 Q&A v2（tool calling / 生レコード参照、9-4b）

- 領域: Shared / KMP / iOS
- 関連: `shared/domain/.../model/CoffeeRecordQuery.kt`, `iosApp/.../Features/Analysis/SearchCoffeeRecordsTool.swift`

- **既存 interface / VM / UI は不変の加算的変更**: `answer(question, stats)` のシグネチャ据え置きで、iOS 実装が内部で tool を登録するだけ（v1 の状態機械を再利用）
- **単一の柔軟な検索 tool** `CoffeeRecordQuery.searchRecords(filter)` 1 本。filter は全 String / Double / Int（enum なし）で、LLM 生成文字列を KMP 側で寛容マッチ。limit は不正値を clamp（既定 10 / 上限 100）
- **userId は KMP 実装が内部解決**（Swift tool は意識しない）。ブリッジ方向は v1 と逆の Swift→Kotlin（SKIE が `async throws` を生成、witness 不要）
- **遅延アタッチ**: provider は container より先に生成され container 引数になるため、`coffeeRecordQuery` は `attachRecordQuery(_:)` で構築後に後付け（依存サイクル解消。詳細は kmp-bridge.md）
- **実機デバッグの結論**（試行錯誤は git 履歴参照）: ①モデルが digest を「全記録の網羅リスト」と誤認して tool を呼ばない → instructions を命令形にし「digest は非網羅の要約 / 記録の有無は tool 結果のみで判断」を明示 ②固有名詞のフィールド誤分類（カフェ名を `origin` に入れて 0 件）→ KMP 側で `origin` / `cafeName` を**フィールド横断 free-text term 化**（公開 API 不変で解決。data-model §1.6 反映済）
- Swift 側注意: Kotlin `Double?` は `KotlinDouble?`（ラップ必要）。`localizedBrewMethod` 等が 3 ファイルに重複（`CoffeeLocalizer` 共通化候補）

### 2026-06-21: CI Android ジョブでダミー google-services.json を生成

- 領域: Build
- 関連: `.github/workflows/ci.yml`

`googleServices` プラグイン導入で `:androidApp:assembleDebug` が `google-services.json`（gitignore 済）を必須化し CI が失敗。Android はリリース対象外の検証ターゲットで実 Firebase 接続は不要のため、CI 内でゼロ埋めダミーを生成して通す（**GitHub Secrets 管理を不要にした**）。実接続テストが将来必要になったら別途仕組みを作る。

### 2026-06-21: マップ POI フィルタを cafe / bakery のみに限定

- 領域: iOS
- 関連: `iosApp/.../Features/Map/MapTabView.swift`

ベース地図の標準 POI が全カテゴリ素通しだったため `.mapStyle(.standard(pointsOfInterest: .including([.cafe, .bakery])))` に限定し、POI タップ許可カテゴリも同じ集合に揃えた（**表示フィルタとタップ許可を一致させる**。非対称にするとタップ導線がズレる）。`restaurant` を再追加する場合は両箇所を同時変更。

### 2026-06-22: 好み判定（FavoriteSignals）の統計設計 — 収縮平均 + n 連動ゲート

- 領域: Shared / KMP
- 関連: `shared/domain/.../usecase/BuildCoffeeStatsUseCase.kt`, `FavoriteSignalsPersonaTest.kt`, `docs/data-model.md` §1.6

（B-1 / B-1b / B-1c / B-1d の 5 エントリを統合。最終仕様は data-model §1.6 が正）

**設計原則**: 生平均ランキングは n=1 の 5.0 が n=20 の 4.2 に勝つ罠があるため、①件数ガード ②経験ベイズ収縮 `shrunkMean = (n·mean + k·globalMean)/(n+k)`（k=5）で抑える。正方向のみ信号化。テイスティング軸はピアソン相関（符号付き。r<0 =「低いほど高評価」も返す）。**交絡は計算しない**（「産地が好き」か「その産地の店が好き」かは個人データでは分離不能。「言える範囲を計算で確定し、LLM はその範囲でしか言わない」= グラウンディングの土台）。

**ペルソナ検証（B-1b）で偽陽性を実測**: 検出力用ペルソナ P1〜P4・P7（仕込んだ好みを拾えるか）+ null ペルソナ P5（好みが無いとき黙れるか）を固定シードで生成し、150 シードで偽陽性率を集計。結果: **カテゴリ信号 100% / tasting 軸 40%**（5 軸 max|r| の winner's curse）。「最大群が globalMean を超えたら信号化」はほぼ恒真で、ゲートになっていなかった。

**対策の変遷と確定値**:
- B-1c: effect-size 閾値 `CATEGORY_MIN_EFFECT = 0.20` + tasting |r| 下限を n 連動化 `max(0.3, 1.97/√n)` → tasting 40%→22%。**カテゴリは固定 δ では下がらない**（winner's curse の幅は σ/√n に比例して膨らむため。不均等分布の実測でも 86.7%）
- B-1d: カテゴリにも n 連動 z ゲート **`mean - globalMean > CATEGORY_Z(=2.0) · globalStd / √n` AND δ** を導入 → カテゴリ FP 100%→**9.3%**（heavy-skew）、検出力は全工程で維持。z=2.5/3.0 は FP ほぼ 0% にできるが実データの弱い好みを弾きすぎるため不採用。選定キーは shrunkMean のまま（n=1 外れ値に頑健）
- 公開 API は companion 定数の追加のみ（`SHRINKAGE_PRIOR_WEIGHT=5` / `CORRELATION_MIN_SAMPLE=5` / `CORRELATION_ABS_FLOOR_C=1.97` / `CATEGORY_MIN_EFFECT=0.20` / `CATEGORY_Z=2.0`）。iOS 追随不要
- iOS 側は `buildPrompt` に好み信号を「弱い傾向 + 件数の但し書き」で渡し、instructions で断定を禁止

### 2026-06-22: 味覚一致カフェのマップ連携（B-4 v1・コンテンツベース推薦）

- 領域: Shared → KMP → iOS
- 関連: `docs/data-model.md` §1.7, `shared/domain/.../{RecommendedCafe.kt,ObserveTasteMatchedCafesUseCase.kt}`, `iosApp/.../Features/Map/`

（設計確定 + KMP 実装 + iOS 追随の 3 エントリを統合）

- **一致定義**: `rating >= 4.0` かつ `FavoriteSignals` のカテゴリ好み（bestOrigin / RoastLevel / BrewMethod）いずれかに一致する記録が 1 件以上。`dominantTastingAxis`（相関軸）は per-record の categorical 一致に変換できないため v1 では使わない（ユーザー合意済み）
- **将来移行を見据えた境界**: 推薦は `CafeRecommendationProvider`（interface）の裏。v1 = ローカル決定論実装、将来 9-6 = サーバ実装への**差し替えだけ**で UI / VM / FM 言語化層は不変。理由は `sealed RecommendationReason`（種類追加可能）、`RecommendedCafe.cafe` は `Cafe` のみ保持（未訪問カフェ推薦に拡張可能な契約）
- 実装メモ: UseCase は `BuildCoffeeStatsUseCase` 全体を実行（重複排除優先、重くなったら分離）。`PreferenceMatchAxis` の Swift case 名は camelCase（`.origin` / `.roastLevel` / `.brewMethod`。`.swiftinterface` で実地確認済み）
- iOS UX: 一致ピンは heart.fill 38pt。タップで**理由シート → 詳細の 2 タップ**（"なぜおすすめか" を先に見せる。callout での 1 タップ化は v2 余地）

### 2026-06-22: Future Direction — 協調フィルタリング推薦（9-6）と FoundationModel の住み分け

- 領域: アーキテクチャ方針（将来 / 未着手）
- 関連: requirements 9-6・data-model §1.7 `CafeRecommendationProvider`

将来像（ユーザー意向）: 複数ユーザーが好みを登録し、**好みが近い他ユーザーの高評価カフェを提案**する（協調フィルタリング）。「今は作らないが設計の北極星」として残す。

- **方式の住み分け**: v1（9-5）= コンテンツベース。9-6 = 協調フィルタで、v1 に**追加**で載る（content → collaborative は典型的な発展経路）
- **味覚の類似度は LLM 不要・決定論**: 好みは既に構造化数値（`tastingAverages` 5 軸 + カテゴリ別評価分布）= そのまま特徴ベクトル。cosine 等で決定論的に計算でき、テキスト埋め込み学習は不要。**FM の役割は将来も「計算済みの推薦結果を一言で言語化」一点**
- **横断ベクトル計算はサーバ側（GCP 等）**。右サイズ重要 — 5〜10 次元・中規模なら Firestore のベクトル KNN or Cloud Function の総当たり cosine で十分
- **本体の難所は計算でなく基盤**: ①プロファイルのサーバ集約（現状 per-user・path-uid のみ）②明示同意 / オプトイン ③カフェ識別子は placeId で共有可能 = item キーに好都合 ④コールドスタート（だから v1 content-based が先、が正しい順序）

### 2026-06-23: Places 疎通トラブルシュート（xcconfig 上書き / エラー握り潰し / bundle ID ヘッダ）

- 領域: iOS ビルド設定 + KMP（data-places）
- 関連: `iosApp/Configuration/Base.xcconfig`, `shared/data-places/.../{PlacesClientImpl.kt,PlacesHttpClient.ios.kt}`

「アプリ上で検索が空結果」の切り分けで、**3 つの独立した問題**が重なっていたことが判明（統合エントリ）:

1. **（真因）API キーの空上書き**: `Base.xcconfig` がフォールバック宣言 `PLACES_API_KEY =` を `#include? "Secrets.xcconfig"` の**後ろ**に書いており、xcconfig は最後の代入が勝つため実キーが空文字で上書きされていた。→ フォールバックを include の**前**へ移動（サマリの xcconfig 3 段構造ルール参照）
2. **API エラーの握り潰し**: `places = emptyList()` デフォルト + Ktor 既定 `expectSuccess=false` により、403 のエラー JSON が「結果 0 件」に化けて発覚を遅らせた。→ `expectSuccess=true` + `HttpResponseValidator` で本文付き `PlacesApiException` を投げる
3. **iOS バンドル ID 制限ヘッダ**: API キーの iOS バンドル ID 制限は `X-Ios-Bundle-Identifier` ヘッダで判定されるが、自動付与するのは公式 GMS SDK のみで Ktor 生 REST では未付与 → `403 API_KEY_IOS_APP_BLOCKED`。→ `iosMain` の `actual createPlacesHttpClient()` で `NSBundle.mainBundle.bundleIdentifier` を `defaultRequest` ヘッダに付与。**iOS 固有制約は `iosMain` の actual に閉じ、`commonMain` は不変**（Android に漏らさない）。`HttpClient.config` は元設定を引き継ぐため `PlacesClientImpl` 側の再構成でも伝播する（Ktor 3.0.3 ソース確認済）

切り分けは curl 実証（ヘッダ有無で 403/200）+ `.app/Info.plist` の実値確認 + バイナリ `grep -a` の 3 点。

### 2026-06-23: 周辺カフェ検索の精度修正（encodeDefaults + includedPrimaryTypes）

- 領域: KMP（data-places）
- 関連: `shared/data-places/.../PlacesClientImpl.kt`

周辺検索に駅・ホテル等の非カフェが混ざった 2 要因: ①kotlinx.serialization の既定 `encodeDefaults=false` で `includedTypes` 等のデフォルト値フィールドが JSON に載らず、型フィルタ無しの searchNearby になっていた → `encodeDefaults=true`（`explicitNulls=false` 併用で null 省略は維持）②`includedTypes`（cafe を副次に含む場所）+ prominence 順では大型店が上位に来る → **`includedPrimaryTypes=["cafe","coffee_shop"]` + `rankPreference="DISTANCE"`** に変更（`coffee_shop` 併記はチェーン店の分類対策）。

### 2026-06-23: マップ近隣表示を Apple POI に一本化（proactive searchNearby 撤去）

- 領域: KMP（feature/map）+ iOS

マップを開くたびに Places `searchNearby`（課金）で周辺グレーピンを描いていたが、①Apple Maps ネイティブ POI（無料）と二重表示 ②同じ店で座標が微妙にズレる ③ユーザー意図と無関係な課金、のため撤去。近隣表示は Apple POI に一本化し、Places は POI タップ時の placeId 解決だけに使う。同日先行して「周辺」フィルタチップも撤去済み（現在地 FAB があればトグルは冗長というユーザー判断）。

- KMP 減算: `UIState.nearbyPlaces` / `isLoadingNearby` / `onLocationUpdated` を削除
- **`CafeRepository.searchNearby` / `PlacesClientImpl.searchNearby` は data 層 capability として温存**（精度改善済みの実装。→ 2026-07-01 フェーズ 14 の「このエリアを検索」で再利用され、未使用状態は解消）

### 2026-06-23: CafeSearch — 検索欄テキストはローカル `@State` で管理（入力ラグ対策）

- 領域: iOS
- 関連: `iosApp/.../Features/CafeSearch/CafeSearchView.swift`

検索欄の表示値を `bridge.query`（Kotlin `StateFlow` 経由）にすると、`set → Kotlin update → SKIE emit → apply → 再描画` の非同期ラウンドトリップまで文字が echo されず入力ラグが顕著になる。**`@State queryText` を表示の真実の源**とし、Kotlin へは `.onChange` で一方向転送のみ。将来 Kotlin 側から query をリセットする経路が生じたら逆方向反映が別途必要（現行 VM には無し）。

### 2026-06-23: CafeSearch — 「該当なし」は検索確定後のみ表示（UIState.hasSearched）

- 領域: KMP + iOS

「`results` が空である理由」を「未検索」と「検索したが 0 件」に区別するため `UIState.hasSearched` を追加（真実の源は ViewModel）。`onQueryChanged` で false、検索の**成功完了時のみ** true。入力中は初期プロンプト維持、確定して 0 件のときだけ「該当なし」。

### 2026-06-23: PlacesClientImpl.searchText — 地名クエリへのカフェ語補完

- 領域: KMP（data-places）

`includedType="cafe"` 付きの Text Search に地名のみ（「渋谷」等）を渡すと locality 型に一致して 0 件になる（curl 実測）。ユーザーのテキスト検索経路（バイアスなし `searchText(query)`）に限り、カフェ語（カフェ / cafe / café / コーヒー / 珈琲 / coffee）を含まないクエリ末尾へ `" カフェ"` を補完。POI タップの placeId 解決経路（bias あり）と `searchNearby` は対象外。「カテゴリ + 地域を textQuery で表現」は Google 推奨の自然言語パターンであり、idiomatic な対応。

### 2026-06-23: SwiftUI Map の Legal オーナメントは `safeAreaPadding` に追随しない

- 領域: iOS

`Map` を `.ignoresSafeArea()`（全辺）にすると内部 `MKMapView` の Legal 表記が TabBar 裏に隠れる。`safeAreaPadding` は Map 内部のオーナメント配置レイヤーに伝播しない（固定大値でも動かないことを確認）。**`.ignoresSafeArea(.container, edges: [.top, .horizontal])` に変更**し、下辺だけセーフエリアを残して Legal を TabBar 上に出す。下辺のフルブリード感は喪失するが法的要件を優先。

### 2026-06-24: コルーチン規約の確定（runCatching 禁止 / 所有 viewModelScope + clear()）— 昇格記録

- 領域: KMP（全 ViewModel）+ iOS（全 Bridge）

`kotlin-coroutines-flows` Skill 観点の横断レビューで確定し、**2026-07-02 に `coding-conventions.md` §1.2 / §1.6 / §1.7 へ昇格済み**。経緯の要点のみ残す:

- **`runCatching` は `CancellationException` も握りつぶす**ため、画面破棄・サインアウト時のキャンセルがエラー扱いになり協調キャンセルを遮断していた → `CancellationException` 先行 catch + 再スロー、`Exception` でエラー表示のパターンへ全 VM 置換
- **全 VM が app-wide `MainScope` を共有**し、push/pop 画面の collector が破棄後も残る増殖リークがあった → 注入 scope の Job を親にした所有 `viewModelScope`（`SupervisorJob(parentJob)` 子スコープ）+ `clear()` を導入し、Bridge の **`deinit`**（`onDisappear` ではなく）から呼ぶ。`clear()` はスコープ畳みのみに留めること（deinit は Main スレッドとは限らない）
- 同レビューの周辺整理: `LocalCoffeeRepository` の context 名 `ioContext` → `queryContext` 改名（実体は `Dispatchers.Default`。`Dispatchers.IO` は commonMain 不可）
- **同レビューで surfacing した未解決の申し送り**（未修正のまま生きているもの）: ①`AccountView` / `MapTabView` の 0.1s ポーリング → `.task(id:)` パターンへの置換候補 ②`CoffeeEditorView` の `Photo_` 直接組み立て（Bridge にファクトリを足せば解消する軽微な規約逸脱）③`ContentView.swift` は未使用のデモ残骸（削除候補・要ユーザー確認）

### 2026-06-25: Sign in with Apple ボタンのダークモード視認性修正

- 領域: iOS
- 関連: `iosApp/.../AccountView.swift`

背景 `Color.primary.opacity(0.9)` + 前景 `.white` はダークモードで「白背景 + 白文字」になり不可視（lessons 済）。`@Environment(\.colorScheme)` で明示分岐（ライト = 黒地白字 / ダーク = 白地黒字 + separator ボーダー、HIG 慣習）。残置 warning 1 件: `AppleSignInCoordinator` の到達不能フォールバック `UIWindow()` の deprecated 警告（別タスク）。

### 2026-06-25: カフェ検索 — テキスト検索にマップ中心の位置バイアスを適用

- 領域: iOS + KMP
- 関連: `shared/feature/cafe-search/.../CafeSearchViewModel.kt`, `iosApp/.../AppState.swift`

テキスト検索を「マップで見ているエリア寄り」にするため、マップタブのカメラ中心を `AppState.mapSearchCenter` でタブ間共有し、`onSearchTapped(latitude:longitude:radiusMeters:)`（オーバーロード追加）でバイアス付き検索する。3 案（エリア検索ボタン / 検索タブに小地図 / 位置バイアス）からユーザー選択。

- radius は `region.span` から緯度・経度方向のメートル換算の**大きい方**を採用し 1〜50,000m にクランプ。Places の locationBias は soft bias のため「広め側に倒す」
- `mapSearchCenter == nil`（マップ未表示）はバイアスなしにフォールバック
- 検索本体は `launchSearch(errorMessage, producer)` に共通化（Job キャンセル → 状態遷移 → CancellationException 先行 catch）
- 余談: 所有 viewModelScope を持つ VM の `runTest` テストは `finally { vm.clear() }` が必要（`UncompletedCoroutinesError`。lessons 参照。他 feature への横展開は別タスク）

### 2026-06-25: カフェ検索 — 現在地系を撤去しテキスト検索のみに整理 + observation 停止バグ修正

- 領域: iOS
- 関連: `iosApp/.../Features/CafeSearch/CafeSearchView.swift`

- **【バグ修正】検索が 1,2 回で効かなくなる原因は `.onDisappear { bridge.cancel() }`**: タブルートの View は push 先から戻っても再生成されず、`onDisappear` で止めた observation が二度と再開しない。→ 削除し、observation は Bridge `deinit` の `kotlin.clear()` まで生かす（タブルート = 永続 / sheet = View 破棄で自然回収）。lessons「タブ常駐 View の observation を onDisappear でキャンセルしない」の出所
- 位置バイアス導入で役割重複になった現在地周辺検索 UI（現在地ボタン + 自動検索）を全撤去（ユーザー選択）。検索発火は `.onSubmit(of: .search)` のみに集約
- `onNearbySearchRequested` API は残置 → 2026-07-01 フェーズ 14 のエリア検索で再利用され解消

### 2026-06-26: iOSDC LT — 逆方向変換 PoC（言葉→数値）を Foundation Models で実装

- 領域: iOS（自己完結・KMP 変更なし）
- 関連: `TastePreferenceExtractor.swift`, `TastePreferenceConversionView.swift`

LT テーマ「数値⇄言葉の双方向変換」の逆方向（自由文 → 構造化データ）を PoC 実装。順方向と同じ availability ガード + ステートレス session を踏襲し、`@Generable struct TastePreference`（5 軸 Int + roast + summary）を `respond(to:generating:)` で抽出。**`@Generable` に 5 軸が「ある / ない」が変換の向きを表す**（LT の対比ネタの実体）。

- `@Generable` マクロは `Equatable` を自動合成しないため `==` を手書き（将来サポートされたら削除可）
- 言及のない軸は 5（中庸）とする instructions 設計。抽出結果を検索につなぐ処理は未実装（口頭説明）

### 2026-06-26: 冗長な可用性ガード除去 + 逆変換 PoC 導線の表示方針

- 領域: iOS

`IPHONEOS_DEPLOYMENT_TARGET = 26.0`（iOS 26 専用）かつ未リリースのため、`@available(iOS 26.0, *)` / `if #available` / PoC を隠す `#if DEBUG` はすべて冗長としてユーザー方針で sweep（lessons 2026-06-26）。意図的に残した `#if DEBUG` は ①Preview 補助（リリースバイナリ除外）②`seedOrClearDummyData`（RELEASE で毎起動 clear が走る破壊的副作用の防止）。

- **要追跡（リリース前の意思決定）**: 逆変換 PoC 導線（`TastePreferenceConversionView` への NavLink）は現在**分析タブ最下部に全ユーザー常時表示**。App Store リリース前に「本番に含める / 設定 > 開発者向けへ移動 / 削除」を決めること

### 2026-06-29: フェーズ 10-A/B — マップピン再設計 + Places API 追加フィールド

- 領域: iOS（10-A）/ KMP + iOS（10-B）

- **10-A**: 訪問済みピンを 36pt + shadow に拡大し、訪問 2 回以上で回数バッジ（9+ 上限）。3 種ビジュアル体系: 訪問済み（36pt 茶）/ 好み一致（38pt アクセント + ハート）/ Apple 標準 POI
- **10-B**: `Cafe` に表示用 5 フィールド（`openNow` / `weekdayDescriptions` / `phoneNumber` / `priceLevel` / `googleRating`）をデフォルト値付きで追加し FieldMask 拡張。**SQLDelight スキーマは変更なし**（スナップショットには含めず Places API 結果のみで利用）。CafeDetail に営業状態・評価・価格帯・電話・外部リンク・営業時間を追加
- Kotlin のデフォルト引数は SKIE 越えに Swift へ伝播しないため、`Cafe` 構築側の Swift 全箇所に新引数の明示追加が必要だった
- `foregroundStyle(.accentColor)` はコンパイルエラー（`ShapeStyle` にメンバなし）。`Color.accentColor` を明示
- **クラスタリングは将来課題**: SwiftUI `Map` にネイティブ API がなく `MKMapView` ラッパが必要になるため、密集が実問題になった時点で再検討

### 2026-06-29: フェーズ 10-C — 検索結果マップオーバーレイ

- 領域: KMP + iOS

検索結果を「マップに表示」明示ボタンでマップへ流す（自動反映なし）。経路は AppState 経由（`mapSearchCenter` と同じタブ間バスパターン。ViewModel 間直結や共有リポジトリは避ける）→ `MapViewModel.UIState.searchResultPlaces`。クエリ変化時に前回結果を自動クリア、タブ離脱ではクリアしない（意図的に表示した結果を保持）。ピンは青 32pt の第 4 種。

### 2026-06-30: マップ内検索バー（検索タブ廃止・Google Maps スタイル）

- 領域: iOS

**iOS 27 で `Tab(role: .search)` の右端固定動作が廃止**されたため、検索タブを削除して 3 タブ + マップ上部常時表示の検索バーに移行（検索実行 → ドロップダウンリスト → 選択でカメラ移動 + 下部カード → 詳細 push）。

- KMP 変更なし: `CafeSearchViewModelBridge` を MapTabView 内 `@State` で再利用
- `TabBarFrameReader`（検索タブ幾何検出ハック）を削除し、FAB は `overlay(alignment: .bottomTrailing)` 固定に
- `CafeSearchView` はエディタ用コールバックモード（`init(appState:onCafeSelected:)`）のみ残しルートモードを削除
- 上部コントロール高さ 120pt 固定 Spacer は Dynamic Type 最大で不足の可能性（実機確認後に動的計測へ差し替え検討）→ フェーズ 14 の検索モード化で構造ごと解消済み

### 2026-06-30: フェーズ 10-D — タグフィルター（ドメインモデル変更 + UI）

- 領域: KMP + iOS

- **`CoffeeRecord.tags: List<String>`** をデフォルト値付きで追加。SQLDelight は `tags TEXT NOT NULL DEFAULT ''`（JSON 配列文字列、`photoRefsSerializer` 流用）。クリーンブレイク（アプリ削除 → 再インストール）。カフェ粒度でなく**記録粒度**でタグ付けする設計
- `MapViewModel` に `selectedTags` / `availableTags` + トグル API。**`combine` に `MutableStateFlow` を含めると `runTest` がタイムアウト**するため、キャッシュ変数 + `applyTagFilter()` 直接呼びのパターンを採用
- Swift 側は `CoffeeRecord` コンストラクタ呼び出し全箇所に `tags:` 明示追加が必要だった（SKIE デフォルト引数制約）

### 2026-06-30: フェーズ 12-A — データ共有同意フロー

- 領域: KMP + iOS + Firestore Rules

（設計 + flatMapLatest + iOS 実装の 3 エントリを統合）

- **consent は Firestore `users/{uid}` ルートの `analyticsConsent: Boolean`**。理由: ①将来の Rules で「同意済みユーザーの集計コレクション書き込み」を条件化するには Firestore 側に必要 ②デバイス間で同意状態を共有（買い替え時に再同意不要）③`UserDefaults` 管理は Rules と乖離する。`users/{uid}` ルートは今回が初利用（Rules は `{document=**}` と別に `match /users/{uid}` の明示が必要）
- **初回オンボーディング判断 = ドキュメント不在**。`analyticsConsent: false` が明示的に書かれていれば「非同意済み」として表示しない。`@AppStorage` 補助は使わない（Firestore が権威ソース）
- **`observeAccount()` は `flatMapLatest` 合成**: `combine` 案は未サインイン時に consent 側 Flow の `close()` で合成 Flow ごと終了してしまう。`flatMapLatest(observeFirebaseUser())` で auth 変化時に Firestore リスナを自動切替。両メソッド同時購読でリスナが 2 本立つ点は現状許容（`shareIn` ホット化は将来候補）
- iOS: オンボーディング判断は `getDocument()` 一発（Flow 購読は過剰）。sheet は `interactiveDismissDisabled()` でボタン閉じのみ。`makeAuthAccount` の `analyticsConsent:` は常に false（Auth state 監視で Firestore を二重購読しない）
- プライバシーポリシー URL は placeholder（App Store 申請前に差し替え。`app-store-metadata.md` チェックリスト明記済み）

### 2026-06-30: CoffeeRecordFilter.tastingMin/Max の tasting=null レコードの扱い（Phase 13-A-2）

- 領域: KMP（shared/domain）

`tastingMin` / `tastingMax` のいずれかが指定されている場合、`tasting == null`（未記録）のレコードは除外する（`rating=0.0` を評価範囲から除外するのと同じ「未記録を誤ヒットさせない」思想）。各軸は独立評価（全 5 軸がそれぞれ範囲内であること）。13-A-3 で iOS が `TastePreference` → filter 変換時に `axis ± margin(=2)` の範囲を渡す。

### 2026-06-30: CoffeeRecordFilter 新フィールド追加時は Swift 呼び出し側の全更新が必要（Phase 13-A-3）

- 領域: KMP / iOS ブリッジ

Kotlin data class に nullable フィールドをデフォルト値付きで追加しても、Kotlin/Native の Obj-C initializer は全パラメーター必須（SKIE 0.10.12 は DefaultArgumentInterop 未有効化）。`CoffeeRecordFilter(...)` を呼ぶ Swift コードに `tastingMin: nil, tastingMax: nil` の追記が必要だった。今後も同様。SKIE の `defaultArgumentInterop` 有効化を検討するとこの問題は自動解消される。

### 2026-06-30: MapViewModel テイストプロファイルフィルタの設計（Phase 13-C）

- 領域: KMP / アーキテクチャ

`tasteMatchedPlaceIds` は `selectedTags`（ピン絞り込み）とは**独立の別軸**として管理（iOS 側で非マッチピンの半透明化に使うため）。両フィルタの AND 要件が出たら再検討。`latestAllRecords` キャッシュ + 即時 `applyTasteFilter()` はタグフィルタと同じパターン。`combine` の変換式は `Pair<Triple, List>` 返し（複雑化したら data class 化を検討）。

### 2026-06-30: MapTabView フィルタチップ内の Foundation Models 可否チェック（Phase 13-C）

- 領域: iOS / パフォーマンス

`filterChipRow` / `searchBarView` の `TastePreferenceExtractor.makeIfAvailable() != nil` は View body 再描画ごとに評価される（内部は availability 確認のみで軽量、実害なし）。問題が出たら Bridge のフラグ or `@State` キャッシュへ移行。

### 2026-06-30: Phase 12-B — Form 内サジェスト UI は VStack 展開（ZStack 非採用）

- 領域: iOS / SwiftUI

SwiftUI の `Form`（内部 List）は行単位クリッピングのため、ZStack で下に伸ばしても他行を覆うフローティング表示にならない。産地サジェストは「行内展開」の VStack 方式を採用。フローティングが必要になったら `NavigationStack` の `.overlay` にパネルを乗せる方式を検討。

### 2026-06-30: Phase 12-B — BeanProfileRepository コンストラクタ設計

- 領域: KMP

`coffeeInsightProvider: CoffeeInsightProvider?` と異なり `BeanProfileRepository` は**非 null**（iOS / Android とも Firestore 実装が必ず要るため）。iOS 用コンストラクタが 6 引数になり、SKIE デフォルト引数制約により `AppState.swift` の `AppContainer` 生成へ `beanProfileRepository:` の明示追加が必要だった。

### 2026-06-30: Phase 12-B — BeanProfileRepositoryAndroidImpl の Firestore Task キャンセル処理

- 領域: Android / KMP

Firestore の `get()` Task はキャンセル不可。`suspendCancellableCoroutine` の `invokeOnCancellation` は空にし、キャンセル後にコールバックが到達した場合は「キャンセル済みコルーチンへの resume は idempotent」という kotlinx.coroutines の仕様に委ねる。`RemoteCoffeeDataSourceAndroidImpl.awaitTask` も同方針。

### 2026-06-30: TastePreference.searchKeywords によるカフェ検索補完（Phase 13-D）

- 領域: iOS / Foundation Models

`TastePreference` の 5 軸ベクトルを日本語キーワード（"フルーティ 浅煎り 酸味" 等）へ変換する `searchKeywords` を追加（スコア 7 以上 =「高い特徴」、body のみ 4 以下 =「低い特徴」）。全スコア中間 + roast unknown は空文字を返し呼び出し元でエラー表示。Places はカフェのテイスティング詳細を持たないため精度は限定的 — 「新しいカフェを発見する」補助機能として位置付ける。

### 2026-07-01: Phase 12-C — PreferredBeanTraits の matchedProfiles と LLM プロンプトの分離

- 領域: KMP / iOS

`PreferredBeanTraits.matchedProfiles: List<BeanProfile>` は保持するが、現時点で LLM プロンプトには含めていない（`dominantFlavorNotes` / `originHint` / `roastLevelHint` / `dominantTastingAxis` のみ使用）。将来豆名や詳細フレーバーを足す場合は `matchedProfiles` を走査すればよい。

### 2026-07-01: Phase 12-C — beanTraitsInsightStatus の初期値は Idle（Unsupported ではない）

- 領域: iOS

`insightStatus`（AI 要約）の初期値は `Unsupported`（非対応端末でセクション非表示）だが、`beanTraitsInsightStatus` は **`Idle`**。LLM 非対応端末でも `PreferredBeanTraitsCard` はフレーバータグのフォールバック表示が機能するため、`Unsupported` にするとフォールバック UI ごと消えてしまう。`beanProfiles` 未投入時は `stats.preferredBeanTraits` が nil でセクション自体が出ない、という表示制御の責任分担。

### 2026-07-01: Phase 12-C — PreferredBeanTraitsCard で InsightLoadedCard を流用しない理由

- 領域: iOS / SwiftUI

`InsightLoadedCard` は `"sparkles"` SF Symbol 固定で、豆傾向カードには `"leaf"` を使いたいため流用せず直接実装。将来アイコン引数を追加して統一可能。

### 2026-07-01: マップ検索の使い勝手改善（フェーズ 14）— エリア検索ボタンと検索モード

- 領域: iOS + KMP（cafe-search）

Google Maps 風に「表示範囲内のカフェを一括ピン表示」できるようにした。product 決定は「このエリアを検索」ボタン方式（自動再検索なし = Places 課金の発火頻度を制御）+ テキスト検索結果は全件ピン + リスト併用。

- KMP: `onNearbySearchRequested` に半径付きオーバーロード追加（SKIE デフォルト引数制約への通常対応）
- **ボタン出現しきい値**: `中心移動 > アンカー半径の 30%` OR `半径比 1.5x 逸脱`。数値は経験則（要件根拠なし）。チューニングは `MapTabView.shouldShowAreaSearchButton`
- **検索完了検知の一本化**: テキスト / エリア両検索を `searchBridge.isLoading` の false 遷移に集約し、`isAreaSearchInFlight` でトリガー判別。極端な連打時の判別整合性は理論上完全でないが v1 許容
- **ピン集合と選択の関心分離**: 選択やカード閉じでは全ピンを残す（Google Maps 的）。全消去は検索バーの × のみ。Places New は 1 回最大 20 件（密集エリアは頭打ち）
- **検索モード化**: `@FocusState` + `showingSearchResults` で `isSearchMode` を定義。検索モード中はフィルタチップ非表示 + 結果リストを検索バー直下の同一 VStack に流し込み、固定オフセット由来の視覚衝突を構造的に解消。エリア検索ボタンは**検索モード中かつパン / ズーム後のみ**表示（ブラウズ閲覧を邪魔しない。ユーザー要望による最終仕様）

### 2026-07-02: docs 棚卸し — 実装と docs の齟齬 4 件を修正

- 領域: Docs

docs 全体精査（実コード突合）で修正: ①`data-model.md` にフェーズ 10 / 12-C を追随（tags / Cafe 表示用フィールド / preferredBeanTraits 等。tasks.md ではチェック済みだが実際は未反映だった）②`kmp-bridge.md` の「data-firebase は export しない」を実体に合わせ修正 ③`app-store-metadata.md` を CoffeeRecord 主体へ全面改訂 ④本ノートのサマリを全面更新（旧サマリは 2026-06-15 頃で凍結し Visit 系記述が残っていた）。lessons 2026-06-16「横断 doc は構造的に陳腐化する」の再発防止としてサマリに「最終棚卸し」日付を導入。

未対応バックログ: kmp-bridge / coding-conventions / ui-ux-guidelines に残る Visit 系の旧例文、backlog ID「B-4」と Phase B-4 の名前衝突。

### 2026-07-03: iosApp コードレビュー指摘 #1〜#5 の修正 — ライフサイクル / 削除順序の判断

- 領域: iOS
- 関連: tasks.md「iosApp コードレビュー指摘対応（2026-07-03）」、lessons.md 2026-07-03

1. **`bootstrap()` は「観測される状態の公開を最後」にする**: `uid` / `status = .ready` は画面切り替えトリガーであり、途中で代入すると loadingView の `.task` キャンセルに巻き込まれて `checkConsentOnboarding` が無音スキップされる timing バグになる。startInitialSync → seed/clear → ブリッジ生成 → consent チェック → 最後に uid/status 公開の順に固定。再入は `guard status != .signingIn`
2. **アカウント処理の完了待ちは二相ポーリング**（`awaitProcessingCompletion()`）: 相1 = `isProcessing == true` 遷移を最大 2 秒待つ（KMP emission 到着前の誤「完了」判定 → 処理中に写真全削除が走るレースの解消）、相2 = false 遷移を最大 30 秒。根治には KMP 側の完了イベント公開が必要（v1 許容）
3. **写真物理削除は「レコード消失を state で確認してから」**: `pendingPhotoDeletions` に登録し、`apply()` で `coffees` から id が消えたのを確認して削除。「孤児ファイル < 写真消失」の安全側。孤児掃除が必要になったら起動時 GC（DB と Documents/photos の突合）を別途検討

### 2026-07-03: shared コードレビュー指摘 #1〜#3 の修正 — 同期・座標・FK の判断

- 領域: KMP / shared
- 関連: tasks.md「shared コードレビュー指摘対応（2026-07-03）」、data-model.md §2.2 注記・§4.2、lessons.md 2026-07-03

1. **同期 reconciliation は「全件スナップショット差分」方式**: `startSync` がスナップショットに無い id のローカル行を削除してから upsert。tombstone 方式は個人アプリ規模に過剰と判断。`DummyCoffeeData.ids` 除外で core が dev データを知る結合は、引数化より単純さを優先。save〜upload 間の一瞬の消失窓は pending writes 込みリスナ前提で極小として許容（競合解決の本格化は backlog B-1）
2. **エディタは選択 `Cafe` を丸ごとセッション保持**（`selectedCafe`、onAppear〜次の onAppear のみ有効）: 座標・photoReferences は「選択あり → selectedCafe / Edit 選択なし → 初期レコード / Create 手入力 → null」の優先順位で `buildCafe()` に集約。**旧判断「draft に座標を保持しない」（2026-06 スライス 2 設計）は本修正で廃止**。過去レコードの座標の遡及補正はしない
3. **FK は本番ドライバで有効化 + 掃除 migration**: Android = `AndroidSqliteDriver.Callback.onConfigure`、iOS = sqliter `extendedConfig.foreignKeyConstraints = true`。明示 `deleteByRecord` 追加は CASCADE と二重管理になるため不採用。FK 無効期間の孤児 photo 行は `2.sqm` で一括削除。iOS テストドライバも FK ON に統一し、`iosSimulatorArm64Test` で赤 → 緑を実証（= 従来 iOS ターゲットのテストは回っておらず、回していれば検出できていた → lessons）

### 2026-07-04: サブエージェント定義の改善 — memory / skills プリロード / スコープ強制フックの採用

- 領域: `.claude/agents/**` / `.claude/hooks/**` / CLAUDE.md（3 ロール運用）
- 関連: tasks.md「サブエージェント定義の改善（2026-07-04）」

エージェント定義が Phase 2.5 時点のまま陳腐化していた（旧 `sharedLogic` スコープ / 実在しないタスク名 / 旧 Visit モデル）のを現行構成に更新し、2026 年時点の公式機能を採用した。

1. **`memory: project` を採用**（`.claude/agent-memory/<name>/` を git 管理）: 「サブエージェントは docs を読めるが書けない → 学びが残らない」への公式解。責任分界は「作業ノウハウ = agent memory / 仕様・トレードオフ・汎用教訓 = レポート経由で親が docs へ」。docs と重複するメモリ複製は禁止
2. **書き込みスコープを PreToolUse フックで機械強制**: `validate-write-scope.sh` 1 本を両エージェント共用、許可プレフィックスは frontmatter 引数。違反は exit 2 で「親への依頼」ルートへ誘導（ガードレールでありセキュリティ境界ではない。Bash 経由は対象外）
3. **Skill は frontmatter `skills` プリロード + フォールバック**: 現行ハーネスはプリロード本文を展開しないと実測判明 → 「展開されていなければ Skill ツールで起動」のフォールバック文を残した（ハーネス更新後に削除予定）
4. model は `sonnet` 据え置き（実装ワーカー = Sonnet、仕様判断 = 親のルーティング維持）
5. 必読 docs から CLAUDE.md を削除（カスタムサブエージェントには自動ロードされる。Explore / Plan 組み込みはスキップされる点に注意）
6. 起動確認 dispatch での補正: メモリがユーザースコープへ書かれた → リポジトリ内を正と明示 / スコープ記述の実在しないパスを実体に修正 — **エージェント定義も「横断 doc」として陳腐化する**（lessons 2026-06-16 と同根）

### 2026-07-04: CLAUDE.md スリム化 — .claude/rules/ パススコープ分割とモジュール表の参照一本化

- 領域: CLAUDE.md / `.claude/rules/**`
- 関連: tasks.md「CLAUDE.md のスリム化と .claude/rules/ 分割（2026-07-04）」

CLAUDE.md が 240 行と公式推奨（200 行以下）を超過し、docs 二重管理箇所が陳腐化の常習箇所になっていたため再構成（240 → 131 行）。

1. **言語別規約は `.claude/rules/` のパススコープ規則へ**（`kotlin-kmp.md` / `swift-ios.md`。対象ファイルを触るときだけロード）。rules は「要点 + docs 正本への参照」の薄い構成で三重管理を回避。**rules のサブエージェント伝播は実測確認済み**: 起動時ではなく、paths にマッチするファイルを Read した直後に全文が遅延注入される（skills プリロードと違い現行ハーネスで機能する）
2. **モジュール構成 11 行表を削除**: `settings.gradle.kts`（一覧）と `architecture.md`（役割・依存方向）への参照に一本化。陳腐化が実証済みのストック型キャッシュを面ごと消した
3. **lessons の親運用ルール 4 件を CLAUDE.md へ昇格**（OVERRIDE フラグ再検証 / iOS テストの DEVELOPER_DIR 実行 / 横断 doc 同時更新 / 横断点検やり切り）: 毎セッション必ず載る場所に置いて常時効かせる
4. アーキテクチャ不変条件は CLAUDE.md 本体に残置（毎回の仕様判断・dispatch 判断に必要で変更頻度も低いため）

### 2026-07-04: 実装ノート棚卸し — 約 120 エントリ → 64 エントリ

- 領域: Docs

本ノートが 2160 行 / 約 297KB に肥大化したため、運用ルール（陳腐化は削除可 / 昇格時は削除）に沿って棚卸しした（ユーザー承認済み）。

- **削除（約 40 件）**: 旧 Visit / sharedLogic 時代（2026-06-19 クリーンブレイク以前）の設計判断、後続エントリで置換済みの暫定対応（CI 暫定コマンド / 3 タブ構成 / Nearby・現在地検索まわり等）。現役の結論はサマリと正規 doc（architecture / data-model / kmp-bridge / coding-conventions / lessons）に反映済みであることを確認のうえ削除
- **統合**: シリーズエントリ（B-1×5 / B-4×3 / アカウント + revoke×4 / Q&A×3 / 12-A×3 / テイスティング×2 / Places 疎通×2 ほか）を最終形 1 本ずつに
- **圧縮**: 現役だが冗長な事前設計エントリを「確定判断 + 理由」だけに
- 見出しスタイルを `### YYYY-MM-DD: タイトル` に統一し日付順へ整列。削除済みエントリへの過去参照（tasks.md の完了行等）は git 履歴（`git log -p docs/implementation_note.md`）で辿る
- **同日 `tasks.md` も縮約**（860 行 / 127KB → 285 行 / 24KB）: 完了フェーズは「完了サマリ + 未完行のみの表」に置換し、未完 26 件は全数維持・`##` セクション見出しは参照アンカーとして全保全。以後この運用（tasks.md 冒頭に明記）を継続する

### 2026-07-04: architecture.md 現行化 — D-2 書き込みフロー再構成と例コードの実体化

- 領域: Docs
- 関連: `docs/architecture.md`, tasks.md バックログ D-2

Visit 残骸 31 件（冒頭の「読み替えてください」バンドエイド含む）を消し込み、現行構成に全面追随した。

- **D-2（書き込みフロー）**: 「プラットフォーム別 VisitRepository 実装」という旧構成の図を、現行の `CoffeeRepositoryImpl`（shared/core・プラットフォーム共通合成）+ `RemoteCoffeeDataSource`（プラットフォーム別実装）+ `WritePolicy` に書き直した
- **例コードと実体の乖離を修正**: `kmp.library` 例（実体は jvmToolchain なし / iosX64 なし / `com.android.kotlin.multiplatform.library`）、`kmp.feature` 例（自動配線は core+domain のみ。coroutines-core は手動追加）、ViewModel / Bridge 例（所有 viewModelScope + clear() / @MainActor / deinit）、テスト例（`finally { vm.clear() }`）、Security Rules 記述（path uid 検証が実体）、外部依存表（未採用の Napier/kermit 行を削除し SKIE / Foundation Models を追加）
- **完了済みの「段階的移行ステップ」表を削除**し、今後も効く運用ルール（別 PR / ビルド確認 / パッケージ一致 / framework 追記）だけ「モジュール分割の運用ルール」として残した
- iosApp ツリーの実在しない `Bridge/` ディレクトリ表記を実体（`Features/<Name>/` 同居 + `FirebaseRepositories/FlowBridge.swift`）に修正（2026-07-04 エージェント定義改善で発覚したのと同じ誤り）
- 残っていた Visit 旧例文は同日中に消し込み済み: `ui-ux-guidelines.md` 2 件を CoffeeListView / コーヒー記録の例に更新（`coding-conventions.md` の 1 件は `ObserveVisitedCafesUseCase` = 現行の正当名で修正不要と確認）。あわせて `tasks/lessons.md` を日付順に整列（誤配置 12 件を発生日セクションへ移動・重複 1 件を統合・旧モデル例文を現行化。教訓 64 件は全数維持）



### 2026-07-06: ゼロベース設計レビュー — 3 条件との突き合わせとフェーズ 15 起票

- 領域: 仕様 / Docs
- 関連: `requirements.md` §10・§2（2-8〜2-11）・§9（9-7, 9-8）・7-4、`tasks.md` フェーズ 15

現状プロジェクトを一旦離れ「①コーヒーを記録できる ②おいしい店を探せる ③自分の好みを見つけられる」の 3 条件から理想の iOS アプリをゼロベース設計し、現状と突き合わせた（ユーザー依頼）。設計の軸は「記録 → 好みが見える → 好みに合う店に出会う → また記録する」のコアループで、ボトルネックは (a) 記録の摩擦 と (b) 探す→行く の橋渡し、と整理した。

**突き合わせの結論**: ③好み分析は理想形超え（3 階層分析 + 味覚一致推薦 + 自然言語検索まで実装済み）。①記録は基盤堅牢だが入力摩擦が高い。②店探しは「検索」は充実しているが「見つけた店を保存して再訪する」出口（ウィッシュリスト）が丸ごと欠落しており、これが最大のギャップ。提案 5 件を全て採用しフェーズ 15 として起票した。

採用しなかった / 見送った論点（要件化していないもの）:

- **`cup` フィールドの削除・タグへの統合**: 使用率が低そうな割に入力欄を占有するが、害が小さく既存データ・全レイヤーに触る割に益が薄いため現状維持。エディタが窮屈になったら再検討
- **カレンダー表示**: 月別セクション（2-11）で当面足りると判断し △ 扱い（要件表の備考に記載）
- **写真のクラウド同期復活**: 端末ローカル + iCloud Backup の確定方針（2026-06-10）は変更しない。代わりにエクスポート 7-4 を ○ に引き上げてテキストデータの持ち出し手段を確保
- **分析の統計精度のさらなる向上**: 収縮平均 + z ゲートで十分。現段階はループの穴埋め（15-A/B）の方がユーザー価値が高い
- **9-8（未経験豆の探索提案）は △ に留めた**: 9-5（既訪問店の再訪推薦）・12-D（協調フィルタ = サーバー前提）の中間に位置する新規開拓ナッジ。BeanProfile × FavoriteSignals でサーバー不要に作れる算段だが、優先度は 15-A〜D の後

### 2026-07-06: 15-A SavedCafe KMP 実装 — WritePolicy 共用ほかの実装判断

- 領域: KMP / shared
- 関連: `data-model.md` §1.9〜§4.3、tasks.md フェーズ 15-A（kmp-engineer レポートより親が採録）

- **`WritePolicy` の共用方法**: `SavedCafeRepositoryImpl` は独自 enum を作らず `CoffeeRepositoryImpl.WritePolicy`（nested enum）をそのまま型として再利用する。トップレベル切り出し案は、既存テストが `CoffeeRepositoryImpl.WritePolicy.*` を参照しており無用な破壊的変更になるため見送り。**3 つ目の Repository 合成パターンが増えた時点でトップレベル化を再検討**（現状 2 箇所の YAGNI 判断）
- **`MapViewModel.recordedPlaceIds` はタグフィルタ前の全件から算出**: 行きたい一覧の「記録あり」バッジは、タグでピンを絞り込んでいても「実は記録済み」を正しく示すべきで、フィルタ適用後の `visitedCafes` に連動させない
- **一覧シートの表示状態（isPresented）は KMP に持たせない**: sheet 表示トグルを VM 状態に持つ前例がコードベースに無く、「画面遷移は iosApp / androidApp の Navigation 層で繋ぐ」原則に従い SwiftUI の `@State` に委ねる
- **`CafeDetailViewModel` に `error: String?` / `onErrorDismissed()` を追加**: `onSaveToggled` の失敗を握りつぶすと `MapViewModel` のエラーハンドリング規約と非対称になるため、同じパターンで対称化（依頼に明記は無かったが妥当と判断し親が承認）
- 破壊的変更は `AppContainer` 公開コンストラクタ 3 本への `remoteSavedCafeDataSource` 追加のみ（SKIE がデフォルト引数を出さないため全オーバーロードに必須追加）。iOS 追随は ios-engineer に dispatch

### 2026-07-06: 15-A SavedCafe iOS 実装 — ピンのビジュアルと表示トグルの置き場所

- 領域: iOS / SwiftUI
- 関連: `data-model.md` §1.9、tasks.md フェーズ 15-A（ios-engineer レポートより親が採録）

- **行きたい店ピンのビジュアル**: `Color.indigo` + `bookmark.fill`、直径 34pt（訪問済み 36pt と検索結果 32pt の中間）。既存 3 種（訪問済み = brown/`cup.and.saucer.fill`、好み一致 = accentColor/`heart.fill`、検索結果 = blue/`mappin.and.ellipse`）との識別性を優先
- **ピンの dedup（訪問済み > 行きたい > 検索結果）は「行きたい」フィルタチップの状態に関わらず常時適用**: 競合解決はデータ整合性の関心事で、表示切替とは独立
- **「行きたい」フィルタチップの表示状態は Swift `@State` のみ（KMP に持たない）**: `MapViewModel` の `onShowVisitedToggled`（訪問済みトグル）とは非対称になるが、表示切替のみの関心事として View 側で完結させた。KMP 側へ寄せ直すかは他プラットフォーム実装が現実化した時に再検討
- **一覧シートは保存日時テキストを表示しない**（savedAt 降順の並びだけで表現。Simplicity First、必要なら後付け可）
- `CoffeeFirestoreMapper` の `toCafeMap`/`cafeFromMap` を `private` → `internal static` 化し、`SavedCafeFirestoreMapper` から再利用（cafe 直列化規則の重複実装を回避）

### 2026-07-06: 15-B 記録摩擦低減 KMP 実装 — Duplicate の cafe 引き継ぎ経路と既存バグの発見

- 領域: KMP / feature/coffee-editor
- 関連: requirements 2-8 / 2-9 / 2-10、tasks.md フェーズ 15-B（kmp-engineer レポートより親が採録）

- **`Mode.Duplicate` の cafe は `Mode.Edit` と同一経路（`currentInitialRecord.cafe` フォールバック）で引き継ぐ**: 複製後の新記録は複製元と同一の placeId を持つ（Places 実在カフェはその ID、セルフ抽出の手入力カフェは複製元採番の UUID）。「cafe を引き継ぐ」=「同じ物理カフェへの参照を保つ」の解釈で、placeId に一意性制約は無いため矛盾しない。`VisitedCafe` 集計上も同一店としてまとまるのはむしろ意図どおり
- **サジェストの発火条件は `draft.cafeName` が空かどうかで判定**（`selectedCafe` 変数ではなく）: `buildCafe` の「cafe = null」判定も `cafeName` ベースであり、判定基準を統一
- **既存バグを発見（未修正・15-B スコープ外）**: `buildCafe` の Edit 分岐は `currentInitialRecord?.cafe` が null なら `return null` するため、セルフ抽出記録の編集で手動カフェ名を入力しても cafe が保存されない（手入力カフェとして新規 UUID を採番すべき）。`Mode.Duplicate` も同分岐のため同挙動を継承。フェーズ 6 の後続タスクに起票済み。次に Edit/Duplicate のカフェ引き継ぎを触るときに修正する

### 2026-07-06: 15-B iOS 実装 — 位置情報ガードの置き場所と詳細画面の Menu 化

- 領域: iOS / SwiftUI
- 関連: requirements 2-8 / 2-10、tasks.md フェーズ 15-B（ios-engineer レポートより親が採録）

- **位置情報の「未許可なら無音」制御は呼び出し側（`CoffeeEditorView`）でガード**: 共有ユーティリティ `LocationManager.requestLocation()` は `.notDetermined` で許可ダイアログを出す設計（`MapTabView` の明示的な現在地ボタン向け）のため、これを変えず、エディタ側が `authorizationStatus` を事前 switch して許可済みのときだけ呼ぶ。共有ユーティリティの挙動変更による他画面への影響を回避
- **詳細画面ツールバーを Menu 化**: 単発「編集」ボタンを `Menu`（`ellipsis.circle`）に置き換え、「編集」「これをもとに記録」の 2 アクションを内包。ツールバーのボタン数を増やさない HIG 標準の overflow パターン
- **サジェストチップの表示条件は `!suggestedCafes.isEmpty` のみ**: 「カフェ選択でチップが消える」制御は KMP 側の状態管理に委ね、Swift 側で二重ガードしない
- 複製起動時は `initialCafe` を渡さない（複製元カフェは KMP の `toDuplicateDraft` が設定済み）。`Duplicate` の画面タイトルは Create と同じ「コーヒーを記録」
- **許可未決定ユーザー向けの明示入口（「近くのカフェから選ぶ」ボタン + タップ時のみ許可ダイアログ）は検討の上見送り**（2026-07-06 ユーザー判断）: サジェストは許可済みユーザー向けの補助機能と割り切る。マップで現在地を一度使えば以後は発動する

### 2026-07-06: 15-C 一覧検索 + 月別グルーピング KMP 実装（サブエージェント中断→親仕上げ）

- 領域: KMP / feature/coffee-list / sharedUI
- 関連: requirements 6-1 / 2-11、tasks.md フェーズ 15-C

- `CoffeeListViewModel` の `UIState.coffees: List<CoffeeRecord>` を `sections: List<MonthSection>` に置換（破壊的）+ `searchQuery` + `onSearchQueryChanged`。検索 → 月別グルーピングの順で `buildSections` に純粋関数化。yearMonth は `"YYYY-MM"` ゼロパディング、セクション降順・月内順序維持（安定フィルタ）
- **サブエージェント（kmp-engineer）がビルド検証直前でセッション上限により中断**。実装・テストは完成状態で残っており、親が内容をレビューのうえ検証を引き継いだ
- **破壊的変更の波及先を親が補完**: `coffees` 廃止により `sharedUI/CoffeeListScreen.kt`（Android 検証用 Compose 画面）が未追随でビルドを壊す状態だった。`sections` ベース（月別ヘッダ + 記録行）に更新。Android 検証画面は「VM が Android でも動く + Firestore observe 往復」を示す最小実装のため、検索 UI は付けず月別表示のみに留める（検索は iOS 一覧の関心事）
- 教訓寄り: feature の `UIState` フィールドを rename/廃止する破壊的変更は、`sharedUI`（Android 検証）と `iosApp`（Bridge）の両方が波及先になる。KMP 側 dispatch 時に「`shared*` 内の参照追随（sharedUI 含む）まで」を必ずスコープに含める

### 2026-07-06: 15-D 分析空状態プログレス KMP 実装 + iOS テストの Native cancel drain 修正

- 領域: KMP / feature/analysis
- 関連: requirements 9-7、tasks.md フェーズ 15-D、lessons 2026-07-06（2 件）

- `AnalysisViewModel.UIState` に `readiness: AnalysisReadiness?` を派生追加（`CoffeeStats` は不変＝LLM 入力を汚さない）。閾値は `FavoriteSignals().minSampleSize` / `BuildCoffeeStatsUseCase.CORRELATION_MIN_SAMPLE` を参照しハードコードしない。`hasAnySignal` は `FavoriteSignals` の file-private 拡張関数
- **サブエージェント（kmp-engineer）のレポートがセッション上限で尻切れ**になり、`androidHostTest` green のみ報告。親が iOS 検証を引き継いだところ **iosSimulatorArm64Test が 16 件全滅**（`UncompletedCoroutinesError` / SupervisorJob Active / 各 60s）だった
- **根本原因と修正**: `vm.clear()`（`viewModelScope.cancel()`）は Native では runTest の完了チェック前にキャンセルが処理されず SupervisorJob が Active のまま残る。`finally { vm.clear() }` → `finally { vm.clear(); testScheduler.advanceUntilIdle() }` に変更して drain。iOS/Android とも 16/0 green を親が実測確認。`backgroundScope` に載せ替える案は `advanceUntilIdle()` が VM の observe を駆動せず state=null になる別の壊れ方をしたため不採用（経緯は lessons 2026-07-06）
- **副次発見**: `AnalysisViewModelQaTest` の fake が 12-C の `summarizeBeanTraits` override を欠き、commonTest が長期間コンパイル不能なまま見過ごされていた（本体 main は green のため気付けず）。fake 追随 + drain 追加で解消
- **プロセス教訓**: サブエージェントの「androidHostTest green」報告を VM テストの完了根拠にしない。親が必ず `iosSimulatorArm64Test` を回す（既存の親責務「iOS ターゲットのテスト実行」の具体例。CLAUDE.md 準拠）

### 2026-07-06: 15-D 空状態プログレス iOS 実装

- 領域: iOS / SwiftUI
- 関連: requirements 9-7、tasks.md フェーズ 15-D

- `AnalysisView` に `AnalysisReadinessProgressCard` を追加。表示条件は `readiness != null && !readiness.hasAnySignal`（`totalCount==0` は既存 emptyState 分岐に入り到達しない）。`ProgressView(value: ratedCount/categoryThreshold)` を主表示に、残り件数 = `max(0, categoryThreshold - ratedCount)` で「あと N 杯…」/「もう少し記録すると…」を出し分け。テイスティング相関 track は残数ありのとき控えめな補足キャプション（「できます」止まりで断定回避）
- **将来リスク（tasks.md 15-D にバックログ化）**: 既存 `favoriteSignalsSection` は iOS 側で `stats.favoriteSignals` の 4 フィールドから独自に「信号あり」を再計算しており、今回の `readiness.hasAnySignal`（KMP 算出）と別経路。現状は同一 `stats` から同時導出で齟齬なしだが、KMP 側判定が変わると乖離しうる。単一ソース化は分析タブを次に触るときに寄せる

### 2026-07-07: 15-E-2 データエクスポート KMP 実装 + B-6（Native .format）解消

- 領域: KMP / shared/domain
- 関連: requirements 7-4、tasks.md フェーズ 15-E-2 / backlog B-6

- `ExportCoffeeRecordsUseCase`（`suspend operator fun invoke(userId): String`、`@Throws`）: `observeAll(userId).first()` → **export 専用 `@Serializable` DTO**（`domain/export/`）→ `Json { prettyPrint = true; encodeDefaults = true }`。ドメインモデルに `@Serializable` を付けず DTO 分離（Firestore 直列化規則踏襲: enum は `.name` / 日時は文字列 / 写真はメタデータのみ）。包みは `{ exportedAt, version: 1, records: [] }`（将来互換のため version 保持）。`AppContainer.exportCoffeeRecordsUseCase` で公開
- **`encodeDefaults = true` 必須**: 既定 false だと `version=1` や空 `tags`/`photos` が省略される（lessons の Places `Json{}` 教訓と同根のため新規 lessons は不要と判断）
- **SKIE は `operator fun invoke` を Swift の `callAsFunction` 化しない**: iOS は `appContainer.exportCoffeeRecordsUseCase.invoke(userId:)` と明示呼び出し（`(userId:)` 糖衣不可）。他の `operator fun invoke` UseCase も同様
- **B-6 解消（親対応）**: 15-E-2 の export テストは domain にあり、iOS 検証が backlog B-6（`FavoriteSignalsPersonaTest` の `"%.Nf".format` = JVM 専用で Native コンパイル不能）でブロックされていた。この壊れテストは domain の iOS テストを丸ごと止めており、15-E-1・15-E-2 と 2 度検証を阻害したため、親が Native 安全な `Double.fmt(digits)` ヘルパ（デバッグ/メッセージ用途のみ・アサーション条件に非関与）に全 44 箇所置換。domain の iOS テストが全 green に回復（Persona 11 / Export 4 / 他 failures=0）。以後 domain の Native テストが CI・親検証で回せる
