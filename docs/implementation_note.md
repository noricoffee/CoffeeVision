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

**2026-06 / 2026-07 / 2026-08 のエントリ（= 1.0 リリースまでの全 139 件）は [`implementation-note-archive.md`](./archive/1.0/implementation-note-archive.md) に凍結移送済み**（2026-08 分は 1.0 リリース時の docs 整理で移送）。他 doc・コードコメントからの「implementation_note 2026-0X-XX エントリ」という参照は**アーカイブ側を指す**（参照は日付で引く運用で、行き先もアーカイブ 1 ファイルに固定しているので、参照側の書き換えは不要）。**本 doc に残っているのは 1.0 リリース後の新規分**。

- **切り出しの単位は月**。作業ログは append-only 気味に伸びるので、行数の閾値（フロー型 1200 行 = `curate-doc` skill）で縮約しきるのは構造的に無理がある。**フェーズが完了して追記が止まった月**を凍結してアーカイブへ送る運用にする
- **月別ファイルには分けず、アーカイブ 1 本に月見出しで積む**（2026-08-11 確定）。日付参照の行き先が 1 ファイルに固定され、参照側の書き換えも「月 → ファイル」の索引維持も不要になるため。アーカイブ側に行数閾値は適用しない（凍結 doc は通読されず日付 grep で引かれる）
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

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。（最終棚卸し: 2026-08-21 / 1.0 リリース時）

> **このサマリに「数え上げ」と「構成要素の列挙」を書かない**（2026-08-01 の棚卸しで制定）。引数の個数・公開プロパティ一覧・コレクション一覧は、依存が 1 つ増えるたびに**全項目がまとめて嘘になる**うえ、増やした本人はソースしか見ないので気づけない。実際この棚卸しでは「プライマリ 7 / iOS 6 / Android 5 引数」（実際は 9 / 8 / 7）と削除済みの `beanProfileMatchUseCase` が残っていた。**書くのは「どこを真とするか」と、数えなくても変わらない構造・不変条件だけ**（`CuratedCafe.kt` KDoc で 2026-07-25 に同じ判断をしている）。

- ドメインは **CoffeeRecord 主体**: 1 杯 = 1 記録、`cafe: Cafe?`（null = セルフ抽出）、`rating` は 0.5 刻み `Double?`（null = 未評価。0.0 を sentinel にしない）、`tasting` は all-or-nothing（`TastingScores?`）、`tags: List<String>`。**産地は `origin: String?`（国名。`CoffeeOriginCatalog` から選択）+ `region: String?`（エリア / 農園、任意自由入力・表示専用で分析非対象、migration 6 で追加）**。モデル・DB・Firestore 表現は `data-model.md` を真とする
- CI（GitHub Actions）は `testAndroidHostTest`（**全モジュール一括指定**。モジュール個別列挙は漏れるため禁止。**件数はここに書かない** — 上の「数え上げを書かない」規約どおり、テストが増えるたびに嘘になる）+ `:androidApp:assembleDebug`（Android ジョブ。ダミー `google-services.json` を CI 内で生成）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成。`xcodebuild` / `iosSimulatorArm64Test` は CI 非対象で親のローカル検証が担保
- `CoffeeRepository` は `commonMain` で 2 段構成（`RemoteCoffeeDataSource` interface + `CoffeeRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteCoffeeDataSource` だけを書く。書き込みはローカル → リモート順、リモート失敗の扱いは `WritePolicy`（既定 `PropagateRemoteFailure`）
- Firestore は `users/{uid}/coffees/{id}` の単一ドキュメント（`cafe` 任意埋め込み + `photos` 埋め込み配列 + `tasting` マップ + `tags` 配列。子サブコレクションなし）+ `users/{uid}` ルート（`analyticsConsent`）+ サービス管理・read-only の `beanProfiles` / `curatedCafes`。**コレクションの正確な一覧は `firestore.rules` を真とする**。nullable はキー省略。`Photo.localPath` は書かず `fileName`（`Documents/photos/` フラット配置）で復元、`remoteUrl` は常に null（Storage 不採用・写真は端末ローカルのみ）
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる。**対になる `stopSync()` が同期 `Job` を畳む**: `AppContainer` が coffees / savedCafes の同期 Job を保持し、`startInitialSync()` は冒頭で `stopSync()` を呼んで冪等化、サインアウト時は `AppState.resetAndRebootstrap()` の冒頭でも呼ぶ。**これが無いとサインアウトのたびに旧 uid の購読が 1 組ずつ残り、Rules（`request.auth.uid == uid`）で必ず権限エラーになる**
- `AppContainer` は scope 引数ありのプライマリが**テスト専用**。通常は scope なしのセカンダリ 2 系統 — iOS = `coffeeInsightProvider` 注入あり / Android = 省略（null）。開発用に `seedDummyData` / `clearDummyData`（DEBUG + ダミーデータ Scheme 限定）。**引数の個数と公開プロパティの一覧はここに書かない**（依存が増えるたびに全滅する）— `AppContainer.kt` を真とする
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一。共通ライブラリの Android namespace は各モジュール個別（`com.noricoffee.<module>` 系）で applicationId と分離
- SKIE 0.10.12 を `shared/framework` umbrella に適用。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する（`__answer(...)` 等の protocol witness）。Swift で Kotlin `Flow` を返す実装は `FlowBridge.swift` の `CallbackFlow` / `CallbackFlowOptional`（`Kotlinx_coroutines_coreFlow` 準拠クラス）が正規パターン（2026-07-10 実態訂正: 旧記述「MutableStateFlow 直接構築が第一候補」は結局未使用）。SQLDelight 生成行型と同名のドメインモデルは Swift 側で末尾アンダースコア付きになる（現状 `Photo` → `Photo_`。`coffee_record` からは `Coffee_record` が生成されるため `CoffeeRecord` は衝突しない）
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。path uid 検証 + `users/{uid}` ルート明示 + `beanProfiles` / `curatedCafes` read-only。本番反映済み（`firestore.rules` の全ブロックが公開中）。`storage.rules` は残置のみ未デプロイ（Storage 不採用。lessons 2026-06-10）
  - **デプロイ日をここに書くのはやめた**。`curatedCafes` を足した 2026-07-17（commit `2614528`）に本行が追随せず「2026-07-01 デプロイ済」のままだったため、2026-08-06 のリリース前点検で**未デプロイの疑いとして誤検出**した（実際は反映済み）。`firestore.rules` の編集と `firebase deploy` は別作業なので、doc 側の日付は必ず遅れる。**現在の公開内容の正本は Console のルールタブ**で、ここには「リポジトリ管理である」ことだけを書く
- `build-logic/convention/` の Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）は precompiled script plugin 方式（`gradlePlugin { register }` 不使用）。`build-logic/settings.gradle.kts` で version catalog を明示共有。`kmp.library` は `jvmToolchain(N)` を付けず `compilerOptions.jvmTarget` のみ指定
- `shared/core` には `AppContainer` / `CoffeeRepositoryImpl` / `DummyCoffeeData`（dev 用）。`shared/data-local` が SQLDelight の単独管理者（`LocalCoffeeRepository` / Mapper / DriverFactory expect/actual。合成リポジトリのテストは expect/actual ドライバの制約で data-local の commonTest に妥協配置）。`shared/data-firebase/androidMain` に Android Firebase 実装（`AuthRepositoryAndroidImpl` / `RemoteCoffeeDataSourceAndroidImpl` / `CoffeeFirestoreMapper` / `BeanProfileRepositoryAndroidImpl`）、iOS 実装は `iosApp` Swift
- iOS 向け umbrella は `shared/framework`（baseName / XCFramework 名とも `SharedLogic`、Swift は `import SharedLogic`）。全 shared モジュールを `api` + `export` で再公開 + `linkerOpts("-lsqlite3")`。**feature を追加したら api / export に 1 行ずつ追記**。モジュールの正確な一覧は `settings.gradle.kts` を真とする（同じ行で「真とする」と言いながら列挙も併記していたため、2026-08-01 の棚卸しで列挙を削除）
- `AppContainer` の ViewModel ファクトリ（`makeCoffeeListViewModel()` 等）は **`shared/framework` の拡張関数**（`AppContainerViewModelFactory.kt`）として配置（`core → feature` の循環依存回避）。feature 追加ごとに追記する
- ViewModel は注入 scope の Job を親にした**所有 `viewModelScope`（SupervisorJob 子スコープ）+ `clear()`** を持つ（2026-06-24。push/pop 画面の collector 増殖リーク対策）。Bridge は `deinit` で `kotlin.clear()` を呼ぶ。**KMP のコルーチン内で `runCatching` は使わない**。→ いずれも 2026-07-02 に `coding-conventions.md`（§1.2 / §1.6 / §1.7）へ昇格済み。経緯は本ノート 2026-06-24 エントリ
- iOS Bridge は `@MainActor @Observable` + `Task { for await state in kotlin.state { apply(state) } }` パターン。生存スコープは、タブ常駐画面（coffee-list / map / analysis 等）= `AppState` で 1 つ保持、push / sheet 画面（coffee-detail / coffee-editor / cafe-detail）= View 内 `@State` で遷移ごとに生成・`deinit` 回収。**タブ常駐 View の `onDisappear` で observation を止めない**（検索停止バグの再発防止。lessons 2026-06-25）
- iOS のルートは **4 タブ（マップ / コーヒー / 分析 / 設定）**。**検索タブは作らない**（iOS 27 で `Tab(role: .search)` の右端固定挙動が変わったため）— 検索は**マップ上部の埋め込み検索バー**（テキスト検索はマップ中心の位置バイアス付き）+「このエリアを検索」ボタン + 検索モードに移行。コーヒー記録の作成は**コーヒータブとカフェ詳細のいずれもナビバー右上の `+`**（FAB は使わない。ui-ux-guidelines「追加アクションの配置」）
- Places API は **New v1** + `X-Goog-FieldMask` で取得フィールド明示。API キーは `AppContainer` コンストラクタ注入（Android = local.properties → BuildConfig、iOS = xcconfig → Info.plist → Bundle.main）。Nearby は `includedPrimaryTypes = [cafe, coffee_shop]`・1 回最大 20 件。Places 写真は永続キャッシュ禁止（規約）で都度取得
- iOS の xcconfig は `Base.xcconfig`（base）→ 先頭 `#include "Config.xcconfig"`（必須）+ `#include? "Secrets.xcconfig"`（任意・gitignore 済）の 3 段構造。**フォールバック宣言（`PLACES_API_KEY =` 等）は `#include?` より前に置く**（後ろだと実キーを空で上書き）
- Places API キーはクライアント埋め込みで**抽出不可避**。`X-Ios-Bundle-Identifier` によるバンドル ID 制限は生 REST 呼び出しでは**ヘッダなりすましで突破可能**（暗号検証なし）＝事故防止レベルで実効的防御ではない。現実的な守りは Google Cloud の**予算アラート + クォータ上限**（被害額に天井）+ API 制限の Places 限定。本命はバックエンドプロキシ + App Attest（規模拡大時に検討）。詳細は 2026-07-08 エントリ。**この 3 点（予算アラート / クォータ上限 / API 制限の Places 限定）は設定済み**（設定状況の正本は paid-services §1「コスト抑制の現状」で、**実値は Cloud Console が正本**）
- 分析は 3 階層分離: 階層1・2 は KMP で決定論（`CoffeeStats` / `FavoriteSignals`。収縮平均 + n 連動 z ゲート `CATEGORY_Z = 2.0` + 相関 floor で「弱い傾向」だけを信号化、断定しない）、階層3 は iOS Foundation Models（`CoffeeInsightProvider`。可否は注入時判定、null = 非対応端末で graceful degradation）。Q&A は v1 = `CoffeeStats` digest 注入（単発・ステートレス）/ v2 = `Tool` から `CoffeeRecordQuery.searchRecords`（計算は KMP・LLM は解釈と整形のみ）
- `BeanProfile`（12-B）はサーバ管理 read-only の豆ナレッジ。`CoffeeRecord` と ID 紐付けせず origin / processings のファジーマッチ。取得は one-shot get + メモリキャッシュ。12-C で `FavoriteSignals` と突合した `preferredBeanTraits` を `CoffeeStats` に付加し、Foundation Models で言語化
- 味覚一致カフェ推薦: **9-5（コンテンツベース v1）は 1.0 で実装済み**（`ObserveTasteMatchedCafesUseCase` / `RecommendedCafe` / `CafeRecommendationProvider`、産地/焙煎/抽出/精製の 4 軸マッチ、マップの好み一致ピン + 理由表示 + 分析タブ連携。テイスティング 5 軸の一致はスコープ外）。**9-6（協調フィルタ / 他ユーザー横断 v2）は設計確定・未実装**（`sharedTasteProfiles/{uid}` + Cloud Function 特権 read。閾値定数 / Function 内実装 / インフラ選定は未決。tasks 12-D で段階 dispatch）。詳細は analysis-model §2
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

### 2026-08-21: 共有カードの「簡潔性」制約は share sheet の payload に及ばない

- 関連: `iosApp/iosApp/Features/CoffeeDetail/ShareCard/ShareCardSheet.swift` / `CoffeeShareCardView.swift` / 要件 2-12 / tasks ASO-7②

1.0.1 で共有経由の流入導線（ASO-7②-a）を入れるにあたり、**要件 2-12 の「カードの簡潔性」が share sheet に渡すテキストまで縛るか**を判断した。**縛らない**と解釈する。

2-12 が挙げる制約は「**メモ・タグは載せない**（誤共有防止 / カードの簡潔性）」で、どちらの理由も**画像として第三者に渡る面**を対象にしている。誤共有防止は「ユーザーが意図しない私的記述が画像に焼き付いて拡散する」ことを防ぐ趣旨であり、簡潔性は 1080×1350 の版面設計の話。**テキスト payload は投稿前のユーザーが編集できる**うえ、内容も定型文と URL で記録の中身を含まない。どちらの懸念も生じないため、URL 追加に要件改訂は要らない。

- 影響: ②-a はカード画像のレイアウトに一切触れないため、`CoffeeShareCardView` の版面（`footerHeight` 等）と `ShareCardRenderer` の出力サイズは不変。**画像自体への URL / QR 焼き込み（②-b）は話が別**で、そちらは版面に入るので 2-12 の改訂が前提になる
- 経緯: ASO-7② は起票時（2026-07-27）「共有カード footer の App Store 導線」と 1 件に見えていたが、1.0.1 のスコープ検討で実コードを読んだところ**穴が 2 箇所**あった。`CoffeeShareCardView.swift` の footer に URL が無いのは既知だったが、**カード画像の外側（テキスト payload）にも導線が無い**点は起票時に見落としていた
- トレードオフ: 画像だけがスクショで転載された場合、②-a では導線が残らない。②-b はそこを塞げるが版面を汚す。**まず ②-a を出し、共有経由の流入が観測できてから ②-b を判断する**順序にした

### 2026-08-21: `SharePreview` は共有されない — 画像 + テキストには `UIActivityViewController` が要る

- 関連: `iosApp/iosApp/Features/CoffeeDetail/ShareCard/ShareCardSheet.swift` / tasks ASO-7②-a

ASO-7②-a のスコープ見積もりで**一度誤った前提を置いた**ので記録する。現状のコードは

```swift
ShareLink(item: result.fileURL,
          preview: SharePreview(shareTitle, image: Image(uiImage: result.image)))
```

で、`shareTitle`（`"\(coffee.name) - CoffeeVision"`）は `SharePreview` に渡っている。**`SharePreview` は share sheet の UI 上に出る表示用メタデータで、投稿先アプリには渡らない**。共有される実体は `item:` の `result.fileURL`（PNG）1 つだけ。したがって **`shareTitle` に URL を足しても X / LINE には一切届かない**（「文字列に 1 行足すだけ」という当初の見積もりは誤り）。

`ShareLink` の `items:` は `RandomAccessCollection where Element: Transferable` を要求するため、**file URL と `String` を混在させられない**。単一の `Transferable` 型に複数 representation を持たせても、投稿先が選ぶのはそのうち 1 つで「画像とテキストの両方」にはならない。よって **`UIActivityViewController` を `UIViewControllerRepresentable` で包み、`activityItems: [fileURL, text]` を渡す**のが正攻法になる。

- 影響: ②-a は「文字列 1 行の変更」ではなく **`ShareLink` の置き換え**。工数は上がるが 1.0.1 に収まらない規模ではない
- 副次: `UIActivityViewController` は完了ハンドラ（`completionWithItemsHandler`）を持つ。ASO-1 で「共有完了をレビュー依頼のトリガにする案」が**`ShareLink` が完了コールバックを持たないことを理由に不採用**になっていた（tasks-archive ASO-1）。この置き換えでその制約自体は消えるが、**発火は分析タブの 1 箇所のみという 9-9 の仕様は維持する**（トリガを増やす判断は別途）
- 教訓: 「share sheet にテキストを渡している」ように読める箇所が、実際には**プレビュー表示にしか使われていなかった**。`SharePreview` という名前が「共有されるプレビュー」とも「共有 UI のプレビュー」とも読めるのが原因。**スコープ見積もりの時点でソースを開いていたのに、引数名だけ見て役割を推定した**（CLAUDE.md「doc に書く事実は、書く前にソースを開いて確かめる」の失敗例。今回は doc に書いた直後に気づいて訂正した）

### 2026-08-21: アプリ内に埋める App Store URL は短縮形に固定する

- 関連: `docs/app-store-metadata.md` §1 / tasks ASO-7②

App ID は `6788339362`。**バイナリやカード画像に焼くのは `https://apps.apple.com/app/id6788339362`** とする。ASC がコピーさせる長い URL（`/app/coffeevision-コーヒーマップ-好み分析/id6788339362`）の**スラグ部分はアプリ名から生成される装飾**でリダイレクトにしか使われず、ASO で名前を変えるたびに変わる。アプリ名は ASO-2 で既に一度変更しており、今後も動きうる。

### 2026-08-21: Crashlytics の疎通を TestFlight 実機で実証した（シンボル化まで）

- 関連: `iosApp/iosApp/iOSApp.swift`（`setCrashlyticsCollectionEnabled`） / `iosApp/iosApp.xcodeproj/project.pbxproj`（`Upload dSYM to Crashlytics` フェーズ） / `docs/app-store-metadata.md` §10 / tasks 1.0.1

1.0.1 の提出は「Crashlytics / App Analytics に実データが溜まるのを 1〜2 週間待つ」方針だが、**待つ前提である Crashlytics 自体が動いている証拠が無かった**。静的に確認できるのは設定が揃っていることだけ（収集の明示有効化 / dSYM アップロードのビルドフェーズの存在 / Release の `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`）で、実際にレポートが届くこととは別物。検証専用ブランチで意図的クラッシュを 1 発起こし、端から端まで通した。

**結果は全経路健全**。クラッシュは Firebase コンソールに到達し、スタックトレースは `SettingsView.swift` の行番号まで解決されていた（= dSYM アップロードも機能している）。

- 影響: **2 週間後にクラッシュがゼロだったとき、それを「クラッシュが起きていない」と読んでよい**ことが確定した。この区別（無事故なのか計測が壊れているのか）が付かないまま待つのが一番まずかった
- 検証の性質: **ビルド成功でも設定の存在でも証明できない**。意図的にクラッシュさせる導線を Release ビルドに載せる必要がある（`#if DEBUG` 配下では TestFlight に載らない）。このため検証は独立ブランチ `chore/crashlytics-verification-do-not-merge` で行い、`develop` へはマージせず検証後に削除した。再検証が要るときは同じ手順を踏む
- 手順上の罠が 2 つ: ①Crashlytics はクラッシュ発生時ではなく**次回起動時**にレポートを送信する（クラッシュさせただけで確認しに行くと永久に届かない）②**デバッガ接続中はシグナルを捕捉できない**ため、Xcode から起動したビルドでは検証にならない。TestFlight 経由でホーム画面から起動する

### 2026-08-31: ASO の切り分けが決着し、露出が出ない原因が 2 層に分かれた

- 関連: `docs/tasks.md` ASO 節（ASO-8 / ASO-9 / ASO-10 起票）/ `docs/app-store-metadata.md` §11 / `.claude/scripts/aso-rank-probe.py` / 計画は `.claude/plans/soft-mixing-hopper.md`

2026-08-21 に「打ち手を選ぶ前に ASC でインプレッションと CVR を見て切り分ける」と決めていた件の結論。**インプレッションがほぼ出ていない = 露出側の問題**（ストアページの CVR ではない）とユーザーが確認。これを受けて ASO-4 / ASO-5 / ASO-7 の保留を解き、露出に効く 3 本へ絞った。

**計測手段として iTunes Search API を採用した**（`itunes.apple.com/search?country=jp&entity=software`）。ASC の App Analytics は**検索語ごとのインプレッションを出さない**ため、語の当たり外れを ASC だけでは切り分けられない。サードパーティの ASO ツールは有料なので、無料で取れるものとして採用した。

> ⚠ **iTunes Search API のランキングは App Store アプリ内の検索結果とは別アルゴリズム**。得られるのは「インデックスされているか」「競合がどれくらい厚いか」の目安であって、**実際の検索順位の正本ではない**。doc に順位を事実として書かないこと。スクリプトの docstring にも同じ警告を置いた。

**原因は 2 層あった**:

1. **評価 0 件がランキングシグナルを殺している**。評価 0 → どの語でも上位に出ない → インプレッション 0 → DL 0 → 評価 0 の自己強化ループ。**キーワードの並べ替えだけでは破れない**ため、初速を外から作る施策（ASO-9）を別建てにした。ASO-1 のレビュー依頼導線は実装済みだが、DL が無いので発火しない
2. **キーワードがヘッドターム偏重**。`コーヒー` / `カフェ` は上位 5 件の評価数中央値が **8390 / 1445** で、構造的に取れない枠に文字数を使っている。一方 `コーヒー テイスティング`（97 件・中央値 **0**）`喫茶店 記録`（21 件・中央値 **0**）`コーヒー 統計`（21 件・中央値 0）のように、**上位が評価数一桁で埋まっている語が多数実在する**。市場そのものは薄い

**当初の読みを 1 つ訂正した**。最初の計測で「サブタイトルにある `テイスティング` `カフェ巡り` が圏外、アプリ名にある `コーヒーマップ` `コーヒー 好み` は順位が付く」ことから **「フィールドをまたいだクロスマッチが効いていない」と読みかけた**が、候補語を広げた 2 回目で `シングルオリジン` 13 位 / `スペシャルティコーヒー` 40 位 / `喫茶店 記録` 16 位が出た。**これらはキーワードフィールドにのみ存在し説明文には無い語**で、キーワードは反映されている。サブタイトル由来の語が圏外なのは**1 語クエリで競合に埋もれた結果**とも読める（`テイスティング` は 98 件ヒット）。

観測できたのは因果ではなく傾向 — **1 語クエリでは全滅し、2〜3 語の複合クエリでは順位が付く**。app-store-metadata §4 の「日本語のトークナイズ挙動は Apple 非公開」という保留は**そのまま維持する**（実測は判断材料であって、クロスマッチの有無を決着させる証拠にはならなかった）。

- **教訓**: 1 回目の計測結果だけで機序を断定しかけた。**候補語を広げた 2 回目で反例が出た**のは、たまたま「キーワードにのみ存在し説明文には無い語」を候補に入れたため。**メタデータのどのフィールドに由来する語かで候補を層別してから測る**べきだった

**副産物: `docs/tasks.md` の誤りを 1 件訂正した**。ASO-7 行と ASO 節前文の「① In-App Events はバイナリ提出が不要」は誤りで、**In-App Events はイベントのディープリンクが必須**（[Apple 公式](https://developer.apple.com/app-store/in-app-events/)）。`grep` で確認したところ `onOpenURL` / カスタム URL スキーム / associated domains の**いずれも未実装**のため、バイナリが要る。起票時（2026-07-27）に Apple の要件を確認せず「ストア運用だから無料・バイナリ不要」と括ったのが原因。**イベント名 30 + 短い説明 50 + 長い説明 120 字が検索インデックスに乗る**点は魅力なので取り下げず、ASO-8 / ASO-9 の数字を見てから着手判断する。

### 2026-08-31: 追加ボタンの視認性を「配置を動かさずに」上げた

- 関連: `docs/ui-ux-guidelines.md`「追加アクションの配置」/ `docs/tasks.md` 同名節 / `docs/tasks/verification-checklist.md` パス 1・2・3 / 計画は `.claude/plans/noble-meandering-newell.md`

ユーザー指摘「コーヒー記録タブの追加ボタンが分かりづらい」。**指摘の言葉は「FAB」だったが、実物は 2026-08-07（UX-3）にナビバー右上へ移した `ToolbarItem` の `plus`** で、FAB は既に存在しない。ここで**指摘の語をそのまま受けて FAB を作り直すと、UX-3 で解消した「一覧は FAB / カフェ詳細は `+`」の分岐が復活する**。配置は据え置き、見た目だけを変える方針をユーザーに確認して確定した。

**打ち手は 2 つ**。①ツールバーの `plus` に `.buttonStyle(.borderedProminent)`（iOS 26 では素の `Button` が無色の Liquid Glass になり、`.large` タイトル + `.searchable` と同居するナビバーで埋もれる）②記録一覧の空状態に実ボタンの CTA。

**②の副産物として位置参照の文言が消せた**。旧文言「**右上の + ボタン**か、マップのカフェ検索から〜」は、`ui-ux-guidelines` 自身が「位置参照は配置変更のたびに腐るので書かない方が安全」と警告している形そのものだった（UX-3 のときに「右下の」→「右上の」と直した箇所でもある）。実ボタンが同じ画面に出れば位置を説明する必要がなくなる — **「腐る文言を直す」より「文言を要らなくする」方が根本的**で、これを ui-ux-guidelines の規則にも反映した（空状態 CTA は `description` の文章ではなく `actions:` の実ボタンで置く）。

**スコープを 1 箇所広げた**。`CafeDetailView.emptyRecordsView` の既存 CTA（`.buttonStyle` 未指定 / `plus.circle.fill` + `.font(.body.bold())`）も `.borderedProminent` + `plus` に揃えた。②を入れると**同じ「コーヒーを記録」の空状態 CTA が画面ごとに別スタイル**になり、UX-3 で潰した分岐が別の形で再発するため。ユーザー指摘の範囲外だが差分は 2 行。

**目視未確認のままコミットした点を明示しておく**。`.borderedProminent` がツールバー内で実際に塗りとして描画されるかは、**コードからは判断できない** — `List` / `Form` では `tint` を明示しても `Label` のアイコンだけ効かない前例があり（lessons 2026-08-07）、**コンテナが子の見た目を書き換える挙動は子側のコードを読んでも分からない**。サブエージェントは sandbox の GUI 制約で目視できず、親も同様。ビルドはフラグ無しで `** BUILD SUCCEEDED **` を確認済みだが、**ビルド成功はこの変更の完了条件になっていない**ため、確認項目を verification-checklist のパス 1（記録 0 件は 1 インストールにつき 1 回しか見られない）/ パス 2 / パス 3 に分けて積んだ。

`04-record-list.png` は訴求ポイント自体が「ナビバー右上の追加ボタン」を含み、`06-cafe-detail.png` にも同じボタンが写るため、**次回提出時の再撮影対象**として `app-store-metadata.md` §5 に警告を置いた（撮り直しは今回やらない）。

**追記（同日）: 上の変更で退行を 1 件出し、ユーザーの目視で発覚した。** カフェ詳細の空状態 CTA で **`+` アイコンが消えた** — `List` 内の `Label` はアイコンだけ `accentColor` で描かれ、`tint` 未指定の `.borderedProminent` は塗りも `accentColor` なので同化した。`.foregroundStyle(.white)` で修正（`saveButton` と同じ処方）。

この件で**上に書いた「目視未確認のままコミットした」の位置づけが変わった**。目視を verification-checklist に積んだこと自体は機能して発見に繋がったが、**この退行は目視の前に防げた**。罠は `lessons.md` 2026-08-07 続報に「②`List` 内 `borderedProminent` + `tint` → こちらもアイコンだけ茶」と**実測結果まで記録済み**で、対処済みの実例は**同じファイルの 200 行上**にあり、しかも親はプランと dispatch 指示の両方でこの罠に言及していた。**にもかかわらず、それを「実装後に目視で確かめる項目」としてしか使わず、「実装時に `.foregroundStyle` を当てる条件判定」に変換しなかった**。教訓は lessons 2026-08-31 に記録し、`.claude/rules/swift-ios.md` と `docs/ui-ux-guidelines.md`（「追加アクションの配置」）にも昇格させた。

