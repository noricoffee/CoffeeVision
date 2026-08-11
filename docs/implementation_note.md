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

**2026-06（36 件・2026-07-25 移送）と 2026-07（73 件・2026-08-11 移送）のエントリは [`implementation-note-archive.md`](./implementation-note-archive.md) に凍結移送済み**。他 doc・コードコメントからの「implementation_note 2026-06-XX / 2026-07-XX エントリ」という参照は**アーカイブ側を指す**（参照は日付で引く運用で、行き先もアーカイブ 1 ファイルに固定しているので、参照側の書き換えは不要）。**本 doc に残っているのは 2026-08 以降**。

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

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。（最終棚卸し: 2026-08-01）

> **このサマリに「数え上げ」と「構成要素の列挙」を書かない**（2026-08-01 の棚卸しで制定）。引数の個数・公開プロパティ一覧・コレクション一覧は、依存が 1 つ増えるたびに**全項目がまとめて嘘になる**うえ、増やした本人はソースしか見ないので気づけない。実際この棚卸しでは「プライマリ 7 / iOS 6 / Android 5 引数」（実際は 9 / 8 / 7）と削除済みの `beanProfileMatchUseCase` が残っていた。**書くのは「どこを真とするか」と、数えなくても変わらない構造・不変条件だけ**（`CuratedCafe.kt` KDoc で 2026-07-25 に同じ判断をしている）。

- ドメインは **CoffeeRecord 主体**（2026-06-19 クリーンブレイク）: 1 杯 = 1 記録、`cafe: Cafe?`（null = セルフ抽出）、`rating` は 0.5 刻み `Double?`（null = 未評価、2026-07-12 B-4 で sentinel 廃止）、`tasting` は all-or-nothing（`TastingScores?`）、`tags: List<String>`。**産地は `origin: String?`（国名。`CoffeeOriginCatalog` から選択、2026-07-22 に自由入力→国ドロップダウン化）+ `region: String?`（エリア / 農園、任意自由入力・表示専用で分析非対象、migration 6 で追加）**。モデル・DB・Firestore 表現は `data-model.md` を真とする
- CI（GitHub Actions）は `testAndroidHostTest`（**全モジュール一括指定**。モジュール個別列挙は漏れるため禁止。2026-07-25 是正。**件数はここに書かない** — 上の「数え上げを書かない」規約どおり、テストが増えるたびに嘘になる）+ `:androidApp:assembleDebug`（Android ジョブ。ダミー `google-services.json` を CI 内で生成）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成。`xcodebuild` / `iosSimulatorArm64Test` は CI 非対象で親のローカル検証が担保
- `CoffeeRepository` は `commonMain` で 2 段構成（`RemoteCoffeeDataSource` interface + `CoffeeRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteCoffeeDataSource` だけを書く。書き込みはローカル → リモート順、リモート失敗の扱いは `WritePolicy`（既定 `PropagateRemoteFailure`）
- Firestore は `users/{uid}/coffees/{id}` の単一ドキュメント（`cafe` 任意埋め込み + `photos` 埋め込み配列 + `tasting` マップ + `tags` 配列。子サブコレクションなし）+ `users/{uid}` ルート（`analyticsConsent`）+ サービス管理・read-only の `beanProfiles` / `curatedCafes`。**コレクションの正確な一覧は `firestore.rules` を真とする**。nullable はキー省略。`Photo.localPath` は書かず `fileName`（`Documents/photos/` フラット配置）で復元、`remoteUrl` は常に null（Storage 不採用・写真は端末ローカルのみ）
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる。**対になる `stopSync()` が同期 `Job` を畳む**（2026-08-09 SR-4）: `AppContainer` が coffees / savedCafes の同期 Job を保持し、`startInitialSync()` は冒頭で `stopSync()` を呼んで冪等化、サインアウト時は `AppState.resetAndRebootstrap()` の冒頭でも呼ぶ。**これが無いとサインアウトのたびに旧 uid の購読が 1 組ずつ残り、Rules（`request.auth.uid == uid`）で必ず権限エラーになる**
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

> **2026-08-08 追記（SR-3）**: この「対象外」判断は**解像度については正しいが、観点が 1 つ抜けていた**。`loadedPhoto` が computed property だったため、**同じフルデコードが body 1 回につき 3 回以上**走っていた（`bandHeight` → `infoAreaHeight` → `radarHeight` → `radarScale` の連鎖 + `headerOrPhotoBand`。`ImageRenderer` は body を複数回評価するのでさらに増える）。**「どの解像度でデコードするか」を検討したときに「何回デコードするか」は見ていなかった。** SR-3 で `init` 解決の stored property に変更（解像度はフルデコードのまま維持）。

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

### 2026-08-08: ドメイン enum の日本語ラベルを `DomainLabels.swift` に集約（SR-2）

- 関連: `iosApp/iosApp/Utilities/DomainLabels.swift`（新設）/ `.claude/rules/swift-ios.md` / `docs/tasks/lessons.md` 2026-08-08 / `docs/tasks.md` SR-2

Swift コードレビュー #4。同じ対応表が **18 箇所**に手写しされていた（roast 6 / brew 7 / tasting 4 / processing 1）。`BrewMethod` / `RoastLevel` / `ProcessingMethod` / `TastingAxis` の 4 型を `Utilities/DomainLabels.swift` の extension へ集約した。

**着手して分かった本題**: 起票時の見立ては「値は全一致しているが `String(localized:)` の有無が既に割れており、将来ケースが増えたら 18 箇所直す必要がある」だった。実際に重かったのは**将来のリスクではなく現在の不具合**で、記録エディタと記録詳細の「精製方法」「焙煎度」が `.name` 直表示のまま英語（`Anaerobic` / `FullCity`）だった。しかもエディタは**同じ `Form` の 3 行隣に `localizedBrewMethod` があり、「抽出方法」だけがそれを使っていた**。構造の分析と横断点検の結果は lessons 2026-08-08 に記録。

**API の形**: 2 つの入り口を用意した。`localizedLabel`（インスタンスプロパティ、`switch` に `default` なし = Kotlin 側のケース追加がコンパイルエラーになる）と `static localizedLabel(forName:)`（`CategoryStat.label` のように KMP の集計結果が `String` で降ってくる経路用。enum 版へ委譲するので対応表は 1 本）。旧実装の `default: return name` は、漏れると黙って英語名を返す作りだった。

- 影響: 記録エディタの Picker 2 箇所（精製方法 / 焙煎度）と記録詳細の 2 箇所が英語 → 日本語に変わる。**UI の表示が変わる変更**なので、ユーザー確認のうえ同一コミットに含めた。詳細の 2 件は当初の対象に入っておらず、**横断点検で初めて出た**（ユーザーへの事前説明で「詳細・分析・共有カードは既に日本語」と述べたのは誤り）。
- トレードオフ: **`TastePreferenceConversionView.localizedRoast` は意図的に集約対象外**。見た目はほぼ同じ対応表だが、入力が `RoastLevel.name` ではなく **Foundation Models の自由出力**で、`"unknown"` → 「不明」を持ち、プロンプトが `RoastLevel` に存在しない `"Dark"` も指示している。定義域が違うので統合しない旨を `DomainLabels.swift` の冒頭に明記した。
- `nonisolated extension` にした理由: 既定 MainActor 分離下では extension も暗黙 `@MainActor` になり、`nonisolated` な呼び出し元（`CoffeeInsightProviderIosImpl` = Kotlin ランタイムが任意スレッドから呼ぶ / `SearchCoffeeRecordsTool` = Foundation Models のツール実行）から呼べない（実際 8 件のコンパイルエラーが出た）。引数だけから決まる純粋関数なので `PhotoFileStore` と同じ判断。
- 作業上の失敗（記録）: 一括置換スクリプトに `re.sub(r"\{\n\n+", "{\n", s)` を入れたため、**`struct X: View {` 直後の空行というプロジェクト共通のスタイルまで消していた**（8 ファイル）。`git checkout` は許可されなかったので、HEAD 版と現在版を `difflib` で比較し「削除されたのが空行だけ」のハンクのみ復元した。**一括置換の後は必ず「意図した種類の差分しか無いこと」を diff で確認する**（今回は `git diff | grep "^-" | grep -v <想定パターン>` が空になることを確認してから再ビルドした）。
- 検証: `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しで `** BUILD SUCCEEDED **`。差分は 8 ファイルで +29 / −287。**記録エディタ / 記録詳細の 4 箇所が日本語表示になることをシミュレータで目視確認済み**（2026-08-08、ユーザー確認）。

### 2026-08-08: 共有カードの写真デコードを body 評価ごとから init 1 回へ（SR-3）

- 関連: `iosApp/iosApp/Features/CoffeeDetail/ShareCard/CoffeeShareCardView.swift` / 本ファイル 1350 行付近の追記 / `docs/tasks/lessons.md` 2026-08-08

Swift コードレビュー #5。`loadedPhoto` を computed property から `init` 解決の stored property へ変更した。**解像度（フルデコード）は維持**し、回数だけを減らしている。前日 SW6-A で「対象外（意図的）」とした判断は解像度については正しく、抜けていたのは回数の観点だけだった（詳細と教訓は lessons 2026-08-08）。

- 影響: **レイアウトは変わらない**。`bandHeight` の判定は `loadedPhoto != nil` で、写真の有無という結果は同じ。純粋な性能改善で、出力される PNG は同一のはず。
- 採らなかった案: `ShareCardRenderer.render` を `async` にして写真解決を `@concurrent` で off-main してから注入する形。呼び出し側（`ShareCardSheet.generate()`）は既に `async` なので実現は容易だが、**それはレビュー #6（`render` の `pngData()` / ファイル書き込みがメインスレッド）の範囲**で、#5 の「回数」とは別問題。`CoffeeShareCardView(coffee:)` のシグネチャを変えずに済む init 解決を採り、Preview 4 件も無変更に保った。#6 に着手するときはこの注入形式へ移すのが自然。
- 残る性質: 修正後も **1 回のフルデコードはメインスレッドで走る**（`ShareCardRenderer.render` が `@MainActor` の同期関数のため）。#6 未着手。
- 検証: `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しで `** BUILD SUCCEEDED **`。**デコード回数の実測はしていない**（共有カード生成は UI 操作起点で、テストターゲットも無いため）。回数が 1 になることは Swift の言語仕様（stored property は init で 1 回評価）で構造的に保証される。修正前の「3 回以上」は参照連鎖の静的解析による。

### 2026-08-09: Firestore 同期の Job ライフサイクル管理と Flow のエラー伝播（SR-4）

- 関連: `shared/core/AppContainer.kt` / `CoffeeRepositoryImpl.kt` / `SavedCafeRepositoryImpl.kt` / `shared/domain` の両 `RemoteXxxDataSource.kt` / `iosApp/FirebaseRepositories/FlowBridge.swift` ほか / `docs/architecture.md` / `docs/kmp-bridge.md` / `docs/tasks/lessons.md` 2026-08-09

Swift コードレビュー #2「`CallbackFlow` にエラーチャネルが無く `permission-denied` が握り潰される」。**着手して分かった本題は、指摘そのものではなくその 1 段下**にあった。

**根本**: `AppContainer.startInitialSync()` が `startSync` の戻り値 `Job` を捨てており、`AppState.resetAndRebootstrap()` もブリッジしか止めていなかった。Firestore Rules は全パスで `request.auth.uid == uid` しか許さないため、**サインアウトのたびに旧 uid の購読が 1 組ずつ残り、新 uid に切り替わった瞬間に必ず `permission-denied` を受ける**。つまり「握り潰されていたエラー」は外から降ってくる事故ではなく、**自分で作って自分で捨てていた**もの。リークと権限エラーが同じ 1 つの原因から出ていた。

**この構造は「エラー伝播だけ直す」と逆効果になりうる**点が設計上の論点だった。Android は既に `close(error)` で伝播しているが `startSync` に try/catch が無く、例外が `MainScope` へ抜ける形になっていた。iOS だけを Android に揃えると、サインアウトのたびに例外が両プラットフォームで漏れる。そのため**ライフサイクル管理（根本）→ 受け止め（`startSync` の catch）→ 伝播（iOS の `fail`）の順**で組んだ。

- **ブリッジ挙動の実測（本件の主要な不確実性）**: 「Swift 実装の suspend 完了ハンドラに `NSError` を渡すと Kotlin 側でどうなるか」が未検証だった。生成ヘッダの `collect` には `Other uncaught Kotlin exceptions are fatal.` と書かれているが、これは **Kotlin → Obj-C 方向**の注意書きで逆方向には効かない、という読みを裏取りする必要があった。`RemoteSavedCafeDataSourceIosImpl` に DEBUG 限定の強制失敗フックを一時的に入れ、`SIMCTL_CHILD_POC_FLOW_ERROR=1` + `simctl launch --console-pty` で実測:

  ```
  [SavedCafeRepositoryImpl] リモート同期を停止しました (userId=...):
      NSError-based exception: PoC forced flow error
  ```

  **catch 可能な Kotlin 例外になり、fatal ではない**（アプリはクラッシュせず起動を継続し、`localizedDescription` も保たれた）。フックは検証後に削除。結論は `kmp-bridge.md` と `FlowBridge.swift` の KDoc に残した（次に同じ疑問が出たときに再実験しなくて済むように）。
- **リトライしない判断**: `permission-denied` は非一時的で、リトライすると無限ループになる。一時的なネットワーク断は Firestore SDK のオフライン永続化が内部で吸収するため、`startSync` の catch に届くのは「リトライしても直らない」失敗だけ。ローカル DB が Source of Truth なので同期が止まってもアプリは動き続ける。
- **`println` の導入**: `shared` の main ソースに `println` は 1 件も無かったが、`startSync` の catch に 1 行だけ入れた。commonMain に他のログ手段が無く、**「同期が静かに止まる」ことが本件の実害そのもの**だったため。同期停止を UI に出すチャネルは現状無く、将来の課題。
- **ついでに直した同系統の別バグ**: `AuthRepositoryIosImpl.observeAnalyticsConsent` が `addSnapshotListener { snapshot, _ in }` とエラーを捨て、読めなかったときに `false` を emit していた。「ドキュメントが無い（= 初回ユーザー、未同意）」と「読めなかった」を同じ値に潰しており、**同意状態の値の捏造**にあたる（`permission-denied` が UI 上「同意していない」として現れる）。`fail(error)` に変更。
- **残る窓（意図的に閉じない）**: `AccountViewModel.signOut()` 完了 → iOS が `resetAndRebootstrap()` を呼ぶまでの間は旧リスナが生きており、権限エラーが 1 回届きうる。完全に閉じるにはサインアウト経路そのもの（`AccountViewModel` が `AppContainer` を知らない構造）の再構成が要るためスコープ外とし、`startSync` の catch で無害化する形にした。
- **`FlowCompletionGate` を挟んだ理由**: `collect` の completion handler は「正常終了」「例外終了」のどちらか一方で**ちょうど 1 回**呼ぶ契約だが、Firestore リスナは解除されるまで何度でもコールバックしうる（エラー直後にもう 1 度エラーが来る並びは普通に起きる）。取り出しと無効化を `OSAllocatedUnfairLock` でアトミックに行い、ハンドラ呼び出しはロックの外に出した（Kotlin 側から同期的に `deinit` まで走りうるため、ロック保持中に呼ぶと再入でデッドロックする）。
- **`nonisolated` の付け忘れ 1 回**: `FlowCompletionGate` は `private` なヘルパなので指定不要と思っていたが、既定 MainActor 分離下では `private` でも暗黙 `@MainActor` になり、`nonisolated` な `__collect` から呼べず 4 件のコンパイルエラーになった。同じファイルに `nonisolated final class` が並んでいても継承されない。`kmp-bridge.md` に追記。
- 検証: KMP テスト 2 件追加（`startSync` が終端例外を catch し、`Job` が完了・スコープ生存・以降のローカル書き込みが通ること）。**ネガティブ検証済み** — catch を外すと新テストだけが FAILED になることを確認してから復元した。全モジュール `iosSimulatorArm64Test` 505 件 PASS / Android `assembleDebug` 成功 / `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しで `** BUILD SUCCEEDED **`。正常系（フック無し）でシミュレータ起動し、同期停止ログも snapshot error も出ないことを確認。
- **シミュレータでの実操作確認: 済**（2026-08-09、ユーザー）。サインアウト → 新しい匿名 uid での同期再開までを実機操作で確認した（自動計測では `stopSync()` の呼び出し経路そのものを踏めていなかった部分）。

### 2026-08-09: LocationManager の生成が位置取得を誘発しないようにする（SR-5）

- 関連: `iosApp/iosApp/Utilities/LocationManager.swift` / `docs/tasks/lessons.md` 2026-08-09

Swift コードレビュー #7「`LocationManager()` が View struct の init ごとに作られ `requestLocation()` を誘発する」。**計測したら指摘の前半と後半で当たり外れが分かれた。**

- **前半（再生成）は起動時には再現しなかった**。`LocationManager.init` は 1 回だけ。`RootTabView.body` は `appState.mapSearchCenter` を読んでいないため、`@Observable` の追跡粒度ではカメラ移動で `MapTabView` は再生成されない。レビュー時の「View struct の init ごと」は**静的推測で、実測していなかった**
- **後半（GPS 誘発）は実在した**。ただし機序は「init が `requestLocation()` を呼ぶ」ではなく、**`manager.delegate = self` の代入で CoreLocation が `locationManagerDidChangeAuthorization` を発火させる**こと。ハンドラが `if newStatus == .authorizedWhenInUse || ... { manager.requestLocation() }` と無条件だったため、**インスタンス生成 = GPS 取得 1 回**になっていた

**実害の本体は無駄な GPS 起動ではなく、両画面が明示的に置いたガードの迂回**だった:

| 画面 | ガード | 迂回のされ方 |
|---|---|---|
| `MapTabView+Location.setupLocation` | `if !didSetInitialCamera { requestLocation() }` | init 由来の取得は `didSetInitialCamera` を見ない |
| `CoffeeEditorView` の `.task` | 要件 2-8「許可ダイアログは出さない・未許可/未決定は何もしない」 | 許可済みだと init 由来 + `.task` で 2 回走る |

- **修正**: `hasPendingRequest` を追加し、ハンドラが取得を再開するのは「`requestLocation()` が `.notDetermined` で保留された」ときだけにした。許可・拒否のどちらに確定してもフラグを下ろす（拒否のまま保留を残すと、後で設定アプリから許可したときに誰も要求していない取得が走る）。**呼び出し側は無変更** — 両画面とも「許可後は callback で自動取得される」前提で書かれており、その前提は保たれる。
- **計測（`simctl` で自動化）**: 一時的な `print` を入れ `simctl privacy grant/revoke/reset location` + `simctl launch --console-pty` で実測。許可済み起動: **修正前 GPS 要求 2 回 → 修正後 1 回**（`init` は前後とも 1 回）。権限 3 経路も自動で確認した:
  - **未決定 → 許可**: `didChangeAuthorization fired status=0`（delegate 代入由来）→ `shouldResume=false` / 許可付与後 `status=4` → `shouldResume=true` → 取得 ✅
  - **未決定 → 拒否**: `status=2` → `shouldResume=false`、フラグは解除 ✅
  - **許可済み**: 生成由来の取得が消えたことを確認 ✅
- **計測できなかったこと**: パン / タブ切替による再生成頻度。`simctl` でタッチを送れないため。起動時に限れば `init` は 1 回で、**手順として「生成コストの集約（`AppState` への hoist）」は不要と判断**した（生成が副作用を持たなくなった以上、余分な init は割り当てが増えるだけ）。
- **副産物（未対応・別件）**: `resetLastLocation()` / `clearError()` / `error` は**どの View からも参照されていない**（grep 済み）。位置取得の失敗は現状 UI にまったく出ないが、`error` の KDoc は「View 側で alert を出す」と書いている。KDoc と実装の乖離。
- 検証: `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しで `** BUILD SUCCEEDED **`。計測用 `print` は 5 行すべて削除済み（`grep -c MEASURE` = 0 で確認）。**シミュレータでの実操作確認: 済**（2026-08-09、ユーザー。マップのパン / FAB の recenter / 記録エディタの現在地サジェスト。`simctl` でタッチを送れず自動化できなかった部分）。

### 2026-08-09: TestFlight のウォッチドッグ強制終了 — 診断の遠回りと、初期カメラのデフォルト値の決め方

- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`（`cameraPosition`）/ `iosApp/iosApp/AppState.swift`（`MapSearchCenter.isEquivalent`）/ `docs/ui-ux-guidelines.md`「マップの初期カメラ」/ `docs/coding-conventions.md` §2.3・§2.5 / lessons 2026-08-09

TestFlight ビルド 28 / 29 が位置情報許諾の直後に落ちる報告。真因は `MapCameraPosition.automatic` の自己駆動ループで、修正は `0dd21c1`（TestFlight ビルド 30 でユーザー確認済み）。落とし穴そのものは lessons に記録した。ここには**判断とトレードオフ**を残す。

**初期カメラのデフォルト値をどう決めたか**: `.automatic` を外すと「初期カメラ確定までの一瞬に何を見せるか」をアプリが決める必要が出る。候補は ①東京駅（`setInitialCameraFromVisitedCafes` の既存デフォルトと同値）②日本全体 ③直近のカメラ位置を永続化して復元。**①を採った**。②は curated ピン 421 件が全国に散っているためズームゲートを跨いでピンが出入りし、修正前と似た見え方になる。③は永続化の追加とマイグレーションが要るうえ、「前回の位置」が現在地と無関係な県だと初回体験が悪い。①なら既存デフォルトと重複しないコードで、かつ許可済みなら現在地・未許可なら訪問済み bounding box に即座に上書きされるため、実際に見えるのは一瞬だけ。

- トレードオフ: 「位置情報を拒否 + 訪問済みカフェ 0 件」の新規ユーザーには東京駅が出る。これは修正前から `setInitialCameraFromVisitedCafes` がそうしていた挙動なので、**変更ではなく現状維持**。日本以外のユーザーには不適切だが、App Store の配信地域が日本のみのため現時点では問題にしない（配信地域を広げるときに再検討する）。

**同値ガード 3 件を残した判断**: `.automatic` を外せば循環は止まるので、`mapSearchCenter` / `cafes` / `showAreaSearchButton` の同値ガードは**なくても症状は出ない**。それでも残したのは、`@Observable` が値を比較しないという性質が変わらない限り、値比較の入らないハンドラからの無条件代入は将来また同じ形の無駄な再評価を生むため。ただし**ガードは原因ではなく症状への対処**だったことは明記しておく — 3 件を入れた時点では引き金が `mapSearchCenter`（533 回）から `showAreaSearchButton`（586 回）へ移っただけで、ループは止まらなかった。

**`761e9a0` を revert しない判断**: あのコミットは `LocationManager` の delegate 3 メソッドを `MainActor.assumeIsolated` から `Task { @MainActor in }` に戻したもので、コミットメッセージは「これがウォッチドッグの原因」と断定していた。**原因の断定は誤り**（クラッシュログのスタックに CoreLocation のフレームが 1 つも無かったのを見落とした）。ただし変更自体は `coding-conventions.md` §2.5 が元から定めていた規約（delegate メソッドの UI 更新は `Task { @MainActor in }` で戻す）への準拠を回復するもので、Swift 6 移行（SW6-1）時の `assumeIsolated` 化が規約違反だった。よって revert せず、規約側に「`assumeIsolated` に置き換えてはいけない」理由（仮定が外れたら precondition failure でクラッシュする / その保証に賭ける必要がない）を明記して昇格させた。

- 経緯（遠回りの記録）: 推測ベースで 2 回、誤った修正方針を出した。①`assumeIsolated` の同期実行 ②`existingPinCoordinates` / `displayed(excluding:)` の O(N×M) 測地距離計算（実測 10 回で合計 1ms、無罪）。どちらも `git diff` とコードから筋書きを立てたもので、**「Release ビルドでのみ起きる」という前提を疑わなかった**のが根。実際にはビルド構成は原因ではなく、必要条件は「デバッガ非アタッチ」+「Background 遷移」だった。最初に計測を提案したが「原因が分かったなら計測不要」に同意して取り下げており、あそこで測っていれば 2 回の空振りは避けられた。**ハング系（`0x8BADF00D`）は実測しないと当たらない**。
- 効いた計測手段は lessons に記録した（`Self._printChanges()` の出力を `sort | uniq -c` で集計 / `xcrun devicectl device process launch --console` はデバッガをアタッチしないので watchdog を有効にしたまま実機の stdout が取れる）。使い捨てプローブ（`MapPerfProbe`）は削除済み（`grep -rn "MapPerfProbe\|_printChanges\|DEBUG-w4t9" iosApp/` = 0 件で確認）。
- 副産物（未対応・別件）: ①`displayedCuratedCafes` に可視領域フィルタが無く画面外のピンまで Annotation に載る（実測 210 個/回）②全ピンが `NavigationLink` / `Button` ラップで、`CafeDetailRoute.initialCafe` が Kotlin の `Cafe` オブジェクトを保持している。どちらも発散とは独立の非効率で、`tasks.md` カテゴリ 2「マップ更新コストの削減」（MU-1 / MU-2）に起票した。

### 2026-08-09（追記）: ウォッチドッグは Swift 6 移行とは無関係だったことの確定

- 関連: `docs/tasks/lessons.md` 2026-08-09 / `0dd21c1` / `761e9a0` / `5cf3c50`

上のエントリの続報。git 履歴で循環の成立時期を確認し、**Swift 6 移行とは無関係**と確定した。あわせて**ユーザーが「Swift 6 前でも発生していた」ことを実際に確認**した。

| 要素 | 導入 |
|---|---|
| `cameraPosition = .automatic` | `7904c7d`（Phase 4 スライス 6 / プロジェクト初期） |
| curated ピンのズームゲート（表示数がカメラ半径依存） | `626fed6`（2026-07-18） |
| curated が全国 421 件（東京 1 県 → 9 県） | `1802db9` / `79eed0a`（2026-07-28） |
| Swift 6 移行 | `5cf3c50`（2026-08-07）/ マージ `8d7139f`（08-08） |

循環の両側は移行の 10 日以上前に揃っている。Swift 6 移行が `CuratedCafeRepositoryIosImpl` に加えたのは `@preconcurrency import` / `nonisolated` 化 / キャッシュの `OSAllocatedUnfairLock` 保護で、**取得ロジック自体は変えていない**（`db.collection("curatedCafes").getDocuments()` は同一）。

**「Swift 6 前は起きなかった」の実体は観測機会の差**: 位置情報の許諾ダイアログは初回インストール時（またはアプリ削除後の再インストール時）にしか出ない。TestFlight で更新を重ねる限り許諾は保持されるので Background 遷移が起きず、循環は「重い・熱い」だけで殺されない。ビルド 28 / 29 でたまたま許諾フローを通す機会が来て顕在化した。今回の診断中、実機に Debug 版を入れたときに署名が変わって許諾がリセットされ、ユーザーが「許諾ダイアログ出しっぱなしでいいの？」と気づいた経緯があるが、同じことが TestFlight 側でも起きていたことになる。

- 影響: `761e9a0` のコミットメッセージは Swift 6 移行を原因と断定していた（`0dd21c1` で「原因の断定が誤り」と訂正済み）。本追記で**時系列的にも無関係**であることまで確定した。ただし `assumeIsolated` → `Task { @MainActor in }` の変更自体は `coding-conventions.md` §2.5 の規約準拠の回復にあたるため、引き続き revert しない。
- 経緯: この誤りの入り口は「Swift 6 対応前は起きなかった」という証言を、**観測条件を確認せずに時系列の原因推定へ使った**こと。教訓は lessons 2026-08-09 に記録した（権限ダイアログ・初回起動フローが絡む症状は変更時期と発現時期がずれる）。

### 2026-08-09: curated ピンの可視範囲フィルタ（MU-1）— 基準に可視領域の矩形を使わなかった理由

- 関連: `iosApp/iosApp/Features/Map/MapTabView+PinResolution.swift`（`displayedCuratedCafes` / `curatedVisibilityMargin`）/ `docs/ui-ux-guidelines.md`「マップ概念の色セマンティクス」表 / `tasks.md` MU-1

`.automatic` のループ修正（`0dd21c1`）の残務。`displayedCuratedCafes` はズームゲート（可視半径 3000m 以内）を通ると `curatedCafes` 421 件を件数で絞らずそのまま返しており、画面外のピンまで `Annotation` として View 構築されていた（実測 210 個/eval）。

**基準に `latestVisibleRegion`（可視領域の矩形）を使わなかった**。矩形の方が正確だが、`latestVisibleRegion` は現在 body から読まれておらず（「このエリアを検索」実行時に `performAreaSearch` へ渡すだけ）、`onMapCameraChange` で**無条件代入**されている。これを body で読むと**新しいカメラ依存が生まれる** — 同日のウォッチドッグ障害は「カメラ → ピン表示数 → カメラ」の循環が原因だったため、依存方向を増やさないことを優先した。`MKCoordinateRegion` が `Equatable` 非準拠で同値ガードを書きにくいことも理由。採用した `mapSearchCenter` は本メソッドがズームゲートで既に読んでおり、`isEquivalent`（1m 許容）の同値ガードも入っている。

- トレードオフ: 半径ベースなので横長の地図では矩形の角が漏れる。ただし `radiusMeters` は `max(latMeters, lngMeters)` = 可視領域の外接半径相当で**半径側が広く出る**方向であり、実用上は可視領域を包含する。curated は補助表示なので厳密な矩形一致は不要と判断した。マージン 1.3 倍はパン時の先読み分（`shouldShowAreaSearchButton` の「中心移動 > 半径 × 0.3」より手前で効く）。
- 検証: 実機・**クリーンインストール + 許諾フロー**（= 本番の再現条件）で実測。curated ピン **210 個/eval → 4 個/eval**、body 再評価 **589 回/60秒 → 9 回/60秒**、引き金は 8 種すべて各 1 回、60 秒間プロセス生存。`devicectl device process launch --console` はデバッガをアタッチしないので **watchdog が有効**であり、「生存したこと」自体が発散していない証拠になる。**測定条件を上書きインストールで始めたのは誤りで、ユーザーの指摘（「元々クリーンインストールで再現した」）で修正した** — 上書きでは許諾ダイアログが出ず Background 遷移が起きないため、本番条件を再現できていなかった。
- MU-2（全ピンの `NavigationLink` ラップ見直し）は**取り下げ**。curated が 4 個規模ならルート値のコピー削減は実測に現れず、`Button` へ変えても `ButtonBehavior` の `State` 初期化と `_UIHostingView` 1 個/ピンの本体コストは変わらない。判断の記録は `tasks.md` MU-2 の備考。

### 2026-08-10: アカウント削除の revoke 完走 + 削除範囲を実機で確認（リリースブロッカー解消）

- 関連: `iosApp/iosApp/Features/Account/AccountView.swift` / `iosApp/iosApp/FirebaseRepositories/AuthRepositoryIosImpl.swift`（`reauthenticate` → `revokeToken`）/ `iosApp/iosApp/Utilities/AppleSignInCoordinator.swift` / ガイドライン 5.1.1(v) / フェーズ 5.2

ユーザーが実機で確認し、**revoke の完走と削除範囲の両方が取れた**（2026-08-10）。`verification-checklist.md` のパス 6 にあった「アカウント削除の revoke 完走 + 削除範囲」は同運用（完了項目は削除する）に従い除去済み。**審査に直結する唯一の項目**だったため、確認できた事実をここに残す。

- **revoke が効いた直接証拠**: iOS 設定 App → Apple アカウント → サインインとセキュリティ →「Apple でサインイン」の一覧から CoffeeVision が消えていること。Firestore と Authentication のユーザー消滅（①②）は revoke が失敗していても達成されうるため、この③だけが `revokeToken` の成否を分ける
- **削除範囲**: `users/{uid}` がルート doc / `coffees` / `savedCafes` の 3 つとも消え、端末ローカルにも「行きたい店」の孤児行が残らないこと。2026-08-06 に後ろ 2 つが残るのを是正した箇所で、その修正が実機で効いていることの実証でもある
- **副次的に Swift 6 移行 ③ の 2/3 が実証された**: 削除経路は `AppleSignInCoordinator` 経由で `ASAuthorizationController` を起動する（サインイン経路と同じコーディネータ）。したがって ①`MainActor.assumeIsolated` 化したデリゲートがクラッシュしないこと ②`presentationAnchor(for:)` のフォールバックを削除（未設定なら `preconditionFailure`）した後もシートが実際に出ること の両方が、この確認の中で通っている。**残るはキャンセル経路のみ**で、`verification-checklist.md` の当該項目はそこへ削り込んだ
- 未実施: 異常系（Apple シートをキャンセル → アラートを出さずオーバーレイが消え、記録・行きたい店・アカウントがすべて残る）。revoke 失敗時の削除中断は Firebase Console の設定を一時的に壊す必要があるため doc 上も任意扱い

### 2026-08-10: マップのテキスト検索が 0 件のときのフィードバック — トーストに寄せてシートは出さない

- 関連: `iosApp/iosApp/Features/Map/MapSearchController.swift`（`emptyResultMessage` / `handleCompletion`）/ `iosApp/iosApp/Features/Map/MapTabView.swift`（`activeToast` / `isShowingSearchResultsSheet`）/ `tasks.md` カテゴリ 1

ユーザー報告「検索結果が 0 件だった時になんのフィードバックもない」への対応。**穴はテキスト検索側だけ**で、他の 3 経路は既に案内を持っていた（記録一覧 / 記録エディタのカフェ検索 = `ContentUnavailableView.search`、マップの「このエリアを検索」= トースト）。原因は 2026-07-24 にエリア検索へ 0 件案内（`areaSearchEmptyMessage`）を足したとき、それを `wasAreaSearch` 分岐の中に置いたこと。テキスト検索側は `fitCameraToSearchResults([])` が座標ゼロ件で早期 return して無反応に終わっていた。プロパティ名を `emptyResultMessage` に一般化し、両分岐で共有する形に直した（文言は検索種別ごとに出し分け: エリア =「このエリアにカフェが見つかりませんでした」/ テキスト =「「〈クエリ〉」に一致するカフェが見つかりませんでした」）。

- **0 件でも結果シートを出す案は採らなかった**: `isShowingSearchResultsSheet` は「ローディング中 or 結果あり」を条件にしており、0 件でシートを出すと `MapSearchResultsSheet.peekHeight`（180pt）が情報ゼロで画面を占有する。さらにこの高さは現在地 FAB の下端インセット（`searchSheetFABBottomInset`）にも二重消費されるため、空シートのぶん FAB が押し上がる。フィードバックはトースト 1 本に寄せ、シートの表示条件は現状維持とした
- **エラーとの二重表示はしない**: `handleCompletion` 冒頭の `guard sb.hasSearched, sb.error == nil` により検索失敗時は 0 件メッセージへ到達しない（失敗はエラートーストが担当）。トーストの優先順位も既存のまま（`bridge.error` > 検索失敗 > 0 件案内 > POI 検索失敗）
- **エリア検索とテキスト検索が同じプロパティを共有しても競合しない**: `wasAreaSearch` で排他分岐するため、1 回の完了で立つメッセージは高々 1 つ

**続き: トーストを上部から下部（タブバーの上）へ移した**（同日、ユーザー指摘）。0 件案内を足したことで、上部トーストが `MapTabView` の検索バーと**同じ位置**（`ErrorToast` の `.padding(.top, 8)` と上部コントロール `VStack` の `.padding(.top, 8)`）に出る問題が顕在化した — 案内が検索欄を 4 秒間覆い、そのまま入力し直せない。**`ErrorToast.swift` を全画面一括で下部化**（`overlay(alignment:)` / スライド方向 / スワイプ消去の向きの 3 点。適用 8 箇所すべてに波及）。配置の引数化は採らなかった（画面ごとにトーストの出る位置が変わる方が悪い。上部が詰まっているのは `.searchable` を持つ記録一覧・カフェ検索シートも同じ）。下部で重なりうるのは `MapTabView` の現在地 FAB / カフェ選択カード / 検索結果シートだが、**0 件案内が出る局面ではカードもシートも表示条件を満たさない**ため実際に重なるのは FAB のみで、自動消去 + タップ消去できることを理由に許容した（FAB の下端インセット計算は `searchSheetFABBottomInset` に絡むため増やさない）。

- 検証: フラグ無し `** BUILD SUCCEEDED **`。**シミュレータでの目視をユーザーが確認済み**（2026-08-10 — マップのテキスト検索 0 件でトーストが検索バーを覆わずタブバー上に出ること / 下部要素と重なっても文言が読めること / 記録一覧・分析タブでもタブバー上に浮くこと）

### 2026-08-11: docs 棚卸し — 「行数が閾値内」と「doc が正しい」は別だった

- 関連: `docs/implementation-note-archive.md` / `docs/kmp-bridge.md` / `docs/data-model.md` / tasks「カフェスナップショットの『8 フィールド』記述の是正」

閾値超過 3 本（implementation_note 1534 / data-model 738 / kmp-bridge 505）に `curate-doc` の 3 段を通した。**検出 5 件のうち、行数超過が理由で見つかったものは 1 件も無い**（陳腐化 2 / 欠落 2 / コード側の誤り 1）。閾値は棚卸しの**発火条件**であって検出器ではない、という前回（2026-08-01）の結論がそのまま再現した。

**検出の内訳**:

- 陳腐化 — 本ノートのサマリの CI 行「全モジュール一括 = **360 件**」（SR-4 時点の実測は iOS 505 件）。**同じサマリが 12 行上で「数え上げを書かない」と自分で規定しているのに、その規約より古い行が残っていた**。規約を足したときに既存行を洗っていない / `kmp-bridge` の Swift 6 節が `FlowCompletionGate` に `@unchecked Sendable` を付けると書いていたが、実体はプレーンな `Sendable`（格納プロパティがロック 1 本だけなら素で適合する）
- 欠落 — サマリの `startInitialSync()` 行に、2026-08-09 SR-4 で追加した `stopSync()` が入っていない（**これが無いとサインアウトのたびに旧 uid の購読が残る**という、まさに SR-4 の根本原因側の API） / `data-model` §2.3 の migration 履歴表が `2.sqm` から始まっていて `1.sqm`（`photo.file_name` 追加）が抜けていた
- コード側 — `Cafe` の永続フィールド数を「8」と書いた KDoc が 4 箇所（iOS 3 / KMP 1）。2026-08-07 に `photoAttributions` を永続対象化した際の追随漏れ。**マッパ実装は 3 経路とも 9 フィールドを正しく扱っており、壊れているのはコメントだけ**

**「数え上げを書かない」の適用範囲がサマリ限定ではなかった。** 2026-08-01 に本ノートのサマリへ課した規約だが、今回コード KDoc で**同じ失敗が独立に発生していた**ことが分かった。件数は依存が 1 つ増えるたびに全項目がまとめて嘘になり、増やした本人はソースしか見ないので気づけない — この性質は doc かコメントかに依存しない。lessons へ横展開した。

**アーカイブは月別ファイルに分けず 1 本に積む**（ユーザー確定）。2026-07 の 73 エントリ（880 行）を `implementation-note-archive.md` へ移し、`## 2026-06` / `## 2026-07` の月見出しで区切った。分割案（`implementation-note-archive-2026-07.md`）を採らなかったのは、**約 70 箇所ある「implementation_note 2026-0X-XX エントリ」参照が日付でしか引かれないため**。行き先が 1 ファイルに固定されていれば参照側の書き換えも「月 → ファイル」索引の維持も不要になるが、ファイルを増やすとその索引が新たな陳腐化ポイントになる。移送は逐語で、`diff` で移送前後の本文が完全一致することを確認してからコミットした（凍結移送であって縮約ではない = 歴史を書き換えない）。archive は 1214 行になるが、**フロー型の 1200 行閾値は「追記が止まった月をアーカイブへ送れ」という発火条件**であり、既にその移送先である archive には意味を持たない。次回誤検出しないよう archive の前文に明記した。

**`data-model.md`（739 行）は分割も縮約もしなかった。** 前文の例外規定（2026-07-27 ユーザー確定・700 行台を許容）が判断の正本で、`check-file-size.sh` の警告より優先する。Phase 1 だけ通し、欠落 1 件を埋めて据え置いた。**kmp-bridge は 505 → 477 行**（Gradle 設定の逐語コピー 12 行と `AppContainer(...)` の引数列挙 11 行を削除。後者は直下に「正本は `AppContainer.kt`」と書いてあるのに列挙が併記されている自己矛盾だった）。ViewModel ブリッジの 52 行の Swift サンプルは**残した** — 実ファイルの逐語コピーではなく最小化した規範テンプレートで、`isolated deinit` の理由がコメントとして埋まっているため。
