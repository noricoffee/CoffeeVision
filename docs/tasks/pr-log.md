# PR / 振り返りログ

過去の PR・バグ修正・機能追加の振り返り記録。
新しい PR をマージしたら以下のフォーマットで追記する。

```
### YYYY-MM-DD - <タイトル>
- 変更点:
- 動作確認:
- 残課題 / フォローアップ:
```

---

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
  - `xcodebuild -sdk iphonesimulator -scheme iosApp build` → BUILD SUCCEEDED（今回変更分の新規 warning ゼロ）
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
  - 🟠設計判断パック（B 系）/ C-1 / D-1 → 後回し可。`tasks.md` の「docs / 設計判断バックログ」節に移管

### 2026-06-23 - マップ「周辺」フィルタチップ撤去（周辺ピン常時表示）
- 背景: 現在地 FAB（カメラを現在地へ recenter）があるため、周辺ピンの表示/非表示トグル（`showNearby`）は冗長というユーザー判断。周辺ピンは常時表示に統一。`訪問済み` チップは維持。
- タスク:
  - [x] KMP: `MapViewModel.UIState.showNearby` と `onShowNearbyToggled` を撤去（`nearbyPlaces` は常時公開のまま）。KDoc 追随
  - [x] iOS: `MapViewModelBridge` の `showNearby` プロパティ / `onShowNearbyToggled` / state 同期を撤去
  - [x] iOS: `MapTabView` の「周辺」`FilterChip` を撤去、`if bridge.showNearby` ゲートを常時表示化
- 動作確認:
  - [x] KMP / iOS `xcodebuild` BUILD SUCCEEDED（新規 warning ゼロ）
  - [ ] シミュレータ目視（周辺ピン常時表示 / 訪問済みチップは機能 / 現在地 FAB）はユーザー作業
- 所見: FilterChip 行は「訪問済み」+（好み一致カフェ時のみ）`RecommendedLegendBadge` が残る。

### 2026-06-23 - カフェ検索の入力ラグ修正（検索欄テキストをローカル @State 化）
- 背景: 実機 debug で検索タブの入力が重い。`.searchable` の text バインディングが Kotlin `StateFlow`（`bridge.query`）を真実の源にしており、1 文字ごとに onQueryChanged → StateFlow emit → SKIE AsyncSequence → apply の非同期ラウンドトリップを経てから表示が追随するため echo が遅延する。
- タスク:
  - [x] iOS: `CafeSearchView` の検索欄テキストをローカル `@State queryText` で即時 echo し、Kotlin へは `.onChange` で一方向転送
- 動作確認:
  - [x] iOS `xcodebuild` BUILD SUCCEEDED（新規 warning ゼロ）
  - [ ] 実機での入力体感（ラグ解消）はユーザー作業

### 2026-06-23 - カフェ検索「該当なし」を検索確定後のみ表示（入力中は出さない）
- 背景: 入力中でも results 空 + クエリ非空だと「該当なし "○○"」が逐次更新表示し、逐次検索しているように見える。Places は確定実行方式なので表示も確定後のみにする。
- タスク:
  - [x] KMP: `CafeSearchViewModel.UIState.hasSearched` 追加 + commonTest 追随（11 ケース green）
  - [x] iOS: `CafeSearchViewModelBridge.hasSearched` 公開 + `CafeSearchView` 表示分岐を更新
- 動作確認:
  - [x] KMP test green / iOS `xcodebuild` BUILD SUCCEEDED
  - [ ] 実機/シミュレータ目視はユーザー作業

### 2026-06-23 - カフェ検索: 地名クエリで 0 件になる問題（textQuery にカフェ語を補完）
- 原因: `PlacesClientImpl.searchText` は `includedType="cafe"` で絞る。地名「渋谷」「池袋」は locality 型にマッチし cafe フィルタで弾かれ 0 件になる。
- 仕様: バイアスなし `searchText(query)` のみ、カフェ語を含まなければ末尾に ` カフェ` を補完。
- タスク:
  - [x] KMP: `PlacesClientImpl.ensureCafeKeyword` を実装 + commonTest 6 ケース
- 動作確認:
  - [x] KMP test green / iOS コンパイル成功
  - [ ] 実機/シミュレータ目視はユーザー作業

### 2026-06-23 - マップ Legal 表記が TabBar に隠れる問題（下端セーフエリア復元）
- 原因: `Map` に `.ignoresSafeArea()` を付けてフルブリード表示しているため、MapKit が自動配置する Legal 表記が TabBar 裏に潜る。
- 経緯: `.safeAreaPadding(.bottom, ...)` は SwiftUI `Map` の Legal オーナメントに追随せず無効と確認。
- タスク:
  - [x] iOS: `Map` を `.ignoresSafeArea(.container, edges: [.top, .horizontal])` に変更（下辺セーフエリアを TabBar 上端で残す）
- 動作確認:
  - [x] iOS `xcodebuild` BUILD SUCCEEDED
  - [x] シミュレータ目視で Legal が TabBar 上端の上に表示確認
  - [ ] 実機での見た目はユーザー確認

### 2026-06-25 - カフェ検索: テキスト検索にマップ中心の位置バイアスを適用
- 背景: 検索タブのテキスト検索は位置バイアスなしで、結果が現在地寄りになりやすい。マップタブのカメラ中心をタブ間で共有してバイアスに使う。
- タスク:
  - [x] KMP: `CafeSearchViewModel` にバイアス版 `onSearchTapped(latitude, longitude, radiusMeters)` 追加 + commonTest 2 ケース
  - [x] iOS: `AppState.mapSearchCenter` 追加、`MapTabView` で `.onMapCameraChange(.onEnd)` 更新、`CafeSearchView` でバイアス発火
- 動作確認:
  - [x] KMP test green / iOS `xcodebuild` BUILD SUCCEEDED
  - [ ] 実機/シミュレータ目視はユーザー作業
- 副産物: cafe-search の既存 commonTest が `UncompletedCoroutinesError` で落ちていたのを発見・修正（`finally { vm.clear() }`）。lessons.md 参照

### 2026-06-25 - カフェ検索: 現在地系を撤去 + observation 停止バグ修正
- 背景: マップ中心バイアス導入後、現在地系が役割重複。ユーザー報告: ①検索が 1,2 回後に効かない ②開いた時点で現在地周辺が出る ③右上ボタン 2 つが冗長。確定方針: 現在地系を全撤去しテキスト検索（マップ中心バイアス）のみに。
- タスク:
  - [x] バグ修正: `CafeSearchView` の `.onDisappear { bridge.cancel() }` を削除（タブ常駐 View で StateFlow 観測が永久停止していた）
  - [x] 右上 toolbar trailing・自動検索・`LocationManager`・位置拒否 alert を撤去。検索発火は `.onSubmit(of: .search)` のみ
- 動作確認:
  - [x] iOS `xcodebuild` BUILD SUCCEEDED
  - [ ] 実機/シミュレータ目視はユーザー作業
- 残置: 未使用になった `onNearbySearchRequested`（Swift Bridge + Kotlin VM）は残置。API 削除は別途 kmp-engineer dispatch
