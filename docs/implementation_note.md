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

**2026-06 / 2026-07 / 2026-08 のエントリ（= 1.0 リリースまでの全 139 件）は [`implementation-note-archive.md`](./archive/1.0/implementation-note-archive.md) に凍結移送済み**（2026-08 分は 1.0 リリース時の docs 整理で移送）。他 doc・コードコメントからの「implementation_note 2026-0X-XX エントリ」という参照は**アーカイブ側を指す**。**本 doc に残っているのは 1.0 リリース後の新規分**。

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
- Places API キーはクライアント埋め込みで**抽出不可避**。`X-Ios-Bundle-Identifier` によるバンドル ID 制限は生 REST 呼び出しでは**ヘッダなりすましで突破可能**（暗号検証なし）＝事故防止レベルで実効的防御ではない。現実的な守りは Google Cloud の**予算アラート + クォータ上限**（被害額に天井）+ API 制限の Places 限定。本命はバックエンドプロキシ + App Attest（規模拡大時に検討）。詳細は 2026-07-08 エントリ。**この 3 点はいずれも設定済み**（設定状況の正本は paid-services §1「コスト抑制の現状」で、**実値は Cloud Console が正本**）
- 分析は 3 階層分離: 階層1・2 は KMP で決定論（`CoffeeStats` / `FavoriteSignals`。収縮平均 + n 連動 z ゲート `CATEGORY_Z = 2.0` + 相関 floor で「弱い傾向」だけを信号化、断定しない）、階層3 は iOS Foundation Models（`CoffeeInsightProvider`。可否は注入時判定、null = 非対応端末で graceful degradation）。Q&A は v1 = `CoffeeStats` digest 注入（単発・ステートレス）/ v2 = `Tool` から `CoffeeRecordQuery.searchRecords`（計算は KMP・LLM は解釈と整形のみ）
- `BeanProfile`（12-B）はサーバ管理 read-only の豆ナレッジ。`CoffeeRecord` と ID 紐付けせず origin / processings のファジーマッチ。取得は one-shot get + メモリキャッシュ。12-C で `FavoriteSignals` と突合した `preferredBeanTraits` を `CoffeeStats` に付加し、Foundation Models で言語化
- 味覚一致カフェ推薦: **9-5（コンテンツベース v1）は 1.0 で実装済み**（`ObserveTasteMatchedCafesUseCase` / `RecommendedCafe` / `CafeRecommendationProvider`、産地/焙煎/抽出/精製の 4 軸マッチ、マップの好み一致ピン + 理由表示 + 分析タブ連携。テイスティング 5 軸の一致はスコープ外）。**9-6（協調フィルタ / 他ユーザー横断 v2）は設計確定・未実装**（`sharedTasteProfiles/{uid}` + Cloud Function 特権 read。閾値定数 / Function 内実装 / インフラ選定は未決。tasks 12-D で段階 dispatch）。詳細は analysis-model §2
- データ利用同意（12-A）: `users/{uid}.analyticsConsent`。初回起動オンボーディングで取得し設定トグルで変更可。ドキュメント不在は false 扱い
- Firebase テレメトリ（iOS のみ）: **Crashlytics + Performance = 常時収集**（同意不要）、**Analytics = `analyticsConsent` 同意時のみ**。Analytics は素の `FirebaseAnalytics` プロダクト（現行 firebase-ios-sdk 12.14.0 では既定で IDFA 非依存 = 旧 `WithoutAdIdSupport` 相当。旧プロダクトは廃止。IDFA を使う場合のみ `FirebaseAnalyticsIdentitySupport` を追加する反転構成）。`Info.plist` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO` で Analytics 自動収集のみ起動時 OFF（Performance は常時 ON）→ `AppState.analyticsConsent` の `didSet` → `applyTelemetryConsent` が Analytics だけ有効化。イベントは自動収集 + `screen_view` のみ（カスタムイベント未導入）。詳細は 2026-07-08 エントリ

---

## エントリ形式

タイトル + 本文だけで十分。

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

**追記 2（同日）: 目視確認が通った。** あわせて **`.buttonStyle(.borderedProminent)` は `ToolbarItem` の中では塗りとして正しく効く**ことが実測で確定した（`ToolbarItem` は `List` / `Form` の外なのでアイコン同化は起きない。lessons 2026-08-07 続報の「③`List` の外 → 文字・アイコンとも揃う」と整合する）。**この doc で 2 度「コードから判断できない」と書いた点への答え**なので、規則側（ui-ux-guidelines「追加アクションの配置」）にも確認済みの旨を明記した。`verification-checklist` の 4 項目は運用ルールどおり削除済み。

**追記 3（同日）: 2 画面の空状態 CTA を構成要素まで揃えてクローズ**（ユーザー依頼）。記録一覧側を `Text` → `Label(systemImage: "plus")` にし、カフェ詳細と同じアイコン付きに統一。目視確認済み。

ここで **`.foregroundStyle(.white)` は写さなかった**。あれは `List` 内の罠への対処であって意匠ではなく、`CoffeeListView.emptyView` は `ContentUnavailableView` = `List` の外なので条件が成立しない。写していたら**将来 tint を変えたときに読めなくなる負債**になっていた。目視で `.foregroundStyle` 無しでもアイコンが正しく描かれることを確認し、**罠の成立には「塗り + `Label` + `List` / `Form` の中」の 3 条件すべてが要る**ことが確定した（lessons 2026-08-31 / `.claude/rules/swift-ios.md` / ui-ux-guidelines に「逆に `List` 外では付けない」を明記）。**同じ見た目の UI を 2 箇所に作るとき、片方に付いている modifier が意匠なのか特定コンテナへの対処なのかを区別してから写す** — 今回はこれを分けたことで負債を作らずに済んだ。


### 2026-09-19: 広告をインライン 2 面から全画面下部固定帯 1 面へ再編

- 関連: `iosApp/iosApp/Ads/AnchoredBannerAdView.swift` / `iosApp/iosApp/iOSApp.swift` / `iosApp/iosApp/AppState.swift` / `docs/requirements.md` §11 / `docs/ui-ux-guidelines.md`「下部固定広告帯」/ 計画は `.claude/plans/mutable-skipping-pizza.md`

ユーザー指示「一番下に広告のエリアを設けてタブバーとコンテンツすべてその上に表示する」（Pixiv 等と同じ構成）。インライン 2 面（カフェ詳細 / マップ検索結果シート）を撤去し、全タブ常設の下部固定帯 1 面に集約した。

**動機はインプレッションの構造的な不足**。インライン枠は「その画面を開いて、かつそこまでスクロールした人」にしか露出せず、Places 従量コストの回収という §11 の目的に届いていなかった。

**2026-07-16 の「記録タブ・分析タブには置かない」を撤回したが、根拠は書き分けた。** リテンション懸念が消えたのではなく**枠の性質が変わった** — コンテンツの流れに割り込むインライン枠と、タブバーの外側に固定されコンテンツを一切押しのけない常設帯では、可処分注意への侵襲度が違う。**インライン枠を記録・分析タブへ再導入する判断は今も無効**である旨を requirements に明記した（ここを曖昧にすると 2026-07-16 の判断ごと無効化されて読まれる）。

**自動リフレッシュはクライアント側 60 秒タイマー**（`scenePhase == .active` 限定）。`BannerView.isAutoloadEnabled` を検討したが、SDK が自動生成するリフレッシュ用リクエストに `makeRequest()` の NPA extras が反映されるかを公式ドキュメントで確認できなかった。**ATT 拒否ユーザーへの NPA 徹底は規約遵守の要点**なので、コード側で完全制御できない経路に委ねられない。doc には「**調べたが分からなかった**のであって、反映されないと確認したわけではない」と書き分けた（SDK 側に保証が出れば再検討できる）。AdMob コンソール側のユニット自動更新は**オフにする必要がある**（二重リフレッシュ防止。`paid-services.md` §2b に運用注意として記載）。

**サイズは `inlineAdaptiveBanner(width:maxHeight: 50)`。配置はアンカードなのにインライン用の関数を使っている。** アンカード用の関数は高さを指定できず、`currentOrientationAnchoredAdaptiveBanner` は SDK で非推奨、置換先の `largeAnchoredAdaptiveBanner` は上限 150pt で実機では画面の約 15% を占めた。**常設帯には高さの天井が要る**という要件が先にあるため、天井を指定できる関数を選んだ。50 は `GADAdSize.h` が推奨する `maxHeight` の下限ちょうどで、これ以上は下げない。

**実装で 2 回作り直した。どちらも親の設計・指示の誤りで、ビルドも型検査も通り、実機の目視でしか出なかった。**

1. **`.safeAreaInset(edge: .bottom)` ではタブバーが広告の裏に隠れた**。`safeAreaInset` はフレームを縮めずセーフエリアの報告値だけを書き換えるため、フレーム基準で位置決めする iOS 26 の浮動タブバーには効かない。フレームごと縮める `VStack` が必要だった。プラン段階で「`VStack` と結果は同じ」と**根拠なく**判断したのが起点（lessons 2026-09-19）
2. **「未受信・失敗時は高さ 0 に畳む」でロード完了時にタブバーごと跳ねた**。これは §11 に既にあった確定仕様だが、**インライン枠（消えても周囲が詰まるだけ）のための作法**で、レイアウトの土台になる常設帯には当てはまらなかった。`.claude/rules/swift-ios.md` に「幅・高さを持つ要素を `if` で条件生成しない」と**自分で書いてある規約に反する指示を親が出していた**。高さ常時確保に修正し、doc 側も「帯は畳まない / インライン枠は畳む」と作法を書き分けた（lessons 2026-09-19）

**`canLoad` のゲートにも設計の穴があった**。「同意フローが閉じるまでロードしない」を `!showAdConsentFlow` で書いたが、これはシートの表示状態でしかなく、`onAdPrePromptContinue()` はシートを閉じた**後**に ATT ダイアログを非同期で開始する。ATT ダイアログ表示中にリクエストが飛び、避けたかった「初回インプレッションが必ず NPA」がそのまま起きていた。`AppState.isAdConsentResolved`（`await AdConsentCoordinator.run()` 完了後に立てる）を追加して解決（lessons 2026-09-19）。

- 影響: **スクリーンショットの全面撮り直しが必要**。全カットの下端に広告帯が入り、「カフェ詳細だけ Test Ad に注意」という 1.0 系の回避が成立しない（`app-store-metadata.md` §5 に撮影手順ごと記載）。**広告ユニットは未発行**で、下部固定帯用の本番 ID を AdMob で発行して `Secrets.xcconfig` / GitHub Secrets へ登録する作業が残る

### 2026-09-20: observation の所有を Swift の構造化並行性へ移した

- 関連: `iosApp/iosApp/Features/<Name>/<Name>ViewModelBridge.swift`（8 本）/ `iosApp/iosApp/AppState.swift` / `docs/kmp-bridge.md`「ViewModel ブリッジパターン」/ tasks B-11 / 教訓は lessons 2026-09-20

docs の冗長排除中に `kmp-bridge.md`「メモリ管理の注意」の記述が同 doc 内の別の記述と矛盾していることに気づいたのが発端。調べると**規約と実装がどちらも正しくなく**、さらにその下に実際のリークが埋まっていた。

**判断の分かれ目は「どこで畳むか」ではなく「誰が持つか」だった。** 最初は `.onDisappear` か `deinit` かの二択で議論していたが、Swift の一次情報を引いて前提が崩れた。

- 非構造化 `Task` は参照を手放しても止まらない（`Task.swift:26-31`）。つまり `deinit` の到達性は問題ではなく、Task がブリッジより長生きすること自体が問題
- キャンセルは**協調的**で、`cancel()` は依頼にすぎない（`Task.swift` の `cancel()` doc / `AsyncIteratorProtocol` は iterator が応答することを **should** としか定めていない）。だから「どこで cancel を呼ぶか」を決めても、**呼べば止まる保証がそもそも無い**
- SE-0304 は「`cancel()` を持つトークンを同期的に返す API 設計は複雑さを持ち込む」と明言している。保持していた `observationTask` はそのトークンだった

**そこで `deinit` に `cancel()` を足す案（A）を採らず、所有をスコープへ移した（C）。** ただし A も 1 本だけ実装して実測している。目的は止血ではなく、**C の前提（SKIE が協調キャンセルに応答するか）を先に確かめる**ため。応答しなければ `.task` に移しても同じリークが残り、C の形自体が変わっていた。

- 影響: `cancel()` / `onDisappear()`（observation 用）が全廃され、正味 53 行減った。`AppState.resetAndRebootstrap()` の手動キャンセル 4 行も不要になった（`AppRootView` がブリッジ nil で `RootTabView` ごと畳むため）
- トレードオフ: `CoffeeEditorViewModelBridge` だけ `onAppear(mode:userId:)`（同期）+ `observe()`（非同期）の 2 メソッドに分かれる。エディタの `.task` は「Kotlin 初期化 → カフェ pre-fill → 現在地サジェスト → 購読開始」の順序依存があり、`observe()` が戻らないため 1 本に畳むと pre-fill とサジェスト（要件 2-8）が実行されない。**シグネチャの不揃いより機能の維持を採った**
- 検証: 番兵オブジェクトによる実測を移行の前後で実施。移行前は 2 サイクルとも解放されず、移行後は `CafeSearch` / `CafeDetail` の全インスタンスで `loop exited` → `sentinel deinit` → `deinit` が揃った。収支も一致（未解放の 1 件は計測終了時に画面を開いたままだったインスタンスで、スクリーンショットで確認済み）
- 実機確認: **ユーザーによる実機確認で OK**（2026-09-20）。見た対象は、過去 2 回凍結バグを出したマップ検索の「他タブへ行って戻る → もう一度検索」、タブ往復での凍結、カフェ詳細の pop → 再 push、そして `resetAndRebootstrap()` の手動キャンセル 4 行を削除した影響が出るサインアウト / アカウント削除後の再起動
- 経緯の注記: **`MapSearchController.searchBridge` は View が持たないブリッジ**で、当初は「そこだけ現状維持でよい」と指示していた。`setupAndObserve(makeViewModel:) async` に統合して `MapTabView` の `.task` から駆動する形で解決し、結果として長寿命ブリッジにも再購読経路ができた

### 2026-09-20: 1.0.3 の提出準備で、リリースビルドがデモ広告のまま出荷される状態を見つけた

- 関連: `.github/workflows/release-testflight.yml` / `iosApp/Configuration/Base.xcconfig` / `docs/app-store-metadata.md` §10 / tasks 1.0.3 節 / 教訓は lessons 2026-09-20

`app-store-metadata.md` §10 のチェックリストを上から潰す過程で発見した。2026-09-19 の広告再編でビルド変数名を `ADMOB_BANNER_AD_UNIT_ID_CAFE_DETAIL` / `_MAP_SEARCH` から `_GLOBAL_BOTTOM` へ変えたのに、**CI の「Restore secret files」が旧キー名のまま**だった。fail-fast のガードは存在しないキーを見張り、実際に必要な `_GLOBAL_BOTTOM` は書き出されないので、`Base.xcconfig` のフォールバック = Google デモ ID が採用される。

**ワークフロー自身のコメントが「未設定のまま出荷すると Base.xcconfig のデモ AdMob ID で広告が載る（収益ゼロ）」と警告しているのに、その状態になっていた。** ガードがキー名に依存していたため、名前が変わった瞬間に無言で無効化されていた。

- 影響: 1.0.3 を**この状態で出荷していたら収益がゼロ**だった。ビルドは通り、実機でも広告は出る（デモ広告が出る）ので、目視でも気づけない
- 検証: `Info.plist` が `$(...)` で要求する変数集合と、CI が `Secrets.xcconfig` へ書き出す変数集合を比較。修正後は `ADMOB_APP_ID` / `ADMOB_BANNER_AD_UNIT_ID_GLOBAL_BOTTOM` / `PLACES_API_KEY` の 3 つで過不足なく一致
- 残るブロッカー: **下部固定帯用の広告ユニットがまだ未発行**（ユーザー作業）。CI を直したので、未登録のままリリースビルドを回すと fail-fast で落ちる。**デモ ID のまま静かに出荷されるより良い挙動**になった
- 経緯の注記: これは 2026-07-22 と**同型の再発**。あのときは「CI が `PLACES_API_KEY` しか書き出していない」問題で、キーを足して直した。今回は「キー名が変わった」ケースで、当時の修正では一般化できていなかった

### 2026-09-20: SL-1 / SL-2 — `@unchecked Sendable` の適用範囲を縮めた

- 関連: `iosApp/iosApp/FirebaseRepositories/FlowBridge.swift` / `AuthRepositoryIosImpl.swift` / `RemoteCoffeeDataSourceIosImpl.swift` / `RemoteSavedCafeDataSourceIosImpl.swift` / `iosApp/iosApp/Features/Analysis/CoffeeInsightProviderIosImpl.swift` / [`kmp-bridge.md`](./kmp-bridge.md) / tasks SL-1・SL-2

`CallbackFlow` / `CallbackFlowOptional` の `onStart` / `onCancel` を `@Sendable` 化し、両クラスを `@unchecked Sendable` から**素の `Sendable`** へ。狙いは挙動ではなく**コンパイラに検査させる範囲を戻すこと**で、クラス全体の `@unchecked` が利用側の捕捉まで検査から外していた。

利用側は起票時に数えた 4 箇所ではなく **5 箇所**だった（`AuthRepositoryIosImpl.observeAnalyticsConsent` も同型で、`permission-denied` 系でリスナが残る）。5 箇所すべてでリスナハンドルを `OSAllocatedUnfairLock` 保護へ移し、取り出しと無効化をロック内でアトミックに、解除呼び出しはロックの外で行う形に揃えた（`FlowCompletionGate.finish` と同型）。

保護対象が非 Sendable な OS ハンドル（`any ListenerRegistration` / `AuthStateDidChangeListenerHandle`）なので `init(uncheckedState:)` + `withLockUnchecked` を使う。`init(initialState:)` は `extension OSAllocatedUnfairLock where State : Sendable` の中にあり、`withLock` は `body: @Sendable` と `R : Sendable` を要求するため、この用途では原理的に使えない（SDK の `.swiftinterface` L2430-2439 / L2538-2539 で親が実読み確認）。

- 影響: Firestore の 2 データソースは `Firestore` インスタンスの捕捉をやめ、`CollectionReference` を外で組み立てて捕捉する形に変えた。`FIRFirestore.h` に `NS_SWIFT_SENDABLE` が無く、`FIRCollectionReference` / `FIRDocumentReference` / `FIRQuery` には付いているため（親がヘッダを実読み確認）。副産物としてクロージャ内のパス手組みと既存 private ヘルパの二重定義が解消された
- トレードオフ: 唯一塞げなかったのが `__collect` の `collector`（SKIE 生成の非 Sendable existential）を `@Sendable` な `emit` へ捕捉する箇所。`FlowBridge.swift` に `@preconcurrency import SharedLogic` を付けて解いた。**これは新しい穴ではない** — collector を別スレッドから触ること自体はブリッジ成立以前からの前提で、既存の前提をファイルスコープで明示しただけ。代案の `extension ...FlowCollector: @retroactive Sendable` は全適合型に効くので採らなかった。**この import は利用側 5 ファイルの検査には影響しない**（`@Sendable` は `onStart` / `onCancel` の型の一部なので、利用側は自分のファイルの通常 import の下で検査される）
- トレードオフ: 「`onStart` がリスナ登録を終える前に `onCancel` が走る」競合窓は**意図的に残した**。`__collect` 実行中は Kotlin 側が Flow オブジェクトへの強参照を保持するため `deinit` が並行して走ることは構造的に起きない。塞ぐなら 3 状態（pending / registered / cancelled）を 5 箇所に入れることになるので、必要になったら共通ヘルパへ切り出す
- SL-2: `CoffeeInsightProviderIosImpl.tasteExtractor` を `private init` 引数の `let` にした。「公開前に 1 回だけ設定」というコメントでの正当化が構文的に不要になり、同クラスも素の `Sendable` へ落ちた
- 残務: `BeanProfileRepositoryIosImpl` / `CuratedCafeRepositoryIosImpl` の `@unchecked Sendable` は残る（`private let db = Firestore.firestore()` が非 Sendable。外すには `db` を持たない設計変更が要る）。判定基準は kmp-bridge の表に明文化したので、外すかは費用対効果で別途判断する

### 2026-09-20: SL-4 — マップのピン競合解決を `MapTabView` の body から `MapViewModelBridge` へ移した

- 関連: `iosApp/iosApp/Features/Map/MapViewModelBridge.swift` / `MapTabView.swift` / `MapTabView+PinResolution.swift` / `AppleNearbyCafeLoader.swift` / [`coding-conventions.md`](./coding-conventions.md) §2.5 / tasks SL-3・SL-4・SL-5

`displayedSavedCafes` / `displayedSearchResultPlaces` / `displayedCuratedCafes` / `existingPinCoordinates` は `MapTabView` extension の関数として body から毎回呼ばれており、body 評価のたびに Set 3 本の構築と最大 421 件の `CLLocation` 測地距離計算が走っていた。入力が実際に変わったときだけ計算する形にするため `MapViewModelBridge` の `private(set) var` へ移した。Apple 周辺ピンの重複排除も同様に `AppleNearbyCafeLoader.displayedCafes` へ。`MapTabView+PinResolution.swift` は `minimalCafe(from:)` だけの 37 行になった。

**ブリッジの責務が「Kotlin state のミラー」から一段広がる**のが代償。代替案は「`@Observable` な resolver を View の `@State` に置き `.onChange` 4 本で駆動」だったが、これは body 評価のたびに Kotlin 配列 4 本の `==`（要素ごとに Obj-C 越しの `isEqual:`、curated は 421 件）を走らせることになり、**解こうとしている問題を別の形で作る**ため採らなかった。「Kotlin state から一意に決まる派生値は emit のタイミングで計算する」= ブリッジが正しい場所、という判断。

- 影響: **body から `appState.mapSearchCenter` を読む依存が消滅した**。`displayedCuratedCafes(bridge)` がその唯一の経路だった。2026-08-09 のウォッチドッグ障害（カメラ → ピン表示数 → カメラの循環）に対して、`MapTabView+PinResolution.swift` の旧 doc コメントが守ろうとしていた「依存方向を増やさない」より**一段強い状態**になっている。親が全 `appState.mapSearchCenter` 参照を確認し、残るのはすべて action closure 内（Button action / `.onChange` ハンドラ / `.task` / `.onSubmit` / `.onMapCameraChange`）で body 評価時に評価される式はゼロであることを確認済み
- 指示からの逸脱（採用）: 親の dispatch は「カメラ依存分は `.onChange(of:)` から更新する」と指示したが、**これは誤りだった**。`.onChange` の `of:` 式は body 評価時に評価されるため、`appState.mapSearchCenter` を `of:` に書くと消したはずの body 依存が復活する。実装は既存の `.onMapCameraChange` ハンドラから `bridge.updateMapSearchCenter(_:)` を直接呼ぶ形になっている。**`.onChange` は「SwiftUI が値比較してくれる」利点と「body 依存を作る」代償がセット**で、既に body が読んでいる値なら前者だけ得られるが、読んでいない値に使うと後者を払う。この区別を `coding-conventions.md` §2.5 に書き分けた
- トレードオフ: 同値判定を `AppState.mapSearchCenter` 側の既存ガードに**相乗りさせず**ブリッジ側に持たせた。サインアウト → `resetAndRebootstrap()` は `mapBridge` だけを作り直して `appState.mapSearchCenter` は残すため、相乗りすると新ブリッジが「同値だから渡されない」でカメラ中心を永久に受け取れず、curated ピンがユーザーが地図を動かすまで出なくなる。あわせて `MapTabView` の `.task` で現在値を 1 回流し込んでいる
- トレードオフ（残存）: Apple ピンの重複排除が `bridge.existingPinCoordinates` → `.onChange` → loader の経路になったため **1 フレーム遅れる**。新しい訪問済み / 保存済み / curated ピンが出た直後の 1 パスだけ、40m 以内に Apple ピンが重なって見えうる（次のパスで消える）。データ投入は起動直後に集中するため実害は小さいと判断。目視確認項目に入れた
- SL-3: ブリッジ 8 本の `apply(_:)` に同値ガード。判定基準は [`kmp-bridge.md`](./kmp-bridge.md)「Swift 側での等価性」へ。`AnalysisViewModelBridge` の 3 status は `!==`（全 case が `data object` = シングルトン）、`CafeDetailViewModelBridge.matches` のみガード不可
- SL-5: `ApplePoiNegativeCache.snapshot()` を追加し、`AppleNearbyCafeLoader.fetch` の `compactMap` 前で 1 回だけ `UserDefaults` 読み + JSON デコード（POI 1 件ごと最大 50 回 → 1 回）。`add(name:coordinate:)` のシグネチャは不変

### 2026-09-20: SL-6〜SL-10 — 書き方を stdlib / SE の先例へ揃えた

- 関連: `iosApp/iosApp/Utilities/AppLog.swift`（新規）/ `Features/Map/MapRegionFitting.swift`（新規）/ `Features/Analysis/AnalysisView+Statistics.swift` / `Utilities/LocationManager.swift` / [`coding-conventions.md`](./coding-conventions.md) §2.3・§2.5 / tasks SL-6〜SL-10

`AnyView` 14 箇所 → `@ViewBuilder`、`Task.sleep(nanoseconds:)` 3 箇所 → `Task.sleep(for:)`、`print` 28 箇所 → `os.Logger`、bounding box 計算の重複解消（force unwrap 8 個を除去）、`@Observable` 同値ガードの残り 2 件。規約への昇格は `coding-conventions.md` §2.3 / §2.5 へ済み。以下は判断の経緯だけ残す。

**`LocationManager.lastLocation` の同値ガードを誤差比較にしなかった理由。** `MapSearchCenter.isEquivalent`（1m 許容）は「MapKit のカメラが再適用のたびに浮動小数の下位桁を揺らす」ことへの対処で、位置バイアス用途では 1m 未満の差が無意味だという前提に立つ。対して `LocationManager` は継続監視を使わず `requestLocation()` のワンショット取得しかしておらず、抑止したい重複は「短時間に複数回呼んだとき CoreLocation が同じキャッシュ fix を返す」ケース = **ビット完全一致**。誤差比較にすると近距離の実移動まで握り潰す副作用の方が大きい。**同じ「座標の同値判定」でも、揺れの出どころが違えば比較方法も違う。**

型を `MapPinCoordinate`（SL-4 で新設）に置き換えなかったのは、消費側 4 箇所（`CoffeeEditorView` / `MapTabView` / `MapTabView+Location` ×2）がいずれも `CLLocationCoordinate2D` のまま MapKit / KMP へ渡しており、変換が全箇所に要るうえ `Utilities/` → `Features/Map/` の依存逆転になるため。

**`AppLog` を `nonisolated enum` + `private nonisolated let` にした理由。** 既定 MainActor 分離下では、`nonisolated final class`（Kotlin interface 実装）から共有ロガーを参照する形にすると分離の不整合が出る。`Logger` は `Sendable` なので `nonisolated` を明示するだけで済み、SL-1 でせっかく外した `@unchecked Sendable` を復活させずに解決できた。

- 影響: `print` の `[CoffeeVision]` 等の手書きプレフィックスは subsystem / category へ移した。開発時は `xcrun simctl spawn <udid> log stream --level debug --predicate 'subsystem == "com.noricoffee.coffeevision"'` で見る（`--level debug` を省くと `.info` / `.debug` が出ない）
- 未確認: **`privacy: .private` の redaction はシミュレータでは実証できない**（デバッガ配下では private データが表示される Apple の挙動）。コード上 `.private` が付いていることまでは確定だが、「本番端末のログに uid が出ない」の実証は実機 / TestFlight ビルドでの確認が要る
- SL-9: 単一件数時のズーム距離が用途ごとに違った（訪問済み 2000m / 検索結果 800m）ため `singleCoordinateMeters` 引数で受ける形にした。0 件は `nil` 返しで、訪問済み側は東京駅 5km デフォルト、検索結果側は no-op という従来の差を呼び出し側に残してある（0 / 1 / 複数件の 3 ケースとも挙動不変）
