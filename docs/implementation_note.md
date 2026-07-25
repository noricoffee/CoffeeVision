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

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。（最終棚卸し: 2026-07-25）

- ドメインは **CoffeeRecord 主体**（2026-06-19 クリーンブレイク）: 1 杯 = 1 記録、`cafe: Cafe?`（null = セルフ抽出）、`rating` は 0.5 刻み `Double?`（null = 未評価、2026-07-12 B-4 で sentinel 廃止）、`tasting` は all-or-nothing（`TastingScores?`）、`tags: List<String>`。**産地は `origin: String?`（国名。`CoffeeOriginCatalog` から選択、2026-07-22 に自由入力→国ドロップダウン化）+ `region: String?`（エリア / 農園、任意自由入力・表示専用で分析非対象、migration 6 で追加）**。モデル・DB・Firestore 表現は `data-model.md` を真とする
- CI（GitHub Actions）は `testAndroidHostTest`（**全モジュール一括 = 360 件**。モジュール個別列挙は漏れるため禁止。2026-07-25 是正）+ `:androidApp:assembleDebug`（Android ジョブ。ダミー `google-services.json` を CI 内で生成）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成。`xcodebuild` / `iosSimulatorArm64Test` は CI 非対象で親のローカル検証が担保
- `CoffeeRepository` は `commonMain` で 2 段構成（`RemoteCoffeeDataSource` interface + `CoffeeRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteCoffeeDataSource` だけを書く。書き込みはローカル → リモート順、リモート失敗の扱いは `WritePolicy`（既定 `PropagateRemoteFailure`）
- Firestore は `users/{uid}/coffees/{id}` の単一ドキュメント（`cafe` 任意埋め込み + `photos` 埋め込み配列 + `tasting` マップ + `tags` 配列。子サブコレクションなし）+ `users/{uid}` ルート（`analyticsConsent`）+ `beanProfiles`（サービス管理・read-only）。nullable はキー省略。`Photo.localPath` は書かず `fileName`（`Documents/photos/` フラット配置）で復元、`remoteUrl` は常に null（Storage 不採用・写真は端末ローカルのみ）
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる
- `AppContainer` は scope 引数ありのプライマリ（7 引数）が**テスト専用**。通常は scope なしセカンダリ 2 系統 — iOS = 6 引数（`coffeeInsightProvider` 注入）/ Android = 5 引数（provider 省略 = null）。公開プロパティは `coffeeRepository` / `cafeRepository` / `authRepository` / `coffeeInsightProvider` / `beanProfileRepository` / `beanProfileMatchUseCase` / `coffeeRecordQuery`、開発用に `seedDummyData` / `clearDummyData`（DEBUG + ダミーデータ Scheme 限定）
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一。共通ライブラリの Android namespace は各モジュール個別（`com.noricoffee.<module>` 系）で applicationId と分離
- SKIE 0.10.12 を `shared/framework` umbrella に適用。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する（`__answer(...)` 等の protocol witness）。Swift で Kotlin `Flow` を返す実装は `FlowBridge.swift` の `CallbackFlow` / `CallbackFlowOptional`（`Kotlinx_coroutines_coreFlow` 準拠クラス）が正規パターン（2026-07-10 実態訂正: 旧記述「MutableStateFlow 直接構築が第一候補」は結局未使用）。SQLDelight 生成行型と同名のドメインモデルは Swift 側で末尾アンダースコア付きになる（現状 `Photo` → `Photo_`。`coffee_record` からは `Coffee_record` が生成されるため `CoffeeRecord` は衝突しない）
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
- **後続候補**: `SavedCafeListSheet` の「記録あり」バッジが `.brown` 直書きのまま孤立（visitedCafePin の brown→accentColor 化に未追随。SavedCafeListSheet.swift:78）。次にこのファイルを触るとき accentColor へ揃える

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
- **一覧行の推薦理由は 1 行サマリ**（例「産地・焙煎度が好みに一致」、軸名の重複除去列挙）に留め、詳細（一致ラベル・代表記録・評価）はピンタップの `RecommendationMatchSheet` に譲る。軸名ラベルはトップレベル関数 `preferenceMatchAxisLabel` に共通化
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
- 好み一致ピンタップの推薦理由シート（`selectedRecommendedCafe` / `RecommendationMatchSheet`）は対象外・無変更（別系統の独立 `.sheet`）。
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
