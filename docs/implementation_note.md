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
| カテゴリ別タスク・進捗 | `tasks.md` |
| 失敗から学んだ **汎用** パターン | `tasks/lessons.md` |

迷ったらまず本ノートに書く。安定したら昇格させる（下記）。

### アーカイブ（過去分の切り出し）

**2026-06 のエントリ 36 件は [`implementation-note-archive.md`](./implementation-note-archive.md) に凍結移送済み**（2026-07-25）。他 doc・コードコメントからの「implementation_note 2026-06-XX エントリ」という参照は**アーカイブ側を指す**（参照は日付で引く運用なので、参照側の書き換えは不要）。

- **切り出しの単位は月**。作業ログは append-only 気味に伸びるので、行数の閾値（`docs/**.md` 500 行 = `curate-doc` skill）で縮約しきるのは構造的に無理がある。**フェーズが完了して追記が止まった月**を凍結してアーカイブへ送る運用にする
- アーカイブには追記しない。過去エントリへの訂正・方針転換は**現在日付の新エントリ**として live 側に書き、旧エントリを参照する

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

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。（最終棚卸し: 2026-08-01）

> **このサマリに「数え上げ」と「構成要素の列挙」を書かない**（2026-08-01 の棚卸しで制定）。引数の個数・公開プロパティ一覧・コレクション一覧は、依存が 1 つ増えるたびに**全項目がまとめて嘘になる**うえ、増やした本人はソースしか見ないので気づけない。実際この棚卸しでは「プライマリ 7 / iOS 6 / Android 5 引数」（実際は 9 / 8 / 7）と削除済みの `beanProfileMatchUseCase` が残っていた。**書くのは「どこを真とするか」と、数えなくても変わらない構造・不変条件だけ**（`CuratedCafe.kt` KDoc で 2026-07-25 に同じ判断をしている）。

- ドメインは **CoffeeRecord 主体**（2026-06-19 クリーンブレイク）: 1 杯 = 1 記録、`cafe: Cafe?`（null = セルフ抽出）、`rating` は 0.5 刻み `Double?`（null = 未評価、2026-07-12 B-4 で sentinel 廃止）、`tasting` は all-or-nothing（`TastingScores?`）、`tags: List<String>`。**産地は `origin: String?`（国名。`CoffeeOriginCatalog` から選択、2026-07-22 に自由入力→国ドロップダウン化）+ `region: String?`（エリア / 農園、任意自由入力・表示専用で分析非対象、migration 6 で追加）**。モデル・DB・Firestore 表現は `data-model.md` を真とする
- CI（GitHub Actions）は `testAndroidHostTest`（**全モジュール一括 = 360 件**。モジュール個別列挙は漏れるため禁止。2026-07-25 是正）+ `:androidApp:assembleDebug`（Android ジョブ。ダミー `google-services.json` を CI 内で生成）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成。`xcodebuild` / `iosSimulatorArm64Test` は CI 非対象で親のローカル検証が担保
- `CoffeeRepository` は `commonMain` で 2 段構成（`RemoteCoffeeDataSource` interface + `CoffeeRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteCoffeeDataSource` だけを書く。書き込みはローカル → リモート順、リモート失敗の扱いは `WritePolicy`（既定 `PropagateRemoteFailure`）
- Firestore は `users/{uid}/coffees/{id}` の単一ドキュメント（`cafe` 任意埋め込み + `photos` 埋め込み配列 + `tasting` マップ + `tags` 配列。子サブコレクションなし）+ `users/{uid}` ルート（`analyticsConsent`）+ サービス管理・read-only の `beanProfiles` / `curatedCafes`。**コレクションの正確な一覧は `firestore.rules` を真とする**。nullable はキー省略。`Photo.localPath` は書かず `fileName`（`Documents/photos/` フラット配置）で復元、`remoteUrl` は常に null（Storage 不採用・写真は端末ローカルのみ）
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる
- `AppContainer` は scope 引数ありのプライマリが**テスト専用**。通常は scope なしのセカンダリ 2 系統 — iOS = `coffeeInsightProvider` 注入あり / Android = 省略（null）。開発用に `seedDummyData` / `clearDummyData`（DEBUG + ダミーデータ Scheme 限定）。**引数の個数と公開プロパティの一覧はここに書かない**（依存が増えるたびに全滅する）— `AppContainer.kt` を真とする
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一。共通ライブラリの Android namespace は各モジュール個別（`com.noricoffee.<module>` 系）で applicationId と分離
- SKIE 0.10.12 を `shared/framework` umbrella に適用。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する（`__answer(...)` 等の protocol witness）。Swift で Kotlin `Flow` を返す実装は `FlowBridge.swift` の `CallbackFlow` / `CallbackFlowOptional`（`Kotlinx_coroutines_coreFlow` 準拠クラス）が正規パターン（2026-07-10 実態訂正: 旧記述「MutableStateFlow 直接構築が第一候補」は結局未使用）。SQLDelight 生成行型と同名のドメインモデルは Swift 側で末尾アンダースコア付きになる（現状 `Photo` → `Photo_`。`coffee_record` からは `Coffee_record` が生成されるため `CoffeeRecord` は衝突しない）
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。path uid 検証 + `users/{uid}` ルート明示 + `beanProfiles` / `curatedCafes` read-only。**2026-08-06 にユーザーが Console で本番反映を確認済み**（`firestore.rules` の全ブロックが公開中）。`storage.rules` は残置のみ未デプロイ（Storage 不採用。lessons 2026-06-10）
  - **デプロイ日をここに書くのはやめた**。`curatedCafes` を足した 2026-07-17（commit `2614528`）に本行が追随せず「2026-07-01 デプロイ済」のままだったため、2026-08-06 のリリース前点検で**未デプロイの疑いとして誤検出**した（実際は反映済み）。`firestore.rules` の編集と `firebase deploy` は別作業なので、doc 側の日付は必ず遅れる。**現在の公開内容の正本は Console のルールタブ**で、ここには「リポジトリ管理である」ことだけを書く
- `build-logic/convention/` の Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）は precompiled script plugin 方式（`gradlePlugin { register }` 不使用）。`build-logic/settings.gradle.kts` で version catalog を明示共有。`kmp.library` は `jvmToolchain(N)` を付けず `compilerOptions.jvmTarget` のみ指定
- `shared/core` には `AppContainer` / `CoffeeRepositoryImpl` / `DummyCoffeeData`（dev 用）。`shared/data-local` が SQLDelight の単独管理者（`LocalCoffeeRepository` / Mapper / DriverFactory expect/actual。合成リポジトリのテストは expect/actual ドライバの制約で data-local の commonTest に妥協配置）。`shared/data-firebase/androidMain` に Android Firebase 実装（`AuthRepositoryAndroidImpl` / `RemoteCoffeeDataSourceAndroidImpl` / `CoffeeFirestoreMapper` / `BeanProfileRepositoryAndroidImpl`）、iOS 実装は `iosApp` Swift
- iOS 向け umbrella は `shared/framework`（baseName / XCFramework 名とも `SharedLogic`、Swift は `import SharedLogic`）。全 shared モジュールを `api` + `export` で再公開 + `linkerOpts("-lsqlite3")`。**feature を追加したら api / export に 1 行ずつ追記**。モジュールの正確な一覧は `settings.gradle.kts` を真とする（同じ行で「真とする」と言いながら列挙も併記していたため、2026-08-01 の棚卸しで列挙を削除）
- `AppContainer` の ViewModel ファクトリ（`makeCoffeeListViewModel()` 等）は **`shared/framework` の拡張関数**（`AppContainerViewModelFactory.kt`）として配置（`core → feature` の循環依存回避）。feature 追加ごとに追記する
- ViewModel は注入 scope の Job を親にした**所有 `viewModelScope`（SupervisorJob 子スコープ）+ `clear()`** を持つ（2026-06-24。push/pop 画面の collector 増殖リーク対策）。Bridge は `deinit` で `kotlin.clear()` を呼ぶ。**KMP のコルーチン内で `runCatching` は使わない**。→ いずれも 2026-07-02 に `coding-conventions.md`（§1.2 / §1.6 / §1.7）へ昇格済み。経緯は本ノート 2026-06-24 エントリ
- iOS Bridge は `@MainActor @Observable` + `Task { for await state in kotlin.state { apply(state) } }` パターン。生存スコープは、タブ常駐画面（coffee-list / map / analysis 等）= `AppState` で 1 つ保持、push / sheet 画面（coffee-detail / coffee-editor / cafe-detail）= View 内 `@State` で遷移ごとに生成・`deinit` 回収。**タブ常駐 View の `onDisappear` で observation を止めない**（2026-06-25 の検索停止バグ再発防止）
- iOS のルートは **4 タブ（マップ / コーヒー / 分析 / 設定）**。検索タブは廃止（iOS 27 で `Tab(role: .search)` の右端固定が廃止されたため）し、**マップ上部の埋め込み検索バー**（テキスト検索はマップ中心の位置バイアス付き）+「このエリアを検索」ボタン + 検索モードに移行。コーヒー記録の作成は**コーヒータブとカフェ詳細のいずれもナビバー右上の `+`**（2026-08-07 に FAB から統一。下記「追加アクションの配置」）
- Places API は **New v1** + `X-Goog-FieldMask` で取得フィールド明示。API キーは `AppContainer` コンストラクタ注入（Android = local.properties → BuildConfig、iOS = xcconfig → Info.plist → Bundle.main）。Nearby は `includedPrimaryTypes = [cafe, coffee_shop]`・1 回最大 20 件。Places 写真は永続キャッシュ禁止（規約）で都度取得
- iOS の xcconfig は `Base.xcconfig`（base）→ 先頭 `#include "Config.xcconfig"`（必須）+ `#include? "Secrets.xcconfig"`（任意・gitignore 済）の 3 段構造。**フォールバック宣言（`PLACES_API_KEY =` 等）は `#include?` より前に置く**（後ろだと実キーを空で上書き）
- Places API キーはクライアント埋め込みで**抽出不可避**。`X-Ios-Bundle-Identifier` によるバンドル ID 制限は生 REST 呼び出しでは**ヘッダなりすましで突破可能**（暗号検証なし）＝事故防止レベルで実効的防御ではない。現実的な守りは Google Cloud の**予算アラート + クォータ上限**（被害額に天井）+ API 制限の Places 限定。本命はバックエンドプロキシ + App Attest（規模拡大時に検討）。詳細は 2026-07-08 エントリ
- 分析は 3 階層分離: 階層1・2 は KMP で決定論（`CoffeeStats` / `FavoriteSignals`。収縮平均 + n 連動 z ゲート `CATEGORY_Z = 2.0` + 相関 floor で「弱い傾向」だけを信号化、断定しない）、階層3 は iOS Foundation Models（`CoffeeInsightProvider`。可否は注入時判定、null = 非対応端末で graceful degradation）。Q&A は v1 = `CoffeeStats` digest 注入（単発・ステートレス）/ v2 = `Tool` から `CoffeeRecordQuery.searchRecords`（計算は KMP・LLM は解釈と整形のみ）
- `BeanProfile`（12-B）はサーバ管理 read-only の豆ナレッジ。`CoffeeRecord` と ID 紐付けせず origin / processings のファジーマッチ。取得は one-shot get + メモリキャッシュ。12-C で `FavoriteSignals` と突合した `preferredBeanTraits` を `CoffeeStats` に付加し、Foundation Models で言語化
- 味覚一致カフェ推薦: **9-5（コンテンツベース v1）は実装完了・○ 確定**（2026-07-21。`ObserveTasteMatchedCafesUseCase` / `RecommendedCafe` / `CafeRecommendationProvider`、産地/焙煎/抽出/精製の 4 軸マッチ、マップの好み一致ピン + 理由表示 + 分析タブ連携。テイスティング 5 軸の一致はスコープ外）。**9-6（協調フィルタ / 他ユーザー横断 v2）は設計確定・△（未実装）**（`sharedTasteProfiles/{uid}` + Cloud Function 特権 read。閾値定数 / Function 内実装 / インフラ選定は未決。tasks 12-D で段階 dispatch）。詳細は analysis-model §2
- データ利用同意（12-A）: `users/{uid}.analyticsConsent`。初回起動オンボーディングで取得し設定トグルで変更可。ドキュメント不在は false 扱い
- Firebase テレメトリ（iOS のみ）: **Crashlytics + Performance = 常時収集**（同意不要）、**Analytics = `analyticsConsent` 同意時のみ**。Analytics は素の `FirebaseAnalytics` プロダクト（現行 firebase-ios-sdk 12.14.0 では既定で IDFA 非依存 = 旧 `WithoutAdIdSupport` 相当。旧プロダクトは廃止。IDFA を使う場合のみ `FirebaseAnalyticsIdentitySupport` を追加する反転構成）。`Info.plist` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO` で Analytics 自動収集のみ起動時 OFF（Performance は常時 ON）→ `AppState.analyticsConsent` の `didSet` → `applyTelemetryConsent` が Analytics だけ有効化。イベントは自動収集 + `screen_view` のみ（カスタムイベント未導入）。詳細は 2026-07-08 エントリ

---

## エントリ形式

タイトル + 本文だけで十分。`影響` / `トレードオフ` / `経緯` は必要なときだけ書く。

> **`- 領域:` は廃止**（2026-07-25 の棚卸し。103 エントリで 60 種類以上の自由記述に散っていて分類・検索に使えていなかった）。所在はタイトルと `- 関連:` のファイルパスで足りる。

```markdown

### YYYY-MM-DD: 短いタイトル

- 関連: `path/to/file.kt` / 他 doc の節（任意。grep の入口になるので書く）

本文を自由に書く。3 行で済めば 3 行で良い。

必要なら以下を付ける（任意・順不同）:
- 影響: ...
- トレードオフ: ...
- 経緯: ...
```

---

## エントリ

<!-- 新しい決定は本セクションの末尾に追記する。陳腐化・昇格時は削除可 -->

### 2026-07-01: Phase 12-C — 実装判断まとめ

（小粒 3 エントリを 2026-07-09 統合）

- `PreferredBeanTraits.matchedProfiles: List<BeanProfile>` は保持するが LLM プロンプトには含めない（`dominantFlavorNotes` / `originHint` / `roastLevelHint` / `dominantTastingAxis` のみ使用。豆名や詳細フレーバーを足すときは `matchedProfiles` を走査）
- `beanTraitsInsightStatus` の初期値は **`Idle`**（`insightStatus` の `Unsupported` と異なる）: LLM 非対応端末でもフレーバータグのフォールバック表示を生かすため。`beanProfiles` 未投入時は `stats.preferredBeanTraits` が nil でセクション自体が出ない、という表示制御の責任分担
- `PreferredBeanTraitsCard` は `InsightLoadedCard`（`"sparkles"` 固定）を流用せず直接実装（`"leaf"` を使うため。将来アイコン引数化で統一可）

### 2026-07-01: マップ検索の使い勝手改善（フェーズ 14）— エリア検索ボタンと検索モード

Google Maps 風に「表示範囲内のカフェを一括ピン表示」できるようにした。product 決定は「このエリアを検索」ボタン方式（自動再検索なし = Places 課金の発火頻度を制御）+ テキスト検索結果は全件ピン + リスト併用。

- KMP: `onNearbySearchRequested` に半径付きオーバーロード追加（SKIE デフォルト引数制約への通常対応）
- **ボタン出現しきい値**: `中心移動 > アンカー半径の 30%` OR `半径比 1.5x 逸脱`。数値は経験則（要件根拠なし）。チューニングは `MapTabView.shouldShowAreaSearchButton`
- **検索完了検知の一本化**: テキスト / エリア両検索を `searchBridge.isLoading` の false 遷移に集約し、`isAreaSearchInFlight` でトリガー判別。極端な連打時の判別整合性は理論上完全でないが v1 許容
- **ピン集合と選択の関心分離**: 選択やカード閉じでは全ピンを残す（Google Maps 的）。全消去は検索バーの × のみ。Places New は 1 回最大 20 件（密集エリアは頭打ち）
- **検索モード化**: `@FocusState` + `showingSearchResults` で `isSearchMode` を定義。検索モード中はフィルタチップ非表示 + 結果リストを検索バー直下の同一 VStack に流し込み、固定オフセット由来の視覚衝突を構造的に解消。エリア検索ボタンは**検索モード中かつパン / ズーム後のみ**表示（ブラウズ閲覧を邪魔しない。ユーザー要望による最終仕様）

### 2026-07-02: docs 棚卸し — 実装と docs の齟齬 4 件を修正

data-model のフェーズ 10 / 12-C 追随・kmp-bridge の export 記述・app-store-metadata の CoffeeRecord 化・本ノートサマリ全面更新の 4 件（詳細は git 履歴）。再発防止としてサマリに「最終棚卸し」日付を導入した。

### 2026-07-03: iosApp コードレビュー指摘 #1〜#5 の修正 — ライフサイクル / 削除順序の判断

- 関連: tasks.md「iosApp コードレビュー指摘対応（2026-07-03）」、lessons.md 2026-07-03

1. **`bootstrap()` は「観測される状態の公開を最後」にする**: `uid` / `status = .ready` は画面切り替えトリガーであり、途中で代入すると loadingView の `.task` キャンセルに巻き込まれて `checkConsentOnboarding` が無音スキップされる timing バグになる。startInitialSync → seed/clear → ブリッジ生成 → consent チェック → 最後に uid/status 公開の順に固定。再入は `guard status != .signingIn`
2. **アカウント処理の完了待ちは二相ポーリング**（`awaitProcessingCompletion()`）: 相1 = `isProcessing == true` 遷移を最大 2 秒待つ（KMP emission 到着前の誤「完了」判定 → 処理中に写真全削除が走るレースの解消）、相2 = false 遷移を最大 30 秒。根治には KMP 側の完了イベント公開が必要（v1 許容）
3. **写真物理削除は「レコード消失を state で確認してから」**: `pendingPhotoDeletions` に登録し、`apply()` で `coffees` から id が消えたのを確認して削除。「孤児ファイル < 写真消失」の安全側。孤児掃除が必要になったら起動時 GC（DB と Documents/photos の突合）を別途検討

### 2026-07-03: shared コードレビュー指摘 #1〜#3 の修正 — 同期・座標・FK の判断

- 関連: tasks.md「shared コードレビュー指摘対応（2026-07-03）」、data-model.md §2.2 注記・§4.2、lessons.md 2026-07-03

1. **同期 reconciliation は「全件スナップショット差分」方式**: `startSync` がスナップショットに無い id のローカル行を削除してから upsert。tombstone 方式は個人アプリ規模に過剰と判断。`DummyCoffeeData.ids` 除外で core が dev データを知る結合は、引数化より単純さを優先。save〜upload 間の一瞬の消失窓は pending writes 込みリスナ前提で極小として許容（競合解決の本格化は backlog B-1）
2. **エディタは選択 `Cafe` を丸ごとセッション保持**（`selectedCafe`、onAppear〜次の onAppear のみ有効）: 座標・photoReferences は「選択あり → selectedCafe / Edit 選択なし → 初期レコード / Create 手入力 → null」の優先順位で `buildCafe()` に集約。**旧判断「draft に座標を保持しない」（2026-06 スライス 2 設計）は本修正で廃止**。過去レコードの座標の遡及補正はしない
3. **FK は本番ドライバで有効化 + 掃除 migration**: Android = `AndroidSqliteDriver.Callback.onConfigure`、iOS = sqliter `extendedConfig.foreignKeyConstraints = true`。明示 `deleteByRecord` 追加は CASCADE と二重管理になるため不採用。FK 無効期間の孤児 photo 行は `2.sqm` で一括削除。iOS テストドライバも FK ON に統一し、`iosSimulatorArm64Test` で赤 → 緑を実証（= 従来 iOS ターゲットのテストは回っておらず、回していれば検出できていた → lessons）

### 2026-07-04: サブエージェント定義の改善 — memory / skills プリロード / スコープ強制フックの採用

- 関連: tasks.md「サブエージェント定義の改善（2026-07-04）」

エージェント定義が Phase 2.5 時点のまま陳腐化していた（旧 `sharedLogic` スコープ / 実在しないタスク名 / 旧 Visit モデル）のを現行構成に更新し、2026 年時点の公式機能を採用した。

1. **`memory: project` を採用**（`.claude/agent-memory/<name>/` を git 管理）: 「サブエージェントは docs を読めるが書けない → 学びが残らない」への公式解。責任分界は「作業ノウハウ = agent memory / 仕様・トレードオフ・汎用教訓 = レポート経由で親が docs へ」。docs と重複するメモリ複製は禁止
2. **書き込みスコープを PreToolUse フックで機械強制**: `validate-write-scope.sh` 1 本を両エージェント共用、許可プレフィックスは frontmatter 引数。違反は exit 2 で「親への依頼」ルートへ誘導（ガードレールでありセキュリティ境界ではない。Bash 経由は対象外）
3. **Skill は frontmatter `skills` プリロード + フォールバック**: 現行ハーネスはプリロード本文を展開しないと実測判明 → 「展開されていなければ Skill ツールで起動」のフォールバック文を残した（ハーネス更新後に削除予定）
4. model は `sonnet` 据え置き（実装ワーカー = Sonnet、仕様判断 = 親のルーティング維持）
5. 必読 docs から CLAUDE.md を削除（カスタムサブエージェントには自動ロードされる。Explore / Plan 組み込みはスキップされる点に注意）
6. 起動確認 dispatch での補正: メモリがユーザースコープへ書かれた → リポジトリ内を正と明示 / スコープ記述の実在しないパスを実体に修正 — **エージェント定義も「横断 doc」として陳腐化する**（lessons 2026-06-16 と同根）

### 2026-07-04: CLAUDE.md スリム化 — .claude/rules/ パススコープ分割とモジュール表の参照一本化

- 関連: tasks.md「CLAUDE.md のスリム化と .claude/rules/ 分割（2026-07-04）」

CLAUDE.md が 240 行と公式推奨（200 行以下）を超過し、docs 二重管理箇所が陳腐化の常習箇所になっていたため再構成（240 → 131 行）。

1. **言語別規約は `.claude/rules/` のパススコープ規則へ**（`kotlin-kmp.md` / `swift-ios.md`。対象ファイルを触るときだけロード）。rules は「要点 + docs 正本への参照」の薄い構成で三重管理を回避。**rules のサブエージェント伝播は実測確認済み**: 起動時ではなく、paths にマッチするファイルを Read した直後に全文が遅延注入される（skills プリロードと違い現行ハーネスで機能する）
2. **モジュール構成 11 行表を削除**: `settings.gradle.kts`（一覧）と `architecture.md`（役割・依存方向）への参照に一本化。陳腐化が実証済みのストック型キャッシュを面ごと消した
3. **lessons の親運用ルール 4 件を CLAUDE.md へ昇格**（OVERRIDE フラグ再検証 / iOS テストの DEVELOPER_DIR 実行 / 横断 doc 同時更新 / 横断点検やり切り）: 毎セッション必ず載る場所に置いて常時効かせる
4. アーキテクチャ不変条件は CLAUDE.md 本体に残置（毎回の仕様判断・dispatch 判断に必要で変更頻度も低いため）

### 2026-07-04: 実装ノート棚卸し — 約 120 エントリ → 64 エントリ

本ノートが 2160 行 / 約 297KB に肥大化したため、運用ルール（陳腐化は削除可 / 昇格時は削除）に沿って棚卸しした（ユーザー承認済み）。

- **削除（約 40 件）**: 旧 Visit / sharedLogic 時代（2026-06-19 クリーンブレイク以前）の設計判断、後続エントリで置換済みの暫定対応（CI 暫定コマンド / 3 タブ構成 / Nearby・現在地検索まわり等）。現役の結論はサマリと正規 doc（architecture / data-model / kmp-bridge / coding-conventions / lessons）に反映済みであることを確認のうえ削除
- **統合**: シリーズエントリ（B-1×5 / B-4×3 / アカウント + revoke×4 / Q&A×3 / 12-A×3 / テイスティング×2 / Places 疎通×2 ほか）を最終形 1 本ずつに
- **圧縮**: 現役だが冗長な事前設計エントリを「確定判断 + 理由」だけに
- 見出しスタイルを `### YYYY-MM-DD: タイトル` に統一し日付順へ整列。削除済みエントリへの過去参照（tasks.md の完了行等）は git 履歴（`git log -p docs/implementation_note.md`）で辿る
- **同日 `tasks.md` も縮約**（860 行 / 127KB → 285 行 / 24KB）: 完了フェーズは「完了サマリ + 未完行のみの表」に置換し、未完 26 件は全数維持・`##` セクション見出しは参照アンカーとして全保全。以後この運用（tasks.md 冒頭に明記）を継続する

### 2026-07-06: ゼロベース設計レビュー — 3 条件との突き合わせとフェーズ 15 起票

- 関連: `requirements.md` §10・§2（2-8〜2-11）・§9（9-7, 9-8）・7-4、`tasks.md` フェーズ 15

現状プロジェクトを一旦離れ「①コーヒーを記録できる ②おいしい店を探せる ③自分の好みを見つけられる」の 3 条件から理想の iOS アプリをゼロベース設計し、現状と突き合わせた（ユーザー依頼）。設計の軸は「記録 → 好みが見える → 好みに合う店に出会う → また記録する」のコアループで、ボトルネックは (a) 記録の摩擦 と (b) 探す→行く の橋渡し、と整理した。

**突き合わせの結論**: ③好み分析は理想形超え（3 階層分析 + 味覚一致推薦 + 自然言語検索まで実装済み）。①記録は基盤堅牢だが入力摩擦が高い。②店探しは「検索」は充実しているが「見つけた店を保存して再訪する」出口（ウィッシュリスト）が丸ごと欠落しており、これが最大のギャップ。提案 5 件を全て採用しフェーズ 15 として起票した。

採用しなかった / 見送った論点（要件化していないもの）:

- **`cup` フィールドの削除・タグへの統合**: 使用率が低そうな割に入力欄を占有するが、害が小さく既存データ・全レイヤーに触る割に益が薄いため現状維持。エディタが窮屈になったら再検討
- **カレンダー表示**: 月別セクション（2-11）で当面足りると判断し △ 扱い（要件表の備考に記載）
- **写真のクラウド同期復活**: 端末ローカル + iCloud Backup の確定方針（2026-06-10）は変更しない。代わりにエクスポート 7-4 を ○ に引き上げてテキストデータの持ち出し手段を確保
- **分析の統計精度のさらなる向上**: 収縮平均 + z ゲートで十分。現段階はループの穴埋め（15-A/B）の方がユーザー価値が高い
- **9-8（未経験豆の探索提案）は △ に留めた**: 9-5（既訪問店の再訪推薦）・12-D（協調フィルタ = サーバー前提）の中間に位置する新規開拓ナッジ。BeanProfile × FavoriteSignals でサーバー不要に作れる算段だが、優先度は 15-A〜D の後

### 2026-07-06: 15-A SavedCafe 実装判断（KMP + iOS）

- 関連: `data-model.md` §1.9〜§4.3、tasks.md フェーズ 15-A（KMP / iOS の 2 エントリを 2026-07-09 統合）

- **`WritePolicy` の共用**: `SavedCafeRepositoryImpl` は独自 enum を作らず `CoffeeRepositoryImpl.WritePolicy`（nested enum）を再利用。トップレベル切り出しは既存テスト参照の無用な破壊になるため見送り（**3 つ目の Repository 合成パターンが増えた時点で再検討**する YAGNI 判断）
- **`MapViewModel.recordedPlaceIds` はタグフィルタ前の全件から算出**: 「記録あり」バッジは、タグでピンを絞り込んでいても「実は記録済み」を正しく示す
- **一覧シートの表示状態・「行きたい」フィルタチップの表示状態は KMP に持たせず Swift `@State`**（「画面遷移は Navigation 層で繋ぐ」原則。`onShowVisitedToggled` との非対称は表示切替のみの関心事として許容し、他プラットフォーム実装が現実化した時に再検討）
- `CafeDetailViewModel` に `error: String?` / `onErrorDismissed()` を追加し `MapViewModel` のエラーハンドリング規約と対称化
- **ピンのビジュアル**: `Color.indigo` + `bookmark.fill` 34pt（訪問済み 36pt と検索結果 32pt の中間。既存 3 種との識別性優先）。**dedup（訪問済み > 行きたい > 検索結果）はチップ状態に関わらず常時適用**（競合解決はデータ整合性の関心事で表示切替と独立）
- `CoffeeFirestoreMapper` の `toCafeMap`/`cafeFromMap` を `private` → `internal static` 化し `SavedCafeFirestoreMapper` から再利用（cafe 直列化規則の重複実装を回避）。破壊的変更は `AppContainer` 公開コンストラクタへの `remoteSavedCafeDataSource` 追加のみ

### 2026-07-06: 15-B 記録摩擦低減の実装判断（KMP + iOS）

- 関連: requirements 2-8 / 2-9 / 2-10、tasks.md フェーズ 15-B（KMP / iOS の 2 エントリを 2026-07-09 統合）

- **`Mode.Duplicate` の cafe は `Mode.Edit` と同一経路（`currentInitialRecord.cafe` フォールバック）で引き継ぐ**: 「cafe を引き継ぐ」=「同じ物理カフェへの参照を保つ」の解釈で、placeId に一意性制約は無く `VisitedCafe` 集計で同一店にまとまるのは意図どおり。この経路のセルフ抽出バグ（発見時は未修正で起票）は 2026-07-08 buildCafe エントリで解消済み
- **サジェストの発火条件は `draft.cafeName` が空かどうか**（`buildCafe` の null 判定と基準統一）。チップ表示条件は `!suggestedCafes.isEmpty` のみで Swift 側の二重ガードなし
- **位置情報の「未許可なら無音」制御は呼び出し側（`CoffeeEditorView`）でガード**: 共有 `LocationManager.requestLocation()` の挙動（`.notDetermined` で許可ダイアログ）を変えず、他画面への影響を回避
- 詳細画面ツールバーは `Menu`（`ellipsis.circle`）化で「編集」「これをもとに記録」を内包（HIG 標準の overflow パターン）。複製起動時は `initialCafe` を渡さない（KMP の `toDuplicateDraft` が設定済み）
- **許可未決定ユーザー向けの明示入口（「近くのカフェから選ぶ」ボタン）は検討の上見送り**（2026-07-06 ユーザー判断）: サジェストは許可済みユーザー向けの補助機能と割り切る。マップで現在地を一度使えば以後は発動する

### 2026-07-06: 15-C 一覧検索 + 月別グルーピング KMP 実装

- 関連: requirements 6-1 / 2-11、tasks.md フェーズ 15-C

- `CoffeeListViewModel` の `UIState.coffees: List<CoffeeRecord>` を `sections: List<MonthSection>` に置換（破壊的）+ `searchQuery` + `onSearchQueryChanged`。検索 → 月別グルーピングの順で `buildSections` に純粋関数化。yearMonth は `"YYYY-MM"` ゼロパディング、セクション降順・月内順序維持（安定フィルタ）
- 破壊的変更の波及で `sharedUI/CoffeeListScreen.kt`（Android 検証画面）も `sections` ベースに追随。検索 UI は付けず月別表示のみに留める（「VM が Android でも動く + Firestore observe 往復」を示す最小実装の位置付け維持）。**feature の UIState フィールドを rename/廃止する破壊的変更は `sharedUI` と `iosApp` Bridge の両方が波及先**（KMP dispatch 時に sharedUI 追随までスコープに含める）

### 2026-07-06: 15-D 分析空状態プログレスの実装判断（KMP + iOS）

- 関連: requirements 9-7、tasks.md フェーズ 15-D、lessons 2026-07-06（KMP / iOS の 2 エントリを 2026-07-09 統合）

- `AnalysisViewModel.UIState` に `readiness: AnalysisReadiness?` を派生追加（`CoffeeStats` は不変＝LLM 入力を汚さない）。閾値は `FavoriteSignals().minSampleSize` / `BuildCoffeeStatsUseCase.CORRELATION_MIN_SAMPLE` を参照しハードコードしない。`hasAnySignal` は `FavoriteSignals` の file-private 拡張関数
- **iOS テスト 16 件全滅（Native の cancel drain 漏れ）** → `finally { vm.clear(); testScheduler.advanceUntilIdle() }` で解消。経緯と別解（backgroundScope）の不採用理由は lessons 2026-07-06 が正。副次発見: `AnalysisViewModelQaTest` の fake が 12-C `summarizeBeanTraits` 未追随で commonTest が長期コンパイル不能だった（fake 追随で解消）
- iOS の表示条件は `readiness != null && !readiness.hasAnySignal`（`totalCount==0` は既存 emptyState 分岐で到達しない）。`ProgressView(value: ratedCount/categoryThreshold)` 主表示 + 残り件数で文言出し分け、テイスティング相関 track は控えめな補足キャプション（「できます」止まりで断定回避）
- `favoriteSignalsSection` の iOS 側再計算との二重判定リスクは 2026-07-09 に `readiness.hasAnySignal` 参照へ単一ソース化して解消済み

### 2026-07-07: 15-E-2 データエクスポート KMP 実装 + B-6（Native .format）解消

- 関連: requirements 7-4、tasks.md フェーズ 15-E-2 / backlog B-6

- `ExportCoffeeRecordsUseCase`（`suspend operator fun invoke(userId): String`、`@Throws`）: `observeAll(userId).first()` → **export 専用 `@Serializable` DTO**（`domain/export/`）→ `Json { prettyPrint = true; encodeDefaults = true }`。ドメインモデルに `@Serializable` を付けず DTO 分離（Firestore 直列化規則踏襲: enum は `.name` / 日時は文字列 / 写真はメタデータのみ）。包みは `{ exportedAt, version: 1, records: [] }`（将来互換のため version 保持）。`AppContainer.exportCoffeeRecordsUseCase` で公開
- `encodeDefaults = true` 必須（coding-conventions §1.12 に昇格済み）。SKIE は `operator fun invoke` を `callAsFunction` 化しない → `.invoke(userId:)` 明示呼び出し（kmp-bridge.md に昇格済み）
- **B-6 解消（親対応）**: `FavoriteSignalsPersonaTest` の JVM 専用 `"%.Nf".format` が domain の iOS テストを丸ごと止めていたため、Native 安全な `Double.fmt(digits)` ヘルパ（デバッグ用途のみ・アサーション条件に非関与）へ全 44 箇所置換して回復（15-E-1 / 15-E-2 の検証を 2 度阻害していた）

### 2026-07-07: 外部 Skill 導入（mattpocock/skills → grilling / diagnosing-bugs / writing-great-skills）

- 出典: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT License。各 SKILL.md 末尾に出典明記）

- 全 20 個弱のうち 3 つを選定して日本語化 + 本プロジェクト調整で移植。**丸ごと導入（`npx skills add`）は不採用** — issue トラッカー前提のワークフロー系（triage / to-issues / to-prd）は docs/tasks.md + 親統制と競合し、code-review / handoff は Claude Code 組み込みと重複するため
- **`grilling`**: 実装前の 1 問ずつ徹底インタビュー（事実は調べる / 意思決定だけ問う）。Plan Mode Default を補完。完了条件を本プロジェクト流（確定仕様を docs に固定してから dispatch）に接続
- **`diagnosing-bugs`**: 「仮説より先に red-capable な tight フィードバックループを作る」6 フェーズの診断規律。フィードバックループ手段の一覧を KMP / iOS スタック（commonTest / iosSimulatorArm64Test の親実行 / xcrun simctl / HITL スクリプト）に置換。Phase 6 ポストモーテムを record-lesson skill・implementation_note・tasks.md バックログに接続。CLAUDE.md の Autonomous Bug Fixing / Plan Mode Default に参照 1 行ずつ追記
- **`writing-great-skills`**: skill 設計原則のリファレンス（invocation の 2 択と 2 つの load、情報階層、leading word、no-op テスト、negation の害）。**原典は user-invoked だが model-invoked に変更** — 本プロジェクトでは親が record-lesson からの昇格等で skill を書く頻度が高く、自律到達の価値が context load を上回ると判断。GLOSSARY.md（201 行）は用語定義の精度維持のため原文英語のまま同梱
- **見送り**: `domain-modeling` / CONTEXT.md（用語集の正本が data-model.md と割れるため。`_Avoid_` 付き用語集のフォーマットだけ将来 data-model.md 内セクションとして借りる案は任意バックログ）、`codebase-design`（architecture.md と役割重複。deep module / seam の語彙は読み物として有用）

### 2026-07-07: フェーズ 16 マップ / タブ UI/UX 改善（保存済み導線・カフェ情報強化・色体系）

- 関連: tasks.md フェーズ 16（インターフェース合意書・色セマンティクス表）、ui-ux-guidelines.md 色セマンティクス、data-model.md §1.2

- **保存済み「強調」を MapViewModel UIState に置かなかった判断**: チップタップ時のピン強調はドメインロジックゼロの純プレゼンテーション状態（必要な placeId 集合は `savedCafes` として既に UIState にある）ため、iOS ローカル `@State savedEmphasisActive` で管理。`showVisited`（UIState）との非対称は「訪問済み = 表示 ON/OFF のドメイン設定、保存済み強調 = 一時的な演出」という意味の違い。保存済みピン自体は常時表示に変更（旧 `showSavedCafes` トグル廃止）
- **CafeDetailViewModel の Places Details リフレッシュは init 1 回のみ**: 発火条件 `initialCafe == null || initialCafe.googleRating == null`（DB スナップショット由来のみ。検索 / POI 由来では API を叩かない = コスト抑制）。取得失敗時はサイレントフォールバックし、当該画面のライフサイクル中は再試行しない（スナップショット表示のまま）。`latestDetails ?: 最新記録 cafe ?: initialCafe` の優先マージで records 再 emit による巻き戻りを防止（テストで固定済み）
- **`MapViewModel.onCafeSaveToggled` の保存判定は `savedCafes` リストから毎回導出**: cafe-detail 側 `onSaveToggled` が `UIState.isSaved` を使うのと非対称だが、MapViewModel は特定カフェの単一 `isSaved` 状態を持たないため
- **`TasteSearchSheet` / sparkles 系の accentColor は pink 化対象外**: 「テイストで探す」（フィルタ / 検索操作 UI）と「好み一致」（推薦結果のセマンティクス）を別概念と整理。pink は推薦結果（recommendedCafePin・凡例・RecommendationMatchSheet の軸アイコン）のみ（注: ここで併記していた `TasteMapFilterSheet`「好みで絞り込む」は 2026-07-21 撤去済み）
- **TagChip の count バッジ配色**: 選択時 = 白背景 + accentColor 文字、非選択時 = accentColor 背景 + 白文字（旧右上ボタンの indigo バッジ意匠を選択状態で反転させる形。仕様未記載のため実装判断）
- **後続候補**: `SavedCafeListSheet` の「記録あり」バッジが `.brown` 直書きのまま孤立（visitedCafePin の brown→accentColor 化に未追随）。2026-07-27 の棚卸しで**未解消のまま残っていることを確認**し tasks.md「マップピンの主従関係の是正」へ起票（行番号での指示は書かない = 前文ルール）

### 2026-07-07: 周辺カフェを Apple 検索由来の自前ピンに（フェーズ 17）

- 関連: tasks.md フェーズ 17

- **なぜ Apple 標準 POI ラベル頼みをやめたか**: 標準マップの POI ラベル表示密度は Apple のレンダリングエンジンがズームレベルで内部決定し、SwiftUI `MapStyle` にも UIKit `MKMapView` にも「広域で POI を出す」密度・閾値の公開 API が無い（`.including([.cafe,.bakery])` はカテゴリ取捨のみで出現ズームは変えられない）。よって「かなりズームしないとカフェが出ない」は POI ラベル依存設計では原理的に直せず、カフェを自前ピンとして描く方向へ転換した
- **データソースに `MKLocalPointsOfInterestRequest`（Apple）を選び Google Places 自動検索を採らなかった判断**: 「このエリアを検索」を手動ボタンにしたのは Places 課金・quota を抑えるため（フェーズ以前の設計意図）。パンのたびに自動で Places を叩くとその意図に反する。Apple 検索は Apple Maps quota で Google Places 課金に無関係、かつカフェ座標を region 単位で取得できるため、常時表示ピンの供給源として最適。ピンタップ時のみ既存 `onPoiTapped` → Places ルックアップを通すので、詳細取得の課金は「ユーザーが実際に開いた店」に限定されたまま
- **ピン競合は座標近接（約 40m）で解決**: Apple の `MKMapItem` は Google placeId を持たないため、既存 4 種ピン（placeId ベース）との重複排除は placeId 一致ではなく座標近接で行う。名前一致はローカライズ差で不安定
- **標準 cafe/bakery ラベルを `.excluding` で消す随伴変更**: 自前ピンと Apple ラベルの二重表示を避けるため。結果として cafe/bakery の `MapFeature` 選択機構（`mapFeatureSelection` / `poiSelectionChanged`）が死にコード化するので一式除去した。`onPoiTapped` の下流（ルックアップ→push→トースト）は不変で、呼び出し元が自前ピンに替わるだけ
- **Apple 検索 fetch 失敗時はサイレントクリア**: `MKLocalSearch` 失敗時は `appleNearbyCafes = []` にするのみでトースト等の通知を出さない。周辺カフェピンは低優先度の補助表示であり、失敗を都度通知するとブラウズ中のノイズになるため。既存 `poiLookupError` トースト（ピンタップ後の Places ルックアップ失敗）とは別レイヤーの扱い
- **`.location.coordinate` を採用**: `MKMapItem.placemark` は iOS 26.0 で deprecated。deployment target が 26.0 のため `item.location.coordinate` を無条件使用

### 2026-07-07: App Store Connect アップロードワークフロー（release-testflight.yml）

- 関連: `.github/workflows/release-testflight.yml`、`iosApp/Configuration/ExportOptions.plist`、`iosApp/iosApp.xcodeproj`（Run Script）

TestFlight へのアップロードを GitHub Actions（`workflow_dispatch` 手動起動のみ）で行う。主要判断:

- **署名は ASC API キー + cloud signing**（`xcodebuild -allowProvisioningUpdates` + `-authenticationKey*`）。Secrets は .p8 の中身だけで済み、p12 のエクスポート・期限管理が不要。API キーは **App Manager 以上のロール必須**（Distribution 証明書を Apple 側が自動作成するため）。不採用: p12 + プロファイルの Secrets 登録（証明書更新のたびに Secrets 更新）/ fastlane（Ruby 依存が増える。スクリーンショット自動化等が必要になったら再検討）
- **アップロードは `-exportArchive` 1 コマンド**: `ExportOptions.plist` の `destination=upload` でエクスポートと同時に ASC へ送る（altool は deprecated、Transporter 別立ても不要）
- **ビルド番号 = `github.run_number`** を `CURRENT_PROJECT_VERSION` としてアーカイブ時に注入（コミット不要で単調増加）。`manageAppVersionAndBuildNumber=false` で Apple 側自動採番と競合させない。MARKETING_VERSION は `Config.xcconfig` の値を使う
- **Run Script（Compile Kotlin Framework）の JAVA_HOME を条件分岐化**: 旧実装は Android Studio の JBR を無条件 export しており CI ランナーで壊れるため、ディレクトリ存在時のみ export に変更（CI では setup-java の JAVA_HOME を継承）
- 影響: gitignore 済み秘匿ファイル（`GoogleService-Info.plist` / `Secrets.xcconfig`）は Secrets から復元する運用が確立。ランナーは deployment target iOS 26.0 の制約で `macos-26`（Xcode 26 系を `xcode-select` で選択）。Konan キャッシュは ci.yml と同一キーで共有

### 2026-07-08: Places API キーのクライアント埋め込みリスクとバンドル ID 制限の実効性

- 関連: `shared/data-places/src/iosMain/kotlin/com/noricoffee/data/places/PlacesHttpClient.ios.kt`

「Places API キーがアプリに埋め込まれているのは安全か」への整理。結論: **キーの抽出は不可避（Info.plist 経由で `.ipa` に平文）で、`X-Ios-Bundle-Identifier` によるバンドル ID 制限はヘッダ文字列の照合のみ（暗号検証なし）のため、なりすましで突破可能 = 実効的防御ではない**。防げるのは他アプリ・別プロジェクトへのキー流用事故のみで、キー抽出後の課金踏み台化は防げない。この制限を実効的セキュリティと誤認しないこと。git 漏洩は無し（`Secrets.xcconfig` 未追跡 + `git log -S` 確認済み）。

推奨対策（優先順）: ①Google Cloud の**予算アラート + 日次クォータ上限**（被害額に天井・クライアント側で完結する唯一の現実的な守り）②API 制限を Places API (New) 限定に ③バックエンドプロキシでキーをサーバ側へ隔離 ④プロキシ + App Attest。**現時点はリリース初期の個人開発規模のため ①+② で十分抑制**と判断（③④はユーザー数増加で課金額が無視できなくなってから）。

### 2026-07-08: `CoffeeEditorViewModel.buildCafe` の cafe 採用判定を mode 分岐から状態判定へ

- 関連: `shared/feature/coffee-editor/src/commonMain/kotlin/com/noricoffee/feature/coffeeeditor/CoffeeEditorViewModel.kt`

フェーズ 6 バックログの既知バグ修正（2026-07-06 の 15-B 実装中に kmp-engineer が発見・スコープ外で保留していたもの）。

- **バグ**: セルフ抽出記録（`cafe == null`）を Edit / Duplicate して手動でカフェ名を入力しても、旧実装 `when (mode) { is Mode.Edit, is Mode.Duplicate -> currentInitialRecord?.cafe ?: return null; is Mode.Create -> ... UUID }` が `?: return null` で入力値を無言で破棄していた。手入力カフェとして新規 UUID を採番すべきところが cafe = null 保存になっていた
- **修正**: cafe 採用の優先順位を状態ベースに一本化 — ①`cafeName` 空 → null（セルフ抽出）②`selectedCafe` あり → それを採用 ③引き継ぎ元 `currentInitialRecord?.cafe` あり → それを引き継ぐ ④いずれもなし → UUID 新規採番（座標 null / photoReferences 空）。これで `buildCafe` の `when (mode)` が不要になり `mode` 引数を削除（`buildCafe(draft)`）
- **なぜ mode 不要か**: `Mode.Create` は `load()` で `currentInitialRecord = null` を明示設定するため、③の判定が Create では常に false → ④に落ちる = 従来の Create 挙動（UUID 採番）と一致。よって「引き継ぎ元 cafe の有無」の一点で 3 モードを統一でき、Create 挙動は不変
- **検証**: 回帰テスト 2 件（Edit / Duplicate のセルフ抽出 × 手動カフェ名）追加。`testAndroidHostTest` 20 件 green / `iosSimulatorArm64Test` 親が override 無しで green
- **iOS 影響なし**: `buildCafe` は private。公開 API（`Mode` / `UIState` / public メソッド）不変で Bridge 追随不要

### 2026-07-08: BeanProfile 初期データの表記・データソース方針（seed 整備）

- 関連: `scripts/seed/bean-profiles.json` / `scripts/seed/seed-bean-profiles.mjs`

Firestore `beanProfiles` が空のまま残っていた初期データ投入（12-B 起票時から「ユーザー作業」扱い）を、seed JSON + Admin SDK スクリプトとして整備した。grilling で確定した仕様と、その理由:

- **スキーマ拡張は見送り**: ユーザー要望の「SCAJ の評価」は 8 項目カッピングスコアの構造化保持ではなく、**description の記述観点（酸の質 / 甘さ / 質感 / クリーンカップ / 余韻 / 調和）と flavorNotes の語彙への反映**で吸収。現行 6 フィールドのまま実装済みの 12-B / 12-C / 15-E-3 が即動く最小コスト案を採用
- **日本語表記に統一**（origin「エチオピア」/ variety「ゲイシャ」/ flavorNotes「ジャスミン」）: 好み突合はユーザーが記録に入力した産地文字列との trim + lowercase 部分一致であり、日本語 UI での手入力（「エチオピア」と書く可能性が高い）とマッチさせるため。data-model.md の英語サンプルは日本語例に改訂済み。`processings` だけは enum 識別子（`"Washed"` 等）のため英語のまま
- **flavorNotes は統一語彙 42 語に固定**（自由記述禁止。正本 data-model.md §3.2）: `PreferredBeanTraitsUseCase` の頻度集計が表記ゆれ（「チョコ」「チョコレート」）で割れるのを防ぐ。seed スクリプトのバリデーションで機械強制
- **著作権**: Blue Bottle 等ロースターのラインナップは「どの産地・品種・精製を揃えるか」の参考にのみ使い、description は一般知識ベースの自作テキスト。転載はしない
- **投入**: doc ID = beanId の `set()` で冪等 upsert（削除はしない。JSON から消した項目は Console で手動削除）。dry-run はバリデーションのみで firebase-admin 不要。サービスアカウント鍵は `.gitignore`（`*service-account*.json`）
- 影響: 投入後、分析タブ「好みの豆の傾向」/「試してみては」/ エディタ産地サジェストが実データで動く（verification-checklist 15-E-3 の実機確認が可能になる）。アプリはメモリキャッシュ（one-shot get）のため投入反映には再起動が必要

### 2026-07-08: OriginNormalizer — 産地シノニム名寄せ（ベクトル検索は見送り）

- 関連: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/OriginNormalizer.kt`

ユーザーから「好み突合を完全一致でなくベクトル検索にする方針はあり？」の問い。**見送りと判断**し、決定論のままシノニム辞書で名寄せを強化した。

- **ベクトル検索見送りの理由**: ①推薦理由の説明可能性が要件（9-5 は一致理由を表示する設計。類似度スコアでは理由が語れない）②完全オフライン動作（非機能要件）に埋め込み生成サーバが反する ③決定論・commonTest 固定という分析層の設計原則 ④豆 38 件・記録数百件の規模に対して過剰。意味的クエリはフェーズ 13（FM が 5 軸数値に構造化変換 → KMP 決定論検索）、本物のベクトル類似は 9-6（サーバ側、`tastingAverages` 数値ベクトル）が受け皿という 3 段整理
- **設計**: `object OriginNormalizer.normalize = trim → lowercase → シノニム辞書の完全キー一致（辞書外は素通し）`。辞書はコードが正本（英語国名 20 ヶ国 + サブ地域・通称。「モカ」は多義のため不収録）。適用は全 origin 正規化ポイント 5 箇所（BeanProfileMatch / BuildCoffeeStats の originRanking・bestOrigin / ObserveTasteMatchedCafes / PreferredBeanTraits / SuggestUnexploredBeans。variety は従来の trim+lowercase のまま非対称）。`CoffeeRecordQuery` の free-text と `getByOrigin`（本番呼び出し元ゼロ）は対象外
- **複合語 contains マッチとの非両立（既知の限界）**: 辞書は単語単位の完全キー一致のみで、複合語（「Ethiopia Yirgacheffe」）へのシノニム適用は行わない。入力「Yirgacheffe」は「エチオピア」へ変換されるため、**変換後文字列と未変換の複合語が contains ですれ違う**。この形の既存テスト 2 件（合成シナリオ）が fail → 実データ（bean-profiles.json 38 件は全て単一国名 origin）で再現しないため**非対応と割り切り、辞書外の語（「ニエリ」）でテストを再構成**した（トークン分割拡張は Simplicity First で不採用。将来複合語 origin を投入するなら再検討）
- 経緯: kmp-engineer が実装（セッション上限で中断し、テスト再構成 2 件 + 名寄せ回帰テスト 1 件は親が引き継ぎ完了）

### 2026-07-08: beanProfiles の取得方式 — Remote Config によるバージョン管理は見送り（現状維持）

- 関連: `BeanProfileRepositoryAndroidImpl.kt` / `BeanProfileRepositoryIosImpl.swift`

ユーザーから「めったに更新されないデータなので、Firebase Remote Config などで更新シグナルが来るまでローカル保持し続ける方針はどうか」の提案。**現状維持（見送り）と判断**。

- **現状の取得方式**: プロセスごとに one-shot `get()`（38 件一括）+ メモリキャッシュ。Firestore SDK のオフライン永続化が効くため圏外でもキャッシュから読める。通信・課金は起動あたり 38 reads + 1 往復が上限で、無料枠（5 万 reads/日）に対して誤差
- **Remote Config 見送りの理由**: ①公式プラットフォーム別 SDK 方針のため RC も Swift/Kotlin 二重実装 + KMP 抽象が必要（豆データ 1 種には過重）②「保持し続ける」にはローカル永続層（SQLDelight or ファイル）の新設が必要 ③**seed 投入（Firestore）と RC バージョン更新が別システムの手作業 2 段になり、上げ忘れで静かに壊れる**（「片側変更 → 対向未追随」ファミリーと同構造の同期ポイントを増やす）
- **将来やる場合の採用案 = `_meta` ドキュメント方式**: `beanProfiles/_meta { version }` を seed スクリプトが投入時に自動インクリメント。起動時は `_meta` 1 read → ローカル保存済みバージョンと一致なら 38 件取得をスキップ。**バージョンがデータと同じ場所に住む**ため 1 回の投入で両方更新され、上げ忘れが構造的に起きない。新 SDK 不要
- **再検討の損益分岐**: 豆データが数百件規模に成長、またはユーザー数増で beanProfiles の reads が課金圏に入ったとき

### 2026-07-08: Firebase テレメトリ導入（Crashlytics / Performance = 常時、Analytics = 同意ゲート）

- 関連: `iOSApp.swift` / `AppState.swift` / `Info.plist` / `iosApp.xcodeproj`

ネイティブアプリのデファクト標準として Firebase Crashlytics / Analytics / Performance を導入。既存のオプトイン同意基盤（`analyticsConsent`、既定 false）に接続する。

- **ゲート方針（ユーザー確定 2026-07-08）**: **Crashlytics + Performance は常時収集（同意不要）**、**Analytics のみ `analyticsConsent` 同意時に有効化**。
  - 根拠: Crashlytics（クラッシュ診断）と Performance（起動/描画/ネットワーク遅延の技術診断）は個人の行動プロファイルではなく「安定性・技術品質の正当利益」で説明でき、常時 ON が妥当。一方 **Analytics は製品利用・行動データで、GDPR/ePrivacy では opt-in 同意が原則必須**。加えて既存オンボーディングで「記録データのサービス改善利用への同意」をユーザーに約束済みで、Analytics を勝手に常時 ON にすると同意文言と実挙動が矛盾する
  - 検討したが不採用: ①3 つとも同意ゲート（Crashlytics のクラッシュ可視性を非同意層で失う。安定性目的の常時収集は業界標準で許容される）②3 つとも常時 ON（上記の Analytics 常時 ON の法務・信頼リスク）
- **IDFA なし**: Analytics は素の `FirebaseAnalytics` プロダクトを採用。クロスアプリ追跡を行わないため **ATT プロンプト不要**を維持し、プライバシー申告を簡潔に保つ。⚠️ **実装時の実態訂正**: 当初は `FirebaseAnalyticsWithoutAdIdSupport` を採用予定だったが、現行 firebase-ios-sdk（解決版 12.14.0）で**同プロダクトは廃止**されていた。現行 SDK は**既定の `FirebaseAnalytics` が IDFA 非対応**に反転し、IDFA を使う場合のみ `FirebaseAnalyticsIdentitySupport` を追加する方式。よって `FirebaseAnalytics` を採用し `IdentitySupport` は足さない = IDFA なし・ATT 不要という結論は不変（プロダクト名だけ変更）
- **収集の起動時制御**: `Info.plist` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO` で Analytics 自動収集を起動時 OFF（Performance は常時 ON なのでフラグを立てない / true）。`FirebaseApp.configure()` 後に Crashlytics を明示有効化。`AppState.applyTelemetryConsent(_:)` を新設し、bootstrap での consent 確定時・設定トグル/オンボーディングでの変更時に `Analytics.setAnalyticsCollectionEnabled(consent)` を呼ぶ（Performance/Crashlytics は触らない）
- **Analytics イベント範囲（今回）**: 自動収集イベント + `screen_view` のみ。SwiftUI は UIKit 自動 screen tracking が効かないため `.trackScreen("name")` view modifier を自作し 4 タブ + 主要画面に付与。カスタムドメインイベント（記録作成 / カフェ検索 等）は後続タスクに分離
- **トレードオフの記録**: Crashlytics の breadcrumb ログと crash-free users 指標は内部で Analytics に依存するため、**非同意ユーザーではクラッシュ前後の文脈が減る**（クラッシュ自体は記録される）。この損失は許容し、Analytics 常時 ON の法務・信頼リスクを回避する方を採った
- **Xcode プロジェクト設定**: 既存 `firebase-ios-sdk` SPM パッケージから 3 プロダクトを追加。Crashlytics は dSYM アップロード用の run-script build phase（`${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`）が Release/TestFlight でのシンボリケーションに必要。`PrivacyInfo.xcprivacy` の集計データ種別更新も要（app-store-metadata.md 6.1/6.3 と対応）

### 2026-07-12: 逆変換 PoC 導線を本番採用（リリース前判断の解消）

- 関連: tasks.md「リリース前バックログ」、本ノート 2026-06-26 エントリ

iOSDC LT 由来の PoC 導線（分析タブ最下部の `TastePreferenceConversionView` への NavLink）を「本番に含める / 設定の開発者向けへ移動 / 削除」から**本番に含める**でユーザー確定（削除・`#if DEBUG` 化は不採用）。

- 判断の根拠: ①フェーズ 13 で同じ `TastePreferenceExtractor` が実用昇格済みで技術は本番品質 ②起票時（2026-06-26）の懸念だった「全ユーザー常時表示」は、その後のフェーズ 13 実装で `makeIfAvailable()` ゲートが入り **FM 非対応端末では導線非表示**になっていた（`AnalysisView.swift` の `tasteSearchSection` で 2026-07-12 コード確認）③`coffeeRecordQuery` 連携済みで、変換デモではなく「自由文 → 好み検索」の実画面に成長している
- 追加実装なし。リリース前バックログの当該行は完了

### 2026-07-12: F-1 — Required Reason API 網羅監査（FileTimestamp C617.1 を追加宣言）

- 関連: tasks.md「リリース前バックログ」F-1、`iosApp/iosApp/PrivacyInfo.xcprivacy`

- **監査方法**: ①iosApp Swift 全域を Apple の 5 カテゴリ（File Timestamp / System Boot Time / Disk Space / Active Keyboard / UserDefaults）の対象シンボルで grep ②自前 Kotlin（shared）のプラットフォーム API 接点を grep（接点は DriverFactory / PlacesHttpClient の 2 ファイルのみ・該当なし）③**アプリ同梱バイナリ `SharedLogic.framework` を `nm -u` でシンボル実測** ④Firebase SDK は各プロダクトが PrivacyInfo.xcprivacy を同梱していることを SPM checkout で確認（SDK 側の自己申告でアプリ側対応不要）
- **結果**: Swift 側の使用は UserDefaults のみ（CA92.1 宣言済み）。**SharedLogic（Kotlin/Native ランタイム）が File Timestamp カテゴリの `stat` / `fstat` / `fstatat` / `lstat` / `getattrlist` / `getattrlistbulk` をリンク**しており、アプリ同梱バイナリのため提出時スキャン（ITMS-91053）の対象 → `NSPrivacyAccessedAPICategoryFileTimestamp` + **C617.1**（アプリコンテナ内ファイルへのアクセス。K/N ランタイムの内部ファイル操作・SQLite DB ファイル等）を追加宣言。Boot Time / Disk Space / Active Keyboard は Swift・バイナリとも該当なし
- K/N ランタイムが posix stat 系を持ち込むのは KMP アプリの既知事象で、C617.1 宣言が標準的な対応。grep だけでなく**バイナリの `nm -u` まで見る**のが監査として確実（Swift ソース grep だけでは K/N 由来を見落とす）。`plutil -lint` OK

### 2026-07-12: B-4 — rating の nullable 化（0.0 sentinel 全廃）と未評価保存の解禁

- 関連: `shared/domain/.../CoffeeRecord.kt`、`shared/data-local/.../migrations/5.sqm`、`iosApp/iosApp/Components/StarRatingView.swift`

backlog B-4 の解消。`CoffeeRecord.rating: Double`（0.0 = 未評価 sentinel）を `Double?`（null = 未評価）へ。確定仕様は `data-model.md` §1.1 / §3.2 / §7、要件は requirements 変更履歴 2026-07-12。

- **未評価保存の解禁（ユーザー決定）**: 従来エディタは rating 必須（0.5 未満はバリデーションエラー）で、requirements の「未評価は集計から除外」と矛盾していた（未評価記録はダミーデータ経由でしか作れなかった）。nullable 化にあわせ「null は OK / 非 null なら 0.5..5.0 かつ 0.5 刻み」に変更し、「まず記録、あとで評価」を可能にした（15-B の記録摩擦低減と整合）
- **Firestore は「null = キー省略」**: 当初案は明示 null 書き込みだったが、既存規約（cafe / origin / tasting 等の nullable はキー省略）に合わせて省略方式へ変更。decode はキー欠如 / null / 0.0（legacy）をすべて null に正規化（リモート既存ドキュメントは migration せず読み側で吸収）。Android mapper の「rating 欠損で record 全体 drop」も撤廃
- **Q&A ツール境界だけ 0.0 sentinel を意図的に残す**: `CoffeeRecordSummary.rating: Double`（`record.rating ?: 0.0`）。LLM ブリッジの primitive 主義（analysis-model §1）を優先し、iOS ツール系の `>= 0.5` 表示分岐も不変で済ませた
- **migration 5 はテーブル再作成方式**: SQLite は NOT NULL 撤廃の ALTER 不可のため CREATE → `NULLIF(rating, 0.0)` で INSERT SELECT → DROP → RENAME → インデックス再作成。`PRAGMA foreign_keys` は SQLDelight グラマの制約で `0`/`1` リテラル表記。「SQLite はトランザクション内の `PRAGMA foreign_keys` を無視する」既知の罠があるため、JVM（JdbcSqliteDriver）に加えて NativeSqliteDriver（iOS 本番ドライバ、FK 有効の本番構成）でも migration テストを追加して実証（`CoffeeRecordMigration5IosTest`、0.0→NULL 変換 + photo FK 保持 + CASCADE 継続を確認。in-memory での検証のため実機ディスク DB はシミュレータ目視で補完）
- **iOS の未評価 UI**: read-only は星 0 個でなく「未評価」テキスト（低評価との誤読回避）。解除は明示クリアボタン + VoiceOver の decrement 下限の 2 経路（再タップ解除は discoverability と VoiceOver 非対応で不採用）
- 影響: `data-firebase` に初のテスト基盤新設（`commonTest` に kotlin-test 追加、plain JVM で Firestore `Timestamp` が動くことを確認）

### 2026-07-13: 周辺カフェピンのノイズ除去（名前フィルタ + ネガティブキャッシュ）

- 関連: `shared/feature/map/.../MapViewModel.kt`、`iosApp/.../Features/Map/ApplePoiNegativeCache.swift`、tasks.md「周辺カフェピンのノイズ除去（2026-07-13 起票）」

Apple `.cafe` 誤分類の非カフェ（法人本社「株式会社 アニメイトカフェ」/ コンカフェ / ガールズバー等）が周辺ピンに混入する問題への 2 段対策。Apple ソース（無料）は維持し、Places 課金構造は不変（paid-services.md 更新不要）。

- **`UIState.poiLookupError` を `String?` → `PoiLookupError(message, isNotFound)` に型変更**: ネガティブキャッシュに記録してよいのは「Google 解決で該当なし」だけで、通信エラー等の一時的失敗を記録すると実在カフェを恒久非表示にしてしまう。この区別は commonMain の状態遷移（空結果 vs 例外）でしか判定できないため、公開 API で型として区別する。表示文言は不変
- **名前ヒューリスティック除外（iOS）**: 除外キーワード 16 語（法人格 / スペース系 / 業態系）を `MapTabView` の static Set に一元化し、`fetchAppleNearbyCafes` で部分一致除外。リストは追記で育てる運用
- **ネガティブキャッシュ設計**: UserDefaults + JSON、一致判定は「名前完全一致 + 座標 30m 以内」（Apple POI に安定 ID がないための複合キー）、上限 300 件 FIFO、**TTL なし**（Google で解決できない POI は恒久的にタップ不能 = 17-B の「表示＝解決可能」原則に沿って隠したままで整合）。件数上限が小さいため線形走査で十分と判断
- 不採用: 周辺ピンソースの Google `searchNearby` 置き換え（データ品質は最良だがカメラ移動ごとの課金が発生しコスト構造が変わる。1+2 で不十分な場合の次の手として保留）
- トレードオフ: 名前フィルタはブラックリスト方式なのですり抜けは残る（すり抜け分はタップ 1 回でネガティブキャッシュが吸収）。逆に「オフィス」等の語を含む実在カフェを誤除外するリスクは許容（該当したらキーワードを見直す）
- 経緯: SKIE 知見 — プレーンな nested data class は `.swiftinterface` に現れず、生成 ObjC ヘッダの `swift_name` 属性で裏取りする（kmp-engineer メモリにも記録済み）。また Kotlin data class は `isEqual:`/`hash` オーバーライドにより SwiftUI `.onChange(of:)` にそのまま使える

### 2026-07-13: POI 除外キーワードの Remote Config 外部注入

- 関連: `iosApp/.../Features/Map/ApplePoiFilterConfig.swift`、tasks.md「名前フィルタの Remote Config 外部注入（2026-07-13 起票）」

同日のノイズ除去で導入した除外キーワード 16 語を Firebase Remote Config（キー `map_poi_excluded_name_keywords`、JSON 文字列配列）で配信し、リリースなしで追加・削除可能にした。iOS 専用の view 層の関心事のため KMP を通さず iosApp 内で完結（`shared/domain` Repository 経由の Firebase 不変条件はユーザーデータの層の話で、アプリ設定値の配信はその対象外と判断）。

- **置き換えセマンティクス**: remote の parse に成功したら bundled デフォルトを完全置換（和集合にしない — コンソールの見た目と実挙動を一致させる）。**空配列 `[]` も「成功」として 0 件を許容**（フィルタの一時無効化に使える。設定ミスで全 POI が出るリスクは許容）。空文字・parse 失敗・未取得は bundled デフォルトへフォールバックし、コンソール未設定でも現行挙動と完全同一
- **fetch 戦略**: 起動時 `fetchAndActivate` 1 回・失敗無視（fire-and-forget）。最小フェッチ間隔は SDK 既定 12h、リアルタイムリスナー不採用（次回起動反映で十分）。テレメトリ同意（`analyticsConsent`）フローの対象外（設定値配信でありユーザーデータ収集ではない）
- **プライバシー**: FirebaseRemoteConfig は SDK 同梱の PrivacyInfo.xcprivacy で UserDefaults(1C8F.1) + Other Diagnostic Data（非トラッキング）を自己申告（SPM checkout の実物を plutil で確認済み）→ アプリ側 `PrivacyInfo.xcprivacy` 変更不要。app-store-metadata 6.3 に SDK 行のみ追加
- 不採用: Firestore の設定ドキュメント方式（新 SDK 不要だが、公開 read の security rule 追加が必要でユーザーデータの層にアプリ設定が混ざる。編集体験もコンソールに劣る）

### 2026-07-13: 分析タブ可視化改善 — 焙煎度の順序尺度化 + テイスティングのレーダー化

- 関連: `iosApp/.../Features/Analysis/AnalysisView.swift`、`iosApp/.../Features/Analysis/TastingRadarChart.swift`、tasks.md「分析タブ可視化改善（2026-07-13 起票）」

分析タブの可視化レビューで採用した 2 件（ユーザー確定: レーダーは横棒を置き換え / 焙煎度は全 8 段階を常時表示）。KMP 変更なし。

- **焙煎度チャート**: 件数降順・単色縦棒 → 全 8 段階を焙煎順（浅→深）の横棒 + 浅→深のブラウン明暗ランプ。**`CoffeeStats.byRoastLevel` の件数降順契約は KMP 側で変更しない**（LLM digest で「最頻焙煎度」参照に使う契約のため）— Swift 側で `RoastLevel` enum 宣言順（= 焙煎順）の固定配列に count 0 補完でマージする表示専用変換とした。記録ゼロの段階もラベルを出す（「飲まない領域が見える」ことが情報）が、`byRoastLevel` 自体が空ならセクション非表示（従来どおり）
- **色ランプ**: `Color.accentColor`（#8B5A2B ブラウン）を `Color.mix(with:by:)`（iOS 18+、本プロジェクトは iOS 26 ターゲット）で white 側 0.55 〜 black 側 0.45 に寄せた 2 端点の線形補間 8 段。Assets の AccentColor ライト/ダーク両変種に自動追従するため Color Set の追加なし（ui-ux-guidelines「勝手に色を増やさない」と整合）。「中央段を純 accent に固定する」案は不採用（全段が単調に明→暗になる方が読みやすい）。寄せ幅は感覚値でシミュレータでのコントラスト確認はユーザー確認待ち
- **テイスティングレーダー**: Swift Charts にレーダーが無いため `GeometryReader` + `Path` のカスタム View。5 軸固定・スケール 0–10 固定（データ最大値に正規化しない — 記録が増えても形を比較可能に保つ）。`RadarChartAxis(label, value, accessibilityLabel)` を受けるドメイン非依存コンポーネントとし、「N 件の記録」等の文言は呼び出し側が組み立てる（将来の 5 軸系転用を想定）。数値精度は各軸ラベルに平均値を添えて担保（横棒廃止の代償）
- **軸ラベル配置**: 2-pass 実測レイアウトではなく軸角度の cos/sin 閾値ヒューリスティック（正五角形固定なら上/左右/下に自然収束）。Dynamic Type 極大時の重なりは許容
- **a11y**: レーダーの装飾レイヤーは `accessibilityHidden`、軸ラベルのみが要素となり VoiceOver は軸ごと 5 要素で読み上げ（既存 `tastingAccessibilityLabel` を維持）

### 2026-07-13: エクスポート JSON の Firestore 投入スクリプト（開発用インポート）

- 関連: `scripts/seed/seed-coffees.mjs`、requirements 7-4、tasks.md カテゴリ 3「開発支援: エクスポート JSON の Firestore 投入スクリプト」

「エクスポートがあるのにインポートが無い」という論点の帰結。開発用途（ダミーデータの実機投入）が動機だったため、**アプリ内のインポート機能は作らず、Admin SDK シードスクリプトで充足**した。

- **アプリ本体のインポート機能は意図的に非対応**: 復元・機種変更は Firestore 同期（7-3）が担い、写真は iCloud Backup（7-2）。エクスポート（7-4）はバックアップではなく「データの持ち出し手段」で、往復対称性は要件でない。アカウント削除後の JSON からの復帰は非サポート（必要になったら要件化から再検討。ID 衝突マージ・version 互換・写真非復元の期待値ギャップがコスト）
- **入力はエクスポート envelope v1 をそのまま受ける**: エクスポート DTO が Firestore 直列化規則を踏襲して設計されているため、変換は薄い差分吸収のみ — ① null キー省略（エクスポートは `encodeDefaults = true` で null キーも出す）② `createdAt`/`updatedAt` の ISO 文字列 → `Timestamp`（`Date.parse` でミリ秒精度に切り詰め、dev 用途で許容）③ **photos は常に空配列**（画像は端末ローカルのみで fileName 参照が解決不能。メタデータだけ入れると詳細画面で欠損表示になる）
- **`userId` は `--uid` 引数で全レコード上書き**: エクスポート元と投入先のアカウントが違っても付け替えて投入できる（doc 内 `userId` とパス uid の不一致を作らない）
- bean-profiles と同じ流儀（`--dry-run` は firebase-admin 不要 / 投入前バリデーション / ドキュメント ID = record.id の `set()` 冪等 upsert）。enum 名リスト（BrewMethod / ProcessingMethod / RoastLevel）は shared/domain と一致させる必要がある（bean-profiles 同様の複製。enum 追加時に追随）
- 投入後は実機のサインイン中リスナー（`startSync`）が自動反映。投入したレコードは `DummyCoffeeData` と違い「本物のレコード」として全端末に同期される点に注意（削除はコンソールかアプリから）

### 2026-07-14: 広告プレプロンプト / ATT フローは既存ユーザーにも 1 回到達させる（UserDefaults フラグ方式）

- 関連: `iosApp/iosApp/Ads/AdConsentCoordinator.swift`, `iosApp/iosApp/AppState.swift`, requirements.md §11-4

requirements.md §11-4 の「データ利用同意オンボーディングの直後に ATT」を文字どおり実装すると、Firestore に `users/{uid}` が既にあるユーザー（オンボーディングが二度と出ない）は ATT フローに永久に到達しない。実装では `UserDefaults` の `hasCompletedAdConsentFlow` フラグを導入し、「未実施なら `bootstrap()` 完了時に 1 回だけ表示」に拡張した（新規はオンボーディング直後、既存は次回起動時に到達）。未リリースのため現時点の実害はないが、意図的な仕様拡張（requirements §11-4 の備考にも反映済み）。

追記（同日）: 初版は UMP `loadAndPresentIfRequired` を無条件に呼んでいたため、フォールバックの Google テスト用 App ID に構成済みの IDFA 説明メッセージ（"Our App wants to stay free…"）が自前プレプロンプト + ATT と**二重表示**された（ユーザーのシミュレータ確認で発覚）。1 回目の修正で `consentStatus == .required` ガードを入れたが解消せず — **ATT メッセージがコンソールに構成されていると、GDPR 圏外でも ATT 未決定なら UMP は required 扱いにする**ため、ガードを素通りする。「条件を狭めて呼ぶ」系はコンソール構成に挙動が依存して制御できないと判断し、最終的に **UMP の呼び出し（`requestConsentInfoUpdate` / `loadAndPresentIfRequired`）をコードから全撤去**した（SDK リンク自体は Google Mobile Ads SDK の内部依存で残る）。同意 UI は自前プレプロンプト + 直接 ATT で完結。`canRequestAds` は requestConsentInfoUpdate を呼ばない構成では常に false のため**参照禁止**。EU 配信を始める場合は GDPR フォーム実装として UMP を再導入する。

### 2026-07-14: ネイティブ広告は mediaView 非表示・icon + text + CTA テンプレートで統一

- 関連: `iosApp/iosApp/Ads/NativeAdContainerView.swift`

4 面とも既存 UI（検索結果行・List セクション・下部固定枠）の行の高さに揃えるため、ネイティブ広告の `mediaView`（画像 / 動画アセット）を表示しないテキスト主体テンプレートにした。AdMob ポリシー上は headline 以外のアセットは任意のため問題ないが、動画中心のインベントリからの fill 率に影響しうる（収益が想定より低い場合の見直しポイント）。UMP SDK は Google Mobile Ads SDK（SPM）の内部依存として自動リンクされるため個別導入は不要。

追記（同日）: テスト広告の AdMob native ad validator が「1 implementation issue」を検出し、ユーザー確認の結果 **MediaView（最小 120×120pt）が必須アセット**と判明（「headline 以外は任意」という当初の理解が誤り）。コンパクト枠に 120pt メディアを組み込むとバナー（50〜60pt）より大きく悪目立ちし「溶け込むからネイティブ」の前提が崩れたため、**全面アダプティブバナーへ再編**（同日ユーザー確定。requirements §11 改訂済み）。本エントリのテンプレート判断はこの時点で廃止。ネイティブ実装で得た教訓（Group+task 発火 / safeAreaInset 統一）はバナー実装にも引き継ぐ。

### 2026-07-14: 広告コンポーネントの task 発火バグ修正（Group → ZStack / ローダー持ち上げ / safeAreaInset 統一）

- 関連: `iosApp/iosApp/Ads/InlineNativeAdCard.swift`, `iosApp/iosApp/Ads/BottomBarNativeAdView.swift`, `CafeDetailView.swift`, `CoffeeListView.swift`

「広告が分析タブ以外表示されない」報告の修正で確定した 3 判断（バグ機構の詳細は lessons 2026-07-14）:

- **広告コンポーネントの root は `ZStack`**: `Group { if let }` + `.task` は子ゼロの間 task が発火しない。ZStack は常に実体化されるため空でも発火し、空時は高さ 0 に畳まれる（畳み仕様は維持）
- **カフェ詳細はローダーを画面側へ持ち上げ**: List の Section 内で空 ZStack を置くと空 Section の余白・区切り線が残るため、`CafeDetailView` が `@State` でローダーを持ち、`List` 自体の `.task` でロード駆動、`nativeAd != nil` のときだけ `adSection` を List に含める
- **下部固定広告は `.safeAreaInset(edge: .bottom)` に統一**: コーヒー記録タブの VStack 末尾直置きは iOS 26 のフローティングタブバー背後に隠れる。分析タブと同方式に統一し、FAB は `ZStack(alignment: .bottomTrailing)` + safeAreaInset で縮んだ安全域基準となり広告の上に自然に乗る（広告が畳まれれば FAB も下がる）

### 2026-07-14: 全面アダプティブバナーへの再実装で確定した判断

- 関連: `iosApp/iosApp/Ads/BannerAdLoader.swift`, `InlineBannerAdView.swift`, `AnchoredBannerAdView.swift`, `CafeDetailView.swift`

MediaView 必須判明によるネイティブ → バナー再編（requirements §11 改訂）の実装で確定した判断:

- **アンカー面のサイズ関数**: ドキュメント記載の `currentOrientationAnchoredAdaptiveBanner` は現行 SDK ヘッダで非推奨のため、当初 `largeAnchoredAdaptiveBanner(width:)` を採用（SDK ヘッダ実読み + 公式サンプルで裏取り）。その後 large の高さ（実測 126pt）が圧迫的との判断で、**`inlineAdaptiveBanner(width:maxHeight: 90)` に変更**（2026-07-15 同日）。SDK v13.6.0 のヘッダ確認で、アンカー系には非推奨でない「標準版」（高さ 50〜90pt）が存在しない（portrait / landscape / currentOrientation 版はすべて非推奨、非推奨でないのは large のみ）ため、同じ幅適応 + 高さ上限 90pt を実現できる inline 系で代替した。サイズ関数の分類（inline / anchored）は adSize の決定ロジックの違いだけで、配置場所（safeAreaInset）とは独立
- **インライン面は `inlineAdaptiveBanner(width:maxHeight:)`**: 実測幅は `.background(GeometryReader)` + `.task` で取得（ロードトリガーは常在ビューに付ける原則を踏襲）
- **カフェ詳細のバナー幅は List 実測幅 − 32pt の概算**: `.insetGrouped` の左右余白の保守的な見積もり（`CafeDetailView.adHorizontalMargin`）。実機で狭すぎ / 広すぎが見えたらこの定数を調整する
- テスト用フォールバック ID はバナー用 `ca-app-pub-3940256099942544/2435281174`（アンカー / インライン共通）。xcconfig キー名は `ADMOB_BANNER_AD_UNIT_ID_*` にリネーム済み
- ネイティブ実装（NativeAd 系 4 ファイル）は完全撤去。NPA / 畳み挙動 / 4 面配置は不変

### 2026-07-15: バナーローダーの安定化（pending 方式 / 実サイズ明示 / 既知の過渡エラー）

- 関連: `iosApp/iosApp/Ads/BannerAdLoader.swift`, `BannerViewRepresentable.swift`, `InlineBannerAdView.swift`, `AnchoredBannerAdView.swift`, `CafeDetailView.swift`

バナー再実装後の「カフェ詳細以外表示されない」報告（ユーザーの Xcode コンソールログで診断）の修正で確定した判断。バグ機構の一般形は lessons 2026-07-15 の 2 エントリ。

- **`BannerAdLoader` は pending 方式**: ロード中の新要求は `pendingAdSize` に保存し完了後に追いかけ実行（最後の要求の保証）。同一サイズロード済みは no-op。`hasEverReceivedAd` 後の失敗では表示を巻き戻さない。呼び出し側は `minimumRequestableWidth`（150pt）未満の過渡幅でロードしない
- **表示は受信後の実サイズで明示 frame**: `loadedAdSize`（didReceive 時の `bannerView.adSize.size`）で `.frame(width:height:)`。Google 公式 SwiftUI サンプル（BannerViewContainer）準拠 + インラインアダプティブの可変返却サイズ対応（リクエスト時サイズではなく実サイズを使う点が公式サンプルとの意図的な差分）
- **既知の過渡エラー（許容）**: 受信直後に `load()` 非経由の「Invalid ad width or height」失敗ログが 1 回出ることがあるが、直後に再受信して表示は正常維持される。テスト段階では 4 面が**同一テストユニット ID を共有**しており切り分け不能なノイズと判断。**本番の面別ユニット ID 発行後も継続して出る場合は再調査する**（観察ポイント）

追記（同日）: コーヒー記録タブの固定広告を**下部 → 上部 → リスト先頭インライン**と 2 段階で変更（いずれもユーザー確定）。①下部→上部: FAB と広告の近接（16pt）は誤タップを誘発し AdMob ポリシー上もリスク + タブバー / 広告 / FAB の下部 3 段渋滞 + 畳み挙動で FAB が動く副作用。②上部→リスト先頭インライン: 上部固定は常時画面を占有するため「スクロールで流れる」要望を受け、最初の月セクション前のインラインアダプティブバナー（`CafeDetailView.adSection` と同じパターン）へ。**常時表示でなくなる分インプレッションは減るが閲覧体験を優先**。分析タブは FAB がないため下部固定のまま（非対称は意図的）。`AnchoredBannerAdView` は分析タブ専用となったがコンポーネントは上下どちらにも載る汎用のまま。

### 2026-07-16: マップ「好み一致」チップのタップ対応（TagChip 化）

- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`, `iosApp/iosApp/Features/Map/RecommendedCafeListSheet.swift`, `iosApp/iosApp/Components/TagChip.swift`

ユーザー報告「好み一致タグをタップしても何も起きない」への対応。旧実装は静的凡例チップ（`TagLegendChip`、意図的にインタラクションなし）だったが、隣のタップ可能チップと同じカプセル見た目で誤解を招くため、**「保存済み」チップと同じ操作体系に変更**（タップで強調 ON + 一覧シート `RecommendedCafeListSheet` 表示、強調中の再タップは強調解除のみ。行タップでカフェ詳細へ push）。挙動 3 案（一覧シート / 見た目のみ非タップ化 / 強調トグルのみ）からユーザーが一覧シート案を選択。

- **`TagChip` に `tint` パラメータ追加**（既定 `.accentColor`）: 色セマンティクス表（ui-ux-guidelines）の「accentColor を『好み』の意味で使わない」を守るため、好み一致チップだけ `.pink` を渡す。塗り + 件数バッジの前景 / 背景を `tint` に連動
- **「保存済み」強調と排他**: 片方 ON でもう片方を OFF（両立させると減光対象が曖昧になるため）。減光は 4 種ピン（訪問済み / 保存済み / 検索結果 / Apple 周辺）すべてに `recommendedEmphasisActive` 分岐を追加。`recommendedCafes` が 0 件化したら強調 / シートを `onChange` でリセット
- **一覧行の推薦理由は 1 行サマリ**（例「産地・焙煎度が好みに一致」、軸名の重複除去列挙）に留め、詳細（一致ラベル・代表記録・評価）はピンタップの `RecommendationMatchSheet` に譲る。軸名ラベルはトップレベル関数 `preferenceMatchAxisLabel` に共通化（**注: `RecommendationMatchSheet` は 2026-08-07 に廃止**。詳細の置き場はカフェ詳細の「好み一致」セクションへ移設し、`preferenceMatchAxisLabel` は `Components/PreferenceMatchViews.swift` へ移動した。1 行サマリに留める方針自体は不変）
- **`TagLegendChip` は production 未使用化したが削除見送り**: 凡例という用途自体は汎用のため部品は残置（ui-ux-guidelines に未使用の旨と削除条件を記載済み）
- 好み一致ピンは強調中もサイズ据え置き（保存済みピンの 34→38pt 拡大パターンには追随せず。要望が出たら検討）

### 2026-07-16: コーヒー記録の削除動線 3 種（詳細削除は isDeleted フラグで pop 通知）

- 関連: `shared/feature/coffee-detail/.../CoffeeDetailViewModel.kt`, `iosApp/iosApp/Features/CoffeeDetail/**`, `iosApp/iosApp/Features/CoffeeList/CoffeeListView.swift`

削除動線を 3 種に整備（要件 2-3）: 既存のリストスワイプ（確認なし即削除、無変更）+ 新規のリスト長押し contextMenu（編集 + 削除）+ 詳細右上 Menu の削除。**確認ダイアログは詳細・長押しのみ**（スワイプ即削除は据え置き。メール系アプリと同じ操作感、ユーザー決定）。Undo なし。

- **詳細からの削除成功は `UIState.isDeleted` フラグで通知し、View が `.onChange` + `dismiss()` で pop**。`coffee == null` を pop トリガーにしない理由: (a) 他画面・リモート同期由来の削除では従来どおり「見つかりません」表示を維持する仕様のため（自己操作と外部要因の削除を区別）、(b) onAppear 直後の「未ロード null」との race 回避。pop までの一瞬に「見つかりません」が出ないよう `content` 分岐先頭に `isDeleted → ProgressView` を追加
- **userId の取得は `onAppear(coffeeId, userId)` の引数拡張**（CoffeeListViewModel と同型の「onAppear で受けて保持 + 未確定時は黙殺」パターン）。不採用: コンストラクタ注入（ファクトリ変更が波及）/ AuthRepository 注入（feature VM で前例なし）
- **写真物理削除は詳細 Bridge に独立実装**（リスト Bridge の pending 辞書方式は sections 監視というリスト固有形のため共通化せず）。「KMP 削除成功を確認してから `PhotoFileStore.delete`」の安全順序は両者同一。対象 1 レコードなので `pendingPhotoFileNames` 1 本で足りる
- 専用 UseCase は作らず `CoffeeRepository.delete(userId, id)` を VM 直呼び（本プロジェクトの既存設計に準拠）。リスト長押し削除の確定時も既存 `onCoffeeDeleted(id:photoFileNames:)` を再利用（KMP 無変更）

### 2026-07-16: 分析タブ「あなたの傾向」のタブ再表示時の再生成抑止

- 関連: `shared/feature/analysis/.../AnalysisViewModel.kt`

ユーザー報告「分析タブに遷移するたびに『あなたの傾向』が再計算される。アプリ利用中は保持したい」への対応。原因は `onAppear()` が無条件に `observeJob` を cancel → 再購読し、Flow の再 emit で Foundation Models 要約が毎回再生成されていたこと。VM は `AppState` 保持のタブ常駐でアプリ生存期間ずっと生きているため、購読を張り直す必要が元々ない。

- **修正は commonMain の 2 ガードのみ**: ① `onAppear()` は `observeJob` が active なら no-op（購読はタブ非表示中も継続し、記録変更は従来どおり反映）② 直前と構造等価な `CoffeeStats` の再 emit では `launchInsightGeneration` をスキップ（SQLDelight query invalidation の同値再 emit への保険）。記録の追加・変更時は stats が変わるので従来どおり再生成される。不採用: 生成済み insight のディスク永続化（アプリ利用中の保持で要件を満たすため過剰）
- **トレードオフ**: 同値判定は `CoffeeStats`（ネスト含め全 data class）の構造等価 `==` に依存。将来 non-data な参照型フィールドを足すと判定が壊れる点に留意
- **テストの罠（kmp-engineer 報告）**: `StandardTestDispatcher` 上で Flow が同一コルーチンから連続 emit すると、先行 collect で launch した `insightJob` が未実行のまま次の collect の cancel に巻き込まれ `summarize` が 1 度も走らないことがある。テスト側は emit 間に `delay` を挟んで仮想時間を進めて回避（`AnalysisViewModelInsightRegenerationTest`）。他画面横断の `onAppear` は点検済みで、引数で対象が変わる画面単位 VM（coffee-list / coffee-detail / coffee-editor）は cancel-and-relaunch が正しく今回の対象外

### 2026-07-16: 記録・分析タブの広告撤去（11-3 の一度撤去）

- 関連: `iosApp/iosApp/Features/CoffeeList/CoffeeListView.swift`, `iosApp/iosApp/Features/Analysis/AnalysisView.swift`, `iosApp/iosApp/Ads/`

ユーザビリティレビュー（2026-07-16）で「個人の記録・振り返り画面（定着の核）のバナーは、定着が命の初期にリテンションを削る割に収益が小さい（日本のバナー eCPM × 小規模 MAU では月数百円規模）」と判断し、requirements §11-3 の 2 面（記録タブ = リスト先頭インライン / 分析タブ = 下部固定）を撤去。カフェ詳細 / マップ検索ドロップダウンの 2 面と ATT フロー（残存面の NPA 判定に必要）は維持。

- **「一度撤去」= 恒久廃止ではない**: 定着後の再導入余地は残す。`AnchoredBannerAdView`（分析タブ専用だった）はファイルごと削除したが git 履歴から復元可能。共通基盤（`BannerAdLoader` / `InlineBannerAdView` / `BannerViewRepresentable`）は残存 2 面が使うため健在で、再導入コストは低い
- ユニット ID の定義（`AdUnitIDs.swift` / `Base.xcconfig` / `Info.plist`）も 2 面分を削除し、AdMob 本番ユニット発行タスクは 4 → 2 に縮小。`Secrets.xcconfig` は親セッションから読み取り不可（本番ユニット未発行のため該当キーは無い見込み。ユーザー確認推奨）
- 収益化の方向性は「まず定着 → 熱量の高い層への課金（広告非表示 / 写真クラウド同期等のプレミアム）」への転換を検討中。requirements §11 の「広告非表示 IAP は見据えない」（2026-07-14）は将来見直し候補

### 2026-07-16: 共有カード画像生成（2-12）の設計判断

- 関連: `iosApp/iosApp/Features/CoffeeDetail/ShareCard/`

ユーザビリティレビュー「外向きの成長回路がゼロ」への対応第 1 弾。記録詳細のツールバー共有アイコン → プレビューシート → `ShareLink` で 4:5（1080×1350px）カード画像を共有する。

- **可変レイアウト 1 テンプレート**: 写真 / レーダー / 評価は「あれば載せる」。テンプレートを複数持たず、欠けた要素の余白は Spacer で再配分（写真なし・テイスティングなし・未評価・セルフ抽出の全組み合わせで成立）。不採用: 写真主役 / レーダー主役の専用テンプレート（データが欠ける記録で導線ごと消えるため）
- **メモ・タグは載せない**: notes は日記的内容の誤共有リスク。共有前にプレビューシートで内容を目視確認させる（外向き送信の確認原則）
- **ライトテーマ固定**（`.environment(\.colorScheme, .light)`）: SNS 上での見た目を端末テーマ非依存に。ui-ux-guidelines のダークモード方針の意図的例外（カードは「アプリ画面」ではなく「出力物」）
- **レンダリングは ImageRenderer（scale 3）+ 一時 PNG + `ShareLink(item: url)`**: SettingsView の JSON エクスポートと同型。`Transferable` 自作はしない（前例なし・URL ベースで足りる）
- 全要素が揃うケースではレーダーが scaleEffect 約 0.5 まで縮む（ios-engineer メモリに計算根拠）。可読性 NG ならシミュレータ確認後に写真帯縮小 / チップ行削減で再配分

### 2026-07-16: 共有カードの RoastLevel ローカライズは CoffeeDetailView 本体と非対称

- 関連: `iosApp/iosApp/Features/CoffeeDetail/ShareCard/CoffeeShareCardView.swift`

共有カードは roastLevel を日本語ローカライズ（AnalysisView 等 3 箇所に既存の辞書と同実装を複製）して表示するが、`CoffeeDetailView` 本体の Form と `CoffeeEditorView` の Picker は raw Kotlin enum 名（例 "Medium"）のまま。外部共有物としての体裁を優先しカード側だけ先行対応した（ios-engineer 判断を親が追認）。`ProcessingMethod` は全画面でローカライズ未実装（カードの属性チップは産地 / 焙煎度 / 抽出方法の 3 種で対象外のため実害なし）。

- 影響: app 全体の roastLevel / processing 表示ローカライズの統一（+ 辞書 4 箇所の一元化）は別タスク。必要になったら設計判断バックログへ起票

### 2026-07-17: CuratedCafe の Firestore Mapper は「1 ドキュメント → List」で BeanProfile 型と非対称

- 関連: `shared/data-firebase/src/androidMain/.../CuratedCafeFirestoreMapper.kt`、data-model.md §1.10 / §3.2

フェーズ 19 の `curatedCafes` は「1 都道府県 = 1 ドキュメント + カフェ埋め込み配列」（読み取り最大 47 reads/起動に抑えるスキーマ）のため、Mapper は BeanProfile の「1 ドキュメント → 1 エンティティ」ではなく `fromDocument(data): List<CuratedCafe>` を返す形にした（kmp-engineer 実装を親が追認）。

- ドキュメント直下の `prefectureCode` 欠如時は**ドキュメント全体を空リスト扱い**（部分的に有効な `cafes` があっても県コード抜きでは domain モデルを構成できない）。`cafes` 配列の要素単位では必須フィールド欠落を mapNotNull で skip
- 座標は Firestore の数値型ゆれ（Long/Double）を `Number.toDouble()` で吸収
- ロード失敗時は `MapViewModel` がサイレントに空のまま（`error` に流さない）。おすすめピンは付加情報でありマップ本体の動作を阻害しない、という表示方針とセット

### 2026-07-18: curated ピンの色とズームゲート改訂（フェーズ 19 追加調整）

- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`、ui-ux-guidelines.md 色セマンティクス表

ユーザーのシミュレータ確認フィードバック 2 件による改訂。

- **色**: star 意匠廃止時に採用した burnt orange（`orange.mix(black, 0.25)`）が訪問済みピン（accentColor #8B5A2B 茶）と誤認されたため、**素の `Color.orange`** に変更。彩度・色相とも茶と明確に離れ、ライト/ダーク両対応（システムカラーのため）
- **ズームゲート**: 常時表示だと引きの地図で東京 157 本が煩雑なため、**Apple 周辺ピンの `applePoiZoomGateRadiusMeters`（可視半径 3000m）をそのまま再利用**して `displayedCuratedCafes` でフィルタ。ズームイン時のみ表示（Google Maps の POI 間引きと同じ挙動）。しきい値は新設せず 1 定数を 2 用途で共有 — **将来この値を変えると Apple 周辺 fetch と curated 表示の両方が連動する**点に注意
- `existingPinCoordinates`（Apple 周辺ピンとの 40m 近接排除）は意図的にゲート非依存で全 curated 座標を参照するが、curated 非表示のズーム域では Apple 周辺 fetch 自体も走らないため実害なし（ios-engineer 確認済み）
- 副次効果: ズームゲートにより「47 県フル展開時の Annotation 数」将来課題（data-model.md §1.10）の描画負荷面は実質解消。UIState には全件保持のままなのでメモリ面のみ残課題

### 2026-07-18: 周辺カフェピンは MKLocalSearch スロットリング時に直前の結果を保持

- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`（`fetchAppleNearbyCafes`）、tasks.md「周辺カフェピンのスロットリング耐性（2026-07-18 起票）」

長時間のパン・ズームで `MKLocalSearch` が Apple 側にスロットリングされると（`MKError.loadingThrottled`、閾値は非公開）、従来の catch は一律 `appleNearbyCafes = []` でクリアするため周辺カフェピンが一斉に消えていた（ユーザー報告: 「しばらく使うと POI が表示されないことが 1 回だけあった」）。

- 対応: catch で `mkError.code == .loadingThrottled` のときのみ early return し既存ピンを保持。それ以外のエラー（ネットワーク断等）は従来どおりクリア。理由: スロットリングは一時的で次の fetch（カメラ移動 + 300ms デバウンス後）で回復するため、空白より古いピンを残す方が自然
- トースト等のユーザー通知は出さない方針を維持（低優先の補助表示のため）
- `MKLocalSearch` の利用箇所はこの 1 関数のみで同型箇所なし（ios-engineer が grep 確認）。なお MapKit の地図表示自体（タイル / 標準 POI ラベル）にはネイティブアプリの利用制限はなく、制限があるのは検索系 API のみ
- Swift の `MKError.loadingThrottled` は `MKError.Code` を返す（`as? MKError` 直接比較はコンパイルエラー）— 詳細は ios-engineer メモリ `location-mapkit.md`

### 2026-07-20: リリース CI の署名は p8（ASC API キー）のみを維持、p12 証明書の永続化は不採用

- 関連: `.github/workflows/release-testflight.yml`、`docs/tasks/lessons.md` 2026-07-20 エントリ

`release-testflight.yml` の archive が証明書上限エラーで失敗した件（詳細な誤診断の経緯は lessons.md 参照）を developer.apple.com 側での証明書 revoke で解消した後、恒久対策として certificate + 秘密鍵を p12 化して GitHub Secrets に永続化する案を提示したが、ユーザーは「p8 のままで」と判断し不採用。

- 経緯: cloud signing（Automatic signing + ASC API キー）は署名用の秘密鍵をランナーに保持しないため、GitHub-hosted の使い捨てランナーでは実行のたびに新規の Development 証明書 + 鍵ペアを発行する。これがアカウントの証明書上限到達の直接原因
- トレードオフ: p8 のみを維持する場合、証明書はいずれ再び上限に達し得る。発生時は developer.apple.com で不要な Development 証明書を手動 revoke する運用が必要（p12 永続化なら鍵を使い回すためこの再発自体を防げるが、Apple ID を使った手元でのキー作成・エクスポート作業が追加で必要になる）
- 判断: リリース頻度が高くない前提で、追加の秘密情報管理（p12 の作成・ローテーション・Secrets 管理）を避け、上限到達時の手動 revoke で対応する運用を選択

### 2026-07-20: 好み一致に精製方法軸を追加（3→4 軸）+ ダミーデータ人格再設計

- 関連: `FavoriteSignals` / `PreferenceMatchAxis` / `ObserveTasteMatchedCafesUseCase` / `BuildCoffeeStatsUseCase` / `DummyCoffeeData`、`AnalysisView.swift`（好みの傾向カード）、`MapTabView.swift`、analysis-model.md §1/§2、tasks.md「好み一致の作り込み（2026-07-20 起票）」

「好み一致」（`RecommendedCafe`）のマッチ軸を **産地 / 焙煎度 / 抽出方法の 3 軸 → + 精製方法の 4 軸**に拡張。あわせて開発用ダミーデータを人格中心に再設計した。

- **なぜテイスティングを外し精製方法を選んだか**: ユーザーは当初「マッチ軸を増やす」を選択。テイスティング 5 要素は `dominantTastingAxis`（評価との相関）として集計済みだが、これは連続値の相関であり「この 1 杯がその軸に一致」という per-record の categorical 一致に変換できない（理由表示も曖昧になる）。一方、精製方法は既存 3 軸と**完全対称**（`selectBestCategory` の再利用のみ・新定数なし）で低リスク。よって今回は精製方法のみ採用、テイスティング軸一致は別途とした。
- **なぜダミーを「焙煎度しか一致しない」状態から人格再設計したか**: 旧ダミー 30 件は「全グラフが映えるよう全 enum に分散」設計で、好み信号が立つ条件（特定カテゴリへの高評価集中）と逆方向。実測 `globalMean=4.0 / globalStd≈0.58` で 2σ の z ゲート（`CATEGORY_Z=2.0`）に産地・抽出が届かず、Light 焙煎だけが信号化していた（ユーザー観測の真因）。ゲートは B-1d の winner's curse 対策で意図的に厳しく、緩めると偽陽性が戻るため**データ側で解決**した。
- **人格の選定（grilling で確定）**: 王道の喫茶店ブレンド像 = 産地ブラジル（信号勝ち）/ 焙煎 City / 抽出 NelDrip / 精製 Natural。`FavoriteSignals.bestOrigin` は**単一勝者しか出せない**制約があるため、ユーザーの「ケニア・ブラジル両方好き」からブラジルを勝たせ、ケニアは高評価だが件数・集中度で負ける「二番手」として配置。
- **デモ設計のトレードオフ**: 好みクラスタ 6 件（ブラジル × City × NelDrip × Natural を同一レコードに同居、rating 4.5〜5.0）を cafe1/2/3 に 2 件ずつ分散。1 レコードで 4 軸すべてを兼ねるため、**3 カフェすべてが 4 軸完全一致ピン**になる。「1 カフェだけ完全一致」よりデモ映えを優先した（`DummyCoffeeDataPersonaTest` で 4 軸信号化 + 4 軸一致カフェ ≥1 を固定 = 将来ダミーを触っても demo が壊れない）。
- **横断点検で拾った回帰**: `AnalysisViewModel.FavoriteSignals.hasAnySignal()`（分析空状態の readiness 判定）が `bestProcessing` を見落とすと「精製のみ信号あり」の場合に「データ不足」表示のまま固まる。kmp-engineer が grep 点検で発見・修正（他の `best*` 列挙箇所に見落としなしを確認）。
- **iOS 側の bridge 注意点**: SKIE はデフォルト引数を Swift に出さないため、`FavoriteSignals` に `bestProcessing` を足すと Swift の init が必須引数化し既存の構築 2 箇所がコンパイルエラーになる（`AnalysisView` プレビュー + `PreviewSamples`）。SKIE 生成 enum に `.processing` が乗るため網羅 switch（`preferenceMatchAxisLabel` / `axisIcon`）も追随必須。精製方法はアプリ内で enum 名を素表示（ローカライズ辞書は分析カードのみ）で、マップ理由表示は既存の焙煎度と同じ扱い。軸アイコンは `leaf.fill`。
- **残課題（別タスク）**: `CoffeeStats.byProcessing`（精製方法別集計）は既存だが分析タブに棒グラフ表示がない（ios-engineer の申し送り）。要件で求められれば別 dispatch。

### 2026-07-21: マップタブに現在地ブルードット表示を追加（`UserAnnotation`）

- 関連: `MapTabView.swift`（`mapContent`）、Info.plist `NSLocationWhenInUseUsageDescription`、`docs/app-store-metadata.md`（プライバシー申告・審査ノート）

マップタブで位置情報許可 ON のとき、ユーザー自身の現在地を標準ブルードット（ヘディング付き）で表示するようにした。`Map { }` コンテンツ先頭に `UserAnnotation()` を追加し、`locationManager.authorizationStatus` が `.authorizedWhenInUse` / `.authorizedAlways` のときのみ描画する条件でゲートする。

- **既存の現在地 FAB とは独立**: FAB（`currentLocationFAB` / `recenterToCurrentLocation`）は「現在地へセンタリング + ズームリセット」の役割で、`LocationManager` のワンショット取得を使う。ブルードットは MapKit が内部で位置を自前管理するため、周辺カフェ検索（`setupLocation` のワンショット）への副作用はない。`MapUserLocationButton` への置き換えはしていない。
- **権限文言の追随**: ブルードットは地図表示中は継続表示のため、旧文言「検索時のみ / 一時的に使用」は実態と食い違う（挙動は依然 when-in-use / フォアグラウンドのみ、バックグラウンド常時取得はしない）。Info.plist の usage description を「近くのカフェの検索と、地図上での現在地表示のために現在地を使用します。」に、app-store-metadata の申告・審査ノートを「カフェ検索と地図上の現在地表示に使用 / バックグラウンド常時取得はしない」に更新した（ユーザー確定）。

### 2026-07-21: カフェ検索の補完語を「カフェ」→「コーヒー」に変更

- 関連: `PlacesClientImpl.ensureCafeKeyword` / `PlacesClientImplSearchTextKeywordTest`、tasks.md「カフェ検索の補完語を…（2026-07-21 起票）」

カフェ検索タブ（位置バイアスなし `searchText(query)`）で味覚語「フルーティー」を入れるとパフェ等のデザート店がヒットする問題に対し、`ensureCafeKeyword` がカフェ語を含まないクエリへ補完する語を「 カフェ」→「 コーヒー」に置換した。

- **なぜ語の追加ではなく置換か**: 「カフェ」は `includedType=cafe` の業態を満たすだけでテキストのランキングをコーヒー方向へ寄せない。Google Places の searchText は全語を加味してランクするため、「フルーティー コーヒー」はコーヒーがフルーティーな店へ寄り、デザート専門店を弱められる。「フルーティー コーヒー カフェ」と 2 語足すよりノイズが少なく、地名のみ問題（例:「渋谷」→ locality 型で 0 件）も「渋谷 コーヒー」で同様に解決する（ユーザー確定）。
- **据え置いたもの**: `includedType=cafe`(業態フィルタ)、`CAFE_KEYWORDS`(補完スキップ判定語。「カフェ」も残し、既に「渋谷 カフェ」等と入れたクエリには補完しない既存挙動を維持)、`searchText(query, locationBias)`(POI タップ経路。補完なし)、`searchByNameNear`。
- **トレードオフ**: コーヒーアプリの前提で全キーワード検索がコーヒー方向へ寄るため、紅茶主体のカフェはわずかに出にくくなる（許容）。`includedType=cafe` は維持のため、cafe 型でない純喫茶チェーン等は依然フィルタされ得る（今回スコープ外）。
- 検証: `:shared:data-places:testAndroidHostTest` + `iosSimulatorArm64Test`（親が override 無しで実行）ともに green。

### 2026-07-21: 9-6 協調フィルタリング推薦の設計確定（grilling で 6 意思決定）

- 関連: requirements 9-6（✕→△）・analysis-model §2・data-model §3.2 / §3.3・tasks 12-D・2026-06-22 Future Direction エントリの具体化

ユーザー要望「9-6 を進める」に対し、リリース前・ユーザーベース皆無（コールドスタート直撃）を踏まえ**今回は設計を docs に固定するところまで**とし、grilling で 6 つの意思決定を確定した。実装コードは書いていない。

- **①同意はフラグを分離（新規 `recommendationConsent`）**: 既存 `analyticsConsent` は「Firebase Analytics 集計」に紐づく App Privacy 申告。協調フィルタは「味覚プロファイルを他ユーザーへの推薦材料として共有」で**目的が異なる** → 目的別同意が原則（申告が濁らない）。既定 false・オプトイン。
- **②計算は Cloud Function 特権 read に閉じる**: 横断参照をクライアントに晒すと他人のプロファイルが見える。Function が Admin 特権で全 `sharedTasteProfiles` を read し、呼び出しユーザーへ「推薦カフェ + 似ているユーザー数」だけ返す。Firestore ネイティブ KNN をクライアント直クエリする案は近傍ドキュメントがクライアントに返るためプライバシー後退で不採用。
- **③特徴ベクトルは 5 軸 cosine + カテゴリ 4 軸補助**: docs 既定「`tastingAverages` 5 軸が基盤」を主軸にしつつ、tasting は任意入力で未入力ユーザーが 5 軸 null になり母集団が痩せるため、カテゴリ好み 4 軸を fallback + 精度シグナルに加味。
- **④推薦対象は未訪問 + 地理制約**: 9-5（既訪問の再訪・ローカル）と役割分担。callable に中心座標+半径を渡し、地球の裏側の無意味推薦を防ぐ。地理制約のため共有プロファイルの `highRatedCafes` に座標を持たせる。
- **⑤マップは型拡張で同型・視覚区別**: analysis-model §2 予告どおり `RecommendationReason.SimilarUsers(count)` を追加（UI/VM は加算的）。ただし 9-6 は未訪問なので 9-5 のハートピン（訪問済み）と視覚区別する。
- **⑥共有プロファイル `sharedTasteProfiles/{uid}`**: 特徴ベクトルのみ（生メモ・タグ・カフェ名は含めない）。本人のみ read/write、横断 read は Function 特権（Security Rules に追加）。

未決（docs に明記）: 閾値定数（K/N/半径）は実装時 sweep / Function 内の類似計算（総当たり cosine vs Firestore ネイティブベクトル KNN。初期は総当たりで十分の想定）/ サーバーインフラ選定（Cloud Functions ランタイム・デプロイ・CI = 12-D 再開の起点）/ FM 言語化を v1 に含めるか。最初の実装可能な一歩は①同意 + 共有プロファイル書き込み基盤（サーバー不要・クライアント完結）。

### 2026-07-22: マップ検索結果を「マップ主体 + 下部ドラッグシート」に刷新

**背景**: ユーザーの不満「検索結果のカフェ位置をマップ上に表示したい」。位置表示（青ピン）自体は既存だが、(1) テキスト検索後にカメラが結果へフィットせず結果が画面外に落ちる、(2) 結果一覧が検索バー直下の上部ドロップダウン（最大 300pt）としてマップ（=位置）を隠す、の 2 点で「位置が見えない」体感になっていた。目指す形は AskUserQuestion で「マップ主体 + 下部ドラッグシート一覧（Apple/Google 風）、一覧はピンと併存」に確定。

**採用した設計判断（トレードオフ）**:
- **native `.sheet` を避け自前オーバーレイ**: 検索モード中は ✨ `TasteSearchSheet` が併存し得るため、結果一覧を native `.sheet` にすると同一 View に 2 枚目の `.sheet` を出して競合する。よって 2 detent（peek/expanded）を `DragGesture` + スナップで実装する自前下部オーバーレイを採用。背後マップは常時操作可能。
- **選択カードはシートに畳み込まず排他表示**: 既存 `cafeSelectionCard` の作り込み（写真/営業/評価/価格/杯数/詳細・保存）を再利用するため、結果シートと選択カードを下部で排他（未選択=シート / 選択=カード）にして重なりを回避。改修範囲を最小化。
- **カメラ自動フィットはテキスト検索のみ**: 「このエリアを検索」は表示範囲内検索で結果が構造的に画面内のため自動フィットすると逆に不自然。テキスト検索（位置バイアス付きで画面外落ちがある）だけ全結果ピンの bounding box に寄せる。
- **選択ピン強調を追加**: 選択中の検索結果ピンを scale 1.3 + 影で強調。色は既存 `Color.blue` を維持（色セマンティクス表は増やさない）。

**影響範囲**: iosApp `MapTabView.swift` のみ（KMP 変更なし。`searchResultPlaces` / `searchBridge.results` を流用）。§11-2 広告は上部ドロップダウン → 下部シート内へ提示先が移動（3 件目後・3 件未満非表示の配置ルールは不変）。requirements §11-2 / §5 マップ行・ui-ux-guidelines・app-store-metadata の「ドロップダウン」表記を同時改訂。

### 2026-07-22: 産地を国ドロップダウン + 任意エリアに分離（記録の手間削減）

- 関連: `shared/domain/.../CoffeeOriginCatalog.kt`（新規）/ `OriginNormalizer.kt` / `CoffeeRecord`（`region` 追加）/ `CoffeeEditorView.swift`

**背景**: ユーザー要望「コーヒー記録の手間を減らしたい。産地はドロップダウン形式（国名を選択）にする」。産地は従来 `String?` の自由入力 + `BeanProfile` ファジーサジェストだったが、都度タイプする摩擦があった。

**確定した設計（AskUserQuestion で 3 点確定）**:
- **国 + 任意エリアの 2 フィールド化**: `origin`（国名）を `CoffeeOriginCatalog`（コーヒー生産国 ~43 か国 + 「ブレンド」/「その他」）からのドロップダウン選択に。粒度（イルガチェフェ等）は新フィールド `region`（エリア/農園・任意自由入力）で保持。
- **国リストはコーヒー生産国を厳選**（全世界 ~200 か国は選択が遅くなるため不採用）。
- **特殊項目「ブレンド」+「その他」**の両方を用意。

**トレードオフ / 設計判断**:
- **origin は `String?` のまま（enum 化しない）**: 「ブレンド」「その他で入力した実国名」「null」「legacy 自由文字列」を型で表現でき、`OriginNormalizer` / `BeanProfile` 突合 / `originRanking`（全て String ベース）を無改修で流用できる（Simplicity First）。enum 化は data-model / SQLDelight / Firestore / 分析へ広く波及するため不採用。
- **カタログの真実点は domain**（iOS はブリッジ経由で読む）。`OriginNormalizer` のシノニム値 ⊇ 関係をテストで担保し、正規化とカタログのカバレッジずれを防ぐ。新規追加国には英語綴りシノニムも追加。
- **「その他」は実国名を保存**（literal「その他」を保存しない）。データ欠損回避。「ブレンド」は単一国でないため literal 保存。
- **`region` は分析非対象（表示専用）**: サブ地域粒度は交絡分離不能で統計に使えない（§1.6 confounding 方針）。`originRanking` / `FavoriteSignals` は従来どおり国のみ。
- **BeanProfile 産地サジェストは撤去**: 国がピッカーで制約されサジェスト不要に。品種サジェストは今回スコープ外（据え置き）。

**影響範囲**: domain（`CoffeeRecord.region` / `CoffeeOriginCatalog` / `OriginNormalizer` 拡張）/ data-local（migration 6 で `region` 列 + upsert + Mapper）/ data-firebase（Firestore `region` キー、null 省略）/ feature-coffee-editor（`CoffeeDraft.region` / `onRegionChanged` / build/toDraft/toDuplicate）/ `DummyCoffeeData`（混在産地を国 + エリアに分割）/ iOS（エディタ UI = 国 Menu + エリア TextField、詳細 / シェアカードの産地表示に region 連結）。未リリースのためクリーンブレイク（ユーザーデータ移行なし）。

### 2026-07-22: 広告 no-fill 診断 — デモユニットの "No fill" は Google 側抑制（コード無問題）

- 関連: `iosApp/iosApp/Features/Settings/SettingsView.swift`（DEBUG 限定 Ad Inspector 導線を追加。commit 514acaf）/ `iosApp/iosApp/Ads/*`

**背景**: ユーザー報告「カフェ詳細・マップ検索の 2 面で 3 日ほど前から広告が出ない（`Error Domain=com.google.admob Code=1 "No ad to show."`）」。冒頭に出る `49 required SKAdNetwork identifier(s) missing` は無関係の警告。

**切り分けの結論（コード・設定に問題なし）**:
- `Code=1` は AdMob の no-fill（サーバー応答）。設定エラー(Code=0)/ネットワーク(Code=2)ではない。
- 使用 ID は全て Google 公式 iOS **デモ** ID（App ID `...~1458002511` / バナー `.../2435281174` = iOS のインライン/アンカー両アダプティブ用の正しいテスト ID）。`Secrets.xcconfig` でも**本番未上書き**（ユーザー確認）＝**アカウント非依存**。
- 広告リクエスト経路（`BannerAdLoader` / `iOSApp.swift` の `MobileAds.shared.start()` / `Base.xcconfig` の ID / SDK v13.6.0）は直近1週間**無変更**（git log で確認）。
- 症状は**シミュレータ・実機の両方**で**3日間継続**。→ 短時間レート制限では説明が弱い。
- **Ad Inspector（本コミットで DEBUG 導線を追加）で対象ユニットが `No fill` と確定**。

**判断**: 開発中の過剰トラフィックによる **Google 側のデモ広告抑制**が原因。端末/IP 単位で数日〜2週間ほど続き自然回復する既知挙動。**コード修正は不要**。本番は実 App ID + 実広告ユニット（`Secrets.xcconfig`、リリース前にユーザーが発行）で配信するため影響しない。

**再発時の初動**: 設定 → デバッグ → 「Ad Inspector を開く」（シミュレータは自動テストデバイス登録）で `No fill` を確認できればコード側は無罪。実機で開くにはコンソールの `testDeviceIdentifiers` 登録が別途必要。

### 2026-07-24: マップ「好み一致」/「保存済み」チップを一覧パネルに一本化（操作モデル改修）

- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`。2026-07-16「好み一致チップのタップ対応」/ フェーズ 15-A・16「保存済み強調」の操作モデルを差し替え

**背景**: ユーザー報告「好み一致タグはタップで一覧が出てマップ強調されるが、再度リストを出すには一度 OFF にしてから再タップが必要で直感的でない」。旧実装はチップが「強調（他ピン減光）」と「一覧ハーフシート」を兼務し、内部で 2 状態（`*EmphasisActive` + `isPresenting*Sheet`）を持っていた。ON 中の再タップは強調 OFF のみで一覧を再表示せず、一覧を下スワイプで閉じた後（強調は ON のまま残存）に一覧へ戻るのに 2 タップ要していた。

**確定した設計（AskUserQuestion で 2 点確定）— 好み一致・保存済み両方に適用**:
- **チップ = 一覧パネルを開くアクションに一本化**。タップは常に一覧シートを開く（既に開いていれば no-op、トグル OFF はしない）。1 タップで必ず一覧が再表示される。
- **マップ強調はシート表示中だけ ON に連動**。シートを下スワイプで閉じる＝強調も自動 OFF。「地図全体を強調したまま眺める（シートなし）」状態は廃止（好み一致ピンは元々ピンク♥で判別可能なため、強調はシート ↔ マップの相関用途に限定してよいと判断）。
- チップの `isOn`（ハイライト）＝該当シート表示中。好み一致 / 保存済みは排他。

**実装判断 / トレードオフ**:
- **強調 State を独立に持たず、単一 item state に集約**。`recommendedEmphasisActive` / `savedEmphasisActive` / `isPresenting*Sheet` の 4 `@State` を廃し、`@State activeCafeListSheet: CafeListSheetKind?`（`.recommended` / `.saved`）1 本へ。強調は `activeCafeListSheet == .recommended/.saved` の **computed property** として同名で残し、多数の opacity / size 計算箇所を無改修に保った（Minimal Impact）。
- **2 本の `.sheet(isPresented:)` を 1 本の `.sheet(item:)` に統合**したのが肝。(1) 排他性が構造的に保証され、medium detent でチップが見える状態からの相互切り替えでも二重表示バグが起きない。(2) スワイプ dismiss 時に item が自動で nil に戻る＝「シートを閉じる＝強調 OFF」を SwiftUI 標準機能でそのまま実現（追加ガード不要）。(3) 同一 item の再代入は再アニメーションなし＝「既に開いていれば no-op」も標準挙動で満たす。
- 好み一致ピンタップの推薦理由シート（`selectedRecommendedCafe` / `RecommendationMatchSheet`）は対象外・無変更（別系統の独立 `.sheet`）。**注: この独立 `.sheet` は 2026-08-07 に State ごと廃止**（ピンタップはカフェ詳細へ直行に変更）。本項の「1 本の `.sheet(item:)` に統合」は一覧シート 2 種の話で、そちらは現存する。
- **状態を KMP UIState に置かない方針は不変**（[implementation_note 2026-07-16 / フェーズ 15-A 参照]）。強調はドメインロジックゼロの純プレゼンテーションで、必要な placeId 集合は `recommendedCafes` / `savedCafes`（UIState）に既にある。旧 `@State savedEmphasisActive` の記述は本改修で computed property 化（Swift ローカルである点は不変）。

**影響範囲**: `MapTabView.swift` のみ。ビルド成功確認済み（`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 不使用）。UI 挙動（1 タップ再表示 / 下スワイプで強調 OFF / 両チップ排他 / medium detent 併存 / 選択 push 時のクローズ）はシミュレータ実地確認が必要。

### 2026-07-24: MapTabView 分割リファクタ Phase 1（M-1）— 検索結果シートの高さ結合の扱い

- 関連: `MapTabView` 分割リファクタ（tasks.md M-0〜M-4）。M-1 でリーフ View 5 ファイルを抽出（`MapPins` / `CafeSelectionCard` / `MapFilterChipRow` / `MapSearchResultsSheet` / `MapTabView+PinResolution`）。MapTabView.swift 2008→1223 行

**論点（Phase 3 への申し送り）**: 検索結果下部ドラッグシートを `MapSearchResultsSheet` へ切り出す際、detent 状態（`searchSheetDetent` / `searchSheetDragTranslation`）とサイズ計算（`searchSheetCurrentHeight` 等）を **`MapTabView` 側に残した**（シート View へ完全移譲しなかった）。

**理由**: `searchSheetCurrentHeight` は現在地 FAB のボトムインセット（`searchSheetFABBottomInset`）でも参照される二重消費値。シート側へ状態を移すと親が現在高さを知れず、高さ変化を親へ逆流させるコールバックが要り複雑化する。SwiftUI の一方向データフローに沿い、**共通の親に状態を残し、子へは算出済み高さ（`let`）と `detent`/`dragTranslation` の `@Binding` を down-flow** で渡す構成にした。

**Phase 3 での扱い**: 検索系 State を `@Observable MapSearchController` へ隔離する際、この detent/高さ状態も controller へ移すか親に残すかを再判断する。FAB インセットとの二重消費が残るため、controller が高さを公開 → 親が FAB インセットに使う形なら移譲可能。M-1 時点では過剰設計を避け親残置とした（Simplicity First）。

**その他**: 別ファイルの `extension MapTabView`（`MapTabView+PinResolution`）へ移した競合解決メソッドと `applePoiZoomGateRadiusMeters` は、`private`（Swift ではファイルスコープ）だとアクセス不能になるため internal 化。モジュール外へは出ず公開 API 化のリスクなし。

### 2026-07-24: MapTabView 分割リファクタ Phase 3（M-3）— `@State` 保持クラスのコールバック事後配線

- 関連: `MapTabView` 分割リファクタ（tasks.md M-3）。検索 + エリア検索を `@MainActor @Observable final class MapSearchController` へ隔離。MapTabView.swift 1132→968 行

**論点**: `MapSearchController` は検索/エリア検索の data state とビジネスロジックを持つが、SwiftUI 固有の 2 要素は View に残し、コールバックで分離した:
- camera 移動（`fitCameraToSearchResults` / `selectResult` 内）→ `onRequestCamera: (MKCoordinateRegion) -> Void`。`withAnimation { cameraPosition = .region(region) }` は **View 側クロージャで実行**し、controller は `onRequestCamera(region)` を呼ぶだけ。
- キーボード解除（`clearSelection` / `selectResult` 内の `isSearchFieldFocused = false`）→ `onDismissKeyboard: () -> Void`。`@FocusState` は View 固有で controller に移せないため。

**配線タイミングの制約（Swift 言語仕様）**: `MapTabView` の `@State private var searchController` の**初期値式からは `self`（＝兄弟の `cameraPosition`/`isSearchFieldFocused`）を参照できない**（格納プロパティ初期化式は他プロパティに触れない）。そのため controller はプロパティ宣言時に **no-op クロージャで仮初期化**し、既存の `.task`（`searchBridge` を初回のみ生成する慣習）内で `configureCallbacks(onRequestCamera:onDismissKeyboard:)` を呼んで本物のクロージャへ差し替える。`.task` は初回マウント時 1 度だけ実行され、その時点で `self` は永続ストレージに結び付いているため安全（カスタム `init` で `_cameraPosition.projectedValue` を使う案は `@State` 確立タイミングの裏取りが困難でリスク大と判断し不採用）。

**appState 非依存**: `performSearch(center:)` / `performAreaSearch(center:)` / `handleCompletion(mapBridge:currentCenter:)` / `clearSelection(mapBridge:)` は `appState`/`mapSearchCenter` を引数で受け、controller を `appState` 非依存に保つ。`TextField` 双方向バインドは `searchBarView` 内の `@Bindable var searchController = searchController` ローカル宣言で対応（他箇所は読み書きのみで `@Bindable` 不要）。

**detent 残置**: 検索シート detent 状態・高さ計算は M-1 の申し送り（FAB インセットとの二重消費）を踏襲し View 残置。controller へは移さなかった。

### 2026-07-24: 「このエリアを検索」がキーワードを維持して再検索するよう変更

- 関連: requirements 5-5、フェーズ 14（implementation_note 2026-07-01）、MapTabView 分割リファクタ M-3

**背景**: 分割リファクタ M-0〜M-4 後の動作確認でユーザーが「検索ワード入力後、地図移動して『このエリアを検索』を押すとキーワードが入っていない」と報告。調査の結果、これは **M-3 リファクタで壊れたバグではなく元からの設計挙動**（`performAreaSearch` は M-3 前後で同一）。「このエリアを検索」はフェーズ 14 で `onNearbySearchRequested` → `searchNearby`（キーワード非依存の周辺一括表示）として実装されており、`CafeSearchViewModel` のコメントも「`UIState.query` とは独立」と明記していた。

**判断（ユーザー決定）**: 検索バーにキーワードを入れた状態で地図を動かすと「このエリアを検索」が出る導線のため、ユーザー期待（そのキーワードで再検索）と食い違う。**キーワードがあればそれを維持して表示範囲を再検索、空なら従来どおり周辺一括**に変更（AskUserQuestion で確定）。

**実装**: `performAreaSearch` で `query`（trim して空判定）が非空なら `onQueryChanged(query)` → `onSearchTapped(lat,lng,radius)`（= `searchText(query, bias)`）、空なら従来の `onNearbySearchRequested(lat,lng,radius)`。`isAreaSearchInFlight = true` は分岐前に立てるため、`handleCompletion` の `wasAreaSearch` 判定は両分岐とも true になり、完了時のアンカー更新・ボタン非表示・0件メッセージ・**カメラ自動フィット非対象**（表示範囲内検索で結果が構造的に画面内）の既存挙動がそのまま維持される。

**トレードオフ / 補足**:
- `onSearchTapped(lat,lng,radius)` は shared 側 `_state.value.query` を使うため、**未確定入力のまま地図移動されたケースに備え `onQueryChanged(query)` で先に最新化**する（`performSearch` と同じ順序）。これを省くと古い/空クエリで検索してしまう。
- 課金構造は不変（`searchText` も `searchNearby` も 1 リクエスト、手動ボタンで発火頻度は同じ）。→ [[paid-services]] 更新不要。
- ボタン文言は「このエリアを検索」のまま（キーワード有無でのラベル出し分けは今回スコープ外）。
- shared 変更なし（`onSearchTapped` の半径付きオーバーロードは既存）。

### 2026-07-24: エリア検索の表示範囲フィルタ（クライアント側）

- 関連: 直前の「このエリアを検索でキーワード維持」変更（同日）、requirements 5-5

**背景**: キーワード維持変更で「このエリアを検索」がキーワードあり時に `searchText(query, locationBias)` を呼ぶようになった結果、ユーザーから「範囲外のカフェも一覧に出る」報告。原因は **Places API の `locationBias` が範囲制限ではなく近傍ヒント**であること（遠方の同名店も返る）。Places の Text Search の `locationRestriction` は rectangle のみ対応でサーバー側厳密制限は shared 大改修になるため、**iOS クライアント側で表示範囲フィルタ**する方針を採用。

**実装**:
- `MapSearchController` に `displayedResults: [Cafe]`（一覧・ピンの単一ソース）と `areaSearchRegion: MKCoordinateRegion?`（エリア検索**実行時**にスナップした可視領域）を追加。`performAreaSearch(center:visibleRegion:)` で region を受け取りスナップ。
- `handleCompletion`: エリア検索由来のみ `filterResultsWithinAreaSearchRegion`（`region.center ± span/2` の矩形内・座標欠損は除外）を通し、`mapBridge.onSearchResultsUpdated` と 0 件メッセージ判定もフィルタ後の `displayedResults` 基準に。テキスト検索は全件維持（`fitCameraToSearchResults` も従来どおり `sb.results`）。
- `MapSearchResultsSheet` を `sb: CafeSearchViewModelBridge` 依存から `results: [Cafe]` + `isLoading: Bool` の受け取りに変更。呼び出し側が `displayedResults` を渡すことで、**ピンと一覧が別フィルタ結果を参照してズレる再発を構造的に防止**。

**トレードオフ**:
- **20 件上限の取りこぼし**: Places 1 応答上限 20 件のうち範囲外分をクライアントで捨てるため、範囲内に候補が 20 件超ある密集エリアでは表示件数が減る。`locationBias` で近傍が上位に来るため実用上は小さいと判断。厳密対応が要れば shared に rectangle `locationRestriction` 付き `searchText` を足す（[[paid-services]] 課金は不変）。
- 可視領域スナップは**検索実行時点**（完了時の最新 region ではない）。検索中にパンしても「押した瞬間の範囲」で絞る＝「このエリア」の意味に忠実。

### 2026-07-25: KMP ViewModel の 800 行超分割は「top-level internal 関数抽出」方式

- 関連: coding-conventions §3.4、Swift 側 View 分割 3 件（MapTabView / AnalysisView / CoffeeEditorView、2026-07-24）

**背景**: 分割閾値 800 行を KMP 側で初めて超過。Swift 側の分割は `extension` でクラス本体を複数ファイルに割ったが、**Kotlin のクラス本体は複数ファイルに割れない**（`partial` 相当なし・nested 型も本体内固定）。この非対称性のため KMP では別方式が要る。

**方式**: クラスに閉じている必要のない純粋ロジックを、同一パッケージの兄弟ファイルへ `internal` top-level 関数として抽出する。
- `CoffeeRecordBuilder.kt`: `validate` / `buildRecord` / `buildCafe` / `CafeSnapshot`。旧実装が暗黙参照していた ViewModel 内部状態（`mode` / `currentInitialRecord` / `selectedCafe`）を**引数として明示注入**する形に変換（呼び出しは `onSaveTapped` 1 か所）。純粋関数化で単体テスト容易性も向上。
- `CoffeeEditorMapping.kt`: `toDraft` / `toDuplicateDraft` / `clamped` / `clampTasting`（元々 class 外の `private` top-level 拡張 → `internal` 化のみ。Swift 露出は元から無いので影響なし）。
- **nested 型（`Mode` / `CoffeeDraft` / `UIState`）はクラス本体に必ず残す**。top-level 化すると Swift 公開名（`CoffeeEditorViewModel.UIState` 等）が変わり iOS 追随が必要になるため。
- **public const（`DEFAULT_COFFEE_NAME`）と `defaultDraft()` は companion に残置**。特に `defaultDraft()` は Swift Bridge が `CoffeeEditorViewModel.companion.defaultDraft()` として直接参照する **public な companion メンバ**であり、これを一度 top-level `internal` へ動かしたところ Swift 側が `has no member 'defaultDraft'` でコンパイル不能になった（下記 落とし穴）。companion の元位置へ戻して解消。

**落とし穴（重要）**: 分割時の可視性判定を誤ると Swift Bridge を壊す。判定基準は「元が `public`（companion メンバ含む）だったか」。`private`/`internal` だったものは移動先で `internal` にしても Objective-C ヘッダに出ないため Swift 露出は不変だが、`public` だったものは**定義位置を動かさない**（companion メンバは companion に残す）。さらに **KMP モジュール単体の Kotlin テスト（`testAndroidHostTest` / `iosSimulatorArm64Test` / `compileTestKotlin*`）では iosApp の Swift コンパイルは検証されない** — `commonMain` の public API に触れる分割では、生成ヘッダ（`SharedLogic.h`）確認だけでなく **実際の Swift ビルド**まで親が検証すること。→ lessons 2026-07-25。

**トレードオフ**: `validate` / `buildRecord` を domain UseCase へ昇格する案は見送り。いずれも feature 層の `CoffeeDraft`（20 フィールドの UI 編集 draft）に依存し、domain へ持ち上げると UI-draft で domain を汚すため、feature モジュール内の純粋関数に留めた。

**検証**: `CoffeeEditorViewModelTest` 20 件を無改変で全緑（testAndroidHostTest / `iosSimulatorArm64Test`）+ 親のフラグ無し `assembleSharedLogicDebugXCFramework`（link まで成功）+ **iosApp スキームの実 Swift ビルド `xcodebuild build ... -scheme iosApp` が `BUILD SUCCEEDED`**（`CoffeeEditorViewModelBridge.swift` 含む）。最終 3 ファイル: `CoffeeEditorViewModel.kt` 695 / `CoffeeRecordBuilder.kt` 141 / `CoffeeEditorMapping.kt` 88 行（全 800 以下）。

### 2026-07-25: CI のテスト対象をモジュール個別列挙から `testAndroidHostTest` 一括指定へ

- 関連: `.github/workflows/ci.yml`、`docs/architecture.md` §アーキテクチャ検証ルール

**発見**: docs 全体の敵対的レビューで、`ci.yml` の Android ジョブが `:shared:data-local:testAndroidHostTest` **1 モジュールだけ**を指定していたことが判明（ジョブ名は "Android assembleDebug & shared tests"）。`shared/domain` / `core` / `feature/*` の commonTest — `FavoriteSignalsPersonaTest`・`OriginNormalizerTest`・VM テスト 7 本など — が **PR チェックで一度も実行されていなかった**。tasks.md 側では各フェーズで「テスト green」を根拠に完了扱いしてきたが、それは親のローカル実行であって CI の回帰網ではなかった。

**是正**: `./gradlew testAndroidHostTest :androidApp:assembleDebug` へ変更（**タスク名のみ・プロジェクトパス無し**）。Gradle が全サブプロジェクトの同名タスクを解決するため、feature モジュール追加時に CI 側の追記が不要になり、「新規モジュールのテストが静かに漏れる」構造的な穴が塞がる。

**トレードオフ**: 実行対象が 1 → 14 モジュール（`sharedUI` 含む）に増え CI 時間が伸びるが、ローカル実測は全キャッシュ有効時 5 秒 / テスト 360 件・37 クラスで、CI のコールドキャッシュでも許容範囲と判断。

**残る穴（意図的）**: iOS ジョブは `assembleSharedLogicXCFramework`（Kotlin/Native リンク）までで、**`xcodebuild`（Swift 側のコンパイル）と `iosSimulatorArm64Test` は CI 非対象**のまま。macOS runner の実行時間コストが大きいため、Swift 側の回帰は親のローカル検証（`verify-kmp-ios` skill、フラグ無し `xcodebuild`）で担保する運用を明文化した（architecture.md に追記）。2026-07-25 の分割 PR で「KMP テスト green でも Swift ビルドは壊れる」実例が出ているので、この分担は意識的に守る。

### 2026-07-25: data-model.md の縮約（1246 → 901 行）— 「ソースの逐語コピーは置かない」を基準化

- 関連: data-model.md 前文「この doc に書くこと / 書かないこと」、`.claude/rules/kotlin-kmp.md`、lessons 2026-07-25

同日の陳腐化チェック（6 件是正 + 欠落 2 件補完）に続き、ユーザー指摘「行数が大きすぎる」を受けて縮約した。**それまでの整理では「ストック型の正本（requirements / data-model）は縮小対象にしない」としていたが、この判断を撤回**した。実測で **1246 行のうち 660 行（53%）がコードブロック**で、その大半がソースファイルの逐語コピーだったため、フロー型・ストック型という軸とは別に「複製か仕様か」で切れると判断した。

**採用した基準**（前文に明文化。CLAUDE.md の「一覧をここに複製しない — 陳腐化防止」の一般化）:

- **削る = ソースが正本のものの逐語コピー**: SQL クエリ本体（`selectAll` / `upsert` 等）/ `firestore.rules` 全文 / `CoffeeRepositoryImpl` の実装 / `CoffeeOriginCatalog.countries` の 43 か国リスト / 各 interface のシグネチャ列挙（→ 箇条書き・表へ）。**列定義（CREATE TABLE）と公開 API の「形」は仕様なので残す**
- **削る = 経緯・実測値・不採用案**: 統計定数の偽陽性率実測（B-1b〜B-1d）と 9-6 の意思決定 6 点は implementation_note の既存エントリに全部あるため、doc 側は結論 + 参照に置換
- **移さず消しただけのものは無い**（受け皿の存在を先に grep で確認してから削除した）

**この判断を支持する実例**: 削除した 2 つのコードサンプルは、過去に**サンプル自体の追随漏れ**で修正タスクになっていた（tasks #6 = §4.2 の `runRemote` が `runCatching` を例示して自プロジェクトの禁止パターンに違反 / #7 = §2.1 の `upsert` に `brew_recipe` 列が無く実体と不一致）。**doc 内のコード複製は、それ自身が追随コストと陳腐化の発生源**という裏付けになった。

**外部参照の生存検証**: 他 doc / コードコメントから名指しされている節番号 20 個（§1.1〜§8）すべてが縮約後も解決することを機械的に確認済み（節見出しは削除・改番していない）。**追記（同日、ユーザー指示で分離を実施）**: 見送った「別 doc への分離」を実行し、§1.6 / §1.7 / §1.7a を [`analysis-model.md`](./analysis-model.md) §1 / §2 / §3 へ移した（data-model 901 → 708 行 + analysis-model 231 行）。分離軸は**永続するか否か**（analysis-model 側はすべて SQLDelight / Firestore 表現を持たない派生集計で、更新契機が永続エンティティと違う）。

- **新 doc は独自採番**（§1〜§3）にした。移動先で `§1.6` から始まる採番を維持する案は参照の張り替えが不要になる利点があったが、新規読者に意味不明な番号が残るため却下
- **`data-model.md` の §1.8 以降は改番しない**。§1 の採番に 1.6〜1.7a の欠番が空くが、他 doc / コードから名指しされている番号を動かす方がコストとリスクが高い（欠番は意図的であることを doc に明記）
- **旧番号にはリダイレクト表を残した**（data-model.md §1.6〜1.7a）。これにより**完了済みタスク行・変更履歴行のような「史実としての参照」は書き換えずに済む**（当時 data-model に書いたという記録を改変しない）。書き換えたのは「現在の正本の場所を指す live pointer」だけ — docs 24 箇所 + KDoc 19 箇所（kmp-engineer 17 / ios-engineer 2 に dispatch）
- 検証: 両 doc の実在節番号と全参照を機械照合し dangling ゼロを確認。`CoffeeRecordDisplay.swift` は §1.3a（data-model 残留）と §1.6（分離）の両方を参照していたため 2 doc を指す形に修正した

### 2026-07-25: 実装ノートの棚卸し（1273 → 約 810 行）— 月次アーカイブ運用へ

- 関連: `docs/implementation-note-archive.md`、`.claude/skills/curate-doc/SKILL.md`、`.claude/hooks/check-file-size.sh`

`docs/**.md` 500 行超で棚卸しするルール（同日制定）の初適用。**フロー型なので `curate-doc` skill の Phase 2（縮約）のみ** + 本ノート前文の昇格パスに従った。1273 → 816 行 / 103 → 61 エントリ。

- **`- 領域:` を廃止**（102 行）: 103 エントリで 60 種類以上の自由記述（`iOS` / `iOS / Ads` / `iOS のみ（KMP 変更なし）` / `全レイヤー` …）に散り、分類にも検索にも使えていなかった。所在はタイトルと `- 関連:` のファイルパスで足りる。エントリ形式テンプレも更新
- **同テーマ系列の統合**: 06-19 分析系 4 件 → 1 / 06-21 Q&A v1・v2 → 1 / 06-30 Phase 12-B の小片 3 件 → 1。**日付は保つ**ので他 doc の日付参照は生存する（2026-06-22 の B-1〜B-1d 5 件統合と同じ手）
- **Phase 2 だけでは 500 行に届かないと判明** → Phase 3（分離）へ: **2026-06 の 36 件を [`implementation-note-archive.md`](./implementation-note-archive.md) へ凍結移送**。`tasks/pr-log.md`（Phase 1〜初期の凍結ログ）と同じ前例に倣った

**判断: 作業ログに行数の閾値は本質的に合わない。** append-only 気味に伸びるので、縮約で 500 行に収めようとすると経緯そのものを削ることになる（それは棚卸しでなく歴史の破棄）。よって本ノートは**「フェーズが完了して追記が止まった月を凍結アーカイブへ送る」月次運用**を正とし、行数閾値は棚卸しの*きっかけ*としてのみ使う。この運用は前文「アーカイブ」節に明文化した。

- 参照の生存: 他 doc / コードから名指しされている 2026-06 の日付参照 20 件すべてがアーカイブ側で解決することを機械確認。**参照は日付で引く運用なので参照側の書き換えは不要**（data-model 分離で使ったリダイレクトと同じ考え方）
- 副産物: `curate-doc` skill の awk スニペットが、skill 起動時の引数展開で `$0` を潰される欠陥を発見（dogfooding で判明）。測定コマンドを skill 同梱スクリプトへ切り出して修正

### 2026-07-25: architecture.md の棚卸し（589 → 438 行）+ README の旧ドメイン名を是正

- 関連: `docs/architecture.md`、`README.md`、`.claude/hooks/check-file-size.sh`

`curate-doc` skill の Phase 1 → 2。Phase 2 で 500 行を切ったため Phase 3（分離）は不要。

**Phase 1（陳腐化チェック）で 3 件 + 欠落 2 件 + コード側 1 件**:

- **Firebase 系 I/F が「4 つ」のまま**（3 箇所）→ `CuratedCafeRepository` を加えて 5 つに。`CuratedCafeRepositoryAndroidImpl` / `CuratedCafeFirestoreMapper` はフェーズ 19 で追加済みだった
- **ViewModel の配置が `shared/feature/*/viewmodel/*ViewModel.kt`** → 実際は `viewmodel/` サブフォルダを作っていない（`.../feature/<name>/<Name>ViewModel.kt`）
- **テスト方針の `FakeFirestore` が架空**。実在は手書き Fake 10 個（`FakeCoffeeRepository` 等）+ `TestSqlDriver`。モック生成ライブラリは使っていない
- 欠落: **外部依存表に AdMob / Firebase Crashlytics・Analytics・Performance / Remote Config が無い**（実際に import されている 4 系統が未記載）。参考リンクに `analysis-model.md` も追加
- コード側: `build-logic/.../kmp.feature.gradle.kts` の KDoc が「feature モジュールはまだ存在せず…`feature/visit-list` 等を作るときに使う想定」= Phase 2.5 当時のまま（feature は 8 個、`visit-*` はクリーンブレイクで全廃）→ kmp-engineer へ dispatch

**Phase 2（縮約）**: コードブロックが 48%（283 行）で、その大半が**実ファイルや他 doc が正本のもの**だった。`framework/build.gradle.kts` 抜粋 / Convention Plugin 2 本 / `CoffeeListViewModel` 53 行（正本は coding-conventions §1.2 に同型スケルトンあり）/ iOS Bridge（正本は kmp-bridge）/ `AppContainer` スケッチ / テスト例を、**要点の箇条書き + 正本への参照**に置換。**構造を示す ASCII 図 5 つ（モジュールツリー / 依存方向 / レイヤー / データフロー 読み書き）は architecture が正本なので残した**（コードブロック比率 48% → 26%）。

**副産物: root `README.md` が 1 か月半前の旧ドメイン名を掲げていた**。参照の生存検証（skill の締め #1）で `architecture.md#段階的移行ステップ` という**存在しない見出しへのアンカー**を検出し、README を読んだところ `visit-list` / `visit-detail` / `visit-editor`、`Visit / CoffeeItem / FoodItem`、「現在は Phase 1 の途中」「Storage（Android 実装）」が残存（2026-06-19 クリーンブレイクの消し込み漏れ）。6 箇所を是正した。

- **フックの対象に root `README.md` を追加**。docs/ だけ見ていて玄関を見ていなかった。リポジトリの玄関はモジュール構成の記述が陳腐化しやすく、かつ最も人目に触れる
- 教訓の一般形: **横断 doc の消し込み漏れは「参照先の見出しが消えている」形で表面化する**。節番号だけでなく**見出し名での参照も生存検証の対象**にする（lessons 2026-06-16「横断 doc は構造的に陳腐化」の実例が 1 件増えた）

### 2026-07-25: kmp-bridge.md の棚卸し（573 → 455 行）— 架空の 47 行を削除

- 関連: `docs/kmp-bridge.md`

`curate-doc` skill の Phase 1 → 2。Phase 2 で 500 行を切ったため分離は不要。**陳腐化 6 件、うち最大のものは「実在しないコードを 47 行にわたって説明していた節」**。

- **「SKIE を使わない場合」節（47 行）が完全に架空**: `FlowWrapper` / `iosApp/Shared/Bridge/` を 0 件と実測（SKIE は 2026-06-04 から採用済みで、この分岐は一度も使われていない）。**採用しなかった選択肢の実装手順は書かない**（分岐が増えるだけで、必要になったら書き直す方が早い）を doc 前文の基準に追加して削除
- **`shared/feature/visit-list`** = 2026-06-19 クリーンブレイク前の旧名（README と同じ消し込み漏れ。同型が 2 doc で出た）
- **`DatabaseDriverFactory` のパスが `com/noricoffee/data/local/`** → 実際は `com/noricoffee/platform/`
- **`makeCoffeeListViewModel(userId:)` のシグネチャが違う** → 実物は引数なしで、`userId` は `onAppear(userId:)` で渡す（サインイン完了と画面生成を切り離す設計）。Swift の呼び出し例 2 箇所も是正
- **`AppContainer` の生成例に `remoteSavedCafeDataSource` が欠落**（7 → 8 引数。フェーズ 15-A の追随漏れ）。iOS / Android の 2 本並記を 1 本 + 差分 1 行に圧縮
- **`extension CoffeeRecord: Identifiable {}`** → Swift 6 では他モジュールの型への準拠に `@retroactive` が必要で、実物は全 4 箇所が `@retroactive`

**Phase 2（縮約）**: 「View 側の使い方」（SwiftUI の一般的な書き方 30 行）→ ブリッジ規約としての要点 2 つに / `expect`・`actual` の `SqlDriver` 実装例 → **要点は「`actual` のシグネチャは揃わなくてよい（Android だけ `Context` が要る）」**の 1 点なのでそこだけ残す / Umbrella Framework 節 → `architecture.md`「iOS 配布戦略」が正本なので、ブリッジを書く側が知るべき 4 点の再掲に圧縮（コードブロック 36% → 28%）。

**この doc に固有の判断**: 型の見え方の表・SKIE の呼び出し方向の制約・Swift で Kotlin interface を実装するときの生シグネチャ表は**この doc が唯一の正本**なので、行数が嵩んでも残す。ブリッジは「知らないと詰まる」種類の知識で、他 doc に散らすと参照コストが跳ね上がる。

### 2026-07-25: 目視 QA を verification-checklist.md へ完全集約（tasks.md から 19 行を移送）

- 関連: `docs/tasks/verification-checklist.md`、`docs/tasks.md`

2026-07-08 に「目視 QA は checklist へ分離」と決めたのに、**その後の実装では `tasks.md` の各フェーズ表に「ユーザー: シミュレータで目視」行を書き続けていた**（19 行 = うち 16 行は `[x]` 完了済み）。checklist 側は 2026-07-08 以降更新されず、tasks.md 側が事実上の QA 台帳になっていた（2026-07-25 の敵対的レビューでも「checklist が未更新」として指摘済みだった）。

**原因は分離のルールが「どこに書くか」しか決めておらず、「いつ移すか」を決めていなかったこと**。フェーズ着手時点では実装タスクと目視タスクが同じ表に並ぶのが自然で、そのまま完了まで走る。

- **運用を追加**: 実装が終わって残るのが目視だけになった時点で checklist へ 1 項目として移し、tasks.md 側はフェーズサマリで「残る目視は verification-checklist」と触れるだけにする。**完了した目視行を `[x]` で残すのも禁止**（確認済みの事実だけが溜まり、次の QA で読み飛ばす行が増える。記録が要る内容は本ノートへ）。両 doc の前文に明文化
- 完了行 16 本の削除前に、備考の知見の受け皿を確認した: 広告の `No fill` = Google 側抑制（本ノート 2026-07-22）/ Remote Config の `minimumFetchInterval` 12h 既定（同 2026-07-13）→ どちらも既にあるため削除可と判断
- **移送した未完 3 件 + 拾い直した残務 1 件**: マップ検索の下部ドラッグシート（広告の fold 下ロード回帰を含む）/ 周辺カフェピンのスロットリング耐性 / BeanProfile 投入後の探索提案 / フェーズ 18 の Crashlytics・Performance コンソール観察（`[x]` 行の備考に埋もれていた「後日コンソール観察」を項目化）

**checklist 側の陳腐化 2 件も是正**:

- **`MapTabView.swift:1383` という行番号参照が壊れていた**（M-1〜M-4 の分割で 2008 → 804 行になり、該当コメントは `AppleNearbyCafeLoader.swift` へ移動）。**QA 項目にコード内の行番号を書かない**ことを前文のルールにした（リファクタで即陳腐化する）
- マップ検索の項目が「結果リストを検索バー直下に統合」という 2026-07-22 に廃止された UI を前提にしていた → 下部ドラッグシート + 「このエリアを検索」のキーワード維持（2026-07-24）に追随

### 2026-07-26: タグサジェスト（要件 2-13）の設計 — 絞り込みの順序と `tagInput` の置き場所

ユーザー要望「追加したタグをコーヒー記録で選択できるようにしたい。周辺のカフェみたいに下に選択できるタグを出したい」から起票。仕様 5 点はその場の grilling で確定（requirements 2-13）。実装上の判断は 3 つ。

**①「絞り込み → 上限 10 件」の順序**: 逆順（先に上位 10 件を取り、その中で部分一致）にすると、**11 位以下のタグは入力欄に何を打っても永久に出てこない**。使用頻度の低いタグこそ打ち直しの手間が大きく、サジェストの価値が高い側なので順序を逆にした。上限は「横スクロールが延々と続くのを防ぐ」ためのものであって、候補集合を先に狭めるためではない。

**② `tagInput`（入力欄の文字列）を Swift `@State` から KMP `UIState` へ移管**: 絞り込みロジックを Swift 側に置けば KMP 変更なしで済んだが、Android 実装時に同じ順位付け・絞り込み・除外を書き直すことになる（CLAUDE.md の「ロジックは commonMain に寄せる」）。`cafeName` 等の既存フィールドと同じ `Binding(get:set:)` パターンに乗るだけなので、Swift 側のコストはほぼゼロ。

**③ `observeAll(userId)` を継続購読（one-shot `.first()` ではなく）**: エディタは一時的に開く画面なので one-shot でも足りるように見えるが、**Firestore 同期が終わる前にエディタを開くとローカル DB が空で、サジェストが出ないまま固定される**。継続購読なら後から埋まる。コストは `MapViewModel` が既に同じ Flow を常時購読しているのと同程度。

タグの**正規化・統合は行わない**（「浅煎り」と「浅炒り」は別タグのまま）。サジェストが出ることで表記ゆれは自然に収束する見込みで、正規化は既存記録の書き換えを伴うため今回のスコープ外とした。

**実装時に判明した追加事項 2 件**（2026-07-26 実装後）:

- **再計算の起点は 4 つだった**。設計時は 3 つ（購読の emit / `onTagInputChanged` / `onTagAdded`・`onTagRemoved`）と見ていたが、`tagCatalogJob`（カタログ購読）と `loadJob`（記録ロード）は `onAppear` から**同時に launch される**ため、カタログ側の初回 emit がロード完了より先に走ると「付与済み除外」が `draft.tags` 未反映（空集合）の状態で計算される。以降 DB に変化がなければ再計算されないので、**Edit / Duplicate で既に付いているタグがサジェストに残り続ける**。Edit / Duplicate の初回ロード完了ブロックにも `recomputeSuggestedTags()` を置いて解消（`CoffeeEditorViewModelTest` で固定）。`kmp-engineer` が実装中に発見
- **重複タグを手入力して「追加」を押したとき、入力欄が残るようになった**。従来は Swift 側が無条件に `newTagText = ""` していたが、クリアを KMP の `onTagAdded` 成功時に一本化した結果、重複で early return するケースではクリアされない。**この挙動を許容する**（「追加されなかった」ことが入力欄に残ることで分かる方が、無言で消えるより良い）。サジェストが出る以上、重複タグを手打ちする経路自体が稀になる

### 2026-07-27: docs 棚卸し 第 2 巡 — 未実施 8 本への Phase 1 適用と data-model の閾値例外

2026-07-25 の第 1 巡で触れなかった 8 本（coding-conventions / ui-ux-guidelines / requirements / app-store-metadata / paid-services / analysis-model / root README / verification-checklist）にコード突き合わせを通した。検出は**陳腐化 10 件 / 欠落 4 件 / コード側 2 件**で、内訳は tasks.md「docs 棚卸し 第 2 巡」に記載。ここには判断の理由だけ残す。

**`data-model.md` 708 行を分割しない（ユーザー確定）**: ストック型の閾値 500 を超え続けているが、表現軸（§1 ドメイン / §2 SQLDelight / §3 Firestore）で切ると **1 エンティティにフィールドを足すときの追随先が複数 doc に散る**。フィールド追随漏れは `.claude/rules/kotlin-kmp.md` のチェックリストが 6 経路を潰しているとおり、このプロジェクトで最も実害が出ている失敗モード（2026-07-25 の `region` 欠損バグ）なので、その追随コストを上げる分割は行数削減と釣り合わない。性質で切れる軸は 2026-07-25 に使い切っている（永続しない派生集計 → `analysis-model.md`）。**閾値の例外は doc の前文に書き、フックのスクリプトは変えない**（フックは警告のみで、判断の正本は doc 側という役割分担を保つ）。

**陳腐化は「その doc を触らない変更」で起きる**: 今回の 10 件は、いずれも**別の doc だけが追随して残りが取り残された**形をしている。広告 2 面の提示先が下部シートへ移った 2026-07-22 の変更では requirements §11-2 は当日更新されたが `paid-services.md` §2b が残った。`iosApp` のディレクトリ構成は `Ads/` 追加・`Bridge/` 廃止・`Utilities/` 新設と何度も変わったが、coding-conventions §2.2 のツリーは初期のまま。**変更のたびに「この事実を書いている doc は他にどれか」を引くコストが高いため追随が漏れる**という構造で、CLAUDE.md の「横断 doc の同時更新」だけでは防ぎきれていない。定期的な Phase 1 が事後の受け皿として機能している（第 1 巡 6 件 + 今回 10 件）。

**`PrivacyInfo.xcprivacy` の TODO（2026-07-14 起票）を「変更不要」で閉じた**: privacy manifest は**そのバイナリ自身のコードが**収集・アクセスするものを宣言する枠組みで、埋め込んだ SDK の収集は SDK 同梱の manifest が宣言する。`iosApp` は `AdConsentCoordinator` で `ATTrackingManager` の状態確認と許可要求をするだけで `AdSupport` を import せず IDFA を直接読まないため、アプリ側 manifest は現状（`NSPrivacyTracking = false` / 収集 3 種）のままで整合する。一方 **App Store Connect の App Privacy 申告は SDK の挙動も含めて申告する**別枠組みなので、§6.1 の IDFA 行はそのまま必要。この 2 つの混同が「広告を入れたのに manifest が false でいいのか」という迷いの正体だったので、app-store-metadata §6.3 に切り分けを明記した。

**root README の `core` は依存の向きごと間違っていた**: 「`core` = Result / Logger / Dispatchers」というレイヤー図は**一度も実在しなかった**（`shared/core` は最初から `AppContainer` = 合成ルートと Repository 合成実装）。矢印も `data-* → core` と最下層に描かれていたが、実際は `core` が `data-*` を束ねる側で向きが逆。architecture.md は 2026-07-25 の棚卸しで正しく直っていたので、**README だけが分割前（Phase 2.5 以前）の想像図のまま残っていた**ことになる。README は「玄関で最初に読まれる doc」なのに実装から最も遠い位置にあり、フック対象に入れた（2026-07-25）だけでは行数閾値でしか鳴らない。

**`.brown` 直書きは「訪問済み」バッジ 1 件では終わらなかった**（MP-4 → MP-5）: 棚卸しの行番号検査で拾った `SavedCafeListSheet` の「記録あり」バッジ（`.brown` 直書き）を `Color.accentColor` へ揃えたが、横断点検で**オンボーディング系 2 画面にも同型が 5 箇所**残っていた（`DataConsentOnboardingView` = 見出しアイコン / 目的リスト 3 アイコン / CTA の `tint`、`AdPrePromptView` = 見出しアイコン / CTA の `tint`）。`.brown` はシステムの固定色で **AccentColor（light #8B5A2B / dark #C08552）と一致しない**ため、ダークモードでブランド色が 2 系統に割れるという同じ実害を抱える。`ui-ux-guidelines.md`「カラーの役割定義」は**マップ限定の色セマンティクスとは別に、アプリ全体で「アクセント = `.accentColor`」**を定めており、`tint(.brown)` は同 doc が Good 例として挙げる `tint(.accentColor)` に正面から反する。5 箇所はユーザーの目に見える意匠変更なので MP-5 として分離して判断を仰ぎ、**「5 箇所すべて accentColor へ揃える」でユーザー確定**（2026-07-27）。`AdPrePromptView`（広告説明画面）だけブランド色を外す案も提示したが、直前のデータ利用同意オンボーディングと地続きで表示される導入フローなので、統一を採った。これで `.brown` の直書きは `iosApp/**` から **0 件**になり、ブランド色の入り口は AccentColor 1 つに揃った。**「マップの色セマンティクス」表しか見ていないと、この種の逸脱は拾えない**（マップ外の画面が対象なので）— アプリ全体の「カラーの役割定義」表と両方を照合軸にする必要がある。

**ピン KDoc から pt 値・色の列挙を落とした**（`ios-engineer` の判断を追認）: `AppleNearbyCafePin` の「小径 24pt」は実装 28pt との実差だったが、あわせて `CuratedCafePin` / `SavedCafePin` の「既存 N 種ピン」「34pt / 28pt」「既存 5 色」といった**現時点では正しい記述も docs 参照へ置換**した。ピンは 4 → 5 → 6 種と増えており、数え上げを書いた KDoc は追加のたびに全件が陳腐化する。正本は `ui-ux-guidelines.md`「ピンの意匠ルール」1 箇所に集約する（2026-07-25 に `CuratedCafe.kt` で採った方針と同じ）。

### 2026-07-28: iPad を対象外で確定（`TARGETED_DEVICE_FAMILY` を 1 に）

`app-store-metadata.md` §1 は初版から「デバイス = iPhone」と書いていたが、`iosApp.xcodeproj` は Xcode テンプレート既定の `TARGETED_DEVICE_FAMILY = "1,2"` のままで、**doc とプロジェクト設定が食い違っていた**（2026-07-27 の ASO 棚卸しで ASO-6 ③ として検出）。実害は 2 つ: ① App Store Connect は iPad 対応バイナリに対して **iPad スクリーンショットを必須要求**するため提出が止まる ② iPad に入る状態で iPad レイアウトを一度も検証していない（マップの下部ドラッグシート・分析タブのチャートはいずれも iPhone 幅前提）。**iPad 対象外でユーザー確定**（2026-07-28）し、設定側を doc に合わせた。

あわせて `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`（Debug / Release 両方）も削除した。デバイスファミリから iPad を外した時点で参照されない死んだ設定で、残すと「iPad も見ている」という誤読を招く。`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` は不変。

検証は**ビルド後の成果物**で取った: `xcodebuild -showBuildSettings` で `TARGETED_DEVICE_FAMILY = 1` / `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`、Debug ビルド `** BUILD SUCCEEDED **` の後に `plutil -extract UIDeviceFamily xml1 -o -` で `coffeevision.app/Info.plist` が **`[1]`** であることを確認（**`-o -` は必須** — 付けないと `plutil -extract` は抽出結果で**元ファイルを上書きする**。2026-08-06 に親がこの行のコマンドをそのまま流用して成果物 `Info.plist` を 6 バイトに破壊した。lessons 2026-08-06）。pbxproj の値は `GENERATE_INFOPLIST_FILE = YES` 経由で `UIDeviceFamily` に変換されるため、**pbxproj の diff だけでは「ASC がどう解釈するか」の証明にならない**（ASC が見るのは成果物の `Info.plist`）。同種の Info.plist 生成系設定を変えたときは成果物側で確認する。

将来 iPad 対応する場合は、この設定を戻すだけでは足りない（iPad スクショ / レイアウト検証 / `UIRequiresFullScreen` の要否判断がセットで要る）。

### 2026-07-28: おすすめカフェを 9 県へ拡張（47 県フルを採らない理由）

`curatedCafes` は東京 1 県のみ投入済みだった。リリースに向けて **東京 / 大阪 / 京都 / 神奈川 / 愛知 / 福岡 / 北海道 / 千葉 / 埼玉 の 9 県**へ広げることでユーザー確定（2026-07-28）。`generate-curated-cafes.mjs` の `PREFECTURES` に 8 県分の `subAreas` を定義した（東京 16 + 各県 5〜6 = 計 46 エリア）。アプリ側のコード変更はゼロ。

**47 県フルを採らなかった理由は「コスト」より「品質」**: 選定は基準上位（評価 4.4 / レビュー 100 件以上、上限 30）+ 人気枠（3.7 / 500 以上を枠外全件）の 2 段だが、スペシャルティ店の少ない県では基準上位が 30 件に届かず、**結果が人気枠の大手チェーンで埋まる**。おすすめピンは「その土地のコーヒー文化を指す」ためのレイヤーなので、埋まらない県を足すとピンの意味が薄まる。加えて Places 規約のキャッシュ規定（placeId 以外 30 日）で generate → レビュー → seed を回し続ける運用が前提なので、**県数はそのまま恒久的な運用コストになる**（1 回のフル実行が 32 → 124 コール）。

**`subAreas` を省略した県は実質的に対象外**という設計上の非対称がある。省略時は `[pref.name]` の 1 エリアにフォールバックし 2 クエリしか投げないため、「コードを `--prefectures` に足しただけ」ではカバレッジが極端に薄いドキュメントが 1 件できてしまう。README にこの点を明記した。

**エリア名は市名で修飾した**（`"札幌 円山"` / `"名古屋 栄"` / `"横浜 関内"` 等）。`円山` は京都・`栄` は他県にも実在し、素で投げると県外候補で 20 件の枠を消費する。県外は `formattedAddress.includes(pref.name)` で落ちるので結果は正しくなるが、**課金されるのはリクエスト単位**なので候補プールの質を落とすだけ損になる。

**生成スクリプトの上書き挙動を docs 化した（既存の地雷）**: `generate-curated-cafes.mjs` は `--prefectures` に渡した県だけで配列を組み直し `curated-cafes.json` を丸ごと `writeFile` する。単県で実行すると**人手レビュー済みの他県データが JSON から消える**（Firestore 側は `set()` されないドキュメントが残るので気づきにくく、リポジトリ内の正本だけが失われる）。東京 1 県だけを運用していた間は表面化しなかったが、県が増えた時点で踏む。スクリプト冒頭と README の両方に「投入対象を毎回すべて列挙する」と明記した。

### 2026-07-28: おすすめカフェ 9 県投入 — 「人気枠」が大手チェーンを必ず通す

9 県の生成・レビュー・投入を実行し 453 件になった。投入後の点検で**大手チェーン 33 件の混入**が判明（コメダ 9 / ドトール 6 / ベローチェ 6 / 星乃 4 / エクセルシオール 3 / タリーズ・上島・ルノアール・倉式・STARBUCKS RESERVE 各 1）。`EXCLUDED_NAME_KEYWORDS` に 10 語追加して 32 件を除去し **421 件**に落ち着いた。

**構造的な原因は選定ロジックの 2 段目**: 「人気枠」は評価 3.7 / レビュー 500 件以上を**上限の枠外で全件追加**する。チェーン店はレビュー数が桁違いなので、この枠を必ず通過する。つまり**チェーン排除は名前キーワードでしか行えない**設計で、`EXCLUDED_NAME_KEYWORDS` は「レビューで気づいたものを事後に足す」蓄積型の仕組みになっている。東京は 2026-07-17 からの運用で蓄積があったため混入 2 件で済み、**新規 8 県には蓄積がゼロだったので 31 件出た**。県を足すたびに同じことが起きるので、README に「新しい県を足したら必ずチェーン混入をチェックする」と明記した。

**キーワードは部分一致なので語の選定に副作用がある**。`珈琲館` を入れると独立店の `表参道珈琲館` を巻き添えにするため入れていない。逆にこの部分一致の性質を利用して、カタカナの「スターバックス」だけを登録しラテン表記の `starbucks` を入れないことで、通常店舗（スターバックスコーヒー 〇〇店）は落としつつ `STARBUCKS RESERVE(R) ROASTERY TOKYO`（焙煎所併設の目的地型フラッグシップ）だけを残している（2026-07-28 ユーザー確定）。**この非対称は表記に依存していて壊れやすい**ので、スクリプトのコメントに理由を残した。

**除去に Places API の再呼び出しは不要**だった。JSON から該当行を落として `set()` で再 seed すれば、ドキュメントの `cafes` 配列ごと置き換わる。生成と投入が分離している 2 段構成の効き目で、**選定基準の見直しはコスト 0 で何度でも試せる**。

東京の再生成では 13 件追加・12 件削除の入れ替わりが出た。評価とレビュー数の変動で基準上位（4.4 / 100 件）の顔ぶれが動くためで、30 日リフレッシュ運用が想定どおり機能している証拠。ただし**人手レビューで消した店のうち `EXCLUDED_NAME_KEYWORDS` に入れていないものは再生成で戻る**（今回 `星乃珈琲店 立川若葉町店` が復活した）。レビューで消したら必ずキーワード登録する、という運用が守られていないと差分が毎回発生する。

### 2026-07-30: アプリ表示テーマの初期値を system → light に変更

`@AppStorage("appAppearance")` の既定値を `AppAppearance.system`（OS 追従）から `.light` に変えた（`iOSApp.swift` の `AppRootView` / `SettingsView` の 2 箇所。片方だけ変えると初回表示と設定 Picker の選択状態がずれる）。設定画面の選択肢（システム / ライト / ダーク）は据え置きで、要件 8-1 の仕様変更ではない。

きっかけは「マップだけライト固定にできないか」という相談で、ダークモード時の地図の見え方が動機だった。マップだけをライトにする案（`Map` に `.environment(\.colorScheme, .light)`）は**採らなかった**: 地図の上には検索バー / フィルタチップ / カフェ選択カード / 検索結果シートが重なっており、地図だけ明るくすると同一画面内でテーマが割れる。適用範囲をマップタブ全体に広げると今度はタブ間で割れる。**テーマの境界を画面の途中に引くと必ずどこかで割れる**ため、アプリ全体の既定を倒す形にした。

**既存インストールにも効く**点に注意。`@AppStorage` の既定値は UserDefaults にキーが無いときだけ使われ、キーが書かれるのは設定画面で Picker を操作したときだけなので、**一度もテーマを触っていないユーザーは次回起動でライトに変わる**。リリース前なので実害はないが、リリース後に同じ変更をすると「勝手にテーマが変わった」になる。

### 2026-07-31: おすすめの高度化の方向性 — 好み検索に BeanProfile を入れず、curatedCafes に産地を持たせる

`beanProfiles` の消費先が分析タブの 2 セクション（好みの豆の傾向 / 未経験の豆への探索提案）だけである確認から、「マップの好み検索にも使えるのでは」という検討をした。**検索案は不採用**、代わりに `curatedCafes` へ産地を持たせる方向でユーザー確定（2026-07-31）。いずれもリリース後の話で、今回のリリースには含めない。

**検討した検索案の構成**: `TastePreference`（Foundation Models が出す 5 軸）→ `TastingScores`（KMP 既存型。Swift から構築済みの実績があるのでブリッジの新規設計が不要）→ 新規の決定論 UseCase で `BeanProfile` を距離順に 2 件選ぶ → 産地名・品種名を `searchKeywords` に足して Places に投げる。狙いは「今の `searchKeywords` が形容詞 11 語しか出さない」点の解消で、Places のテキスト検索に効くのは固有名詞だという読み。`BeanProfile` に 5 軸が無いので seed の 38 件に代表値を手オーサリングする前提（`flavorNotes` の統一語彙に軸タグを付ける案・Foundation Models に選ばせる案も並べたが、後者は Places に投げる語が非決定論になり `SuggestUnexploredBeansUseCase` が掲げる「決定論」方針に逆行するため却下）。

**却下の理由は Places がヒットするかどうかではなく、推薦の根拠が存在しないこと**。`beanProfiles` はサービス管理の一般知識で、カフェにもユーザーにも紐付いていない。「エチオピア」で店名がヒットしても**その店が実際にエチオピアを出している保証がどこにもない**ので、固有名詞で検索精度を上げたつもりでも偽陽性を量産する。当初は「Places が産地名でヒットするか」を PoC ゲートに置く想定だったが、仮に黒でなくても採るべきでないと整理した。

**代わりの資産はユーザーの記録**。記録は `cafe.placeId` と `origin` のペアを持つので、溜まるほど「このカフェではこの産地が飲めた」という在庫情報が生える。Places も `beanProfiles` も持たない一次情報で、推薦の根拠としての質が違う。ただし**自分の記録に出るのは既訪問店だけ**なので、単独ユーザーのデータでは未訪問店を推薦できない。`ObserveTasteMatchedCafesUseCase` が「既訪問店の再訪推薦」で止まっているのは実装の手抜きではなく、このデータ制約そのものだった。

**採る構成は `curatedCafes` の各エントリに `origins` を持たせ、既存の seed 運用に乗せる形**。`curatedCafes` は既にサービス管理 / クライアント read-only / `allow write: if false` なので **Rules 変更ゼロ・Cloud Functions ゼロ**で済み、30 日リフレッシュの generate → レビュー → seed のサイクルに相乗りできる。クライアント側は `FavoriteSignals.bestOrigin` と照合するだけで、おすすめピンを「好みの産地を出している**未訪問**カフェ」に格上げできる（好み一致ピン = 既訪問店 と意味が重複しない）。集約の入力は当面ユーザーデータでなくてよく、人手で入れれば既存のレビュー工程と同じコストで始められるためコールドスタートも同意設計も回避できる。

**Cloud Functions によるリアルタイム集約（案 1）は捨てない**。スキーマが `placeId → 産地リスト`である限り集約元が手作業でもユーザーデータでも同じなので、**案 2 を先に作れば案 1 が後から差し込める**。案 1 を先に採ると、現行の `analyticsConsent`（文言は「コーヒー記録の統計情報を匿名で収集します」で Firebase Analytics の gating 専用）では記録内容を他ユーザーの推薦に使う同意として足りず、別トグルか文言改訂 + App Privacy 申告の更新 + 新規課金（Functions）が同時に乗る。順序として案 2 が先。

**実装時に確認すること**: ① 産地の粒度（国止まりか `region` まで持つか。細かくすると人手コストと `OriginNormalizer` のシノニム辞書の守備範囲が変わる）② 「この店ではこの産地が飲める」は時期で変わるのでシングルオリジンの入れ替わりに耐える文言にする（断定を避ける）③ **産地は自前データなので Places 規約の 30 日キャッシュ規定の対象外**という整理で進めているが、規約原文で再確認してから着手する。

### 2026-07-31: 産地サジェスト撤去の残骸を削除 — デッドコードは 3 つでなく 4 つだった

2026-07-22 に撤去したエディタの産地サジェストの名残を削除した（kmp-engineer → ios-engineer の順で 2 回 dispatch、計 59 + 25 行削除）。

**着手前の見立ては「`AppContainer.beanProfileMatchUseCase` と `BeanProfileRepository.getByOrigin` の 2 つ」だったが、実際は 4 シンボルだった**。追加で出たのは `shared/framework` の `AppContainer.fetchBeanSuggestions(origin:processing:)` で、これは `@Throws` 付きの **SKIE 経由で Swift に公開されていたブリッジ関数**。当初の 2 つが「repository と container のプロパティ」という同じ層にあったため、その層だけを見て数えていた。**撤去した機能の残骸を数えるときは、ドメイン層だけでなくブリッジ層（`shared/framework` の `AppContainer` 拡張）まで見る**。ブリッジ関数は iOS からしか呼ばれない前提で作るので、Kotlin 側の grep では「宣言 1 件・参照 0 件」に見えて死んでいることに気づきにくい。

**`getByOrigin` の KDoc は自分が死んでいることを明記していた**（「本番コードに呼び出し元が無いため実害はないが、新規に呼び出す場合は…」= 2026-07-22 の撤去時に書かれたもの）。デッドコードだと分かった時点で消さず注記に留めると、注記ごと残り続ける。

**削除の順序は KMP → iOS** で固定した。Swift 側はプロトコル要件に無い余分なメソッドがあってもコンパイルが通るので KMP を先に消しても壊れないが、逆順にすると Kotlin の interface が要求するメソッドが未実装になり Swift が壊れる。**プロトコル要件を減らす変更は、要件を出す側（Kotlin）から先に**。

**残したもの**: `BeanProfileMatchUseCase` クラス本体とそのテスト。`SuggestUnexploredBeansUseCase` がコンストラクタのデフォルト引数で自前に合成しており（`AppContainer` のインスタンスは経由していない）、探索提案の origin ファジーマッチはこのクラスが現役で担っている。「`AppContainer` のプロパティが死んでいる = クラスも死んでいる」ではない点に注意。

**検証**: `commonMain` の public API 削除なので lessons 2026-07-25 に従い**親がフラグ無しで実 Swift ビルドまで確認**した（`xcodebuild -scheme iosApp -configuration Debug` → `** BUILD SUCCEEDED **`）。ios-engineer 側は生成済み `.swiftinterface` に `getByOrigin` が無いことも裏取りしている。なお削除後に SourceKit が `No such module 'FirebaseFirestore'` を出したが、これは IDE のインデックス由来で実ビルドには影響しない。

### 2026-08-01: 写真の保存時リサイズ — リサイズが「無かった」ことの発見と、副作用の広さ

- 関連: `iosApp/iosApp/Utilities/ImageDownsampler.swift` / `iosApp/iosApp/Features/CoffeeEditor/CoffeeEditorView+Photos.swift` / requirements 未決事項「写真の最大枚数 / サイズ上限」/ paid-services §2「写真 1 枚のサイズ」

ASO-6 ①「写真が機種変更で消える」の**対策コストを試算する過程で**、写真が一切リサイズされずに保存されていたことが判明した。`handlePickerSelection` は `UIImage(data:)` → `jpegData(compressionQuality: 0.85)` だけで、PhotosPicker のフル解像度をそのまま再エンコードしていた。**HEIC は同画質で JPEG の約半分なので、取り込むと元より大きくなる**。実測（下記）で 12MP HEIC が 2.68MB → **4.39MB（×1.64）** と確認できた。一方このアプリが写真を最大解像度で使うのは共有カードの 1080×1350px だけで、用途を大きく超えた解像度を保存していたことになる。

**確定値は長辺 2048px / JPEG q0.8 / 1 記録 10 枚**（ユーザー決定）。2048 は共有カード 1080×1350px と全画面表示（6.7 インチ @3x = 1290px）の両方に余裕を持たせた値。1600px 案もあったが、将来カードを高解像度化したときに再び足りなくなるため 2048 を採った。

**`UIImage(data:)` ではなく ImageIO の `CGImageSourceCreateThumbnailAtIndex` を使う**。前者は 48MP 機で約 190MB のビットマップを展開してしまい、10 枚連続取り込みでメモリピークが問題になる。サムネイル API はデコード時点で縮小するのでこれを回避できる。オプション 3 点（`CreateThumbnailFromImageAlways` = 埋め込みサムネイルを掴まない / `ThumbnailMaxPixelSize` = 長辺上限・元が小さければ拡大しない / `CreateThumbnailWithTransform` = EXIF の向きをピクセルに焼き込む）はいずれも外すと不具合になる。特に最後の 1 つを落とすと**縦向き写真が横倒しで保存される**ため、目視確認の筆頭項目にした。

**影響が課金以外に 2 方向へ伸びていた**:
- **iCloud Backup**: requirements 7-2 は写真のバックアップを iCloud Backup に委ねているが、**iCloud 無料枠は 5GB**。旧ペース（1 日 1 杯・平均 1.5 枚で年 約 1.6GB）はバックアップ失敗を招く水準で、**ASO-6 ①の実発生確率を自分で押し上げていた**。リサイズ後は年 約 0.4GB
- **将来の Storage 復活コスト**: 写真 1 枚のサイズは保存料・転送料をそのまま決める変数（paid-services §2 に実測表）

**枚数ガードは iOS 側に置いた**。`onPhotoUpserted` は `commonMain` だが、これはピッカーの選択制限という UI 入力側の制約で、Android はリリース対象外かつエディタ画面自体が未実装なので二重化のリスクが現時点で無い。KMP の公開 API を変えずに済み 1 dispatch で閉じた。なお `PhotosPicker` の `maxSelectionCount` に **0 を渡すと「無制限」の意味になる**ため、上限到達時は残り枚数 0 を渡さず `.disabled` で塞いでいる。

**既存写真の一括再圧縮はしない**（未リリースでテスト端末は再インストールが既定運用。data-model.md のクリーンブレイク方針と同じ）。

**クラウド保持そのものは今回の判断対象外**。Firebase Storage と CloudKit（private database はユーザーの iCloud 容量を消費するので開発者課金ゼロ。iOS 単独リリースなので選択肢になる）の比較は、写真をクラウドに置くと決めた段階で行う。どちらを選んでもリサイズが前提になるため、順序としてリサイズを先に単独で入れた。

**検証で分かった、当初見積もりの外れ方**: プラン段階では「1 枚 約 3.5MB → 約 0.5MB ＝ 約 1/7」と**推定**していたが、実測は **約 1.6〜5 倍の削減**（12MP HEIC の代表ケースで 4.39MB → 1.31MB ＝ 約 3.4 倍）で、削減率を楽観的に見積もっていた。原因は縮小後サイズを解像度比だけで外挿したこと（ピクセル数は 1/4 以下になるが、JPEG のバイト数はディテール量に効くので比例して落ちない）。**膨張側の見立て（HEIC が JPEG 再エンコードで大きくなる）は方向・桁とも合っていた**（×1.64）。docs の数値は推定を消して実測に差し替えた。なお削減率は元画像の解像度に依存し、長辺が 2048px に近い写真ほど小さい（実測に 1668×2500 → ×0.61 のケースあり）。

**エンドツーエンドは未確認**: サンドボックスから PhotosPicker をタップ操作できないため（`osascript` / System Events が権限待ちでタイムアウト、`simctl` にタップ送出コマンドが無い）、実アプリの `handlePickerSelection` → `PhotoFileStore.save` を通した `<Documents>/photos/*.jpg` の実測は取れていない。上記は `ImageDownsampler` と同一の ImageIO オプションを実写真に適用した検証で、アルゴリズムの正しさ（2048px キャップ / 拡大しない / EXIF orientation=6 が幅高さの入れ替わった portrait ピクセルとして出力される）までを裏取りしたもの。UI 経由の確認は verification-checklist へ。

- 経緯: 当初 `paid-services.md` は「写真はローカル完結で課金対象サービスを使っていないから更新不要」と判断したが、**ユーザー指摘で誤りと判明**。同 doc の対象は冒頭で「課金が発生する**または将来発生しうる**もの」と定義されており、`Cloud Storage` は未採用のまま行が存在していた。判断の前に doc を開いていなかった（lessons 2026-08-01）

### 2026-08-01: ASO-6 ①② — 「写真は消える」ではなく「端末バックアップが唯一の引き継ぎ経路」

- 関連: `iosApp/iosApp/Features/Settings/SettingsView.swift`（データの保存先セクション）/ `iosApp/iosApp/Features/Account/AccountView.swift` / requirements 7-2・7-3・画面一覧

**tasks.md の ASO-6 ①「写真が機種変更で消える」は、実装を確かめたら無条件には成立しなかった**。写真は `Documents/photos/` に置かれ（`PhotoFileStore.swift`）、リポジトリ全体で `isExcludedFromBackup` は **0 件**。つまり iPhone 本体のバックアップ（iCloud / Finder）には含まれ、**バックアップから復元すれば写真も戻る**。requirements 7-2 の「iCloud Backup でバックアップする方針」の方が正確だった。

実際に失われるのは「**新しい端末にアプリを入れ直してサインインしただけ**」のケース（記録は Firestore から戻るが写真は戻らない）。したがってコピーを「写真は消えます」と書くと、バックアップから復元した人にとって嘘になり、逆の問い合わせを生む。**「写真はこの端末の中だけにある」+「引き継ぎ手段は端末のバックアップ」**という書き方に整理した。

**着手前の現状把握で、既存コピーの方が問題だった**: `AccountView` の匿名時説明が「Apple ID でサインインすると…**現在の訪問記録はそのまま引き継がれます**」で、写真に一切触れていなかった。サインインすれば全部持っていけると読める唯一の場所で、★1 に最も直結する。新規コピーを足すより**この一文を直すことが本丸**だった。あわせて「訪問記録」表記 4 箇所（本体 2 + `#Preview` 2）をフェーズ 7 以降の「コーヒー記録」へ統一。Preview は本体コピーの複製なので同時に直さないと乖離する。

**文言の確定**: ユーザーが 3 点を選択（設定 footer = **簡潔版** / アカウント匿名時 = **穏当版** / エクスポート footer = **行動を促す版**）。結果として「端末のバックアップで残してください」という行動喚起は**エクスポートの footer にだけ**載る形になった。エクスポートは「バックアップしている」という安心感が生まれる瞬間なので、写真の例外を伝える場所としてはむしろ適切。設定側は事実の提示に留め、バックアップ復元の可否には踏み込まない（iCloud 無料枠 5GB でバックアップ自体が失敗している人に「戻るはず」と誤解させないため）。

**トレードオフ: 設定画面に「未サインイン」状態は出さない**。`AccountViewModelBridge.account` は `onAppear()` を呼ぶまで nil で、`AppState` は `uid` は持つが `isAnonymous` を持たない。設定画面から購読を張ると `AccountView` の `onDisappear()` が pop 時に同じ購読を切って状態が固まる。ブリッジを init 購読に変えれば解けるが、**4 ブリッジすべてが `onAppear`/`onDisappear` 型で統一されている**ため、コピー変更のために観測ライフサイクルの規約を崩すのは割に合わないと判断した。静的コピーは匿名 / サインイン済みのどちらで読んでも正しい。条件表示は必要になった時点で別途。

**副産物**: requirements の画面一覧（設定画面の行）に**データエクスポートが載っていなかった**（実装は `SettingsView.exportSection` に存在）。今回の追記に合わせて補完した。

### 2026-08-01: ASO-1 レビュー依頼 — 「OFF 出荷」の助言を撤回した理由と、フラグを試行時に立てる理由

- 関連: `iosApp/iosApp/Utilities/ReviewPrompt.swift` / `RemoteConfigBootstrap.swift` / `AnalysisView.swift` / requirements 9-8

**助言を途中で変えた**。ASO-1 を最初に検討した時点では「実装はしてよいが、Remote Config で事実上 OFF にして出荷し、crash-free 率を見てから開放する」と述べた。理由は **ASO-6 ①②（写真消失・匿名アカウントの期待値管理）が未対応**で、★1 の原因を放置したままレビューを催促することになるため。その ASO-6 が同日に完了した（commit `e622afb`）ことで前提が解消したので、**ON 出荷 + キルスイッチ**に切り替えた（ユーザー確定）。オフのまま出荷すると星は 1 つも増えず、ASO-1 の価値がそのまま失われる。

**発火点を「傾向信号の初出」1 つに絞った**。候補には記録 N 件到達と共有カードの共有完了もあったが、①件数だけでは「価値を感じた」証拠にならない ②`ShareLink`（SwiftUI）は完了コールバックを持たず、共有とキャンセルを区別するには `UIActivityViewController` への置き換えが要る — の 2 点で見送り。傾向信号は「アプリが初めてユーザーについて何かを言い当てた」瞬間で、かつ信号が出るには相応の記録数（相関軸は最低 5 件 + 2σ ゲート）が要るため、engagement の代理指標を別途持たなくてよい。分析タブを開かないユーザーには永久に出ないという欠点は許容した。

**フラグは「提示を試みた時点」で立てる**。`AppStore.requestReview(in:)` は**実際にダイアログが表示されたかを返さない**（Apple 側の年 3 回上限、ユーザーの OS 設定で出ないことがある）。成功可否で分岐する設計にはできないので、試行 1 回で確定させる。結果として「OS 側の都合で出なかった」ケースでは二度と出ないが、これは Apple の設計思想（アプリ側に表示可否を握らせない）に沿った割り切り。

**`.task` と `.onChange` の両方から呼ぶ**。`AnalysisViewModel.onAppear()` は購読中なら no-op（2026-07-16 の再生成抑止）のため、2 回目以降のタブ訪問では新しい emission が来ず `.onChange` が発火しない。表示時点で既に `hasAnySignal = true` のケース（アップデート後の既存ユーザー、タブ再訪）を `.task` 側で拾う。マイルストーンフラグがあるので二重呼び出しは無害。

**Remote Config の fetch を中立な受け皿へ移した**。従来 fetch は `ApplePoiFilterConfig.fetchAndActivate()` が担っており、`RemoteConfig` はシングルトンなので activate は全キーに効く = レビュー用のキーも「たまたま読める」状態だった。**この依存は名前から読み取れず、「POI フィルタの設定を消したらレビュー依頼が固まる」という将来の事故になる**ため、`RemoteConfigBootstrap.fetchAndActivate()` を新設して `iOSApp.swift` の呼び出しを差し替えた（ロジックは移動のみ・挙動不変）。

**未設定時のフォールバックは「出荷時 ON」の生命線**で、取り違えると**意図と逆に一切発火しない**（しかもレビューが増えないだけなので壊れていることに気づく手段がない）。`FIRRemoteConfigValue.boolValue` は non-optional で、**キーが存在しないときは型の静的既定値 `false` を返す**ため、素直に読むと OFF になる。実装は `value.source != .static` で「remote にも in-app defaults にも値が無い」状態を判別し、そのときだけ `true` に倒している（Firebase SDK の `FIRRemoteConfigSourceStatic` = "The data doesn't exist, return a static initialized value." まで確認済み）。親が当初想定した `setDefaults` でも解けるが、`source` 判定の方が「未設定」と「明示的 false」を確実に区別できる。

**レビューで見つけた穴: `try? await Task.sleep` はキャンセルを飲み込む**。`try?` は失敗時に `nil` を返すだけで実行は次行へ進むため、遅延中に `.task` がキャンセルされても（= ユーザーが 1.5 秒以内に分析タブを離れても）そのまま提示に進み、**マップタブの上にダイアログが出る**。1.5 秒遅延は「何を評価するのか分かる状態で出す」ためのものなので、この経路では目的が反転していた。sleep 直後に `guard !Task.isCancelled`（**フラグを立てる前に return** = キャンセル回は試行に数えず次回再試行）を追加して是正。

- 残存制約だったもの → **同日 B-8 で解消**: `.onChange` 側は `Task { }` で非構造化タスクを起こすためキャンセルされず同じレースが残っていたが、`.task` + `.onChange` の 2 経路を **`.task(id: viewModel.readiness?.hasAnySignal)` 1 本に統合**して解消した。`.task(id:)` は ①表示時に 1 回 ②id 変化のたびに前タスクをキャンセルして再起動 ③ビュー消滅時にキャンセル、をまとめて満たすので、2 経路のカバレッジを包含する。**「初期状態 + 変化」を拾うために `.task` と `.onChange` を並べると、片方だけキャンセル可能という非対称が入る**のが根で、一般則として `.claude/rules/swift-ios.md` へ昇格（lessons 2026-08-01）。横断点検で `CoffeeEditorView` の写真取り込みにも同型が 1 件あり同時に是正した。

### 2026-08-01: implementation_note の棚卸し — 行数は閾値未満だったが、サマリは壊れていた

- 関連: 本ノート「現在生きてる方針サマリ」/ `.claude/skills/curate-doc/SKILL.md` / lessons 2026-08-01

`curate-doc` skill の Phase 0 で型を判定したところ **フロー型 / 1062 行 = 閾値 1200 行未満**で、規則上はアーカイブ不要だった。コードブロック比率も **1%（11 行）** で Phase 2（縮約）も効かない。つまり **skill のルーティングどおりに進めると「やることなし」で終わる状態**だった。

そこで present-tense の節（「現在生きてる方針サマリ」）だけコードと突き合わせたところ、**陳腐化 2 件 + 欠落 4 件 + コード側の誤り 1 件**が出た。日付付きエントリは*その時点の記録*なので古くなるのが正常だが、サマリは現在形で断言していて、しかも doc の冒頭にあって最初に読まれる。**skill のフロー型ルーティングに「present-tense の節にだけ Phase 1」を追加**した。

検出したもの:
- 陳腐化: `AppContainer` の引数個数「プライマリ 7 / iOS 6 / Android 5」→ 実際は **9 / 8 / 7** / 公開プロパティ列挙に削除済みの `beanProfileMatchUseCase`（2026-07-31 削除）
- 欠落: 公開プロパティに `savedCafeRepository` / `curatedCafeRepository` / `exportCoffeeRecordsUseCase` / `placesApiKey` / Firestore コレクションに `curatedCafes`
- コード側: `AppContainer` のクラス KDoc の Swift init シグネチャ 2 件が古く、**同ファイル内のセカンダリコンストラクタ KDoc と矛盾**（→ tasks B-9 に起票。棚卸し中にコードは触らない）

**原因は 1 つで、数え上げと構成要素の列挙**。要素が増えるたびに個数と一覧が同時に古くなるうえ、増やした本人はソースしか見ないので気づく契機がない。修正は個々の値を直すのではなく **「どこを真とするか」を書いて数えるのをやめる**方向に倒し、前文にルールとして明文化した。3 例目なので lessons へ昇格（`CuratedCafe.kt` 2026-07-25 / `SavedCafePin` 2026-07-27 / 本件）。

**アーカイブ（Phase 3）は見送り**（ユーザー確定）。前例の 2026-07-25 は 2026-06 を月末から 25 日後に凍結しており、2026-07 を月末 1 日後に凍結するのは早い。07-25〜07-31 の docs 棚卸し・ASO 系エントリは現在も参照中。**次の契機は 1200 行到達（あと約 135 行）か 8 月中旬**。

### 2026-08-01: ASO-3 オンボーディング再設計は見送り — ただし「ATT は後ろへ回せない」は誤りだった

- 関連: `iosApp/iosApp/Ads/AdConsentCoordinator.swift` / `iosApp/iosApp/Ads/BannerAdLoader.swift` / `iosApp/iosApp/AppState.swift` / tasks ASO-3（取り下げ）

ASO-3 に着手し、現状把握と技術的制約の確認を終えて grilling の Q1（初回起動に何を見せるか）を出した時点で、**ユーザー判断により現状維持で確定**。初回起動の「データ利用同意 → 広告プレプロンプト → ATT」の 3 連はそのまま残す。コード変更ゼロ。

**起票文の「価値訴求を先に出し、許諾は最初の記録を保存した後へ回す」は親が書いた提案**であって確定仕様ではなかった。tasks.md の備考が確定仕様のように読めたため、取り下げにあたって明記した（再検討時に前提を引き継がせないため）。

**着手前の直感が誤りだったので記録する**: 「広告 2 面（カフェ詳細 / マップ検索）は初回起動直後から到達できるので、ATT ダイアログを後ろへ回すと ATT 未実施のまま広告が出てポリシー違反になる」と考えて、これが再設計の最大の障害だと見ていた。**実際には障害ではない**。`AdConsentCoordinator.isPersonalizedAdsAllowed` は `ATTrackingManager.trackingAuthorizationStatus == .authorized` **のみ** true で、`.notDetermined`（未実施）も `.denied` と同じ扱いになる。`BannerAdLoader.makeRequest()` はこれを見て `npa=1` を付けるので、**ATT を訊く前の広告は自動的に非パーソナライズになる**。つまり ATT ダイアログの位置は広告の掲出可否と独立に決められる。将来 ASO-3 を再検討するなら、ここは制約として数えなくてよい。

**現状フローの構造**（再検討時の起点として）: `showConsentOnboarding`（Firestore `users/{uid}` の不在で true）→ `onConsentGranted` / `onConsentDeclined` → `presentAdConsentFlowIfNeeded()`（`UserDefaults` の `hasCompletedAdConsentFlow` で 1 回きり）→ `onAdPrePromptContinue()` → `AdConsentCoordinator.run()` → ATT。2 画面とも `RootTabView` の `.sheet` + `interactiveDismissDisabled()` で、既定タブはマップ。`CoffeeListView.emptyView` は `ContentUnavailableView` で**能動的な CTA ボタンを持たない**（説明文のみ）。

### 2026-08-06: プライバシーポリシー / サポートを GitHub Pages で公開

- 関連: `.github/workflows/pages.yml` / `docs/legal/*.html` / `iosApp/iosApp/Features/Onboarding/DataConsentOnboardingView.swift` / app-store-metadata §6.4

App Store 提出の必須項目 2 件（プライバシーポリシー URL / サポート URL）を解消。本文は 2026-07-21 に起草済みだったので、今回やったのは公開手段の選定とプレースホルダの消し込み。

**公開範囲を `docs/legal/` に絞った**。リポジトリは public なので「`develop` の `/docs` フォルダを Pages のソースにする」だけでも動くが、それだと `tasks.md` / `implementation_note.md` / `architecture.md` まで**Web サイトとして配信され検索インデックスの対象になる**。リポジトリが読めることと、サイトとして公開されることは露出の度合いが違う。GitHub Actions（`upload-pages-artifact` の `path: docs/legal`）にすれば、ソースを `docs/legal/` 単一に保ったまま 2 ページだけを配信できる。

- **Pages サイトの作成はワークフローからはできない**。当初 `actions/configure-pages@v5` の `enablement: true` で自動作成させて GitHub UI 操作を省く構成にしたが、初回実行が `Create Pages site failed. Error: Resource not accessible by integration`（run 31021287789）で落ちた。既定の `GITHUB_TOKEN` は `pages: write` を与えても **Create Pages site API に必要な admin 権限を持たない**（`pages: write` はデプロイ用で、サイトの新規作成は別枠）。`gh api -X POST repos/noricoffee/CoffeeVision/pages -f build_type=workflow` を**一度だけ人手で**叩いて有効化し、ワークフローからは `enablement` を外した。同じ構成を他リポジトリで組むときも「サイトの有効化は 1 回きりの手作業」と割り切るのが早い
- ページ間リンクは**相対パス**（`privacy-policy.html`）。同一公開ルートに並ぶので、絶対 URL にするとカスタムドメインへ移すときに壊れる
- 公開ルートが 404 になるのを避けるため `index.html`（2 ページへの目次）を新設
- 発火ブランチは `develop` 単独。`main` と併記すると同一サイトへの二重デプロイになり、どちらが最後に勝つかが不定になる

**副産物: 起草者向けの指示文が本文に混ざっていた**。`privacy-policy.html` §5（子どものプライバシー）の直後に `<div class="note">※ App Store の年齢レーティング設定と整合させてください。対象年齢の方針が異なる場合はこの記述を調整してください。</div>` があり、**そのまま公開すればエンドユーザーに見える**状態だった。app-store-metadata §7 の想定レーティング 4+ と本文（13 歳未満を主たる対象としない）は既に整合しているので、指示文は役目を終えたものとして削除。`.placeholder`（未確定箇所をアクセント色 + bold で目立たせる装飾）も同様に、値を埋めた後は「ここだけ強調された連絡先」に見えるので span ごと撤去した。

- 影響: 本文を改訂すると `develop` への push だけでアプリ内表示まで追随する（`DataConsentOnboardingView` は URL を開くだけで、文面を持たない）。ただし収集項目や第三者 SDK を変える改訂では app-store-metadata §6.1 / §6.3 と `PrivacyInfo.xcprivacy` の 3 点セットで整合を取る必要がある
- サポート用メールアドレスはアプリ専用に新規作成し（`noricoffee593@gmail.com`）、同日 2 ページへ反映して**プレースホルダは全て解消**。`mailto:` リンクにしてある（サポートページは連絡が目的なので、平文よりタップで開ける方が素直）

### 2026-08-06: アプリアイコン刷新 — 発端は意匠だったが、実体は SF Symbols のライセンス違反リスクの解消

- 関連: `iosApp/scripts/generate_app_icon.swift` / `iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/*` / `LaunchLogo.imageset/launch-logo.png` / ui-ux-guidelines「アイコン」/ `.claude/rules/swift-ios.md` / app-store-metadata 提出前チェックリスト

ユーザーの「コーヒー要素のみで Vision 感がない」という意匠の相談から入ったが、現状把握の時点で**別の、より重い問題**が出た。旧実装は `NSImage(systemSymbolName: "cup.and.saucer.fill")` をレンダリングして PNG に焼き込んでおり、**SF Symbols のライセンス条項はシンボルをアプリアイコン / ロゴ / 商標に使うことを禁じている**。提出時のリジェクト要因になり得たため、意匠変更と同時に自前パス描画へ全面移行した。`implementation-note-archive.md` の「AppKit + SF Symbol をレンダリングする Swift スクリプト生成」という記述は**本エントリで置き換わる**（アーカイブは当時の記録なので改変しない）。

**意匠の決定**: 候補を実際にレンダリングして比較する方式を取った（言葉での提案は判断できないため）。第 1 ラウンドの 4 案（俯瞰カップ=虹彩 / 豆=眼 / フレーバーホイール）は**全滅**で、失敗の仕方が全案共通だった — **「コーヒー」と「Vision」のどちらか片方に倒れて両立しない**。カップの記号性を上げると眼に見えず、眼として成立させるとコーヒー要素が消える。第 2 ラウンドでユーザーが出した「アイラインの中にカップを入れる」が解で、2 モチーフを並置ではなく**入れ子**にしたことで両立した。

- **線とカップを同一平面に置くと癒着する**: アイラインを線、カップを塗りで同じクリーム色にすると、皿の縁と下まぶたが接触して 1 つの塊になる（60px で判読不能）。採用案は両者に余白を取ることで回避している
- 皿の造形だけで 7 版を行き来した。**「1 つ前に戻して」が通じなかった**ため、全 7 版を 1 枚のシートに並べて番号で選ばせる方式に切り替えて決着（採用 = 版 2 = 細い輪の皿）。視覚的な差分は自然言語で同定できないので、選択肢を目に見える形で提示するのが早い

**SF の比率は目測せず実測した**: ユーザーが「SF Symbols のカップの方が良い」と判断したため、その理由を分解する必要があった。シンボルをビットマップに焼いて**行ごとのインク幅プロファイル**を取り、自前パスに転写した（皿は幅比 1.48 倍・胴のテーパーは 7%（自前は 25% だった）・取っ手は半径 0.101u で f=0.25〜0.52 に及ぶ、等）。最終的に行幅の最大乖離は 1 行で +0.070、他は全行 0.032 以内。

- **指標選択の落とし穴**: 当初 2 画像のインク領域の **IoU** で一致度を測っていたが、これは**線を細くする / インクを減らす方向の修正を必ず減点する**（交差が減り和集合はほぼ変わらない）。皿を塗り潰しから輪に変えた際、見た目は改善したのに IoU は 80.3% → 75.4% に下がった。**面積比の指標を形状一致の判定に使ってはいけない**ケースで、行プロファイル比較に切り替えて解決した

**LaunchLogo で踏んだ 2 点**:

- `drawCup` は「背景を描き直す」ことで穴（リム開口 / 取っ手の穴）を開ける設計なので、**透過キャンバスでは `NSColor.clear` + `.sourceOver` では穴が開かない**。`fill(using: .copy)` でアルファごと上書きする必要がある
- 初回生成物は**コンテンツの透明パディングが上 64px / 下 140px と非対称**で、bbox 中心がキャンバス中心より 38px 上にあった。`UILaunchScreen` は画像の**枠**を画面中央に置くため、これはそのまま起動画面上の表示ずれになる。修正は数値のハードコードではなく「描画結果から alpha>0 の bbox を実測して中央に寄せる」実装にさせた（マークサイズや文言を変えたときに再発しないため）。最終値は左右 97/97・上下 101/101

**検証手法**: 親が先に参照 PNG（light / dark / tinted）を作っておき、`ios-engineer` の生成物と `cmp` で**バイト一致**を要求した。幾何定数が多くレビューでの目視照合が現実的でないため、一致 / 不一致の二値に落とした。3 枚とも一致。副次的に、`renderLaunchLogo` の後続修正がアイコン側へ波及していないことも同じ `cmp` で確認できた。

- 副作用: light バリアントの背景下端色が `#5A3A22` → `#4E3020` に変わっている（新意匠のコントラスト調整。dark / tinted は不変）
- `grep -rn "systemSymbolName" iosApp/` = **0 件**が、以後この問題の回帰検出手段になる（app-store-metadata の提出前チェックリストに項目化した）

### 2026-08-06: アプリが「英語バンドル」として振る舞っていた — 単一言語アプリの死角

App Store 用スクリーンショットの目視中に、記録エディタの `DatePicker` が日本語端末でも `Aug 6, 2026` と英語表記になることを発見した。実装作業ではなく**撮影という別作業で見つかった**もので、そのまま提出していれば日本のユーザーに英語日付が出ていた。

原因はアプリの有効ローカライゼーションが `en` のみだったこと（`project.pbxproj` の `developmentRegion = en` / `knownRegions = (en, Base)` / `.lproj` 0 件 / `CFBundleLocalizations` 無し）。iOS は端末が `ja_JP` でも `Locale.current` を英語にフォールバックさせる。

**修正は `.lproj` を新設しない最小構成を採った**: `developmentRegion` を `ja`、`knownRegions` に `ja`、`Info.plist` に `CFBundleLocalizations = [ja]`。文字列リテラルは 1 つも変えていない。既存 docs の「UI は日本語のみ・`.xcstrings` / `.lproj` は未整備」という記述と矛盾しない — 今回直したのは**文言ではなく OS が判定する実効言語**であり、多言語化に踏み出したわけではない。App Store で英語(U.S.) ロケールを「キーワード枠としてのみ」使う方針（app-store-metadata §4）にも影響しない。

**検証はビルド成果物の `Info.plist` を実読みして行った**（`CFBundleDevelopmentRegion = ja` / `CFBundleLocalizations = [ja]` / `.lproj` 0 件）。pbxproj の diff もビルド成功も実効ロケールの証明にならない点は、2026-07-28 の `UIDeviceFamily` 検証と同じ構図。

**副産物 — 修正が別の潜在バグを顕在化させた**: 横断点検で `SettingsView.writeExportFile` の `DateFormatter` が `locale` 未設定なのを検出した。固定 `dateFormat = "yyyyMMdd"` でも**暦法はロケール依存**なので、端末の暦法が和暦だとファイル名の年が和暦年になる。修正前は `en` フォールバックでグレゴリオ暦に落ちていたため、**今回の `ja` 化で初めて踏みうる状態になった**。「ロケールを正しくする修正が、ロケール依存の別バグを起こす」という順序があるので、この種の修正では**依存箇所の点検を修正と同じ変更に含める**必要がある。

**さらにその点検が、初期から存在した実バグを掘り当てた**: `CoffeeEditorView` の `LocalDate ↔ Date` 変換が `Calendar.current` を使っており、端末の暦法が和暦だと記録日が壊れる。親が PoC で実測したところ、表示は `2026-08-06` → **`4044-08-06`**、Firestore への保存値は **`0008-08-06`**（元号年が西暦欄に入る）で、**永続データまで壊れる**性質だった。`Calendar(identifier: .gregorian)` に固定し（タイムゾーンは `TimeZone.current` を維持）是正。未リリースのため実ユーザーへの被害はない。

**実装方針として固定する**: `LocalDate ↔ Date` の変換は `CoffeeEditorView.gregorianCalendar` 経由で行い、**`Calendar.current` は使わない**。`Calendar.current` は「ユーザーに見せる書式」のための API であって、ドメインの西暦年月日を変換するための API ではない。同じ理由で固定書式の `DateFormatter` には `locale = en_US_POSIX` を明示する（Apple QA1480）。

教訓（`.lproj` 無しでも実効言語の設定は要る / `plutil -extract` の破壊挙動 / `Calendar.current` の暦法依存）は lessons 2026-08-06 に記録。

### 2026-08-06: テイスティングスライダーの tap-to-seek — ジェスチャー共存で 2 段の副作用を踏んだ

ユーザー報告「つまみを正確に掴まないと動かせない。つまみじゃないところをタップしても変わるようにしたい」への対応。標準 `Slider` はトラックのタップを無視し thumb のドラッグしか受けない仕様なので、SwiftUI の範囲では自前ジェスチャーに置き換えるしかない。

**構成**: 標準 `Slider` を `.allowsHitTesting(false)` で**描画専用**にし、同じ frame に重ねた `Color.clear` の `DragGesture(minimumDistance: 0)` で駆動する（`TappableTastingSlider`、`CoffeeEditorView+Sections.swift` 内 private）。トラック / thumb を自前描画する全自作は見た目の再現コストが高いので採らなかった。値の算出は **thumb 半径ぶんのインセット補正**込み（トラックの描画幅は View 幅ではなく左右に半径ぶん詰まっている。補正しないと両端に到達できない）。thumb 直径はシミュレータでの実測手段がないため標準サイズの近似値 **28pt** を定数化した — 目視でズレたらこの定数を調整する前提でコメントを残してある。触覚は `.sensoryFeedback(.selection, trigger: value)` で標準 Slider の step 移動時のフィードバックを代替。

**この変更の本体は tap-to-seek そのものではなく、`Form`（List）内でジェスチャーを共存させる部分だった**。初回実装から親のレビューで 2 段の副作用が出た:

1. **`.gesture` はスクロールを奪う** → `.simultaneousGesture` に変更（ios-engineer の判断）。だが `DragGesture(minimumDistance: 0)` は **touch down の瞬間に `onChanged` が発火する**ため、今度は「Form を縦スクロールしようとしてスライダー行に指を置いただけで、その x 位置の値に書き換わる」が発生する。テイスティングは 5 本並ぶので指が乗る確率が高く、**保存されるデータが黙って変わる**方向のバグだった。対策は、ジェスチャー開始時の値を保持し、縦方向の移動が支配的（`|height| > 10pt` かつ `|height| > |width|`）になったらスクロール意図と判定して**開始値へロールバック**し、以後そのジェスチャー中は更新しない。一瞬値が変わって戻るちらつきは許容した（データが壊れるより軽い）
2. **その状態リセットを `onEnded` だけに置くと固着する**。SwiftUI のジェスチャーは他のジェスチャーに競り負けて**キャンセル**されたとき `onEnded` を呼ばない。スクロールが本格的に始まった経路でこれが起きると `isScrollDominant = true` が残り、**そのスライダーが以後まったく反応しなくなる**（＝1 の対策が 1 より悪い壊れ方を生む）。対策は `onChanged` 側で毎イベント「これは新しいジェスチャーの最初のイベントか」（`translation` が 0.1pt 未満）を判定して状態をまとめて初期化すること。`onEnded` のリセットは保険として残した

**一般化**: `ScrollView` / `List` の中に `minimumDistance: 0` のドラッグジェスチャーを置くときは、①スクロールを奪わないか ②touch down だけで副作用が出ないか ③ジェスチャーがキャンセルされても状態が復元するか、の 3 点をセットで確認する。①だけ見て `.simultaneousGesture` にすると ②③ が残る。**状態リセットをジェスチャー終端イベントに依存させず、開始イベント側で初期化する**のが ③ の一般解。

ビルドは親がフラグ無しの `xcodebuild` で再検証済み（`> Task :shared:framework:...` が走った上での `** BUILD SUCCEEDED **`）。実操作（タップ位置の一致 / 端 1・10 への到達 / スクロール共存 / 固着の回帰 / VoiceOver）は verification-checklist パス 2 へ移送。

### 2026-08-06: アカウント削除の消し残し — 「消せなかった」ではなく「消す対象を数えていなかった」

- 関連: `DeleteAccountUseCase` / `AuthRepository` / `AuthRepositoryAndroidImpl` / `AuthRepositoryIosImpl.swift` / `data-model.md` §3.1 / `docs/legal/privacy-policy.html`

verification-checklist パス 6「アカウント削除の revoke 完走」を実機で実行中、**Firestore コンソールで `users/{uid}/coffees` は空になっているのに `savedCafes` が残っている**のをユーザーが発見した。`DeleteAccountUseCase` は coffees のループ削除 → `deleteAuthUser()` の 2 段しか持っておらず、**`users/{uid}` 配下 3 要素のうち 2 つ（ルートドキュメントと `savedCafes`）に一度も触れていなかった**。

**発見経路が示唆的**: revoke（Apple 側のトークン失効）の検証をしていて、その過程で開いた Firestore コンソールの表示から見つかっている。テストも型検査もこの種の欠落を検出しない — 消し忘れたコレクションは、コードのどこにも現れないからだ。既存テストは「coffees が消えてから `deleteAuthUser` が呼ばれること」を検証しており、**書いた分については正しかった**。

**性質**: 単なるゴミ残りではない。`firestore.rules` は `users/{uid}` 配下を `request.auth.uid == uid` でガードしているので、Auth ユーザーを削除した瞬間に**残留データは本人が二度と読めず消せない、運営側からのみ見える永久孤児**になる。しかも公開済みプライバシーポリシー（`docs/legal/privacy-policy.html`「アカウント削除により削除されます」「削除時にはクラウド上の記録データも削除されます」）と要件 1-4 に対する明確な違反で、App Store 5.1.1(v) の観点でもリリースブロッカー。

**修正は 4 段の順序が仕様そのもの**（savedCafes → coffees → ルート doc → `deleteAuthUser`）。順序が効く理由が 2 つあり、どちらも守らないと消し残る:

- **Firestore はドキュメントを消してもサブコレクションをカスケードしない**ため、サブコレクションが先
- **Auth ユーザー削除後は Rules で `users/{uid}` 配下に一切触れなくなる**ため、Auth 削除は必ず最後。ここを逆にすると「削除処理は成功したのに永久に消せないデータが生まれる」

**savedCafes 側に新しい API を足さずに済んだ**のが設計上の収穫。当初はローカルの `deleteByUser` クエリとリモートの `removeAll(userId)` を追加する想定だったが、`SavedCafeRepository` の既存 `observeAll(userId)` + `delete(userId, placeId)` で足りる（`SavedCafeRepositoryImpl.delete()` がローカル DB とリモートの両方を消し、`AppContainer` の既定 `WritePolicy.PropagateRemoteFailure` によりリモート削除失敗が例外として伝播して削除全体が中断する）。**coffees の削除と全く同じ形**になり、SQLDelight の変更もプラットフォーム実装 2 本（Swift / Android）の変更もゼロで済んだ。新規 API が要ったのは `users/{uid}` ルート doc を消す `AuthRepository.deleteUserProfile()` の 1 本だけ。

**「coffees は削除せず将来の好み分析に使う」案を検討し、不採用にした**（ユーザー提案）。目的自体は正当だが、この形では成立しない:

- **公開済みのプライバシーポリシーと正面から矛盾する**。既に対外的に「削除されます」と約束しているものを実装が残す側に倒すと、単なる仕様差ではなく虚偽の表示になる
- `users/{uid}` 配下に残す形は、匿名化を一切伴わない**個人紐付きデータの保持**そのもの。しかも Rules の構造上「本人だけがアクセスできず運営だけが持っている」状態になり、説明が難しい
- 分析に必要なのは 1 杯ごとの個票ではなく**集約値**（テイスティング 5 軸の平均、産地・焙煎の傾向）で、個票の保持は要件から導かれない

将来やるなら、**削除時に残すのではなく、同意に基づいて最初から個人と切り離した派生データを別の場所に置く**設計になる。枠組みは既に 12-D（9-6 協調フィルタ / `analysis-model.md` §2）にあり、`recommendationConsent` と `sharedTasteProfiles` がそれ。ただし現行設計の `sharedTasteProfiles/{uid}` は **uid キーなのでアカウント削除時に消す対象**であり、「分析用に残す」用途にはそのままでは使えない（uid と切り離した形が要る）。実装時に必要なのは 4 点セット: ①`users/{uid}` の外に出す ②収集時点で同意を取る（削除の瞬間に許諾を求めるのは同意の任意性として筋が悪い）③uid を外すだけでなく再識別性を評価する（テイスティング 5 軸 + カテゴリ 4 軸 + 高評価カフェ座標は母数が小さいうちは容易に特定できる。9-6 の「最小 K 未満は推薦を出さない」は**表示側**の対策であって保存側の話ではない）④プライバシーポリシーと App Store Connect のプライバシー申告の改訂。**この 4 点が揃うまでは全削除が唯一の正しい挙動**。

**既存の孤児データはクライアントから消せない**（Rules 上、削除済み uid のパスには誰も到達できない）。検証で作った分と過去の削除分は **2026-08-06 にユーザーが Firebase Console から手動削除済み**。未リリースのため実ユーザー分は存在しない。**この「後始末が手作業でしかできない」性質が、削除経路の消し漏れを他のバグより重くしている** — 修正をリリースしても、それ以前に発生した孤児データは自動では回収されない。

### 2026-08-07: App Store ガイドライン全体レビュー — 「動くから守れている」が成立しない要件を 3 件検出

ユーザー依頼で [App Store Review Guidelines](https://developer.apple.com/jp/app-store/review/guidelines/)（2026-06-08 版）とアプリ全体を突き合わせた。docs の記述ではなく実コードで確認し、**リジェクト実績のある条項に該当する欠落を 3 件**検出して同日中に修正した。5.1.1(v) アカウント削除 / 4.8 ログインサービス / 2.5.18 広告 / Required Reason API / 1.2 UGC など**他 12 項目は確認して問題なし**（tasks.md の起票行に一覧）。

**なぜ実装レビューでは出なかったか**が今回の要点。3 件とも「書かなかったこと」による欠落で、コンパイラ・テスト・lint・動作確認のいずれにも現れない。

1. **プライバシーポリシーにアプリ内から到達できなかった（5.1.1(i)）** — リンクは初回起動のオンボーディングにしか無く、同意/拒否のどちらでも Firestore `users/{uid}` が作られるため **2 回目以降の起動で到達不能**になっていた。「実装した機能が後から到達不能になる」型のバグで、実装時点では正しく動いていた。設定の「データとプライバシー」に 2 リンク（ポリシー + サポート）を追加し、URL は `LegalLinks` に集約してオンボーディング側と共有した
2. **Google の帰属表示が皆無だった（5.2.2）** — 詳細は lessons 2026-08-07。教訓としては「規約の一部だけを doc 化すると残りは存在しない要件になる」（`paid-services.md` は広告ターゲティングの規約だけ書いていた）
3. **ライセンス表示に Google 系 3 件が欠落（5.2.1）** — GoogleMobileAds を `Apache 2.0` と書かないこと（SPM ラッパーのライセンスであって `.xcframework` 実体は AdMob 利用規約）

**写真の作者帰属は永続化まで踏み込む判断をした**（ユーザー確定）。`Cafe.photoAttributions` を `photoReferences` と同じ順序・長さで持ち、SQLDelight 2 テーブル + migration 7 + Firestore キーまで通す。**「表示のときに取り直す」案は Places の課金がリクエスト単位なので採らない** — カフェ詳細は DB スナップショット由来だと Details を叩かない設計（フェーズ 16 の抑制）で、帰属のためだけに毎回叩くとコスト構造が変わる。未リリースでスキーマ変更が最も安いタイミングだったことも後押しになった。

**判断として明示的に線を引いたもの**:

- **帰属を出す面は 4 面に限定**（カフェ詳細 / マップ検索結果シート / ピン選択カード / エディタのカフェ検索シート）。記録一覧・記録詳細・共有カード・保存済みリストが表示する店名は**保存済みスナップショット = ユーザー自身の記録の表示**であって Places の生データ提示ではない、という整理。全 10 面以上に出すと UI が帰属だらけになる
- **小サムネイルの作者帰属は省略**。Places のポリシーが「ギャラリーのようにスペースが限られる場合、より大きな版で完全な帰属にアクセスできるなら省略可」と認めており、タップ → カフェ詳細の写真帯で作者名に到達できることが根拠。**この緩和は導線がある前提なので、将来カフェ詳細から写真帯を消すなら再検討が要る**
- **`CoffeeRecord` への `Cafe` スナップショット永続保存自体はグレーのまま残した**。Places のポリシーで無期限保存が明示的に許されるのは place ID のみで、店名・住所・座標の永続保存は規定に照らすと灰色。ただし記録アプリとして「訪れた店の名前が記録に残る」ことは成立要件なので、リスク認識に留めて変更しない

**年齢制限アンケート（2.3.6）に広告の項目が無い件は未着手**。`app-store-metadata.md` §7 の想定回答表が暴力/ギャンブル/UGC/Web/位置情報の 5 行だけで、ASC が問う「アプリ内広告の有無」に触れていない。ASC 側は 2026-08-06 に回答済みなので**実際の回答と doc の突き合わせが要る**（4+ 維持は広告があっても可能）。ユーザーが今回の修正対象を 1・2・4 に絞ったため tasks.md に残してある。

**3 件とも 2026-08-07 にユーザーが目視確認済み**（設定の 2 リンクが Safari で開くこと / ライセンス 3 行 / 4 面の Google Maps 帰属と写真の作者バッジ）。`verification-checklist.md` からは規約どおり項目を削除した。コミットは意味単位で 3 本に分割している（`df89136` 法務リンク / `f20edf2` ライセンス / `e43d369` 帰属表示）— 前 2 本は `Cafe` に触れないため、`photoAttributions` の必須引数追加を含む 3 本目より前の時点でもビルドが通る。

### 2026-08-07: マップのピン重なり — 間引きもクラスタリングも採らない（UX-2 取り下げ）

- 関連: `iosApp/iosApp/Features/Map/AppleNearbyCafeLoader.swift` / `MapPins.swift` / tasks.md UX-2

UI/UX レビューで「渋谷のような密集地でピンが 5〜6 個重なり、下のピンがタップ不能に見える」と指摘された件。**周辺ピン同士を画面距離 28pt で間引く実装を入れたが、実測の結果ユーザー判断で取り下げ・revert した**（コミット `05b7b23` / `6ea9197` は reset 済みで履歴に残っていない）。

**実測値（渋谷、可視半径 988m、地図実寸 440×811pt）**:

| 段階 | 件数 |
|------|------|
| `MKLocalSearch` の生の返却 | 50 |
| 名前ヒューリスティック除外後 | 50（除去 0） |
| ネガティブキャッシュ除外後 | 50（除去 0） |
| クロスファミリ 40m 除外後 | 38 |
| **28pt 重なり間引き後** | **6** |

**結論: 密集地では「ピンが重なる」のが実データの正常な姿であり、重なりを消すことは情報を消すこと**。38 → 6 は 84% の欠落で、タップ不能なピンを救うために大多数の店を見えなくしている。しきい値 28pt はピン直径と同値＝重なりゼロの下限なので、これ以上緩めれば重なりは解消せず、間引きという方向自体が成立しない。

- クラスタリングも採らない。**SwiftUI の `Map` にクラスタリング API が無い**（`clusteringIdentifier` は UIKit `MKAnnotationView` 専用）。自前グリッド実装は `MapProxy` 経由の座標変換と 7 種類目のピン追加を伴い、`MKMapView` への移行は `UserAnnotation` / `Annotation` 内 `NavigationLink` / `MapCameraPosition` / `.onMapCameraChange` への依存ごとマップ全体の書き直しになる。**将来 `MKMapView` へ移行する別の理由が生じたときに、標準クラスタリングをついでに得るのが唯一まともな経路**。
- 副産物として確認できた事実 2 つ:
  - **`MKLocalSearch` の返却は 50 件で頭打ち**（渋谷で raw=50 ちょうど）。可視領域が広いと 50 件が中心付近に偏るため、「マップの一部にしかグレーピンが出ない」ように見えることがある。間引きとは独立の制約。
  - **名前ヒューリスティック除外とネガティブキャッシュは渋谷で 1 件も除去していない**（50 → 50）。ノイズ除去として効いていない可能性があり、`ApplePoiFilterConfig`（Remote Config）の見直し余地がある。ただし今回は未調査。
- **経緯に 1 つ実装上の落とし穴があった**（間引き自体は捨てたが、パターンは再発しうるので残す）。当初 m/pt を `radiusMeters / (mapContainerSize.height / 2)` で手計算していたが、`mapContainerSize` は外側 ZStack の `GeometryReader` 実測値でセーフエリアを含まない一方、`Map` 自身には `.ignoresSafeArea(.container, edges: [.top, .horizontal])` が付いており実描画範囲はより大きい。`radiusMeters` は `Map` の実 `region.span` 由来なので分母だけが小さくなり、換算が過大評価されていた。**`MapProxy.convert(_:to:)` で座標→画面ポイントへ直接変換すれば、m/pt の手計算・`cos(緯度)` 補正・セーフエリアの一致がすべて不要になる**。SwiftUI で「実測サイズを分母に使う換算」を書きたくなったら、まず座標変換 API があるか探すこと。

### 2026-08-07: 営業状態の緑 / 赤は維持する（UX-5 取り下げ）

- 関連: `iosApp/iosApp/Features/CafeDetail/CafeDetailView.swift:141-148` / `Features/Map/CafeSelectionCard.swift:97-104`

UI/UX レビューで「閉店中を赤で出すのは、iOS で赤がエラー / 破壊的操作の色なので警告に見える」と指摘したが、**ユーザー判断で現状維持**。**Google マップが閉店中を赤で表示しており、マップの慣習から外れていない**ことが根拠。

- `ui-ux-guidelines.md` のカラー役割表が `.red` を「危険操作」に割り当てており、「テイスティングを削除」等と赤を共有する点は**認識のうえで許容**する。表に例外を書き足すこともしない（役割表はあくまで既定で、マップ慣習が優先する領域があるという整理）。
- 代替案として検討したのは ①閉店時のみ `.secondary`（営業中の緑は維持）②両方 `.secondary` ③閉店時を `.orange`。③はオレンジがおすすめピンの概念色と衝突するため候補としても弱かった。**再提案しないこと。**
- **別件として未解決で残っているもの**: 同じ状態の文言が `CafeDetailView` では「営業時間外」、`CafeSelectionCard` では「終了」で割れている。配色とは独立した問題で、「終了」は閉店＝廃業とも読める。tasks.md UX-5 の備考に残置。

### 2026-08-07: コーヒー記録一覧の行レイアウト（UX-7 / UX-8）

- 関連: `iosApp/iosApp/Features/CoffeeList/CoffeeListView.swift`（`CoffeeRow`）/ `Utilities/PhotoFileStore.swift`

行の左に写真サムネイル（56pt 角丸）を追加し、コーヒー名を読めるようにする。**主従は入れ替えない**（カフェ名 `.headline` / コーヒー名を `.subheadline`+`.secondary` → `.body`+`.primary` へ格上げ）。

- **入れ替え案（コーヒー名を主）は不採用**。「同じカフェが連続すると何を飲んだか追いにくい」という指摘には効くが、**コーヒー名が「本日のコーヒー」のような一般名のとき行の情報量が落ちる**（新規作成時の name 初期値がまさに「本日のコーヒー」= requirements 2-9）。サムネイルが入れば想起の手がかりは写真が担うため、格上げだけで足りるという判断（2026-08-07 ユーザー確定）。
- **写真が無い記録でもサムネイル枠は常に確保する**。`if` で枠ごと消すと兄弟がシフトして行ごとにテキストの開始位置がズレる（`.claude/rules/swift-ios.md` の既存規則）。**写真ゼロの記録の方が多数派**なのでここが設計の中心で、プレースホルダは薄いグレー地 + `cup.and.saucer` のグレーアイコン。
- **既存の写真読み込み経路はリストに転用できない**。`PhotoFileStore.loadImage(fileName:)` は `UIImage(contentsOfFile:)` によるフルデコードの同期 API で、詳細画面（数枚・1 画面）では妥当だが、**スクロールするリストで 1 行ごとに長辺 2048px の JPEG をデコードすると確実にカクつく**。`ImageDownsampler` は保存時用（`Data` 入力 → JPEG `Data` 出力）でそのままは使えない。サムネイル用に「ファイル URL から `CGImageSourceCreateThumbnailAtIndex` で縮小デコード + メモリキャッシュ + 非同期」の経路が要る。**`PhotoFileStore` の「絶対パスを呼び出し側に露出しない」という設計方針は維持すること**（同ファイル冒頭に明記）。
- **日付の短縮（`2026/08/06` → `6日`）は今回対応しない**。月セクションヘッダ「2026年8月」と重複しているが、ユーザー判断で保留。

追記（2026-08-07、実装後）: サムネイルの縮小デコードは `PhotoFileStore.loadThumbnail(fileName:maxPixelSize:) async` に置き、`NSCache` でメモリキャッシュする。**この関数がメインスレッドを離れて走ることは言語モードに依存している** — `PhotoFileStore` に actor / `@MainActor` 注釈が無いため `nonisolated` で、SE-0338 により `nonisolated` な async 関数はグローバル実行キューで実行される。`project.pbxproj` が `SWIFT_VERSION = 5.0` かつ `SWIFT_UPCOMING_FEATURE` / `SWIFT_DEFAULT_ACTOR_ISOLATION` を指定していないことを実確認済み。**Swift 6.2 の `NonisolatedNonsendingByDefault` を有効にすると `nonisolated` async は呼び出し元アクター上で走るようになり、この関数はメインスレッドでデコードするようになる**（ビルドは通り、スクロールが重くなるだけなので気づきにくい）。言語モードを上げるときはここを `@concurrent` 等で明示すること。

**追記（2026-08-08、Swift 6 移行で決着）**: 上の予告どおりになったため `loadThumbnail` に **`@concurrent` を明示**した（SW6-3）。移行時に `iosApp` 全体の `async` 関数 23 本を洗い、同型（`nonisolated async` にバックグラウンド実行を暗黙に期待している）は**この 1 件のみ**だったことを確認済み。**この件はコンパイラの診断が一切出ない** — 移行の全診断 32 件を採取した中に `loadThumbnail` に関するものは 1 件も無く、上の予告を doc に残していなかったら気づけなかった。同種の落とし穴は `.claude/rules/swift-ios.md` に規約として昇格させた。

`maxPixelSize` は `56pt × @Environment(\.displayScale)`。`UIScreen.main` は iOS 26 で deprecated なので使っていない。

### 2026-08-07: 好み一致の推薦理由をカフェ詳細へ移設（`RecommendationMatchSheet` 廃止）

- 関連: `shared/feature/cafe-detail/.../CafeDetailViewModel.kt`, `shared/framework/.../AppContainerViewModelFactory.kt`, `iosApp/iosApp/Components/PreferenceMatchViews.swift`（新設）, `iosApp/iosApp/Features/CafeDetail/CafeDetailView.swift`, `iosApp/iosApp/Features/Map/MapTabView.swift`

ユーザー報告「好み一致のピンタップで『好みのコーヒーがあった店』シートが出る。そのせいでカフェ詳細に辿り着けない / 直感的ではない」。

**まず遷移バグを疑ったが、これは外れだった**。`onOpenDetail` が「シートを閉じる状態変更」と「同じ `NavigationStack` の `path` への `append`」を同一クロージャで同期実行しており、SwiftUI で push が握り潰される既知パターンに形が一致していたため原因と見立てたが、**ユーザー実機確認で「ピン経由・チップ経由とも遷移する」ことが判明**。同ファイルの `CafeSelectionCard`（`MapTabView.swift`）は `append` を先に呼ぶ逆順で書かれており、その非対称さも傍証に見えたが結論には結びつかなかった。**コードの「形」が既知バグに一致することは、そのバグが起きている証拠にはならない**。

**実際の問題は構成**だった。①同じ見た目の丸いピンなのに好み一致だけ行き先が違う（他 4 種は `NavigationLink` で詳細直行）②詳細への導線がフッター状の帯で主アクションに見えない ③その帯だけ `Color(.secondarySystemBackground)` の不透明色を敷いており、半透明 material のシート上で 1 枚だけ白く浮いていた（ユーザーがスクリーンショットで指摘）。

**採った解**: 推薦理由は「その店が好みに合う理由」= 店に属する情報なので、経由地のシートではなく**カフェ詳細のセクション**に置く。ピンタップは他ピンと同じく直行にする。

- **副次的だがこちらが本質的な利得**: 旧構成では**好み一致ピンをタップしたときしか理由が見られなかった**。コーヒー記録一覧や検索から同じ店を開いても「この店は好みに合っている」と分からない。移設後はどの経路から開いても出る。
- **不採用案**: (a) シートを残してボタンを `.borderedProminent` 化 — ③は直るが①②の「1 種だけ挙動が違う」が残る (b) 直行化 + 理由シート廃止 — 軸ごとの詳細（一致ラベル・代表記録・評価）が失われ、残るのは一覧行の 1 行サマリだけになり推薦機能の説明力が落ちる。
- **KMP 側**: `CafeDetailViewModel` に `CafeRecommendationProvider` を注入し `UIState.matches` を追加。provider は `makeMapViewModel` と同じく `AppContainer` ファクトリ内で都度生成（DI コンテナ化は既存方針どおり YAGNI）。再計算が二重に走る件は analysis-model §2 の注記参照。
- **`preferenceMatchAxisLabel` の置き場**: Map と CafeDetail の 2 feature から使うため `Features/Map/` から `Components/PreferenceMatchViews.swift` へ移した。軸ごとの行 View も `PreferenceMatchRow` として同居させ、シート本体だけを削除。
- **`MapTabView.swift` は 804 → 771 行**。分割目安 800 行を下回った（M-1 以降の分割作業とは別に、機能削除で解消した形）。

### 2026-08-08: Swift 5 → Swift 6 移行（既定 MainActor 分離を選択）

`iosApp` を `SWIFT_VERSION = 6.0` + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY = YES` へ移行（SW6-1〜7）。Debug / Release とも警告 0・エラー 0（残る 1 件は Swift 6 と無関係な `UIWindow()` の iOS 26 deprecation）。

**なぜ既定 MainActor 分離か**: 素の Swift 6（nonisolated 既定）だと UI 側に `@MainActor` を書き足す量が増える一方、CoffeeVision の Swift コードはほぼ全部が UI か UI ブリッジで、実際に MainActor を離れるのは Kotlin interface の実装クラスだけ。**多数派を既定にして少数派を明示する**方が差分も小さく、意図も読める。

**SKIE 側は移行の影響を受けない**（着手前の懸念だったが実測で否定された）。`SharedLogic.swiftmodule` の `.swiftinterface` は `-language-mode 5 -enable-library-evolution` でビルドされており、アプリを Swift 6 にしても Swift 5 セマンティクスで再構築される。**`shared/**` は 1 行も触っていない**。

#### 使い分けの判定軸（正本は coding-conventions §2.5 / kmp-bridge「Swift 6 の並行性境界」）

「既定から外す 3 手段」のうちどれを使うかは、**そのクラスが誰にどのスレッドで生成・破棄されるか**で決まる。同じ `deinit` の警告でも答えが逆になる:

- **ViewModel ブリッジ 8 本** → `isolated deinit`。SwiftUI / `AppState` から MainActor 上でのみ保持・破棄されるため、ホップが実質ノーオペになる
- **`CallbackFlow` / `CallbackFlowOptional`** → `nonisolated final class` + plain `deinit`。Kotlin ランタイムが任意スレッドで破棄するため、`isolated deinit` にすると **Firestore リスナの解放が MainActor へ非同期にホップして遅延し、同一クエリの即時再購読で旧リスナが生き残る競合窓ができる**（読み取り課金にも響く）。`paid-services.md` を更新しなかったのは、この判断が**コスト構造を現状維持するためのもの**だから

検査を外す手段は**穴の広さで選んだ**。`@preconcurrency import SharedLogic` はファイル内の SharedLogic 型すべての検査を外すため、**`@Sendable` クロージャの引数型に Kotlin 型が直接現れる 3 ファイル**（`BeanProfileRepositoryIosImpl` / `CuratedCafeRepositoryIosImpl` / `CoffeeInsightProviderIosImpl` — Kotlin interface の `completionHandler` が該当し、関数シグネチャ自体の要件なのでプロパティ単位の対処が構造的に効かない）に限定した。プロパティ 1 個の問題は `nonisolated(unsafe)` で済ませている（`AppState.container` / `PlacePhotoLoader.repository`）。なお `@preconcurrency import` は**移行前から 4 ファイルに存在していた**（`SearchByTasteProfileTool` / `SearchCoffeeRecordsTool` / `TastePreferenceConversionView` / `TasteSearchSheet`）ので、今回増えたのは 3 ファイル。

`nonisolated` にしたクラスの可変キャッシュは `OSAllocatedUnfairLock` + `@unchecked Sendable` に置き換えた。**`nonisolated` を付けた瞬間にそのクラスの可変状態は無保護の共有可変状態になる**ため、セットで考える必要がある。

#### 副次的に直ったもの

`CoffeeInsightProviderIosImpl` を `nonisolated` にしたことで、**オンデバイス LLM 推論（Foundation Models）がメインスレッドから外れた**。既定 MainActor 分離の下では、Obj-C プロトコル要件の `__summarize` 系は暗黙に nonisolated 化される一方で内部の private メソッドは MainActor に留まり、`Task { await self.generateInsight(...) }` が毎回メインへホップして推論していた。**警告は出ないし、移行前も同じ構造だった**（移行で悪化したのではなく、移行の副産物として直った）。実機での UI 挙動確認は verification-checklist に起票。

#### 計測方法の落とし穴

**`xcodebuild` のコマンドライン引数で `SWIFT_VERSION=6.0` 等を渡してはいけない。** SPM 依存パッケージ全体に波及し、`FirebaseCoreInternal` が 4 エラーで落ちて iosApp のソースに 1 ファイルも到達しない。設定は `Base.xcconfig`（アプリターゲット限定）に書いて計測する。

**`SWIFT_VERSION` は `project.pbxproj` の `buildSettings` に直書きされていた**ため、xcconfig に足すだけでは無視される（同一キーは pbxproj > xcconfig）。pbxproj の Debug / Release 両ブロックから削除して `Base.xcconfig` に一本化した。

計測は **2 段階（`SWIFT_STRICT_CONCURRENCY = complete` のみ → 既定 MainActor 分離を追加）に分ける**。既定 MainActor 分離は診断を減らす方向にも働くため（`PreviewSamples` 10 件 / `CoffeeInsightProviderIosImpl` 3 件 / `PhotoFileStore` 1 件が自然解消、`FirebaseRepositories` 系で 8 件が新規発生）、1 回で測るとどちらの設定がどの診断の原因か切り分けられない。

### 2026-08-08: `presentationAnchor` の到達不能フォールバックを削除（SW6-B）

`AppleSignInCoordinator.presentationAnchor(for:)` は、保持した anchor が nil のときに「foregroundActive な scene の key window → `UIWindow(windowScene:)` → `UIWindow()`」と 3 段でフォールバックしていた。最後の `UIWindow()` が iOS 26 で deprecated になり、Swift 6 移行後に**唯一残った警告**だった。

**フォールバック全体を削除して `preconditionFailure` にした**（ユーザー選択）。呼び出し経路を追うと全パスが到達不能:

- `AccountView.startAppleSignIn()` が `guard let anchor = currentPresentationAnchor() else { return }` で nil を弾く
- `signIn(anchor:)` は `controller.performRequests()` の**前に** `self.presentationAnchor = anchor` を設定する

**「無効な window を返す」は安全策になっていなかった**のが判断の決め手。`UIWindow()` を返してもサインインシートは出ず、ユーザーには無反応に見えるだけで、しかもエラーとして観測されない。クラッシュの方が検出可能な分ましだと判断した。加えて scene 探索は `AccountView.currentPresentationAnchor()` と**二重に書かれていた**ので、削除で重複も解消した（実行パス 18 行 → 2 行）。

**これで iosApp のビルド警告が Debug / Release とも 0 件になった。** 到達不能の確認は静的なものなので、実機で**シートが実際に出ること**の確認は verification-checklist「Swift 6 移行 ③」に統合した（lessons 2026-08-07「コードの形が既知バグに一致しても、そのバグが起きている証拠にはならない」の裏返しで、**到達不能の証明も静的なままでは仮説**）。

### 2026-08-08: 記録写真のサムネイルを共通コンポーネントへ統合（SW6-A）

記録写真を `PhotoFileStore.loadImage`（長辺 2048px のフルデコード ≒ 16MB/枚）で表示していた 3 箇所を、縮小デコードする共通 View `Components/RecordPhotoThumbnail.swift` に統合した。

| 箇所 | 表示サイズ | コンテナ |
|---|---|---|
| `PhotoThumbnailCell`（エディタ） | 100×100pt | LazyHStack 横スクロール |
| `PhotoDetailCell`（記録詳細） | 120×120pt | LazyHStack 横スクロール |
| `CafePhotoHeader.ownPhotoCell`（カフェ詳細） | 224×168pt | LazyHStack 横スクロール |

**構図として重要なのは「1 箇所だけ直されて横展開されなかった」こと。** 2026-08-07 に一覧の `CoffeeRowThumbnail`（56×56pt）が `PhotoFileStore.loadThumbnail` へ移行された時点で、同じ「`LazyHStack` 内で記録写真をフルデコードしている」箇所が他に 3 つ残っていた。`requirements.md` の非機能要件「一覧表示は 60fps を維持する。画像はサムネイルキャッシュで遅延読み込み」を満たさない箇所が残っていたことになる。**起票時の見積もりも 2 箇所で、着手時の調査で 3 箇所に増えた。**

**共通化したのは画像解決だけ**（`fileName` / `pendingData` → 縮小デコード済み `UIImage`）。サイズ・角丸・プレースホルダー・ラベル・アクセシビリティは呼び出し側に残した。4 箇所でプレースホルダーの見た目（`cup.and.saucer` / `photo.badge.exclamationmark` / `photo`）も角丸も違うため、そこまで共通化すると分岐だらけの View になる。**プレースホルダーを `@ViewBuilder` で外注する点が、内蔵する `PlacePhotoThumbnail` との設計差**（Places 写真は 1 用途しかないので内蔵で足りる）。

`ImageDownsampler` には `downsampledImage(from:maxPixelSize:)`（Data → UIImage、JPEG 再エンコードなし）を新設し、既存の `downsampledJPEG` は `@concurrent async` 化した。後者は `handlePickerSelection`（`@MainActor`）から同期で呼ばれていて、**写真選択のたびにメインスレッドで 48MP 級のデコード + JPEG エンコードをしていた**。

**対象外（意図的）**: `CoffeeShareCardView` の `loadImage` は共有カードが 1080×1350px 出力なのでフルデコードが正しい。

#### ビルド警告の数え方について（親の計測ミス）

SW6-B 完了時に「警告 0 件」と報告したが、正確には**Swift コンパイラ警告が 0 件**で、ビルドインフラ由来の警告は 3 件残っている（`grep ": warning:"` はファイル:行:列 形式にしかマッチせず、ビルドスクリプト警告は `warning:` だけで出るため数え漏れていた）。3 件とも実害は無いことを確認済み:

- `appintentsmetadataprocessor: Metadata extraction skipped` — AppIntents 未使用なので無害
- `DEBUG_INFORMATION_FORMAT should be set to dwarf-with-dsym` — **Debug ビルドのみ**。`-showBuildSettings` の実効値は Debug = `dwarf` / **Release = `dwarf-with-dsym`** で、Release ログにこの警告は出ない（Crashlytics の dSYM アップロードは正しく機能する）
- `Run script build phase 'Upload dSYM to Crashlytics' will be run during every build` — Crashlytics 公式構成でこうなる。outputs を指定するとアップロードが漏れうるので触らない

### 2026-08-08: サインアウト / 削除の完了検知を、ポーリングから KMP 側の契約へ（SR-1）

- 関連: `shared/feature/account/.../AccountViewModel.kt` / `iosApp/iosApp/Features/Account/AccountViewModelBridge.swift` / `AccountView.swift` / `docs/tasks.md` SR-1

Swift コードレビュー（`iosApp/**` 全 90 ファイル）で挙げた 20 件のうち、ユーザーが 1 件だけ選んで着手したもの。

**元の壊れ方**: `AccountViewModelBridge.awaitProcessingCompletion()` が `isProcessing` を 340 周ポーリング（50ms×40 → 100ms×300）する一方、`AccountView` が `.onDisappear` で observation を cancel していた。完了前に画面を離れると `apply(_:)` が止まって `isKmpProcessing` が凍結し、300 周スピンして `false` を返す → `onResetRequested()` が呼ばれず、**Firebase はサインアウト済みなのに `AppState` は古い uid とブリッジを保持したまま**になる。

**採った形**: 完了検知の責任を KMP 側の契約として明文化した。`AccountViewModel` の 3 アクションは**戻る時点で `isProcessing = true` を反映済み**にする（`markProcessingStarted()` を `launch` の外へ）。これにより iOS 側は「呼んだ直後から `state` を購読し、最初の `isProcessing == false` を待つ」だけでよくなり、ポーリングも「開始を待つ」相も消えた。`kotlin.state` を `observationTask` とは別に購読するため、画面を離れても取りこぼさない。

**同時に必要だった 2 つ**（どちらも単独では新しいバグを生む）:

- `catch (CancellationException)` の `isProcessing = false` を外した。cancel は必ず「次のアクション開始」（= `markProcessingStarted()`）か `clear()` とセットで起きるため、残すと**直後に立てた `true` を非同期に打ち消すレース**になる。連打時に処理中オーバーレイが消える
- Bridge のアクション転送で `isKmpProcessing = true` を楽観的に立てた。KMP は同期で立つのに Swift 側は observation の次の emit まで反映されず、**1 フレームだけオーバーレイが消える**（Apple 削除フローの `onDeletePreflightSucceeded()` → `onDeleteAccountTapped()` の継ぎ目で顕在化しうる）

- トレードオフ: **タイムアウトを撤廃した**。KMP は成功・失敗どちらでも必ず `isProcessing = false` を emit するため待ち続けても取り残されないが、KMP がハングすれば `Task` は戻らない。旧実装の 30 秒上限は、記録が多いユーザーのアカウント削除（全 Visit の Firestore 削除）で**超えうる実害の方が大きい**と判断した。
- 影響: `AccountViewModelBridge.onDisappear()` → `cancel()` にリネーム（View から呼ばなくなり、`MapViewModelBridge.cancel()` と同じ「`AppState` からの明示キャンセル」専用になったため）。`AppState.resetAndRebootstrap()` が追随。
- 退出封じは「完了」ボタンの `.disabled(viewModel.isProcessing)` **のみ**にとどめた。`AccountView` は `.sheet` ではなく `SettingsView` から `NavigationLink` で **push** されるため `interactiveDismissDisabled` は効かない。戻るボタン / スワイプバックの封じには `AccountView` が自前で持つ**入れ子 `NavigationStack` の解消が前提**になり、SR-1 のスコープを超える（`CoffeeListView` は「親の NavigationStack 内に置くので自身では持たない」と明記していて、`AccountView` だけが逆）。**完了検知自体は画面を離れても成立する**ので、封じは UX 上の親切に過ぎない。
- 検証: `AccountViewModelTest` に契約テストを 4 件追加（`runTest` の `StandardTestDispatcher` は `advanceUntilIdle` まで `launch` の中身を走らせないので、「呼び出し直後の観測」= 「コルーチンがディスパッチされる前」になる）。**`markProcessingStarted()` を `launch` の内側に戻すと新テスト 2 件が FAILED になることを実測**してから元に戻し、テストが契約を実際に検証していることを確認した。iOS 18 件 / Android 18 件 PASS、`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しで `** BUILD SUCCEEDED **`。
