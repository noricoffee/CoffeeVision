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

ノート本文がスクロールしないと読めない長さになる前に、ここに **今生きてる方針だけ** を一行サマリで列挙する。陳腐化したら削除、昇格したら削除（昇格先 doc を見ればわかるため）。

- CI（GitHub Actions）は `:shared:data-local:testAndroidHostTest` + `:androidApp:assembleDebug`（Android ジョブ）と `:shared:framework:assembleSharedLogicXCFramework`（iOS ジョブ）で構成。2026-06-08 Phase 2.5 PR3 で `:sharedLogic` 系から完全移行済
- `VisitRepository` は `commonMain` で 2 段構成（`RemoteVisitDataSource` interface + `VisitRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteVisitDataSource` だけを書く
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる。サインアウト時の sync 停止再開は要件発生時に拡張する
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一する。共通ライブラリの Android namespace は各モジュール個別（`com.noricoffee.core` / `com.noricoffee.domain` / `com.noricoffee.dataLocal` / `com.noricoffee.dataFirebase` / `com.noricoffee.framework`）で applicationId と分離
- SKIE 0.10.12 は `shared/framework` umbrella に適用済（Phase 2.5 PR3 で旧 `sharedLogic` から移行）。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する必要がある。Swift で `Flow` を作るには `MutableStateFlow` を直接構築するパターンを第一候補とし、詰まったら `iosMain` にラッパを追加する
- iOS 側 Firebase 実装（`iosApp/iosApp/FirebaseRepositories/`）は Phase 2 で実装済。`SkieSwiftFlow<T>` の Swift 側構築は `_unconditionallyBridgeFromObjectiveC(SkieKotlinFlow(callbackFlow))` 経由（`init(internal:)` が internal アクセスのため直接構築不可）。ドメインモデルのうち SQLDelight が同名の行型を生成するものは Swift 側で末尾アンダースコア付きで現れる（現状 `Visit` → `Visit_`、`Photo` → `Photo_`。`CoffeeItem` / `FoodItem` / `Cafe` はそのまま）
- `AppContainer` は **scope なしの 4 引数セカンダリコンストラクタ**（`sqlDriver` / `remoteVisitDataSource` / `authRepository` / `placesApiKey`）を通常用途（Swift / アプリ起動）とし、5 引数プライマリ（`scope` 注入可）はテスト用途に限定する。SKIE が Kotlin デフォルト引数を Swift に引き出さないため、プライマリのデフォルト値 `= MainScope()` は持たせず用途をコンストラクタ単位で分けている。`placesApiKey` は Phase 4 で追加。public プロパティは `visitRepository` / `cafeRepository` / `authRepository`
- Visit 子コレクション（`coffeeItems` / `foodItems` / `photos`）の Firestore 同期は **WriteBatch + 差分削除**（既存子 ID を取得 → 新配列に含まれないものを batch.delete）で原子化。observe は **案 A**（親 visit リスナ 1 本 + 子は snapshot 受信ごとに `getDocuments` 並列）。`sortOrder` はドメインモデルに持たせず、upload 時に配列 index で採番 / decode 時はソートに使ってから破棄。nullable は `null` を入れずキーごと省略。`Photo.localPath` は端末固有値のため Firestore には保存しない。`Photo.fileName` は `{photoId}.jpg` 形式で Firestore にも保存し、復元時に **`photos/{fileName}`（フラットな photos/ ディレクトリ。visitId 別サブディレクトリにしない）** で localPath を再構築できるようにする（`data-model.md` §1.5 / iOS `PhotoFileStore.swift` と一致）。`Photo.remoteUrl` は常に null（2026-06-10 Storage 採用見送り。写真本体は端末ローカル保存方針）
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `storage.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。Firestore は path uid のみ検証で 2026-06-06 にデプロイ済。`storage.rules` はリポジトリ残置のみで未デプロイ（2026-06-10 Storage 採用見送り決定。写真は端末ローカル保存方針のため）
- `build-logic/convention/` の Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）は **precompiled script plugin 方式**（`src/main/kotlin/*.gradle.kts`）。`gradlePlugin { plugins.register(...) }` は置かず、`kotlin-dsl` の自動 plugin id 生成に任せる。`build-logic/settings.gradle.kts` で `versionCatalogs.from(files("../gradle/libs.versions.toml"))` を宣言して同一カタログを共有
- `kmp.library` は `jvmToolchain(N)` を付けない。開発機 JDK バージョン依存の罠（Toolchain auto-provisioning 未設定でビルドが落ちる）を避け、`compilerOptions.jvmTarget = JvmTarget.JVM_11` だけで Android 側 JVM target を指定する
- `shared/core` には `AppContainer` と `VisitRepositoryImpl` が居る。`api(projects.shared.dataLocal)` 経由で `AppDatabase` / `LocalVisitRepository` を取り込み、`api(projects.shared.dataFirebase)` で Firebase Repository インターフェースを再公開する。Result / Logger / Dispatcher ラッパは必要が出てきたフェーズで追加（YAGNI）
- `shared/data-local` が SQLDelight プラグイン + `AppDatabase` 宣言の単独管理者。Mapper / DriverFactory expect/actual / LocalVisitRepository を含む。`VisitRepositoryImplTest` は `createInMemoryTestSqlDriver` の expect/actual がここに閉じている制約から、振る舞いの所属（`shared/core`）ではなく `data-local` の commonTest に置く妥協配置
- `shared/data-firebase`（namespace `com.noricoffee.dataFirebase`）の `androidMain` に Android Firebase 実装（`AuthRepositoryAndroidImpl` / `RemoteVisitDataSourceAndroidImpl` / `VisitFirestoreMapper`）を移送済（2026-06-11 Phase 3.5 検証スライス）。iOS 実装は `iosApp` Swift で継続
- 旧 `sharedLogic` モジュールは 2026-06-08 Phase 2.5 PR3 で完全削除済。iOS 向け umbrella は `shared/framework`（baseName / XCFramework 名ともに `SharedLogic`、Swift `import SharedLogic` のまま）。`commonMain.dependencies { api(...) }` + `framework { export(...) }` で **全 shared モジュール（基盤層 + 全 feature）** を再公開 + `linkerOpts("-lsqlite3")`。**feature を追加したら api / export に 1 行ずつ追記する**。`assembleSharedLogicXCFramework` で XCFramework 生成、`embedAndSignAppleFrameworkForXcode` を Xcode の Run Script から呼び出し。`sharedUI` も `api(projects.shared.framework)` 経由でこれらを取り込む
- モジュールの正確な一覧は `settings.gradle.kts` を真とする（基盤層 `core` / `domain` / `data-local` / `data-places` / `data-firebase` + `feature/*`（1 画面 = 1 モジュール、画面追加ごとに増える）+ `framework` + アプリ層 `androidApp` / `sharedUI`）。Phase 4/5 で `data-places` と feature 群（cafe-search / map / cafe-detail を含む）の切り出しを完了済
- `AppContainer` の ViewModel ファクトリ（`makeVisitListViewModel()` など）は **`shared/framework` の拡張関数として配置**する。`kmp.feature` が `feature -> core` を `api` で自動配線するため `core` から `feature` を参照すると循環依存になる。`framework` は全 shared モジュールを `api` で持つ最上位レイヤーなので循環なし。Swift からは Obj-C category として `appContainer.makeVisitListViewModel()` で呼べる。今後 feature を追加するたびにファクトリ拡張を `shared/framework/.../AppContainerViewModelFactory.kt` に追記する
- iOS Bridge は `@MainActor @Observable` クラス + `Task { for await s in kotlin.state { apply(s) } }` パターン（`kmp-bridge.md` §推奨パターン）で実装。SKIE 0.10.12 環境では `UIState.visits` は Swift 側で既に `[Visit_]` 型として取得できるため、`as? [Visit_]` キャストは不要（書くと "always succeeds" / "no effect" 警告）
- Bridge の生存スコープは画面ライフサイクルに応じて 2 パターンを使い分ける: **一覧画面（VisitList）は `AppState` で 1 つ保持**（uid 確定後に 1 度だけ生成、画面再描画でも再生成しない）。**詳細画面（VisitDetail）/ 編集画面（VisitEditor）は View 内の `@State` で遷移ごとに生成・破棄**（それぞれ `appState.container.makeVisitDetailViewModel()` / `makeVisitEditorViewModel()` を呼ぶ、`AppState` にホルダは置かない）。「一覧 = 常時 1 つ」と「Detail / Editor = push/sheet ごとに新規」のライフサイクルの違いを設計に反映している
- `AppState` は bootstrap（匿名サインイン + startInitialSync）と `visitListBridge` 保持に責務を絞り、書き込み系のダミー動作（旧 `writeDummyVisit()` / `Status.writing` / `lastWroteVisitId`）は VisitEditor 完成と同時に削除済。新規 / 編集の動線は `VisitEditorView` の sheet 起動が単一エントリ
- Phase 4（Places API）は 5 スライス分割: ①KMP 基盤（data-places + PlacesClient + CafeRepository + AppContainer 配線）→ ②iOS UI（CafeSearchView + VisitEditor 統合 + xcconfig 連携）→ ③ CoreLocation + Nearby + Detail → ④写真都度取得 → ⑤ feature/cafe-search 切り出し。**Places API (New) v1** を採用、料金最適化のため `X-Goog-FieldMask` で取得フィールドを明示する。API キーは **`AppContainer` のコンストラクタ引数として外部から注入**（Android = local.properties → BuildConfig、iOS = xcconfig → Info.plist → Bundle.main）。Firebase Repository インスタンス注入と同じパターン
- iOS の xcconfig は **`Base.xcconfig` を base configuration とし、先頭で `#include "Config.xcconfig"`（必須、bundle ID / TEAM_ID / `-lsqlite3` リンク等を継承）+ `#include? "Secrets.xcconfig"`（任意、PLACES_API_KEY ローカル設定）の 3 段構造**。`Secrets.xcconfig` は `.gitignore` 追加済（コミット禁止）。Info.plist の `$(PLACES_API_KEY)` で展開 → `Bundle.main.object(forInfoDictionaryKey:)` で Swift から取得 → `AppContainer` へ注入。既存 xcconfig がある環境で新規 xcconfig を base にする場合は必ず `#include` 継承を確認すること
- `CafeSearchViewModel` は **`shared/feature/cafe-search`（namespace `com.noricoffee.feature.cafesearch`）に移送済**（2026-06-15 Phase 4 スライス 5）。実装中は `shared/core/.../feature/cafesearch/` の暫定置き場で先行し、UI 一段落後に専用 feature モジュールへ `git mv` する運用を採った（`shared/core` の暫定置き場ディレクトリは削除済）
- Places API DTO は `PlacesListResponse` を Text Search / Nearby Search で共用（レスポンス構造が同形のため）。`FIELD_MASK`（リスト系、接頭辞 `places.` あり）と `DETAILS_FIELD_MASK`（`getDetails` GET 専用、接頭辞なし）は別定数。`CafeSearchViewModel.onNearbySearchRequested` は `radiusMeters` 引数を持たず 500m 固定（SKIE デフォルト引数制約により VM 内で隠蔽）
- iOS のルートは TabBar 構成（iOS 26 `TabView` 新 API）。3 タブで `Tab "マップ"` / `Tab "訪問"` / `Tab(role: .search)` の順、`role: .search` は TabBar 右端固定。新規 Visit 作成は **マップ / 検索 → カフェ詳細 → 「+ Visit を追加」** に導線を一本化し、VisitList の `+` ボタンは撤去。カフェ詳細画面は要件の「カフェ別 Visit 一覧画面」を統合する 1 画面
- `MapViewModel` / `CafeDetailViewModel` は `CafeSearchViewModel` と同じく **`shared/feature/map`（`com.noricoffee.feature.map`）/ `shared/feature/cafe-detail`（`com.noricoffee.feature.cafedetail`）に移送済**（2026-06-15 Phase 4 スライス 5）。Bridge のライフサイクルは `mapBridge` = AppState 1 つ保持（TabView は常時 3 タブ生存）、`CafeDetailViewModelBridge` = View 内 `@State` で push ごとに生成（`place_id` 依存）

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

### 2026-06-05: Visit 子コレクションの Firestore 同期方針（iOS）

- 領域: iOS / Firebase
- 関連: `iosApp/iosApp/FirebaseRepositories/{RemoteVisitDataSourceIosImpl,VisitFirestoreMapper}.swift`

`coffeeItems` / `foodItems` / `photos` サブコレクションを `RemoteVisitDataSourceIosImpl` に実装した際の方針メモ。

- **upload**: WriteBatch で「親 visit setData + 新子 setData + 既存子のうち新配列に含まれない ID を delete」を 1 commit に原子化。1 Visit あたり子は数十件想定なので 500 オペレーション上限は十分余裕。Firestore SDK のオフライン永続化が WriteBatch を含めて再送するため、原子性と offline 耐性を同時に得られる
- **delete**: 子全削除 → 親削除を同様に WriteBatch で原子化
- **observe**: **案 A** = 親 `visits` コレクションに snapshot listener 1 本 + スナップショットごとに各 visit の子 3 種を `getDocuments` で並列取得 → 完全な `Visit_` 配列として emit。listener 数が `O(1)` で済む。upload 時に親の `updatedAt` が必ず更新される規約に依存
- **sortOrder**: ドメインモデルに持たせず、upload 時に配列 index で採番。decode 側は `(item, sortOrder)` ペアで取得 → `sortOrder` で並べ替えた後に破棄してドメインモデルへ
- **nullable フィールド**: `null` を入れず **キーごと省略**（Firestore のクエリで `null` 比較を避ける）。Swift 側 decode は `data["origin"] as? String` が nil 返しでそのまま動く
- **enum**: Kotlin の `name` 文字列で永続化（`BrewMethod.HandDrip` → `"HandDrip"`）。decode は SKIE 生成 Swift enum の `allCases` から `name` 一致で逆引き
- **`Photo.localPath`**: 端末固有値のため Firestore には書き出さない / decode 時も常に nil

未解決:
- visit 件数が 100 件超になると snapshot 1 回ごとに 300 回程度の `getDocuments` が走る。本番運用フェーズで件数増えたら「差分のみ子 fetch」or 案 B（子も listener）or 案 C（collectionGroup）への移行を再検討
- 写真本体の Storage アップロード（`remoteUrl` を埋める処理）は Phase 3 / 4 タスク
- Firestore Security Rules 未設定のため、書き込み実体の確認は Rules 設定後にユーザー作業

---

### 2026-06-05: AppContainer はセカンダリコンストラクタで scope を隠蔽し IosMainScope hack を解消

- 領域: KMP / iOS Bridge
- 関連: `sharedLogic/src/commonMain/kotlin/com/noricoffee/AppContainer.kt`, `iosApp/iosApp/AppState.swift`, `iosApp/iosApp/FirebaseRepositories/IosMainScope.swift`（削除）

`AppContainer` に **scope 引数なしのセカンダリコンストラクタ** を追加し、Swift から `AppContainer(sqlDriver:remoteVisitDataSource:authRepository:)` で呼べるようにした。同時に、プライマリコンストラクタのデフォルト値 `= MainScope()` を **削除**して用途を明確化:

- セカンダリ（3 引数）: 通常用途 — Swift / アプリ起動。内部で `MainScope()` を生成
- プライマリ（4 引数）: テスト用途 — `CoroutineScope` を明示注入したい場合のみ

理由: SKIE が Kotlin のデフォルト引数を Swift に引き出さないため、デフォルト値を残しても Swift から省略呼び出しできず、用途が二重化する。コンストラクタ単位で用途を分ける方が API として明瞭。

これにより Swift 側の `IosMainScope`（dispatcher なし hack）と `DummyCoroutineContext` は不要になり削除。`VisitRepositoryImpl.startSync()` の `scope.launch { ... }` が `Dispatchers.Main` 上で動く正規状態に復帰した。Firestore リスナのリアルタイム同期は Security Rules 設定後に動作確認する想定。

影響:
- Kotlin 側のテストや `androidApp` で `AppContainer` を呼んでいた箇所は **なかった**（grep 確認済）ため、プライマリのデフォルト値削除による互換性破壊の影響範囲はゼロ
- 汎用知見として `docs/tasks/lessons.md` に「SKIE は Kotlin のデフォルト引数を Swift に引き出さない」を追加済

---



### 2026-06-03: CI（GitHub Actions）の iOS ビルドコマンドを暫定で `:sharedLogic` に向ける

- 領域: Build / CI
- 関連: `.github/workflows/ci.yml`, `docs/tasks.md`（フェーズ 0 / フェーズ 3.5）

`tasks.md` フェーズ 0 の CI 整備タスクは iOS 側コマンドを `./gradlew :shared:framework:assembleSharedFrameworkXCFramework` と書いているが、`:shared:framework` モジュールはフェーズ 3.5 で `sharedLogic` から切り出す前提のため、現時点では未作成。

暫定対応として CI では `:sharedLogic` の iOS framework link タスクを直接呼ぶ：

- `:sharedLogic:linkReleaseFrameworkIosArm64`
- `:sharedLogic:linkReleaseFrameworkIosSimulatorArm64`

ローカル（macOS）で両ジョブのコマンド（Android: `:sharedLogic:testAndroidHostTest :androidApp:assembleDebug` / iOS: 上記 link 2 つ）が成功することを確認済。GitHub Actions 上でのグリーン確認は初回 PR まで保留する。

差し替えタイミング: フェーズ 3.5「分割後ビルド確認」のチェック項目に `ci.yml` の link コマンドを `:shared:framework:assembleSharedFrameworkXCFramework` に置き換える旨を備考で明記した。

トレードオフ: tasks.md の文言と完全一致しなくなるが、"モジュール分割前に CI を整える" という方針を優先し、現状でグリーンになるコマンドで CI を成立させた。

---

### 2026-06-04: VisitRepository を commonMain で合成し、Firestore は薄いアダプタに限定する

- 領域: KMP / Shared
- 関連: `sharedLogic/src/commonMain/kotlin/com/noricoffee/repository/{VisitRepositoryImpl,RemoteVisitDataSource}.kt`

Phase 2 の I/F 整備として `VisitRepository` の local + remote 合成方針を確定した。

- 採用: `RemoteVisitDataSource` interface を `commonMain` に切り出し、`VisitRepositoryImpl`（`commonMain`）が `LocalVisitRepository` と合成する案
- 不採用: プラットフォーム別に `VisitRepository` を実装する案（合成ロジックが iOS / Android で重複し、ローカル → リモート順序が共通層で保証できない）
- 既定書き込みポリシー: `WritePolicy.PropagateRemoteFailure`（リモート失敗を呼び出し元に伝播）。Firestore オフライン永続化に委ねる場合は `WritePolicy.IgnoreRemoteFailure` を選択可能
- 読み取り経路: UI は常にローカル DB を見る。Firestore からの変更は `startSync(userId, scope)` でローカル DB に反映してから UI に流れる（二重キャッシュを避ける）

影響: iOS / Android の Firebase 実装者が書くのは `RemoteVisitDataSource` の実装だけになる。Phase 2.5 で `VisitRepositoryImpl` は `shared/domain` に移送する想定。

---

### 2026-06-04: AppContainer は手書き DI、startInitialSync で sign-in + sync を一気に起こす

- 領域: KMP / Build
- 関連: `sharedLogic/src/commonMain/kotlin/com/noricoffee/AppContainer.kt`

`AppContainer(sqlDriver, remoteVisitDataSource, authRepository, scope = MainScope())` を Phase 2 用のスケッチとして `commonMain` に追加。`startInitialSync()` で匿名サインインと `VisitRepositoryImpl.startSync` を一括で起こす。

ViewModel ファクトリは Phase 3 で ViewModel を作るタイミングで追加（YAGNI で Phase 2 では未実装）。サインアウト / uid 切り替え時の sync 停止・再開は要件に出てきたら拡張する。

---

### 2026-06-04: SKIE 0.10.12 を採用、ただし「呼び出し方向限定」で実装側は completion handler 形式が必要

- 領域: KMP / Build / iOS Bridge
- 関連: `gradle/libs.versions.toml`, `sharedLogic/build.gradle.kts`, `docs/kmp-bridge.md`

Phase 2 iOS 実装の前準備として SKIE 0.10.12（Kotlin 2.3.21 互換）を `sharedLogic` に導入した。デフォルト機能（SuspendInterop / FlowInterop / SealedInterop）のみ有効化。Android テスト 12 件 / iOS link / Android assembleDebug すべてグリーン確認済。

**重要な発見**: SKIE の SuspendInterop は **「Kotlin の suspend / Flow を Swift から呼ぶ」方向のみ** に効果がある。**Swift 側で Kotlin の interface を実装する場合**（= `iosApp/FirebaseRepositories/AuthRepositoryIosImpl.swift` 等）、Obj-C ヘッダ準拠の生シグネチャを実装する必要がある:

- `suspend fun signInAnonymouslyIfNeeded(): String` → Swift では `func signInAnonymouslyIfNeeded(completionHandler: @escaping (String?, Error?) -> Void)` を実装
- `fun observeChanges(userId: String): Flow<List<Visit>>` → Swift では `func observeChanges(userId: String) -> any Kotlinx_coroutines_coreFlow` を実装（Swift の `AsyncStream` を直接返せない）

Swift から Kotlin `Flow` を返すには、SKIE 経由で `MutableStateFlow(initialValue:)` を Swift から構築し、Firestore リスナのイベントごとに `setValue` で更新する案を第一候補とする。これで詰まったら `iosMain` に「AsyncStream → Flow」の薄いラッパを追加する（`commonMain` ではなく `iosMain` に置く理由: Kotlin の `Flow` インスタンスは Kotlin/Native で生成する必要があり、Swift 単独では完結しない）。

影響:
- `docs/kmp-bridge.md` の SKIE セクションを「採用済み」に確定 + 実装側制約セクションを追記済
- `docs/tasks.md` Phase 0 SKIE 行を `[x]` に更新済
- Phase 2 iOS 実装の dispatch では Swift 側実装シグネチャを明示する必要がある

トレードオフ: SKIE は呼び出し側のエルゴノミクスを劇的に改善するが、両方向の interop が魔法のように解決されるわけではない。ios-engineer はこの制約を最初から理解した上で `FirebaseRepositories/` の Swift 実装に取り掛かる必要がある。

---

### 2026-06-04: Phase 2 iOS Firebase 実装の現状（動作確認範囲と未解決の hack）

- 領域: iOS / Firebase / KMP Bridge
- 関連: `iosApp/iosApp/{AppState,Phase2VerificationView,iOSApp}.swift`, `iosApp/iosApp/FirebaseRepositories/*.swift`

Phase 2 の iOS 側実装（SPM で `firebase-ios-sdk 12.14.0` 追加 / `FirebaseApp.configure()` / `AuthRepositoryIosImpl` / `RemoteVisitDataSourceIosImpl` / `AppContainer` 構築 + `startInitialSync()`）を `ios-engineer` 経由で実装。iPhone 17 / iOS 26.1 シミュレータでアプリ起動 → 匿名サインインで uid 取得まで動作確認済。

**動作確認できた範囲:**
- `xcodebuild` BUILD SUCCEEDED
- シミュレータ起動 → アプリ表示
- 匿名サインイン → uid 取得 → 画面表示
- Firestore オフライン永続化の起動ログ確認

**未解決（次タスクに分離）:**

1. ~~**`IosMainScope` の dispatcher 欠如**~~ → **2026-06-05 解消済**。`AppContainer` に scope なしのセカンダリコンストラクタを追加し、Swift 側は 3 引数版に切り替え、`IosMainScope.swift` を削除した。詳細は下の「2026-06-05: AppContainer はセカンダリコンストラクタで scope を隠蔽し IosMainScope hack を解消」エントリ参照

2. ~~**Firestore Security Rules 未設定**~~ → **2026-06-06 解消済**。`firestore.rules` をリポジトリ管理化し `firebase deploy --only firestore:rules` で本番反映。詳細は下の「2026-06-06: Firestore Security Rules をリポジトリ管理化、Storage は Phase 3 まで後ろ倒し」エントリ参照

3. **Visit 子コレクション同期未実装**: `RemoteVisitDataSourceIosImpl.upload()` 内に TODO コメントで明示。`coffeeItems` / `foodItems` / `photos` サブコレクションの同期は別タスクに分離

**SKIE 関連の重要発見（kmp-bridge.md / lessons.md に反映済）:**
- `SkieSwiftFlow<T>` の Swift 側構築は `_unconditionallyBridgeFromObjectiveC(SkieKotlinFlow(callbackFlow))` 経由
- Kotlin の `Visit` データクラスは Swift では `Visit_`（末尾 `_`）。SQLDelight 生成行型 `Visit` との衝突回避
- SKIE protocol witness は `__` プレフィックス付き completion handler 形式 / `SkieSwiftFlow<T>` / `SkieSwiftOptionalFlow<T>` 戻り値が正規シグネチャ

経緯: `ios-engineer` への dispatch で SKIE 制約への対応を含めた実装が完了。動作確認は匿名サインインまでで止め、`IosMainScope` hack 解消と Security Rules 設定を別タスクとして分離してコミットする方針（小分けコミット）。

---

### 2026-06-04: Android applicationId を iOS バンドル ID と揃え `com.noricoffee.coffeevision` に統一

- 領域: Android / Build
- 関連: `androidApp/build.gradle.kts`, `androidApp/src/main/kotlin/com/noricoffee/coffeevision/MainActivity.kt`

iOS バンドル ID は `com.noricoffee.coffeevision` だが、Android の `applicationId` / `namespace` は `com.noricoffee` のままになっていた。Firebase Console へのアプリ登録時に齟齬の原因になるため、Android 側を `com.noricoffee.coffeevision` に揃えた。

- `androidApp/build.gradle.kts` の `namespace` / `applicationId` を更新
- `MainActivity.kt` を `com.noricoffee.coffeevision` パッケージへ git mv（履歴保持）
- `App()` Composable は `sharedUI` の `com.noricoffee.App` にあるため、明示的に import 追加

`sharedLogic` のライブラリ namespace（`com.noricoffee.sharedLogic`）と `commonMain` の Kotlin パッケージ（`com.noricoffee.*`）は **applicationId とは別概念** のため、そのまま維持する。共通ライブラリのパッケージは複数アプリから再利用できる名前空間として残しておくのが自然。

トレードオフ: 既存ファイルが少ないうちに統一できたため、影響範囲は MainActivity 1 ファイルのみ。Firebase Console の Android アプリ登録時は新 package で登録すること。

---

### 2026-06-08: Phase 2.5 PR1 — build-logic/convention と shared/{core,domain} の切り出し

- 領域: Build / KMP
- 関連: `build-logic/**`, `shared/core/**`, `shared/domain/**`, `sharedLogic/build.gradle.kts`, `settings.gradle.kts`, `gradle/libs.versions.toml`

Phase 2.5 を 3 PR に分割するうち、PR1 として「Convention Plugin の足場 + ドメイン層の切り出し」を完了。

**採用:**
- precompiled script plugin 方式（`build-logic/convention/src/main/kotlin/{kmp.library,kmp.feature,android.library}.gradle.kts`）。`gradlePlugin { plugins.register(...) }` ブロックは置かない（`kotlin-dsl` が自動で plugin id を生成するため、register 併用は descriptor 二重生成で衝突する）
- `build-logic/settings.gradle.kts` に `versionCatalogs { create("libs") { from(files("../gradle/libs.versions.toml")) } }`。ルート build と `build-logic` build は別 build のため、同じカタログでも両方で個別宣言が必要
- `gradle/libs.versions.toml` の `[libraries]` に Gradle plugin classpath 用 4 件（`android-gradle-plugin` / `kotlin-gradle-plugin` / `sqldelight-gradle-plugin` / `skie-gradle-plugin`）を追加
- `shared/domain` に Visit / Cafe / CoffeeItem / FoodItem / Photo / 3 enum + AuthRepository / VisitRepository / RemoteVisitDataSource 計 11 ファイルを `git mv` で移送（パッケージ宣言は `com.noricoffee.domain.*` / `com.noricoffee.repository.*` のまま）
- `sharedLogic/build.gradle.kts` の `commonMain.dependencies` 先頭に `api(projects.shared.domain)` を追加。残った `AppContainer` / `LocalVisitRepository` / `VisitRepositoryImpl` / `Mapper` が新 domain モジュールを参照できるように再公開

**不採用:**
- `kmp.library` での `jvmToolchain(17)` 指定。開発機 JDK 26 環境で Toolchain auto-provisioning 未設定によりビルドが落ちる。既存 `sharedLogic` も Toolchain 未指定で動いており、`compilerOptions.jvmTarget = JvmTarget.JVM_11` だけで Android 側 JVM target を指定する方が運用が楽
- `build-logic` 内での `projects.shared.core` の type-safe project accessor 参照。`build-logic` は別 build のため accessor が生成されない。precompiled script plugin 内では文字列 API `project(":shared:core")` を使う必要がある
- 既存 `sharedLogic/build.gradle.kts` の Convention Plugin への移行。PR3 で `sharedLogic` モジュール自体を削除予定のため、移行コストを払う価値が薄い

**`shared/core` の暫定空殻判断:**
- PR1 時点では `AppContainer` / `VisitRepositoryImpl` を `shared/core` に **移さない**。理由は循環依存：`AppDatabase` / `LocalVisitRepository` は `sharedLogic` に残っており、`shared/core` から `sharedLogic` への依存は禁じ手のため
- Kotlin/Native のリンク段階で空モジュール警告を回避するため、`internal object CoreMarker` を 1 つ置いた。PR2 で AppContainer / VisitRepositoryImpl / Dispatcher ラッパが入ったタイミングで削除

**残課題（`android.library` Convention Plugin の AGP 9 deprecation 警告）:**
- AGP 9.x で `com.android.build.gradle.LibraryExtension` が deprecated（`com.android.build.api.dsl.LibraryExtension` に置換要請）。`android.library` プラグインは Phase 2.5 では適用側ゼロのため放置。実際に使う側が出てきた段階で DSL を最新版に置き換える

**検証:** Android テスト 12 件グリーン / `:androidApp:assembleDebug` 成功 / `:sharedLogic:linkReleaseFrameworkIosSimulatorArm64` 成功 / Swift から見えるシンボル変化なし（`import SharedLogic` は無変更で動作）

---

### 2026-06-08: Phase 2.5 PR2 — data-local / data-firebase 切り出しと AppContainer の shared/core 移送

- 領域: Build / KMP / iOS Bridge
- 関連: `shared/data-local/**`, `shared/data-firebase/**`, `shared/core/**`, `sharedLogic/build.gradle.kts`, `settings.gradle.kts`

Phase 2.5 PR2 として、SQLDelight 関連を `shared/data-local` に集約し、Firebase Android 実装の置き場として `shared/data-firebase` を空殻で作成、`AppContainer` / `VisitRepositoryImpl` を `shared/core` に移送した。`sharedLogic` は **Umbrella Reexport 専用** に縮小（`Greeting` / `Platform` 残骸は iOS / sharedUI で参照中のため PR3 で扱う）。

**採用:**
- SQLDelight プラグインと `AppDatabase` 宣言を `shared/data-local/build.gradle.kts` に集約。`sharedLogic` から SQLDelight プラグインを除去
- `data-firebase` は `build.gradle.kts` + Firebase BoM/firestore/auth/storage 依存のみ、ソース 0 ファイルでもリンク成功するため空殻で OK
- `shared/core` の `build.gradle.kts` で `api(projects.shared.{domain,dataLocal,dataFirebase})` を宣言し、`AppContainer` から各層を取り込む
- 旧 `sharedLogic/build.gradle.kts` を **Reexport 専用化**: `commonMain.dependencies { api(projects.shared.{core,domain,dataLocal,dataFirebase}) }` の 4 行 + `framework { export(projects.shared.{core,domain,dataLocal,dataFirebase}) }` の明示。Ktor / kotlinx-serialization / Firebase Android の直接依存は全削除
- `VisitRepositoryImplTest` は `shared/data-local/src/commonTest/.../repository/` に配置（タスク指示の `shared/core` commonTest 案は `expect/actual` の見え方制約で頓挫したため妥協配置）

**重要な発見（lessons.md 級の汎用知見、別途追記）:**
- KMP iOS framework では `commonMain.dependencies { api(projects.shared.other) }` だけでは依存モジュールの Kotlin class が Obj-C ヘッダに出ない。klib への取り込みは保証されるが、Swift 側 `import` で型が見えなくなる
- `framework { ... export(projects.shared.other) ... }` の **追加の明示が必須**。export 抜けと追加後で `SharedLogic.h` のヘッダ行数が 631 行 → 2412 行に激変する（実測）
- これは PR3 で `shared/framework` を Umbrella 化する際にも同じ知見が必要

**不採用:**
- タスク指示の「`VisitRepositoryImplTest` を `shared/core` の commonTest に置く」案: `createInMemoryTestSqlDriver` の `expect/actual` が `data-local` の commonTest/androidHostTest/iosTest に閉じており、他モジュールの commonTest から再利用する標準手段がない（`testFixtures` 導入 or expect 再宣言が必要で PR スコープ超過）
- SQLDelight プラグインを `sharedLogic` に残す案: 「`AppDatabase` 生成は `data-local` の責務」という整理を優先

**残課題（PR3 で対応）:**
- `Greeting` / `Platform` 残骸（`sharedLogic/src/{commonMain,iosMain,androidMain}/kotlin/com/noricoffee/`）が `iosApp/iosApp/ContentView.swift` と `sharedUI/src/commonMain/kotlin/com/noricoffee/App.kt` から参照されているため削除できず残置。PR3 でこれらを整理して `sharedLogic` を完全削除する
- `shared/framework` Umbrella モジュール作成（`export(...)` 群を移送）
- `sharedLogic` 削除 + iOS 側 Xcode の framework 参照先切り替え（Run Script のターゲット差し替え、Swift `import SharedLogic` は維持）
- `.github/workflows/ci.yml` の iOS link コマンド差し替え

**検証結果:**
- `:shared:data-local:testAndroidHostTest`: `LocalVisitRepositoryTest` 5 件 + `VisitRepositoryImplTest` 5 件、計 10 件グリーン
- `:androidApp:assembleDebug`: 成功
- `:sharedLogic:linkReleaseFrameworkIosSimulatorArm64`: 成功、`SharedLogic.framework/Headers/SharedLogic.h` で `AppContainer` / `VisitRepository` / `Visit_` 等の主要シンボルの export を確認

---

### 2026-06-08: Phase 2.5 PR3 — shared/framework umbrella 移行と sharedLogic 完全削除

- 領域: Build / KMP / iOS Bridge / CI
- 関連: `shared/framework/**`, `sharedLogic/**`（削除）, `sharedUI/build.gradle.kts`, `iosApp/iosApp/{ContentView.swift,iosApp.xcodeproj/project.pbxproj}`, `.github/workflows/ci.yml`, `settings.gradle.kts`

Phase 2.5 の最終 PR として、`shared/framework` umbrella モジュールへの完全移行を完了し、旧 `sharedLogic` モジュールを削除した。3 dispatch に分割して実施。

**dispatch A（kmp-engineer）:**
- `shared/framework` umbrella モジュール新設。Convention Plugin (`kmp.library`) は使わず KMP 設定を直接記述（`framework { ... }` DSL と SKIE プラグインが umbrella 専用のため）
- `XCFramework("SharedFramework")` ヘルパ宣言で `assembleSharedFrameworkXCFramework` タスクを生成（dispatch C で `SharedLogic` 名に統一）
- 内部 framework `baseName = "SharedLogic"` + `linkerOpts("-lsqlite3")` + `export(projects.shared.{core,domain,dataLocal,dataFirebase})` 明示
- `sharedUI/App.kt` の `Greeting` 参照削除（固定文字列に置換）
- `.github/workflows/ci.yml` を `:shared:data-local:testAndroidHostTest` + `:shared:framework:assembleSharedFrameworkXCFramework` に差し替え

**dispatch B（ios-engineer）:**
- `iosApp/iosApp/ContentView.swift` の `Greeting().greet()` 参照削除（固定文字列に置換）
- `iosApp/iosApp.xcodeproj/project.pbxproj` の Run Script を `:sharedLogic:embedAndSignAppleFrameworkForXcode` → `:shared:framework:embedAndSignAppleFrameworkForXcode` に差し替え
- 内部 framework 名 `SharedLogic.framework` を維持したことで Xcode の framework 参照・Framework Search Paths 等は無変更で完了
- `xcodebuild` で iPhone 17 シミュレータビルド成功確認
- 親フォロー: SourceKit が `import SharedLogic` を解決できないインデックス問題が発生（実ビルドは通る）。`ContentView` 内で SharedLogic シンボルを参照していなかったため `import SharedLogic` を削除して解消

**dispatch C（kmp-engineer）:**
- `sharedUI/build.gradle.kts` を `api(projects.sharedLogic)` → `api(projects.shared.framework)` に切り替え
- `Greeting.kt` / `GreetingUtil.kt` / `Platform.kt` / `Platform.android.kt` / `Platform.ios.kt` 削除
- `sharedLogic/` ディレクトリ完全削除、`settings.gradle.kts` から `include(":sharedLogic")` 除外
- XCFramework 名を `SharedFramework` → `SharedLogic` に統一（baseName と揃えて mismatch warning 解消）、タスク名が `assembleSharedLogicXCFramework` に追随
- `.github/workflows/ci.yml` のタスク名もそれに合わせて更新

**採用判断:**
- 内部 framework `baseName` と XCFramework 名を `SharedLogic` に統一（既存 Swift 7 ファイルの `import SharedLogic` を壊さない原則優先）。結果、umbrella モジュール名は `shared/framework` だが framework 名は `SharedLogic`、Swift 側命名は完全に維持された
- ~~`architecture.md` の例コードは `baseName = "SharedFramework"` だが、実装上 Swift 互換性を優先して `SharedLogic` を採用（docs 側の更新が要る）~~ → 2026-06-16 に `architecture.md` / `kmp-bridge.md` / `coding-conventions.md` の `SharedFramework` 表記を `SharedLogic` に統一済

**残課題:**
- ~~各モジュールの KDoc コメント中に旧 `sharedLogic/androidMain` 等の経緯記述が残る（計 5 箇所）~~ → 2026-06-08 に整理済（`docs/{architecture,coding-conventions,data-model,kmp-bridge}.md` の sharedLogic 言及と同時に消し込み）
- Kotlin/Native の bundleId 推論 warning（`Cannot infer a bundle ID...`）は Phase 2.5 スコープ外として残置。気になるなら `binaryOption("bundleId", "com.noricoffee.sharedlogic")` 相当を追加する別タスク

**検証:** `:shared:framework:assembleSharedLogicXCFramework` 成功（debug / release 両方 `SharedLogic.xcframework` 出力）、`:shared:data-local:testAndroidHostTest` 10 件グリーン、`:androidApp:assembleDebug` 成功、`xcodebuild` BUILD SUCCEEDED。iOS シミュレータでの最終動作確認（`Phase2VerificationView` 書き込みボタン → Firebase Console 反映）はユーザー作業

---

### 2026-06-06: Firestore Security Rules をリポジトリ管理化、Storage は Phase 3 まで後ろ倒し

- 領域: Firebase / Build / Docs
- 関連: `firebase.json`, `firestore.rules`, `storage.rules`, `.firebaserc`, `.gitignore`

Phase 2 セキュリティタスクの実装。Firestore Security Rules を **リポジトリ管理 + CLI デプロイ** 運用で確定し、Firestore のみ本番反映した。Storage Rules はファイルだけ先回りで作成しデプロイは Phase 3 に分離。

- **管理方式**: Firebase Console 直接編集ではなく、`firestore.rules` / `storage.rules` をリポジトリに置き `firebase.json` で参照、`firebase deploy --only <target>` で反映。理由は差分レビュー可能 / 再現性 / 履歴管理。Console のルールエディタはこれ以降触らない（衝突回避）
- **厳格度**: `data-model.md` §3.3 の概略案そのまま採用（`request.auth.uid == uid`、path uid のみ検証）。doc 内 `userId` フィールドの検証は加えない理由 = path 自体が auth uid に固定されるため重複。クライアント側の attach 漏れで write が落ちるリスクを避けた
- **Storage の後ろ倒し**: 2024 年 10 月以降、新規プロジェクトでの Storage 有効化に Blaze プラン（従量課金）アップグレードが必須化。写真機能（Phase 3）の実装着手時にクレカ登録 + Blaze + Storage 有効化 + `firebase deploy --only storage` をまとめてやる方が、用途とタイミングが一致して合理的と判断
- **storage.rules を Phase 2 時点で書いた理由**: Phase 3 で `firebase.json` に `"storage": { "rules": "storage.rules" }` を 1 行戻すだけで再デプロイ可能にしておくため。ルール内容は path uid のみ検証で Firestore と対称

経緯:
- 初回 `firebase deploy --only firestore:rules,storage` で `HTTP 404 / applications/<project> not found` が出た → 切り分けで Storage 側が原因と判明
- 並行して PATH 上に古い Standalone CLI（`/usr/local/bin/firebase` = 11.17.0）が残っていて `npm install -g firebase-tools@latest` が効かない罠も踏んだ。`sudo rm /usr/local/bin/firebase` で解消（汎用パターンとして `tasks/lessons.md` に記録）

影響:
- `docs/tasks.md` Phase 2 のセキュリティタスクは「Firestore のみ完了」備考で `[x]`。Phase 3 に Storage 有効化タスクを「写真ピッカー」の前段として追加
- 次タスクの「シミュレータ動作確認」が解禁（書き込みボタン → Console でデータ実体目視）

---

### 2026-06-09: Phase 3 — AppContainer ViewModel ファクトリは `shared/framework` の拡張関数として配置

- 領域: KMP / Build
- 関連: `shared/framework/src/commonMain/kotlin/com/noricoffee/framework/AppContainerViewModelFactory.kt`, `shared/core/src/commonMain/kotlin/com/noricoffee/AppContainer.kt`

Phase 3 の最初の `feature/visit-list` 切り出しで、`AppContainer.makeVisitListViewModel(): VisitListViewModel` をどこに置くかが問題になった。

`AppContainer` は `shared/core`、`VisitListViewModel` は `shared/feature/visit-list` にあり、`kmp.feature` Convention Plugin が `feature -> core` の `api` 依存を自動配線しているため、`core` が `feature` を参照しようとすると **循環依存** で Gradle が `CircularReferenceException` を投げる。

採用: `shared/framework`（iOS Umbrella）に拡張関数として配置する。`framework` は全 shared モジュールを `api` で持つ最上位レイヤーのため循環しない。Kotlin/Native は同モジュール内のレシーバを持つ拡張関数を Obj-C category として出力するため、Swift 側からは `appContainer.makeVisitListViewModel()` の形でインスタンスメソッドとして呼べる（呼び出し側 API は変わらない）。

不採用:
- `core` に直接置く → 即 `CircularReferenceException`
- `AppContainer` 自体を `framework` に移動 → Phase 2 から動いている iOS / Swift 側の参照やテストが広範に壊れる
- `kmp.feature` から `core` への依存を `implementation` に下げる → feature 内で `core` の型（`AppContainer` の依存型など）が見えなくなる

トレードオフ:
- `androidApp` から `makeVisitListViewModel()` を呼ぶ場合は `:shared:framework` に依存するか、`VisitListViewModel(repo, scope)` を直接呼ぶ必要がある。Android は検証ターゲットの 1 画面なので影響軽微
- 今後 feature を追加するたびに `framework/AppContainerViewModelFactory.kt`（または機能別ファイルへの分割）にファクトリ拡張を追記する運用になる

---

### 2026-06-09: Phase 3 — @Observable クラスは lazy var をサポートしないため Optional + bootstrap 時生成で回避

- 領域: iOS
- 関連: `iosApp/iosApp/AppState.swift`

`AppState` 内で `VisitListViewModelBridge` を 1 度だけ生成して保持するパターンを実装する際、`lazy var visitListBridge: VisitListViewModelBridge` を試すと `@Observable` マクロのコンパイルエラーになる（マクロが生成する init accessor は他 stored property を参照できない制約）。

採用: `private(set) var visitListBridge: VisitListViewModelBridge?` で宣言し、`bootstrap()` 成功後（`startInitialSync()` で `container` が確定し uid を取得した直後）に `if visitListBridge == nil { ... }` ガードで 1 度だけ生成する。`RootView` 側で `if let bridge = appState.visitListBridge, appState.uid != nil` で両方確認してから `VisitListView` を表示するため、nil 参照は構造的に発生しない。

影響: 今後追加する ViewModel ブリッジ（`VisitDetailViewModelBridge` 等）も同じパターンに揃える。本格的に Bridge が増えるなら専用 `BridgeContainer` を切り出すことも検討する余地はあるが、現時点では YAGNI。

---

### 2026-06-09: VisitRepository.delete に userId 引数を追加し Firestore 削除の TODO を解消

- 領域: KMP / Shared
- 関連: `shared/domain/.../VisitRepository.kt`, `shared/core/.../VisitRepositoryImpl.kt`, `shared/feature/visit-list/.../VisitListViewModel.kt`

Phase 3 着手の縦スライス直後フォロー。`VisitRepositoryImpl.delete()` が「ローカル削除のみで Firestore に届かない」状態（Phase 2 の I/F 整備で TODO に残されていた）を解消した。

- `VisitRepository.delete(id)` → `delete(userId, id)` にシグネチャ変更
- `VisitRepositoryImpl.delete()` で `local.delete(userId, id)` + `runRemote { remote.remove(userId, id) }` を呼ぶ（既存 `save` と対称）。`WritePolicy` も保存と同じく適用される
- `VisitListViewModel` 内に `private var currentUserId: String?` を保持し、`onAppear(userId)` で更新 → `onVisitDeleted(id)` で参照。Swift 側の `onVisitDeleted(id: String)` シグネチャは変えない（Bridge / View 無変更で済んだ）。`onAppear` 前の削除呼び出しは uid 未確定として黙殺
- テスト: `VisitRepositoryImplTest` に `delete_removes_local_then_remote_in_order` と `delete_propagates_remote_failure_by_default` の 2 件追加（合計 7 件、`LocalVisitRepositoryTest` 5 件と合わせて data-local の commonTest は 12 件グリーン）

トレードオフ: `userId` を `onVisitDeleted(id)` の引数に追加する案は Swift 側 Bridge / View の追随が必要なため見送り。VM 内部保持で Swift 側ゼロ変更を実現した。

不採用: `RemoteVisitDataSource.remove` 側で「自分の uid 配下から id で削除」を実装に責任持たせる案も検討したが、iOS Swift 実装が `AuthRepository` 等から自分で uid を取得する結合を生むため不採用。

---

### 2026-06-09: Phase 3 — VisitDetail 縦スライス（feature/visit-detail 切り出し + read-only Form 表示）

- 領域: KMP / iOS / Build
- 関連: `shared/feature/visit-detail/`, `shared/framework/.../AppContainerViewModelFactory.kt`, `iosApp/iosApp/Features/VisitDetail/`, `iosApp/iosApp/Features/VisitList/VisitListView.swift`

VisitList 縦スライスに続く Phase 3 の第 2 スライス。同じ Phase 3.5「feature 切り出し」と同時に実施した。

- `shared/feature/visit-detail`: `kmp.feature` Convention Plugin 適用の新規モジュール。`VisitDetailViewModel(visitRepository, scope)` + `UIState(visit: Visit?, isLoading, error)` + `onAppear(visitId)` / `onErrorDismissed()`。`observeById(visitId)` を `cancel & relaunch` パターンで購読
- `shared/framework`: `api(projects.shared.feature.visitDetail)` + `export(...)` 追加。`AppContainerViewModelFactory.kt` に `makeVisitDetailViewModel()` 拡張関数追加、ファイル KDoc を「複数 ViewModel ファクトリ前提」に書き換え（今後 feature 追加時は本ファイルにファクトリを追記する運用）
- `VisitDetailView`: `Form` ベースの read-only 表示（ヘッダ / 雰囲気 / メモ / コーヒー / フード / 写真プレースホルダ）。`StarsView` / `CoffeeItemRow` / `FoodItemRow` を同ファイル内 `private struct` として定義
- `VisitListView`: `NavigationLink` 先を `VisitDetailPlaceholderView` から `VisitDetailView(visitId:, appState:)` に差し替え、旧 placeholder struct は削除
- Bridge の生成方針: `VisitDetailView` 内 `@State` 保持 + `init(visitId:appState:)` で `appState.container.makeVisitDetailViewModel()` を呼ぶ。`AppState` にホルダプロパティを追加しない（一覧画面とパターンを意図的に分ける）
- enum 表示の暫定: Kotlin `BrewMethod` / `ProcessingMethod` / `RoastLevel` は Swift 側で class として現れ、`.name` で英語小文字（例: `"handdrip"`）を返す。日本語マッピングは別タスク（フェーズ 3 末か Phase 5 仕上げ）

検証: `:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` / `xcodebuild -sdk iphonesimulator` 全成功。シミュレータ実機での目視確認は未実施（親に依頼）。

---

### 2026-06-09: VisitEditorViewModel の設計（事前確定）

- 領域: KMP / iOS
- 関連: 実装予定 `shared/feature/visit-editor/`, `shared/framework/.../AppContainerViewModelFactory.kt`, `iosApp/iosApp/Features/VisitEditor/`

Phase 3 タスク「Visit 作成 / 編集画面（VisitEditorView）を実装」+ Phase 3.5「`feature/visit-editor` 切り出し」+ CoffeeItem / FoodItem モーダルを 1 縦スライスで進めるにあたり、サブエージェント dispatch 前に親が固めた設計判断。仕様判断（カフェ手入力 / モーダル同梱 / 写真ピッカー省略）はユーザー Plan 承認済み。

- **Mode は `sealed interface Mode { Create / Edit(visitId) }`**: 1 つの ViewModel で新規 / 編集を扱う（画面構造が共通のため別 VM に割らない）
- **VisitDraft を Visit と分離**: `Visit` は `id` / `userId` / `createdAt` / `updatedAt` / `cafe.placeId` 等 UI で編集しない値を含むため、UI 用 `VisitDraft` data class を別途持つ。save 時に draft からドメイン `Visit` を組み立てる
- **Edit モード初期化は `observeById(visitId).first()` で 1 回取得**: 継続購読にすると他端末更新が編集中の draft を上書きする事故が起き得るため避ける。MVP は last-write-wins（`updatedAt = now` で上書き）で十分
- **Save 時 Visit 構築**: Create は `id` / `createdAt` / `cafe.placeId` を新規 UUID 採番、`updatedAt = now`。Edit は `id` / `createdAt` / `cafe.placeId` を既存維持し `updatedAt` のみ now で上書き
- **カフェ手入力の暫定 placeId**: Places API は Phase 4 まで無いため UUID v4 で採番。Phase 4 着手時に「手入力 placeId → Google placeId」のマッピング or 個別差し替えが要件となる（Phase 4 課題として下のサマリにも記載）
- **バリデーション**: `data-model.md` §7 に従い ViewModel 集約。`cafeName` 非空 + 200 文字、`rating` 1..5（0 は未入力エラー）、`ambiance` 200 文字、`notes` 2000 文字。失敗時は `UIState.error` に詰めて `isSaving` を解除
- **保存完了 → View dismiss の合図**: `UIState.savedVisitId` に保存後の id を入れる。Swift 側は `onChange(of: viewModel.savedVisitId)` で `dismiss()`。`isSaving` トグル + `error` 詰めとあわせて View からは観測だけで完結
- **CoffeeItem / FoodItem モーダルは独立 Bridge を作らない**: 子モーダルは View 内 `@State` で編集中値を持ち、保存クロージャで親 VM の `onCoffeeUpserted` / `onFoodUpserted` に渡す。state を親 VM に集約する原則を守る。`Bridge` を増やすと「並行編集中の状態管理」が複雑化するため

トレードオフ:
- 編集中に他端末更新が反映されない: MVP ではユーザー 1 名想定で許容。複数端末同時編集の競合検知は将来の issue
- カフェ手入力 placeId と Google placeId が将来混在する: Phase 4 で差し替えロジックが必要

---

### 2026-06-09: VisitEditor 縦スライス完了時の実装側追加判断

- 領域: KMP / iOS / Build
- 関連: `shared/feature/visit-editor/`, `shared/framework/.../AppContainerViewModelFactory.kt`, `iosApp/iosApp/Features/VisitEditor/`, `iosApp/iosApp/{AppState,iOSApp}.swift`, `iosApp/iosApp/Features/{VisitList,VisitDetail}/`

前エントリ「VisitEditorViewModel の設計（事前確定）」の実装で追加で固まった判断と発見をまとめる。

- **`currentInitialVisit` を private プロパティで保持**: Edit モードで `observeById(visitId).first()` から得た初期 Visit は `private var currentInitialVisit: Visit?` として ViewModel 内部に隠蔽し、save 時に `id` / `placeId` / `createdAt` を引き出す。UIState に含める案は「UI で観測・表示しない内部値を Swift 側公開型に出すのは不適切」として不採用
- **`onDisappear()` を VisitEditorViewModel に追加**: visit-list / visit-detail には無いが、Editor は `loadJob` + `saveJob` の 2 本を持ち、特に保存中の画面離脱時のリソースリーク防止が重要なため例外的に追加した。既存 VM への追随修正は YAGNI で見送り
- **`@OptIn(ExperimentalUuidApi::class)` はクラスレベル付与**: `Uuid.random()` 呼び出しが複数あるため、関数単位より一括付与が運用しやすい
- **`validate()` の戻り値型は `String?`**: 失敗時のエラーメッセージを直接返す。`sealed interface ValidationResult` 案より呼び出し側が `if (error != null)` 1 行で完結する単純さを優先
- **SKIE `sealed interface Mode` の Swift 分岐は `is` キャストを採用**: SKIE SealedInterop で `onEnum(of:)` パターンマッチも生成されるが、ナビゲーションタイトル等の 2 分岐のみの判定では `is VisitEditorViewModelModeCreate` の方が読みやすい。3 分岐以上になったら `onEnum(of:)` 側に切り替える
- **SKIE EnumInterop の発見を kmp-bridge.md / lessons.md に昇格**: `BrewMethod` 等の Kotlin `enum class` が Swift 側で `@frozen enum: Hashable, CaseIterable`（case 名 camelCase）になる仕様を `kmp-bridge.md` §SKIE 適用後の見え方テーブルに追記、関連の「`.h` ではなく `.swiftinterface` を見る」「Picker 用 `ForEach(BrewMethod.allCases, id: \.name)`」を `tasks/lessons.md` に追記。同種の安定知見は今後も lessons / kmp-bridge へ即昇格する
- **`CoffeeEditingTarget` / `FoodEditingTarget` enum + `.sheet(item:)`**: 新規 / 編集を 1 つの sheet で扱うため、`enum CoffeeEditingTarget: Identifiable { case new; case existing(CoffeeItem) }` のラッパを Swift 側で定義し、`@State private var coffeeBeingEdited: CoffeeEditingTarget?` で `.sheet(item:)` を駆動。CoffeeItemEditorView 自体はバインディング不要で `initial: CoffeeItem?` + `onSave` クロージャの薄い API を維持できた
- **検証結果**: `:shared:framework:assembleSharedLogicXCFramework` / `:androidApp:assembleDebug` / `:shared:data-local:testAndroidHostTest`（12 件）/ `xcodebuild -sdk iphonesimulator -scheme iosApp build` 全成功。SourceKit の `No such module 'SharedLogic'` 系警告が一部出るが、`docs/tasks/lessons.md` 既出のキャッシュ問題で実害なし（DerivedData クリアで解消）
- **シミュレータ目視確認は未実施（ユーザー作業）**: 新規作成 / 編集 / キャンセル / バリデーションエラー / 子要素削除 / フード追加の 6 動線

---

### 2026-06-11: Phase 3.5 Android Firebase 実装の追加判断（実装後追記）

- 領域: Android / KMP / Build
- 関連: `shared/data-firebase/src/androidMain/`, `androidApp/`, `sharedUI/`

Phase 3.5 Android 検証スライス実装で確定した追加判断。事前設計エントリ（後述）の補足。

- **`kotlinx-datetime` は `domain` 側が `implementation` のため `androidMain` に届かない**: `shared/data-firebase/build.gradle.kts` と `sharedUI/build.gradle.kts` の `androidMain` / `commonMain` に個別に `implementation(libs.kotlinx.datetime)` を追加。KMP の `androidMain` は JVM classpath として扱われるため、推移的依存の `api` / `implementation` 区別が strict に効く。他モジュールが `androidMain` / `commonMain` で `kotlinx-datetime` の型を直接使う場合も同様に追加が必要
- **`Tasks.await` は `suspendCancellableCoroutine` で自前ラップ**: `kotlinx-coroutines-play-services` 不採用。10 行のヘルパで十分。`addOnSuccessListener` / `addOnFailureListener` を両方設定して成功・失敗パスをハンドル。キャンセル時は Firebase Task のキャンセルはできないがコールバック無視で安全に破棄
- **`androidApp` に `compose.material3` / `compose.runtime` の直接依存が必要**: `sharedUI` が transitively に含むが、`androidApp` の直接 Kotlin ソースから `MaterialTheme` / `Text` を使う場合は明示依存が必要
- **二重 `startInitialSync` 呼び出し**: `CoffeeVisionApp.onCreate()` と `VisitListScreen.LaunchedEffect` の両方で呼んでいる。`signInAnonymouslyIfNeeded()` は既存 uid をそのまま返すだけ、`startSync()` は Firestore listener を起動するが SQLDelight `upsert` が idempotent なため実害なし。将来「uid-first 表示」設計（`authRepository.observeUserId().filterNotNull().first()` で uid 待機）に変えれば整理可能だが Phase 3.5 検証スコープでは見送り
- **callbackFlow 内 coroutine 起動**: `callbackFlow` の ProducerScope は `CoroutineScope` を実装しているため `this.launch(Dispatchers.IO) {}` が使える。`val flowScope = this` でスコープを取り出してリスナーコールバック内から `flowScope.launch` するパターンが Android `observeChanges` で採用された
- **iOS / Android で Firestore Mapper は別実装**: iOS は Swift、Android は Kotlin で対称に書く（同じ Firestore スキーマを扱うがコード重複あり）。`commonMain` への共通化は Firebase SDK のオブジェクト型（`Timestamp` 等）がプラットフォーム依存のため割が合わない

### 2026-06-11: Phase 3.5 Android 検証スライスの事前設計

- 領域: Android / KMP / Build
- 関連: 実装予定 `shared/data-firebase/androidMain/`, `androidApp/`, `sharedUI/src/commonMain/kotlin/com/noricoffee/`

Phase 3.5 残タスク「androidApp で feature/visit-list を Compose の 1 画面として表示」+「Android 側で data-firebase の observe 経由 Firestore 読み取りが動くことを確認」を 1 スライスで進めるにあたり、サブエージェント dispatch 前に親が固めた設計判断。

Android は **リリース対象外の KMP 共通レイヤー検証ターゲット**。iOS と機能パリティを目指さず、「VisitListViewModel が Android でも動く + Firestore observe が往復する」を 1 画面で証明する最小実装に絞る。

- **Android Firebase 実装の置き場**: `shared/data-firebase/src/androidMain/kotlin/com/noricoffee/repository/` 直下に `AuthRepositoryAndroidImpl.kt` / `RemoteVisitDataSourceAndroidImpl.kt` / `VisitFirestoreMapper.kt`（iOS Swift マッパと等価な Kotlin 実装）を新規作成
- **iOS 側との非対称性は是認**: iOS は Swift で `AuthRepositoryIosImpl` / `RemoteVisitDataSourceIosImpl` を書いている。Android は Kotlin で `AuthRepositoryAndroidImpl` / `RemoteVisitDataSourceAndroidImpl` を書く。両者は `AuthRepository` / `RemoteVisitDataSource` インターフェースに準拠して `AppContainer` に渡される
- **Android の `observeChanges` は `callbackFlow` で実装**: `FirebaseFirestore.collection.addSnapshotListener` を `callbackFlow { ... awaitClose { listener.remove() } }` でラップ。iOS 側 SKIE 経由の SkieSwiftFlow とは対称な「素の Kotlin Flow」
- **書き込みは WriteBatch で原子化**: iOS と同じく、親 visit set + 3 子コレクション set + 既存子 ID との差分 delete を 1 commit に。`Tasks.await(batch.commit())` で suspend 化（`kotlinx-coroutines-play-services` が必要なら使うか、シンプルに `await` ラッパを自前で書く）
- **AppContainer の Android 構築**: `CoffeeVisionApp`（Application）クラスを `androidApp` 新規追加し、`FirebaseApp.initializeApp(context)` → `FirebaseFirestore.firestoreSettings` で `PersistentCacheSettings`（オフライン永続化）有効化 → `DatabaseDriverFactory(context).create()` で SQL Driver 作成 → `AppContainer(sqlDriver, RemoteVisitDataSourceAndroidImpl(), AuthRepositoryAndroidImpl())` を構築 → `companion object` の `lateinit var appContainer: AppContainer` に保持 → `scope.launch { appContainer.startInitialSync() }` で sign-in + sync 開始
- **AndroidManifest.xml に Application クラス指定**: `<application android:name=".CoffeeVisionApp" ... >` を追加
- **androidApp/build.gradle.kts の依存追加**: `alias(libs.plugins.googleServices)` プラグイン適用 + `implementation(projects.shared.framework)`（`makeVisitListViewModel()` を呼ぶため）+ `implementation(platform(libs.firebase.bom))` + `implementation(libs.firebase.auth)` + `implementation(libs.firebase.firestore)`。`google-services` プラグインがファイル末尾で apply するパターンも検証
- **Compose 1 画面の置き場**: `sharedUI/src/commonMain/kotlin/com/noricoffee/VisitListScreen.kt` を新規追加し、`@Composable fun VisitListScreen(appContainer: AppContainer)` を定義。既存 `App()` Composable は壊さない（iOS で参照されていないか不明なため安全側）。`MainActivity.setContent { MaterialTheme { VisitListScreen(CoffeeVisionApp.appContainer) } }` で呼ぶ
- **VisitListScreen の内容**: `val viewModel = remember { appContainer.makeVisitListViewModel() }` + `val state by viewModel.state.collectAsState()` + `LaunchedEffect(Unit) { val uid = appContainer.startInitialSync(); viewModel.onAppear(uid) }`（または `authRepository.observeUserId()` を購読）。`LazyColumn` で `state.visits` を簡素に表示（カフェ名 + visitedOn + rating）。削除 / 編集 / 詳細遷移は実装しない（検証範囲外）
- **enum 日本語化 / 写真表示 / Swipe to delete / 編集モーダル**: いずれも検証範囲外。Android は MVP で必要最小限のみ
- **VisitFirestoreMapper.kt（Android Kotlin 版）の API 設計**: `object VisitFirestoreMapper` の static メソッドとして `toDocument(visit: Visit): Map<String, Any?>` / `fromDocument(data: Map<String, Any?>): Visit?` / 子コレクション系も同様。iOS Swift 版と同等のフィールド扱い（nullable はキー省略 / Photo の localPath は Firestore に書かない / fileName は書く）

トレードオフ:
- iOS 側マッパは Swift で書き、Android 側マッパは Kotlin で書く。両側で同じ Firestore スキーマを扱うが、コード重複が発生する。`commonMain` に Kotlin マッパを置いて両プラットフォームで共有する案も検討できるが、Firebase SDK のオブジェクト型（`Timestamp` 等）がプラットフォーム依存のため、共通化のコストが高い。Phase 3.5 では「両側別実装で OK」と割り切る
- Android で `Tasks.await(...)`: `kotlinx-coroutines-play-services` を入れる or `suspendCancellableCoroutine` で薄く自前ラップする。シンプル化のため後者で開始し、必要なら依存追加に切り替える
- `CoffeeVisionApp.appContainer` の Singleton 化: テストしやすさを犠牲にするが Phase 3.5 検証では構わない。本格的な DI（Hilt / Koin）は Phase 5 以降の課題
- 写真の Documents/photos/ ファイル保存は iOS のみ実装。Android では Photo の `localPath` / `fileName` は Firestore から取れたメタデータをそのまま `LocalVisitRepository` 経由で SQLDelight に書くだけで、画像本体は持たない（検証スコープ外）

### 2026-06-11: SwiftUI Preview は「戦略 B（ダミー Demo）」+ PreviewSamples 集約

- 領域: iOS
- 関連: `iosApp/iosApp/PreviewSupport/PreviewSamples.swift`, `iosApp/iosApp/Features/{VisitList,VisitDetail,VisitEditor}/`, `iosApp/iosApp/Components/StarRatingView.swift`

各画面の SwiftUI Preview 実装で採用した方針メモ。

- **戦略 B 採用**: 本体 View は `AppState` / `AppContainer` / Kotlin VM を要求する Bridge を強く要求するため、Preview で本物の Bridge を構築するのは過剰。本体 View ロジックには手を入れず、`#Preview` ブロック内で「同等構造のダミー Demo」を書く方針を採った
- **PreviewSamples の集約**: `iosApp/iosApp/PreviewSupport/PreviewSamples.swift` に `Visit_` / `CoffeeItem` / `FoodItem` / `Photo_` のダミーデータを `static let` で定義し、Preview 間で共有。`Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds` / `Kotlinx_datetimeLocalDate(year:monthNumber:dayOfMonth:)` で日時を作成するヘルパも置く
- **写真セルは Preview Canvas で常に placeholder 表示**: `samplePhotos[0].fileName` が指すファイルは Preview 環境の Documents に存在しないため、`PhotoDetailCell` / `PhotoThumbnailCell` は `photo.badge.exclamationmark` placeholder になる。Preview 用に UIImage を inject する仕組みは作らない（割に合わない）
- **コード重複の容認**: 本体 View の `cafeSection` などの ViewBuilder を Preview から直接呼べないため、Form Section の構造を Preview Demo で手書き再掲する。本体の構造が変わった際は Preview 側も追従が必要。Phase 5 で `private struct Content` 抽出リファクタを行えば解消可能だが、MVP では割り切る
- **`#Preview` 件数**: VisitList 3 / VisitDetail 5 / VisitEditor 5 / CoffeeItemEditor 2 / FoodItemEditor 2 / StarRating 2 = 計 19 件。各画面の主要サブビュー（行 / セル）+ 本体 Demo + 編集モードバリエーションをカバー

### 2026-06-10: 写真ピッカー縦スライスの事前設計

- 領域: Docs / KMP / iOS
- 関連: 実装予定 `shared/{domain,data-local,feature/visit-editor}/`, `iosApp/iosApp/Features/{VisitEditor,VisitDetail}/`, `iosApp/iosApp/FirebaseRepositories/VisitFirestoreMapper.swift`, `docs/data-model.md`

Phase 3 残タスク「写真ピッカー組み込み + Documents 保存」+「Photo メタデータ（fileName / width / height）を SQLDelight + Firestore に永続化」を 1 縦スライスで進めるにあたり、サブエージェント dispatch 前に親が固めた設計判断。

- **fileName セマンティクス**: `{photoId}.jpg` を採用。`localPath` = `photos/{fileName}` を端末側で組み立てる。`fileName` を Firestore に保存することで、機種変・iCloud Backup 復元時に `localPath` を端末側で再構築可能。`localPath` と `fileName` は冗長に見えるが、`localPath` は SQLDelight DB の即時読み込み用 / `fileName` は Firestore メタデータの最小単位として両方持つ
- **画像形式は JPEG 統一**: PhotosPicker の戻り値は HEIC のことが多い。`UIImage` 経由で `jpegData(compressionQuality: 0.85)` に変換して Documents 配下に保存する。圧縮品質 0.85 はファイルサイズと画質のバランス取り
- **PhotosPicker（iOS 16+）採用**: `PHPickerViewController` ではなく SwiftUI ネイティブの `PhotosPicker(selection: $items, maxSelectionCount: 10, matching: .images)`。`PhotosPickerItem.loadTransferable(type: Data.self)` で `Data` を取得 → `UIImage` 経由で JPEG 化
- **Documents 配下のディレクトリ規約**: `<Documents>/photos/{photoId}.jpg` の **フラットディレクトリ**。visitId 別ディレクトリにしない理由は「Create モードで visitId 確定前に写真を保存できる」「VisitEditorViewModel の Mode.Create 拡張不要」「保存タイミングが UI 側の関心事に閉じる」の 3 点。Visit 削除時は `Visit.photos` の id 列挙でファイル個別削除（小規模なら問題なし、1 visit あたり数枚〜数十枚想定）
- **SQLDelight migration**: 開発中検証データの DB 互換のため、`schemaVersion` を 2 に上げて `shared/data-local/src/commonMain/sqldelight/migrations/1.sqm` で `ALTER TABLE photo ADD COLUMN file_name TEXT;` を追加する。リリース前ではあるが既に Phase 2-3 で `writeDummyVisit()` や VisitEditor で書いたデータが端末に残っている前提で migration を書く
- **画像表示（VisitDetailView）**: `Documents URL + localPath`（= `photos/{fileName}`）で `Image(uiImage: UIImage(contentsOfFile: url.path)!)` で表示。表示は単純な horizontal `ScrollView` + `LazyHStack` で 3-4 枚並べる軽量 UI。サムネイル / 拡大表示は別タスク
- **削除時の orphan ファイル削除**: 画面上で写真を削除（onPhotoRemoved）+ Visit ごと削除（VisitRepository.delete）時に、Documents 配下の物理ファイルも消す。フラット配置のため、Visit 削除側は `Visit.photos` の各 `fileName` を列挙して `photos/{fileName}` を個別削除する（visitId 別ディレクトリは存在しない）
- **保存タイミング**: PhotosPicker で選択 → 一時 `Data` をメモリ保持（`pendingImageData: [String: Data]`） + `Photo` インスタンス作成 → `onPhotoUpserted(item:)` で VM に push。Documents への物理書き出しは **保存ボタン押下時にまとめて実行**。Editor 内で削除した既存写真は `removedFileNames` に貯めて VM `savedVisitId` 確定後にまとめて物理削除。これでキャンセル時の orphan ファイル発生をゼロにできる（途中までは Documents に何も書かない）
- **VisitFirestoreMapper.fileName**: 既存 `width` / `height` と同じ nullable パターンで `if let fileName = photo.fileName { dict["fileName"] = fileName }` 追加。decode 側も同様
- **enum 日本語化は別タスクのまま据え置き**: 写真ピッカースライスとは独立。Picker 等の表示は `.name`（英語）のまま

トレードオフ:
- `localPath` と `fileName` の冗長性: SQLDelight DB だけ見ると `fileName` がなくても `localPath` から basename を抽出すれば取れる。ただし「Firestore に保存するのは `fileName` のみ」の規約があるため、ドメインモデルに `fileName` を独立フィールドとして持たせる方が往復経路が単純になる
- 残オーファンの境界条件: 「`saveWithPhotoFlush` で Documents 書き出し成功 → VM 保存エラー」の状態でユーザーが閉じた場合のみ、書き出し済みファイルが残る。`onDisappear` での自動 cleanup は「エラー alert 表示中の一時 dismiss」と区別しにくいため見送り。Phase 5 仕上げ候補

実装後追記（2026-06-10）:
- Create モード visitId の Swift 側事前発番は **不要**だった。`photos/` フラットディレクトリ規約により VisitEditorViewModel の Mode 拡張も不要
- VisitEditor 実装は `pendingImageData` (新規分メモリ保持) + `removedFileNames` (既存削除分の遅延物理削除) の 2 状態で完結。保存ボタンの順序は「pendingImageData 書き出し → VM.onSaveTapped → savedVisitId onChange で removedFileNames 物理削除 + dismiss」
- iOS デプロイメントターゲット 26.0 のため PhotosPicker の `@available(iOS 16, *)` ガード不要



- 領域: Docs / Firebase / Data Model
- 関連: `docs/{requirements,data-model,architecture,kmp-bridge,coding-conventions,ui-ux-guidelines,tasks}.md`, `storage.rules`（残置）, `Photo.kt`

写真の保管先を「ローカル + Firebase Storage アップロード」から「**端末ローカルのみ**」に変更。Phase 3 で写真ピッカーを実装する前にユーザーと方針合意して docs を先行更新（実装コードへの影響は写真ピッカー未実装のためゼロ）。

**採用:**
- 写真本体は端末の Documents 配下に保存（相対ファイル名で管理）。Firestore の `photos` サブコレクションには `fileName` / `width` / `height` / `createdAt` などメタデータのみを書く
- バックアップは iCloud Backup に委ねる（SQLDelight DB + 写真ファイル）。複数端末同期は諦め
- `Photo.remoteUrl: String?` フィールドは null 固定で残置（将来 Storage 復活余地 + Firestore スキーマ安定 + 移行コスト最小化）
- 写真ファイルパスは **相対パス保存に統一**（iOS の Documents URL は起動ごとに変わるため絶対パス禁止）

**採用見送り理由:**
- 新規 Firebase プロジェクトの Storage 有効化が Blaze プラン（クレカ登録）必須化されており、Phase 3 リリース閾値が高い（[`tasks/lessons.md`](./tasks/lessons.md) 2026-06-06 エントリ）
- iOS のみリリース方針（[[platform-release-policy]] memory）のため、iCloud Backup で機種変・複数端末・アプリ削除復元のカバー範囲は実用上十分
- アップロード処理 / リトライ / `remoteUrl` 同期の実装が不要になり Phase 3 が軽くなる

**実装影響:**
- 現状ゼロ（写真ピッカーが Phase 3 未着手のため）
- 次の写真ピッカー実装タスクから「Documents 配下にファイル保存 + 相対 `fileName` を `Photo.localPath` に詰める」実装が初登場
- iOS `RemoteVisitDataSourceIosImpl` の `photos` サブコレクション同期はそのまま残置（書き込まれるデータが「常に `remoteUrl = null`」になるだけ）
- `storage.rules` ファイル / `Photo.remoteUrl` フィールドを残しているため、将来 Storage を復活させる場合は本決定の逆操作（docs 復元 + `firebase.json` に `storage` キー追加 + Blaze 化 + `firebase deploy --only storage`）で戻せる

---

### 2026-06-11: Phase 4 着手の事前設計（スライス分割と API キー注入経路）

- 領域: KMP / iOS / Android / Build / Docs
- 関連: 実装予定 `shared/data-places/`, `shared/domain/.../CafeRepository.kt`, `shared/core/.../AppContainer.kt`, `local.properties`, `androidApp/build.gradle.kts`, `iosApp/Configuration/`

Phase 4（Places API / カフェ検索）に着手する。Phase 4 は要件項目数が多く（Text/Nearby/Detail 検索 + 位置情報 + 写真 + UI + モジュール分割）、1 dispatch で全部を進めるとビルド検証粒度が粗くなる。**5 スライスに分割**して進める方針を固めた。

**スライス分割**:

1. **スライス 1（KMP 基盤）**: `data-places` モジュール作成 + Ktor / Serialization セットアップ + `PlacesClient` interface（`commonMain`）+ Places API New v1 の `places:searchText` 実装 + DTO + `CafeRepository` interface（`shared/domain`）+ `CafeRepositoryImpl` + `AppContainer` への API キー注入経路。**UI 統合・位置情報・写真取得はスコープ外**
2. **スライス 2（iOS UI 検証）**: `CafeSearchView`（テキスト検索のみ）+ `VisitEditor` 統合（「カフェを検索」ボタン → 検索画面 → 選択結果でフィールド自動入力）。Bridge と Search ViewModel は `shared/core` 経由で配線（feature 切り出しは最終スライス）
3. **スライス 3（位置情報 + Nearby + Detail）**: CoreLocation 連携 + Place Details 補完 + Nearby Search
4. **スライス 4（写真都度取得）**: Place Photo Media API（`places/{placeId}/photos/{photoName}/media`）。Cafe.photoReferences をキーに表示時取得する `PlacePhotoLoader`（iOS 側で URLSession 経由）
5. **スライス 5（feature 切り出し）**: `shared/feature/cafe-search` モジュール切り出し + `AppContainer.makeCafeSearchViewModel()` 拡張関数を `shared/framework` に追加

**Places API バージョン**: **Places API (New) v1 を採用**

- エンドポイント: `https://places.googleapis.com/v1/places:searchText`（POST）/ `places:searchNearby`（POST）/ `places/{placeId}`（GET）/ `places/{placeId}/photos/{photoName}/media`（GET）
- 認証: `X-Goog-Api-Key: <APIキー>` ヘッダー
- 取得フィールド指定: `X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,places.websiteUri,places.googleMapsUri,places.photos` 必須（指定しないとリクエストエラー）
- リクエストボディ: `{"textQuery": "...", "includedType": "cafe", "languageCode": "ja"}` 形式
- 不採用: **Places API (Legacy)**（Text Search / Nearby Search / Place Details）。理由は新規プロジェクトは New 推奨で料金体系も New に集約、フィールドマスクで明示課金できる方が運用上望ましいため

**API キー管理方針**:

- `local.properties` に `placesApiKey=AIza...` を 1 行追加（`.gitignore` 済、コミットしない）
- **採用: `AppContainer` のコンストラクタ引数として外部から注入する経路**
  - Android: `androidApp/build.gradle.kts` で `local.properties` を読み取り → `buildConfigField("String", "PLACES_API_KEY", "\"...\"")` で BuildConfig 注入 → `CoffeeVisionApp.onCreate()` で `AppContainer(..., placesApiKey = BuildConfig.PLACES_API_KEY)` 渡し
  - iOS: `Configuration/Secrets.xcconfig`（`.gitignore` 済）に `PLACES_API_KEY = AIza...` を 1 行 → `iosApp.xcconfig` に `#include "Secrets.xcconfig"` → `Info.plist` に `<key>PLACES_API_KEY</key><string>$(PLACES_API_KEY)</string>` → Swift 側 `Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String` → `AppContainer` 構築時に渡し
  - 採用理由: Firebase の Repository インスタンス注入と同じパターン。KMP コア（`commonMain`）は API キーを知らなくてよく、テスト時もダミーキーを渡せる
- **不採用**:
  - `local.properties` を直接 KMP コードから読み込む案: Gradle 用ファイルのため runtime からは読めない / 全プラットフォームで一貫しない
  - 環境変数注入案: iOS の Run Scheme 環境変数は実機ビルドで効かないため不採用
  - キーを直接 Kotlin ソースに hardcode する案: コミットすると Google API Console から失効指示が来る + .gitignore 漏れリスク

**`data-places` モジュール構成**:

- `shared/data-places/build.gradle.kts`: `kmp.library` Convention Plugin 適用 + `kotlinSerialization` プラグイン適用
- 依存:
  - `commonMain`: `kotlinx-coroutines-core`, `kotlinx-serialization-json`, `ktor-client-core`, `ktor-client-content-negotiation`, `ktor-serialization-kotlinx-json`, `api(projects.shared.domain)`
  - `iosMain`: `ktor-client-darwin`
  - `androidMain`: `ktor-client-okhttp`
- パッケージ: `com.noricoffee.data.places.*`

**コンポーネント設計**:

- `PlacesClient` interface（`commonMain`、`shared/data-places`）
  - `suspend fun searchText(query: String): List<PlaceSummary>`（スライス 1）
  - 後続スライスで `searchNearby(lat, lng, radius)` / `getDetails(placeId)` / `photoMediaUrl(placeId, photoName, maxSize)` 追加
- `PlaceSummary` data class（`commonMain`）: Places API New の `places.id` / `places.displayName.text` / `places.formattedAddress` / `places.location.{latitude,longitude}` / `places.websiteUri` / `places.googleMapsUri` / `places.photos[].name` をフラットにマッピング
- DTO: `SearchTextRequest` / `SearchTextResponse` / `PlaceDto` / `LocationDto` / `DisplayNameDto` / `PhotoDto` を `@Serializable` で定義（API スキーマに従いプロパティ名は camelCase / Json.ignoreUnknownKeys = true）
- `PlacesClientImpl(httpClient: HttpClient, apiKey: String)` で実装。`Json { ignoreUnknownKeys = true; explicitNulls = false }` でゆるい decode
- `CafeRepository` interface（`shared/domain`）: `suspend fun searchText(query: String): List<Cafe>`。実装は `data-places` 側
- `CafeRepositoryImpl(placesClient: PlacesClient)` を `shared/data-places/commonMain` に実装。`PlaceSummary` → `Cafe` 変換（`photoReferences` には `places.photos[].name` を入れる。形式は `"places/{placeId}/photos/{photoReference}"`、表示時は Photo Media API へ `?key=...&maxHeightPx=...` で叩く）
- HttpClient ファクトリ: `commonMain` に `internal expect fun createPlacesHttpClient(): HttpClient`、`iosMain`（darwin engine）/ `androidMain`（okhttp engine）で `actual`

**AppContainer 配線**:

- `AppContainer` の **プライマリコンストラクタに `placesApiKey: String` 引数を追加**（既存 3 引数セカンダリも 4 引数版に追随。テスト用 5 引数版で scope 注入可）
- 内部で `createPlacesHttpClient()` → `PlacesClientImpl(httpClient, placesApiKey)` → `CafeRepositoryImpl(placesClient)` → `val cafeRepository: CafeRepository` を公開
- Phase 4 後続スライスで `makeCafeSearchViewModel(): CafeSearchViewModel` を `shared/framework` の拡張関数として追加（Phase 3 の `VisitListViewModel` ファクトリと同じパターン）

**スライス 1 範囲外（明示）**:

- iOS / Android の検索 UI（`CafeSearchView` / Compose 検証）→ スライス 2
- `VisitEditor` との統合（手入力 → 検索ベース）→ スライス 2
- CoreLocation 連携 → スライス 3
- Place Details / Nearby Search 実装 → スライス 3
- Photo Media API（都度取得）→ スライス 4
- `feature/cafe-search` 切り出し → スライス 5
- 既存 `Cafe.placeId` が「Places API 由来 / VisitEditor 手入力の UUID」を識別する仕組み → 必要が出た時に「`placeId` の先頭が `ChIJ` から始まる」等のヒューリスティクスで判定するが、現状は混在のまま許容

**トレードオフ**:

- スライス 1 で UI まで作らない: dispatch の規模を抑え、ビルド検証可能な単位（KMP 基盤のみ）に分けるため。UI 統合は次スライスに送る
- スライス 1 ではキーが未設定でもビルドが通る: `placesApiKey` が空文字でも HttpClient 構築は成功する（実 API 呼び出し時に 401 になるだけ）。CI 上で実 API キーを必要としないメリットを優先
- `shared/data-places/commonMain` への `kotlinx-serialization-json` 依存: 既存 `shared/data-local` の `Mapper.kt` も `kotlinx-serialization` を使っているため新規依存は libs.versions.toml で宣言済（再利用のみ）

**iOS 側の xcconfig 整備の注意（スライス 1 で実施するか議論）**:

- iOS の API キー注入（`Secrets.xcconfig` + Info.plist 連携）は **iOS UI 実装（スライス 2）と同時に進める方が自然**。スライス 1 では Android 側のみ BuildConfig 整備して KMP 配線を完了し、iOS は AppContainer 構築時にハードコード空文字（後で xcconfig 経由に差し替え）でビルド検証する暫定対応とする
- スライス 2 で iOS 側 `Secrets.xcconfig` + Info.plist + AppState 経由の AppContainer 構築を確定する

---

### 2026-06-11: Phase 4 スライス 1 実装後追記（KMP `internal` とモジュール間アクセス、SKIE 警告）

- 領域: KMP / Build / iOS Bridge
- 関連: `shared/data-places/src/commonMain/kotlin/com/noricoffee/data/places/{PlacesHttpClient.kt,PlacesModule.kt}`, `shared/core/.../AppContainer.kt`

スライス 1 実装で固まった追加判断と発見。

**KMP `internal` 可視性とモジュール境界**:

- `createPlacesHttpClient()` を `internal expect` にすると、`api` 依存の別モジュール（`shared/core`）から直接呼べない。KMP の `internal` 可視性は「同一 Gradle モジュール内」に閉じるため、`api` 依存で classpath に乗っていても **別モジュールからはアクセス不可**
- 採用: `PlacesModule.kt` にパブリックなファクトリ関数 `fun createCafeRepository(apiKey: String): CafeRepository` を置き、`AppContainer` はこれ経由で `CafeRepository` を組み立てる設計。これで `HttpClient` のエンジン選択（Darwin / OkHttp）と `PlacesClient` の構築詳細が `data-places` モジュール内に閉じる
- 同パターンは将来 `data-firebase` の Android 実装本格移送時にも適用可能（Firestore 設定詳細を Android 内に閉じてファクトリ関数を公開）

**Ktor を `framework` に `export` した際の SKIE 警告**:

- `shared/framework/build.gradle.kts` で `export(projects.shared.dataPlaces)` を追加すると Ktor が XCFramework に取り込まれ、`Ktor_httpHttpStatusCode.description` が Swift の `description()` と名前衝突して SKIE が `description_` にリネームする警告が出る。ビルドは通る
- 現状は UI から `HttpStatusCode` を直接参照しないため放置。スライス 2 で UI から扱う必要が出たら `@ObjCName("description")` 相当の Kotlin 側調整で解消する

**`AppContainer` コンストラクタ拡張**:

- プライマリコンストラクタに `placesApiKey: String` を **`authRepository` の次・`scope` の前** に挿入
- セカンダリ（scope なし）も 4 引数に拡張（`placesApiKey` 追加）
- Swift / Android 双方の構築コードを同スライスで追随（`AppState.swift` は暫定空文字 `placesApiKey: ""`）
- 既存の引数順は保持。今後 `cafeRepository` 関連で追加引数が出る場合も末尾追加を原則とする

---

### 2026-06-12: Phase 4 スライス 2 の事前設計（CafeSearchViewModel + VisitEditor 統合 + iOS xcconfig）

- 領域: KMP / iOS / Build
- 関連: 実装予定 `shared/core/.../CafeSearchViewModel.kt`, `shared/feature/visit-editor/.../VisitEditorViewModel.kt`, `shared/framework/.../AppContainerViewModelFactory.kt`, `iosApp/Configuration/Secrets.xcconfig`, `iosApp/iosApp/Features/CafeSearch/`, `iosApp/iosApp/Features/VisitEditor/VisitEditorView.swift`

スライス 2 着手前の親による仕様確定。スライス 1 で KMP 基盤（data-places / PlacesClient / CafeRepository）が動くようになったため、本スライスは「Places API を実画面から呼べる状態」と「VisitEditor が検索結果を取り込める状態」を作る。スライス 3 以降（CoreLocation / Photo / feature 切り出し）はスコープ外。

**`CafeSearchViewModel` の置き場と API**:

- **配置**: `shared/core/src/commonMain/kotlin/com/noricoffee/feature/cafesearch/CafeSearchViewModel.kt`（スライス 5 で `shared/feature/cafe-search` に移送する暫定置き場）。`shared/core` 配置の理由は、Phase 3 で `VisitListViewModel` 等を切り出す前と同じく「feature module を増やすより `core` 暫定で UI 実装を先行する」方針。スライス 5 の git mv で移送する想定
- **コンストラクタ**: `class CafeSearchViewModel(private val cafeRepository: CafeRepository, private val scope: CoroutineScope)`
- **`UIState`**:
  - `val query: String = ""`
  - `val results: List<Cafe> = emptyList()`
  - `val isLoading: Boolean = false`
  - `val error: String? = null`
- **API**:
  - `fun onQueryChanged(query: String)` — `query` を更新するのみ（検索は実行しない）
  - `fun onSearchTapped()` — 現在の `query` で `cafeRepository.searchText(query)` を呼び、`results` を更新。`isLoading` トグル + `runCatching` で `error` 詰め
  - `fun onErrorDismissed()` — `error` を null に戻す
- **検索ジョブ管理**: `private var searchJob: Job?` を保持し、再タップ時は前回を `cancel()` してから再起動
- **`onAppear` は持たない**: 検索結果は初期空でよく、明示タップで初回検索が走る方が消費 API 量を制御しやすい。SwiftUI 側も任意の `.task` 不要

**`VisitEditorViewModel` への統合 API 追加**:

- 新規メソッド: `fun onPlacesCafeSelected(cafe: Cafe)`
- 効果: `_state.value.draft` の `cafeName` / `cafeAddress` / `cafeWebsiteUrl` / `cafeMapsUrl` を `cafe` のフィールドで上書きする。`Cafe.address` / `websiteUrl` / `mapsUrl` が null の場合は空文字を入れる（既存の手入力フィールドが nullable でなく String のため）
- **`placeId` の扱い**: Edit モード時の保持パターンを壊さないため、`currentInitialVisit` 経由でなく **`_state` に `selectedPlaceId: String?` を新規追加して保持**。`buildVisit()` の Create モード分岐で `selectedPlaceId != null` なら UUID 採番ではなく `selectedPlaceId` を使う。Edit モード時は既存 `placeId` を維持する既存ロジックを保つ
  - これにより「VisitEditor 起動 → Places 検索選択 → Create 保存」フローで Google placeId が保存される
  - 手入力のまま保存した場合は従来通り UUID 採番（Phase 4 完了時点でも混在する）
- 位置情報（latitude / longitude）/ `photoReferences` は draft に保持しない（VisitDraft は表示フィールドのみを持つ原則を保つ）。代わりに `_state` に `pendingCafeLocation` 等の内部値を持つ案もあるが、現状 UI 表示しないためスライス 4（写真）まで省略
- **トレードオフ**: Cafe ドメインの全フィールドを VisitDraft に持たせるリッチ案より、UI が表示するフィールドだけ draft、隠れ値（placeId / location / photoReferences）は `_state` 直下に持つ案を採用。`Visit` を組み立てる責務は `buildVisit()` に一元化する設計を保つ

**`AppContainer` ファクトリ拡張**:

- `shared/framework/.../AppContainerViewModelFactory.kt` に `fun AppContainer.makeCafeSearchViewModel(): CafeSearchViewModel = CafeSearchViewModel(cafeRepository, scope)` を追記。既存の `makeVisitListViewModel` / `makeVisitDetailViewModel` / `makeVisitEditorViewModel` と同パターン

**iOS `CafeSearchView` の構造**:

- 配置: `iosApp/iosApp/Features/CafeSearch/{CafeSearchView,CafeSearchViewModelBridge}.swift`
- `CafeSearchView` は `.sheet` で起動される前提。内部に `NavigationStack` ラップ
- `CafeSearchViewModelBridge` は `@MainActor @Observable`、`for await s in kotlin.state { apply(s) }` パターン（既存 Bridge と同じ）
- API: `init(appState:onCafeSelected:)`。`onCafeSelected: (Cafe) -> Void` を保持し、結果セルタップで呼ぶ → 親が `dismiss()` + `onPlacesCafeSelected(cafe:)` を呼ぶ
- 検索バー: `TextField` + 検索ボタン（フォーカス時 `.submitLabel(.search)`、`onSubmit` で `onSearchTapped()`）
- 結果セル: 簡素な VStack（カフェ名 + 住所）。写真は表示しない（スライス 4）
- 空状態: 初回起動時は `ContentUnavailableView` で「カフェ名で検索してください」表示
- `error` は alert 表示
- Preview: ダミー `[Cafe]` を渡す Demo を 2 件追加（結果あり / 空状態）

**`VisitEditorView` 統合**:

- カフェ Section の `カフェ名（必須）` TextField の上または下に **`Button { isCafeSearchPresented = true } label: { Label("カフェを検索", systemImage: "magnifyingglass") }`** を追加
- `@State private var isCafeSearchPresented: Bool = false` を追加
- `.sheet(isPresented: $isCafeSearchPresented) { CafeSearchView(appState: appState) { cafe in viewModel.onPlacesCafeSelected(cafe: cafe); isCafeSearchPresented = false } }` を追加
- 手入力モードは残置（カフェ名 TextField はそのまま編集可能）
- Edit モードでも検索ボタンは表示（カフェを差し替えたいケースを許容）

**iOS API キー注入経路**:

- 採用: **`Configuration/Secrets.xcconfig` を新規作成して `PLACES_API_KEY = AIza...` を 1 行**。`.gitignore` に `iosApp/Configuration/Secrets.xcconfig` を追加してコミットしない
- `iosApp/Configuration/Base.xcconfig` も新設して `#include? "Secrets.xcconfig"` を書き、ベースファイルとしてプロジェクトの Build Settings から参照する
  - `?` 付き include により Secrets.xcconfig が存在しない CI 環境でもビルドが落ちないようにする（CI 上で空キーフォールバック）
- `Base.xcconfig` で `INFOPLIST_KEY_PLACES_API_KEY = $(PLACES_API_KEY)` 形式の指定、または `Info.plist` に `<key>PLACES_API_KEY</key><string>$(PLACES_API_KEY)</string>` を追加
- Swift 側: `Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String ?? ""` で取得、`AppState` の `bootstrap()` で `AppContainer(..., placesApiKey: ...)` に渡す
- スライス 1 の `placesApiKey: ""` 暫定コードを上記呼び出しに差し替える
- `Configuration/` ディレクトリは `iosApp/Configuration/` 配下に作成し、Xcode プロジェクトに `Configuration` グループとして登録

**ビルド検証**:

- `./gradlew :shared:framework:assembleSharedLogicXCFramework`
- `./gradlew :androidApp:assembleDebug`
- `./gradlew :shared:data-local:testAndroidHostTest`
- `cd iosApp && xcodebuild -sdk iphonesimulator -scheme iosApp build`

**スコープ外（明示）**:

- CoreLocation（現在地検索）→ スライス 3
- Place Details 補完 → スライス 3
- Photo Media API（写真表示）→ スライス 4
- `feature/cafe-search` モジュール切り出し → スライス 5
- 検索結果の保存（最近検索したカフェなど）→ 必要が出てきたフェーズで検討
- enum 日本語化（既存タスクとして並存）

**トレードオフ**:

- `selectedPlaceId` を `_state` に持つ vs `VisitDraft` に持つ: `VisitDraft` を「表示フィールドのみ」に保つ既存規約を守るため `_state` 直下を採用。ただし `currentInitialVisit` と並んで「draft 以外の隠し状態」が増えるため、スライス 5 や Phase 5 で `EditorContext` 等の集約クラスを検討する余地あり
- `CafeSearchView` を sheet で開く vs `NavigationLink` で push: VisitEditor 自身が sheet なので二重 sheet になるが、SwiftUI iOS 17+ では問題なく動く。NavigationLink 案だと VisitEditor の NavigationStack のスタックに積み上がり戻り遷移が複雑化するため sheet 採用
- 初回起動時の自動検索: 行わない。タップで初回検索が走る方が API 消費を制御できる
- `Secrets.xcconfig` の include に `?` を付ける: ファイル不在時もビルドが通る（CI 環境想定）。スライス 1 で `placesApiKey: ""` 暫定にしたのと同じ「キー無しでもビルドだけは通る」原則を維持

---

### 2026-06-12: Phase 4 スライス 2-B 実装後追記（xcconfig 継承 / `.searchable` 採用 / `@MainActor` deinit 制約）

- 領域: iOS / Build / Docs
- 関連: `iosApp/Configuration/{Base,Config,Secrets}.xcconfig`, `iosApp/iosApp.xcodeproj/project.pbxproj`, `iosApp/iosApp/Features/CafeSearch/`

スライス 2-B 実装で固まった追加判断と発見。

**xcconfig の継承構造（重要）**:

- iOS の `iosApp` ターゲットには **既存 `Config.xcconfig`** があり、`PRODUCT_BUNDLE_IDENTIFIER` / `TEAM_ID` / `PRODUCT_NAME` / `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` / `OTHER_LDFLAGS = $(inherited) -lsqlite3` を持つ（最後はスライス 1 から動いていた sqliter リンクに必須）
- 採用: 新規 `Base.xcconfig` の先頭で `#include "Config.xcconfig"`（必須 include、不在時エラー）→ `#include? "Secrets.xcconfig"`（任意 include、不在時無視）→ `PLACES_API_KEY =` フォールバック宣言、の 3 段構造
- pbxproj の `baseConfigurationReferenceRelativePath` は `Base.xcconfig` に差し替え。`Config.xcconfig` は **直接参照されないが Base から `#include` 経由で必ず継承される**
- 不採用:
  - 既存 `Config.xcconfig` に `PLACES_API_KEY` 関連を直接追記する案: 「アプリ識別 / リンカ設定」と「API キー」が同居して可読性が下がる
  - `Base.xcconfig` だけで bundle ID 等を再宣言する案: `Config.xcconfig` を「アプリ識別の単一情報源」として残しておくほうが、将来の TEAM_ID / バージョン管理時に触る場所が 1 つに集約される
- 失敗履歴（親が事後修正）: ios-engineer 初回実装で `Base.xcconfig` が `Config.xcconfig` を継承していなかった。`xcodebuild` はキャッシュと KMP framework 側の `linkerOpts("-lsqlite3")` で通っていたが、初回クリーンビルド + bundle ID 解決で破綻するリスクがあった。親が `#include "Config.xcconfig"` を追加して継承を復活、再ビルドで `com.noricoffee.coffeevision` の bundle ID 出力を確認した
- 今後の教訓（lessons.md 級）: 既存 `Configuration/` ディレクトリに xcconfig がある場合、新規 xcconfig は **必ず既存ファイルを `#include` で継承するか、Build Settings 経由でマージするかを検討してから差し替える**。pbxproj の `baseConfigurationReference` 差し替えは「上書き」になるため、既存設定が消える事故が起きる

**iOS Bridge の deinit 制約**:

- `@MainActor @Observable` クラスの `deinit` は **non-isolated** 扱いになるため、`@MainActor` プロパティ（`observationTask` 等）にアクセスできない
- 採用: `deinit` を持たず、`func cancel()` を公開して `.onDisappear { bridge.cancel() }` から呼ぶパターン（既存 `VisitListViewModelBridge` / `VisitEditorViewModelBridge` と統一）
- 同パターンは Phase 5 以降の新規 Bridge にも適用

**`.searchable` 採用（HIG 準拠の検索 UI）**:

- 採用: `NavigationStack { ... }.searchable(text: ..., prompt: ...)` + `.onSubmit(of: .search)` + toolbar の補助検索ボタン
- 不採用: 仕様メモの `TextField + .submitLabel(.search) + .onSubmit` 単独構成
- 理由: `.searchable` は NavigationStack 統合の検索バーとして HIG 準拠 / VoiceOver 対応 / Dynamic Type 自動対応が得られる。フォーカス管理も SwiftUI が引き受ける
- 影響: Phase 4 後続スライス（CoreLocation 現在地検索ボタンの追加）も `.searchable` の toolbar / leading 領域に補完できる

**Xcode 16.2 の `PBXFileSystemSynchronizedRootGroup` 形式**:

- pbxproj の xcconfig 参照は `baseConfigurationReferenceAnchor`（`PBXFileSystemSynchronizedRootGroup` の UUID）+ `baseConfigurationReferenceRelativePath`（ファイル名）の 2 行で済む。`PBXFileReference` を個別作成する旧形式と互換
- 既存の `Config.xcconfig` も同形式で登録されており、`Base.xcconfig` / `Secrets.xcconfig` / `README.md` は同一 `Configuration` グループ配下に自動認識される
- 追加ファイルを pbxproj に明示登録する必要がない（Xcode が自動同期）

---

### 2026-06-13: Phase 4 スライス 3 の事前設計（CoreLocation + Nearby Search + Place Details）

- 領域: KMP / iOS / Build
- 関連: 実装予定 `shared/data-places/.../PlacesClient.kt`, `shared/domain/.../CafeRepository.kt`, `shared/core/.../CafeSearchViewModel.kt`, `iosApp/iosApp/Utilities/LocationManager.swift`, `iosApp/iosApp/Info.plist`, `iosApp/iosApp/Features/CafeSearch/CafeSearchView.swift`

スライス 2-B で CafeSearchView のテキスト検索が動くようになった。本スライスは「現在地周辺のカフェ検索」と「Place Details」を加える。スコープは 2 段（KMP 側 + iOS 側）で分ける。

**Nearby Search API（Places API New v1）**:

- エンドポイント: `POST https://places.googleapis.com/v1/places:searchNearby`
- 認証ヘッダー: `X-Goog-Api-Key` / `X-Goog-FieldMask`（Text Search と同じ FieldMask を使い回す）
- リクエストボディ（JSON）:
  ```json
  {
    "includedTypes": ["cafe"],
    "maxResultCount": 20,
    "languageCode": "ja",
    "locationRestriction": {
      "circle": {
        "center": {"latitude": <lat>, "longitude": <lng>},
        "radius": <radius_meters>
      }
    }
  }
  ```
- `radius` の単位はメートル。デフォルト 500m を採用（カフェ歩き圏想定）
- `maxResultCount` は 20（API 上限）を使う
- レスポンス構造は Text Search と同じ `places: [...]` 配列なので、既存 `SearchTextResponse` → `SearchNearbyResponse` の DTO を分けるか、共通の `PlacesListResponse` にまとめる。**実装判断は kmp-engineer に委ねる**（既存 `SearchTextResponse` を `PlacesListResponse` にリネームして両方で再利用する案 / 別 DTO 案いずれも可、判断理由をレポートに記録すること）

**Place Details API（Places API New v1）**:

- エンドポイント: `GET https://places.googleapis.com/v1/places/{placeId}`
- 認証ヘッダー: `X-Goog-Api-Key` / `X-Goog-FieldMask`
- FieldMask: Text/Nearby の `places.*` 接頭辞が **不要**（単一 place 取得のため）。スキーマは `id,displayName,formattedAddress,location,websiteUri,googleMapsUri,photos` を指定（接頭辞なし）
- リクエストボディなし
- レスポンスは `PlaceDto` 単体（`places` 配列ではない）
- スライス 3 では API のみ実装し、**UI への組み込みは行わない**。要件 5-3「カフェ詳細（住所・写真・営業時間）」のうち営業時間表示は将来タスク（VisitEditor が住所欠落カフェを保存しないようにする補完用途を想定）

**`PlacesClient` の API 追加**:

```kotlin
interface PlacesClient {
    suspend fun searchText(query: String): List<PlaceSummary>           // 既存
    suspend fun searchNearby(latitude: Double, longitude: Double, radiusMeters: Double = 500.0): List<PlaceSummary>
    suspend fun getDetails(placeId: String): PlaceSummary
}
```

- `searchNearby` の `radiusMeters` はデフォルト引数で 500m
- `getDetails` の戻り値 `PlaceSummary` は単一値（`List<PlaceSummary>` でなく `PlaceSummary` 直接）
- SKIE は Kotlin デフォルト引数を Swift に引き出さないため、Swift 側から呼ぶ際は明示的に `radiusMeters: 500.0` を渡すが、現状 iOS 側で呼ぶのは `CafeRepository` 経由なのでこのケースは生じない

**`CafeRepository` の API 追加**:

```kotlin
interface CafeRepository {
    suspend fun searchText(query: String): List<Cafe>                    // 既存
    suspend fun searchNearby(latitude: Double, longitude: Double, radiusMeters: Double = 500.0): List<Cafe>
    suspend fun getDetails(placeId: String): Cafe
}
```

- 戻り値は `Cafe` ドメインモデル（`PlaceSummary` → `Cafe` 変換は既存 `toCafe()` 拡張関数を再利用）
- `getDetails` は **単一 `Cafe`**（見つからない場合は API 側で 404 → 例外伝播）

**`CafeSearchViewModel` への API 追加**:

- 新規メソッド: `fun onNearbySearchRequested(latitude: Double, longitude: Double)`
- 効果: 既存 `searchJob` を `cancel()` → 新ジョブで `cafeRepository.searchNearby(latitude, longitude)` を呼び `results` を更新
- `UIState.query` は更新しない（テキスト検索バーは「現在地検索」の入力ソースではない、別系統のクエリとして扱う）
- 失敗時は既存 `onSearchTapped` と同じく `error` 詰め
- **位置情報の取得自体は iOS 側の責務**（Kotlin VM は座標を受け取るだけ）。CoreLocation を `expect`/`actual` で抽象化する案は不採用（複雑度に対して見合わない、Android は検証ターゲットのみで現在地検索を実装しないため）

**iOS `LocationManager` ラッパ設計**:

- 配置: `iosApp/iosApp/Utilities/LocationManager.swift`
- 構造: `@MainActor @Observable final class LocationManager: NSObject, CLLocationManagerDelegate`
- 公開プロパティ:
  - `authorizationStatus: CLAuthorizationStatus`
  - `lastLocation: CLLocationCoordinate2D?`
  - `error: Error?`
- メソッド:
  - `func requestPermission()` — `manager.requestWhenInUseAuthorization()` を呼ぶ
  - `func requestLocation()` — `manager.requestLocation()` を呼ぶ（1 回限り取得）。許可がまだなら先に `requestWhenInUseAuthorization()` を呼ぶ
- Delegate コールバック:
  - `locationManagerDidChangeAuthorization(_:)` で `authorizationStatus` 更新
  - `locationManager(_:didUpdateLocations:)` で `lastLocation` 更新
  - `locationManager(_:didFailWithError:)` で `error` 更新
- **使用方針**: 完全に 1 回限りの単発取得（continuous 監視はしない）。許可ダイアログは初回タップ時に出る

**`Info.plist` 追加**:

- `<key>NSLocationWhenInUseUsageDescription</key>`
- `<string>近くのカフェを検索するために、現在地を一時的に使用します。</string>`

**`CafeSearchView` への UI 追加**:

- toolbar の検索ボタンの **隣** に `Button { handleNearbyTapped() } label: { Image(systemName: "location.fill") }` を追加
- `handleNearbyTapped()`:
  - `locationManager.requestLocation()` を呼ぶ
  - `.onChange(of: locationManager.lastLocation)` で取得した座標を `bridge.onNearbySearchRequested(latitude:, longitude:)` に渡す
  - `lastLocation` をリセットする（同じ座標で連続検索したいときに反応するように `nil` に戻す）
- 位置情報拒否時は `locationManager.authorizationStatus == .denied` を見て alert で「設定アプリで位置情報を有効化してください」と案内する
- `LocationManager` は `CafeSearchView` 内 `@State private var locationManager = LocationManager()` で保持（sheet ライフサイクルに紐付ける）

**スコープ外（明示）**:

- Place Details の UI 表示 → スライス 5 以降 or Phase 5
- 位置情報の継続監視（地図画面で現在位置追従など） → 必要が出てきたら
- 「位置情報を許可しないユーザー」向けの代替フロー（IP ベース概略位置など） → 仕様に無いため不要
- Android 側の現在地検索 → リリース対象外、Phase 6 任意タスク
- `feature/cafe-search` モジュール切り出し → スライス 5

**トレードオフ**:

- CoreLocation を `expect`/`actual` で抽象化しない: Android で `FusedLocationProviderClient` のラッパを書く必要が出るが、Android は検証ターゲットで現在地検索を実装しないため、KMP 抽象化は YAGNI
- 単発取得（continuous なし）: 検索のたびに新しい座標を取得する方が UX として直感的（移動した場合に追従できる）。バッテリ消費も最小
- 半径 500m 固定: 都市部のカフェ密度では 500m で 20 件取れる想定。スライダ等で可変にする UI は MVP 不要
- Place Details は API のみ実装: 「使い道のない API を実装するのは YAGNI 違反」だが、要件 5-3 に明記されているため Phase 4 のうちに API は揃えておく。UI 統合は次フェーズ判断

---

### 2026-06-13: Phase 4 スライス 3-B 実装後追記（`@Observable` ユーティリティの状態リセット / `nonisolated` delegate）

- 領域: iOS
- 関連: `iosApp/iosApp/Utilities/LocationManager.swift`, `iosApp/iosApp/Features/CafeSearch/CafeSearchView.swift`

スライス 3-B 実装で固まった追加判断と発見。

**`@Observable` クラスの状態リセットは `private(set)` + リセットメソッド方式**:

- `LocationManager` の `error` / `lastLocation` は外部書き込み禁止（`private(set)`）にして、View 側からのリセットは `resetLastLocation()` / `clearError()` 公開メソッド経由
- 当初の設計案では `locationManager.error = nil` を View から直接代入する想定だったが、`private(set)` 制約に引っかかるためメソッド化が必要だった
- このパターンは「`@Observable` のユーティリティクラスで、View から状態リセットが必要なプロパティ」が出てきた場合の標準パターンとして以後の Bridge / Manager 系に適用する
  - 例: `CafeSearchViewModelBridge.error` は Kotlin 側で `onErrorDismissed()` を呼ぶ転送が既に同パターン
  - 例: `LocationManager.lastLocation` も `.onChange` の再トリガ用に `resetLastLocation()` で明示リセット

**`CLLocationManagerDelegate` メソッドの `nonisolated` 必須**:

- CoreLocation のデリゲートコールバックは MainActor 外（背景スレッド）から呼ばれるため、`@MainActor` クラスに準拠させる場合は **デリゲートメソッドすべてを `nonisolated` で宣言**する必要がある
- 内部の `@MainActor` プロパティ更新は `Task { @MainActor in ... }` でメインアクター上に戻して反映
- 同パターンは将来 `UIImagePickerControllerDelegate` 等の他フレームワーク Delegate 連携でも踏襲

**SourceKit の `'authorizedWhenInUse' is unavailable in macOS` 警告**:

- `iosApp` ターゲットは iOS 専用だが、SourceKit のインデックス処理がプラットフォーム判定を誤ることがある（DerivedData の状態次第）
- `xcodebuild -sdk iphonesimulator` での実ビルドは正しい iOS Simulator ターゲットを使用するため警告は出ず BUILD SUCCEEDED
- DerivedData クリア / Xcode 再起動で SourceKit 警告は解消する
- `#if canImport(UIKit)` 等のガードは不要（iosApp ターゲットが iOS 専用と pbxproj で定義されているため）

**現在地検索ボタンの配置**:

- toolbar の右側を `HStack { 現在地ボタン; 検索ボタン }` で並べる構成を採用
- 不採用: leading 配置（NavigationStack のキャンセル / 戻るボタンと干渉）
- 「現在地」と「キーワード検索」は同列の検索開始操作のため、右側にまとめてユーザーがどちらも 1 タップで起こせる UX を優先

---

### 2026-06-13: 画面構成を TabBar 化（Map / Visits / Search）+ カフェ詳細統合

- 領域: iOS / Shared / Docs
- 関連: `iosApp/iosApp/{iOSApp,AppState,RootTabView}.swift`, `iosApp/iosApp/Features/{Map,CafeDetail,VisitList,CafeSearch}/**`, `shared/core/.../feature/{map,cafedetail}/`, `shared/domain/.../{model/VisitedCafe.kt, usecase/ObserveVisitedCafesUseCase.kt}`, `docs/requirements.md`

iOS の画面構成を `RootView → VisitListView` の単一画面から、iOS 26 `TabView` 新 API（`Tab` / `Tab(role: .search)`）を活用した 3 タブ構成にリファクタする決定。

**新しいルート構造**:

- **Tab 1 マップ**（`systemImage: "map"`）: 訪問済みカフェ（ブラウンピン）+ 現在地周辺 Places（グレーピン）を同時表示。toolbar の `Menu` 配下に 2 つの `Toggle`（訪問済み / 周辺）でフィルタ切替
- **Tab 2 訪問**（`systemImage: "list.bullet"`）: 既存 `VisitListView`。`+` ボタンと `isPresentingEditor` sheet は撤去
- **Tab 3 検索**（`role: .search`）: 既存 `CafeSearchView` をルート化。NavigationStack + `.searchable` + 現在地検索ボタン

**新規 Visit 作成導線の一本化**:

- マップピンタップ / 検索結果タップ → CafeDetailView push → 「+ Visit を追加」ボタン → VisitEditorView sheet（カフェ pre-filled）
- VisitListView からの直接作成は撤去（ユーザー指示）
- CafeDetailView は要件 `requirements.md` の「カフェ別 Visit 一覧画面」を統合し、Cafe スナップショット + 過去 Visit 一覧 + 追加ボタンを 1 画面に集約

**マップ初期カメラ位置**:

- 現在地許可済み → 現在地中心
- 未許可 → 訪問済みカフェの bounding box（fit）
- 両方なければデフォルト座標（東京駅相当）

**KMP 側の追加**:

- `ObserveVisitedCafesUseCase`: `VisitRepository.observeAll(userId)` を `groupBy { place_id }` → `VisitedCafe(cafe, lastVisitedAt, visitCount, averageRating)` 集約。Visit 一覧の派生情報なので `shared/domain/usecase` に配置
- `VisitedCafe` 集計モデル: `shared/domain/model/`
- `MapViewModel` / `CafeDetailViewModel`: `CafeSearchViewModel` と同じく `shared/core/.../feature/{map, cafedetail}/` の暫定配置（→ 2026-06-15 Phase 4 スライス 5 で `shared/feature/map` / `shared/feature/cafe-detail` に移送済）
- `AppContainer` に `makeMapViewModel()` / `makeCafeDetailViewModel(placeId)` factory を追加（`shared/framework` の拡張関数として置く、既存 `makeVisitListViewModel` 等と同パターン）

**Bridge ライフサイクル**:

- `mapBridge` = AppState 1 つ保持（TabView は 3 タブ常時生存。`visitListBridge` と同じく bootstrap 完了時に 1 度だけ生成）
- `CafeDetailViewModelBridge` = CafeDetailView 内 `@State` で push ごとに生成（`place_id` 依存のため、`CafeSearchViewModelBridge` と同パターン）

**`role: .search` の挙動**:

- iOS 26 では `Tab(role: .search)` が TabBar 右端に固定配置
- 中身は `NavigationStack` ルート + `.searchable`。テキスト入力時に iOS 26 標準の検索 UI 展開動作に乗る

**温存する既存導線**:

- `VisitEditorView → CafeSearchView (sheet)` の callback 経路は残す（編集モードでカフェ変更が必要なため）。`CafeSearchView` の `onCafeSelected` を Optional 化し、未指定（= ルート用途）時は内部 `NavigationLink` で CafeDetailView へ push する分岐を追加

**影響**:

- `requirements.md` 画面一覧（L178-189）を Tab 構成に書き換え、カフェ別 Visit 一覧を「カフェ詳細画面」に統合明記
- `iOSApp.swift` の `RootView` 表示先が `VisitListView` → `RootTabView` に切替
- `AppState` に `mapBridge` 追加（visitListBridge と同等の lazy 管理）
- `VisitListView` の toolbar `+` と sheet を撤去（既存 sheet 起点が一本化されたため）

**トレードオフ**:

- マップ + Places 周辺ピンの同時描画は MapKit `Annotation` を 2 種類重ねる構成。ピン数が増えた場合のクラスタリングは初期実装では入れない（必要が出てきたら後追い）
- マップ初期カメラ位置の「訪問済み bounding box fit」は許可なし時の fallback。実装段階で SwiftUI `Map(initialPosition:)` の `MKMapRect` 指定で実現する。位置情報許可後は中心を現在地に切替
- **`VisitedCafe.cafe` は「最新訪問のスナップショット勝ち」採用**（同 `placeId` で過去店舗名 / 住所が変わっていた場合、最新訪問のものに上書きされる）。`Visit` 自体には訪問時点のスナップショットが残るため履歴は失われないが、`VisitedCafe` 集計レベルでは過去スナップショットは見えない。要件として「あの時のカフェ名」を集計表示したくなった時点で再検討する
- **`ObserveVisitedCafesUseCase` の `lastVisitedAt` は `Visit.visitedOn`（LocalDate）を UTC 0:00 の Instant に変換した値**。ソート用なので日本時間の「当日」感覚とは微妙にズレるが、ソート精度は維持される。iOS 表示で日付を出す用途には使わず、`visitedOn: LocalDate` を直接使うこと
- **`rating == 0` は未評価として `averageRating` 算出から除外**（全 Visit が 0 なら null）。`Visit.rating` の型が non-nullable Int なため、0 をセンチネル扱いする実装上の判断

**実装上の補足**:

- `shared/core/build.gradle.kts` に `implementation(libs.kotlinx.datetime)` を明示追加した（`MapViewModel` / `CafeDetailViewModel` が `LocalDate` を直接扱うため）。`shared/domain` は `kotlinx-datetime` を `implementation` 持ちのため transitively には Android JVM 側に届かず、コンパイル成功時でも実行時 NoClassDefFoundError になり得る。`shared/core` から直接利用する箇所では明示依存が必要
- `CafeSearchView` をルート化（`onCafeSelected` Optional 化）した副作用として、**VisitEditor の sheet で起動する側は `NavigationStack { CafeSearchView(...) }` でラップする必要がある**。理由: ルート化により `CafeSearchView` 自体は `NavigationStack` を持たない素の View になったため、sheet 起動時に親 NavigationStack がいないと `.navigationTitle` / `.searchable` / `.toolbar` がレンダリングされない。Tab 起動時は RootTabView の NavigationStack が親になるので不要
- `MapTabView` の位置情報取得は `LocationManager.lastLocation` を **AsyncStream ポーリング（0.1s × 30 回 = 最大 3 秒）** で監視。`@Observable` を `.task` 内で安全に観察する手段として現実的だが、最大 3 秒の遅延が生じる。位置情報が取れなかった場合は訪問済み bounding box → 東京駅デフォルトに fallback
- `RootTabView` への切替で iOS `iOSApp.swift` の `private struct RootView` を **`AppRootView` にリネーム**（既存コードとの可視性衝突回避）。`bootstrap()` 完了の判定条件に `mapBridge != nil` を追加した（visitListBridge と同等扱い）

---

### 2026-06-15: マップ画面に Apple Maps POI タップで Visit 追加する動線

- 領域: iOS / KMP / Places
- 関連: `iosApp/iosApp/Features/Map/MapTabView.swift`, `iosApp/iosApp/Features/Map/MapViewModelBridge.swift`, `shared/data-places/.../PlacesClient.kt`, `shared/domain/.../repository/CafeRepository.kt`, `shared/core/.../feature/map/MapViewModel.kt`

iOS 17+ の `Map(selection:)` + `MapFeature` API で Apple Maps の標準 POI（地図上のカフェ / 飲食店アイコン）タップを検知し、Google Places に照合してカフェ詳細に進める動線を追加する。CoffeeVision が描画する 2 種類のピン（訪問済み / 周辺）と別軸の発見導線として並列。

**カテゴリフィルタ**: `MapFeature.kind == .pointOfInterest` かつ `MapFeature.pointOfInterestCategory` が `.cafe` / `.restaurant` / `.bakery` のいずれかのときのみ反応する。それ以外の POI（公園 / ガソリンスタンド等）のタップは無視（selection を nil リセット）。

**Google Places 照合方式**: `searchText(name, locationBias=circle(POI座標, 500m))` で名前一致 + 近接の両条件をサーバ側で評価。

- 不採用: iOS 側で `searchText(name)` の結果を距離フィルタ（同名チェーン店が広範囲で返る場合に効率劣化 + 誤マッチ可能性）
- 不採用: `searchNearby(POI座標, 500m)` の結果を name フィルタ（Nearby は name 絞り込みできず無関係カフェが混ざる）

**MapFeature の `featureIdentifier` は使わない**: Apple Maps の internal identifier で Google Places の `placeId` と互換性なし。ルックアップ結果の Google `placeId` を採用することで、`VisitedCafe` 集計や CafeDetail の過去 Visit 紐付けと整合する。

**UI 動線**: タップ → ProgressView オーバーレイ → CafeDetailView に**プログラマティック push**（`NavigationPath` に append）。既存の描画ピンタップ（`NavigationLink(value:)` 経由）と push 経路が違うが、両方とも最終的に `navigationDestination(for: CafeDetailRoute.self)` で `CafeDetailView` を出す。確認 sheet は挟まない（CafeDetailView 自体が「カフェ情報 + 過去 Visit + 追加ボタン」の確認画面の役割を兼ねる）。

**ヒットなしの fallback**: `searchText` 結果が空 → alert で「該当するカフェが見つかりませんでした」。ネットワークエラー → alert で「カフェ情報の取得に失敗しました: {error}」。手入力 fallback は今回スコープ外（必要が出たら別タスク）。

**KMP の API 拡張**:

- `PlacesClient.searchText(query: String, locationBias: LocationBias?)` に拡張（`SearchTextRequest` DTO に `locationBias.circle.center` + `radius` を追加）
- `CafeRepository.searchText` も同シグネチャに拡張（Optional の `LocationBias` 引数）
- SKIE デフォルト引数制約のため、Swift 側からは「位置バイアスなし版」「あり版」のオーバーロード 2 つで露出させる方針（既存 `searchNearby` の `radiusMeters` 隠蔽パターンと統一）
- `MapViewModel` に `onPoiTapped(name, latitude, longitude)` / `onPoiLookupConsumed()` を追加、`UIState` に `isLookingUpPoi: Bool` / `poiLookupResult: Cafe?` / `poiLookupError: String?` を追加

**トレードオフ**:

- POI 1 タップごとに Places `searchText` リクエストが 1 回発生（料金 / レイテンシ）。誤タップしても課金される
- 同名近接店舗が複数ある場合（同じビルに 2 店舗等）の 1 件目採用が誤マッチになり得る。CafeDetailView 上で「違うカフェだった」と気付ける UX で許容

**実装補足（スライス 7-A 完了時点）**:

- `LocationBias` は `shared/domain` パッケージ（`com.noricoffee.domain`）に配置。Repository インターフェースのシグネチャとして `CafeRepository.kt` と同じ階層
- `PlacesClientImpl.searchTextInternal(query, locationBias: LocationBiasDto?)` に HTTP 構築ロジックを集約し、2 オーバーロードから委譲する DRY 構造を採用
- `LocationBiasDto` は `SearchNearbyRequest` が使う `CircleDto` / `LatLngDto` を再利用（Places API New v1 の `locationBias.circle` と `locationRestriction.circle` が同一 JSON 構造のため）
- Swift から呼ぶ際は `bridge.onPoiTapped(name:latitude:longitude:)` の 3 引数のみ（`locationBias` の `radiusMeters = 500.0` は VM 内部固定）

**実装補足（スライス 7-B 完了時点）**:

- `MapTabView` が自身で `NavigationStack(path: $navigationPath)` を保有する構造に変更し、`RootTabView` 側の外側 NavigationStack を撤去（Map タブのみ自己完結 / Search タブは引き続き `RootTabView` 内の NavigationStack）。理由: `navigationPath.append` でのプログラマティック push を実現するため `path` バインディングが必要だが、`MapTabView` の外側から渡すと API が増える割に得るメリットが小さい
- `MapFeature` は iOS 26 SDK で `#if compiler(>=5.3) && $NonescapableTypes` ガード経由で公開されており、Xcode 26 (Swift 6.x) ターゲットで条件を満たし BUILD SUCCEEDED
- `bridge.error`（周辺検索エラー）と `bridge.poiLookupError`（POI ルックアップエラー）の 2 系統 `.alert` が `MapTabView` に共存。同時発火は稀だが、SwiftUI で複数 `.alert` modifier を並べた際の同時表示挙動は非決定的。問題が出たら sealed `AlertKind` + `.alert(item:)` の単一 modifier に集約する

---

### 2026-06-15: Phase 4 スライス 4 の事前設計（Photo Media API による写真都度取得）

- 領域: KMP / iOS / Places
- 関連: `shared/data-places/.../PlacesClient.kt`, `shared/domain/.../repository/CafeRepository.kt`, `iosApp/iosApp/Utilities/PlacePhotoLoader.swift`（新規予定）, `iosApp/iosApp/Features/CafeSearch/CafeSearchView.swift`

カフェ検索結果セルに Places 側の店舗写真（1 枚目）をサムネ表示する。Cafe.photoReferences（= `places/{placeId}/photos/{photoRef}` 形式の name 文字列）を Photo Media API に投げて表示用 URL を得る。

**Photo Media API の呼び方**: `skipHttpRedirect=true` 採用

- 採用: `GET https://places.googleapis.com/v1/{photoName}/media?skipHttpRedirect=true&maxWidthPx={W}` + ヘッダ `X-Goog-Api-Key`、レスポンスは JSON `{"name": "...", "photoUri": "https://lh3.googleusercontent.com/..."}`。`photoUri` を AsyncImage に渡す
- 不採用: `?key=API_KEY&maxWidthPx={W}` で 302 リダイレクトを AsyncImage に直接フォローさせる方式
  - API キーが画像 URL に埋め込まれ、システムログ / プロキシ / スクリーンキャプチャ等から露出する経路が増える
  - 既存 PlacesClient 全メソッドが `X-Goog-Api-Key` ヘッダ統一のため、URL 埋め込みだけ別系統になるのも一貫性が悪い
  - `photoUri` は時限付き署名 URL（Google Photos CDN）で漏洩耐性が相対的に高い

**SKIE オーバーロード方針**: スライス 7 と同じパターン

- KMP `PlacesClient.photoMediaUrl(photoName, maxWidthPx, maxHeightPx)` を 1 つだけ定義（全引数必須、`maxWidthPx` / `maxHeightPx` は `Int?` で nullable）
- `Int?` は SKIE 経由で Swift `KotlinInt?` になる。デフォルト引数は Swift に出ないため、Swift 側からは常に 3 引数で呼ぶ
- iOS の典型用途は「リストセル用に幅 200px」「カフェ詳細用に大きめ」程度。`maxWidthPx` だけ指定 + `maxHeightPx = nil` で十分

**キャッシュ方針**: 永続キャッシュなし

- Places 利用規約上、Photo Media の永続キャッシュは禁止（時限署名 URL の expiry 前提）
- `URLSession`（AsyncImage 内部）の標準 HTTP キャッシュ（メモリ + ディスク短期）のみ許容。明示的なディスクキャッシュやアプリ側保存はしない
- `photoUri` JSON レスポンス自体も保持しない（毎表示時に Photo Media API を再叩き）

**iOS 構造**: 薄いローダー + AsyncImage ラッパ Component

- `PlacePhotoLoader`: `@MainActor` `final class`。`CafeRepository` を init で受け、`func fetchUrl(photoName: String, maxWidthPx: Int) async throws -> URL` を提供。状態は持たない（URL を返すだけのファクトリ）
- `PlacePhotoThumbnail` SwiftUI View: `photoName` + `maxWidthPx` + `loader` を受け、`.task` で URL を取得 → AsyncImage で表示。empty / failure phase 両方とも SF Symbols `photo` プレースホルダ
- `AppState` に `placePhotoLoader: PlacePhotoLoader` を `init` で組み立て（uid 不要なので bootstrap 前から利用可能）。`CafeSearchView` には `appState` 経由で渡す

**CafeSearchView 結果セル統合**:

- `CafeRow` を `name` + `address` + 左側に 56pt 正方形サムネに変更（横並び HStack）
- `cafe.photoReferences.first` がある場合のみ `PlacePhotoThumbnail` を出す。空の場合は同サイズの placeholder（角丸 + secondary 背景）
- 既存 Preview は loader を nil 渡しできるよう設計（Preview ではプレースホルダ固定）

**スライス 5 への影響**: 当スライスで追加する API は全て `shared/data-places` + `shared/domain` 配下のみ。`shared/feature/cafe-search` への移送（スライス 5）には影響しない。

**スコープ外（フォローアップ候補）**:

- `CafeDetailView` への写真 carousel 表示
- 同 Place の複数枚（`photoReferences[1..]`）表示
- 取得失敗時の再試行 UI（現状は SF Symbols プレースホルダで終端）

**実装補足（スライス 4 完了時点）**:

- KMP 側: `PLACES_MEDIA_BASE_URL = "https://places.googleapis.com/v1"` を別定数化（既存 `PLACES_BASE_URL = "https://places.googleapis.com/v1/places"` と組み合わせると `photoName` 先頭の `places/` と重複するため）。`photoName` は URL encode せず Ktor `get("...$photoName/media")` で直接埋め込み
- KMP 側: `commonTest` 用に `ktor-client-mock` を `libs.versions.toml` + `shared/data-places/build.gradle.kts` に追加。MockEngine で URL path / `X-Goog-Api-Key` ヘッダ / null パラメータ省略を検証
- iOS 側: `PlacePhotoLoader` は `any CafeRepository` を保持（SKIE 生成の Swift protocol を existential type で受ける）。状態を持たないため `@Observable` は不要、`@MainActor` のみ
- iOS 側: `AppState.init` で `container` をローカル変数に格納してから `self.container` / `self.placePhotoLoader` の順に代入する必要があった。`@Observable` マクロが「全 stored property 初期化前の self アクセス禁止」制約を持つため。同パターンが今後も出る可能性あり
- iOS 側: SKIE が Kotlin `Int?` を `KotlinInt?` として公開（`.swiftinterface` 確認済）。Swift から `KotlinInt(int: Int32(maxWidthPx))` でラップして渡す
- iOS 側: `AsyncImagePhase` は enum でなく struct のため網羅チェックが効かない。`@unknown default` の明示が必要（`default` 禁止規約の例外として許容）

---

### 2026-06-15: `kmp.feature` Convention Plugin と feature module の依存追加ルール（スライス 5 で確認）

- 領域: Build / KMP
- 関連: `build-logic/convention/src/main/kotlin/kmp.feature.gradle.kts`, `shared/feature/*/build.gradle.kts`

スライス 5 で `cafe-search` / `map` / `cafe-detail` を切り出したときに改めて整理した、`kmp.feature` Convention Plugin の挙動と feature module ごとに必要な手動追加。

**Convention Plugin が自動配線するもの**:
- `api(project(":shared:domain"))`
- `api(project(":shared:core"))`

**Convention Plugin が自動配線しないもの（各 feature で必要に応じて手動追加）**:
- `kotlinx-coroutines-core`（全 feature 必須）
- `kotlinx-datetime`（`Visit.visitedOn: LocalDate` や `VisitedCafe.lastVisitedAt: Instant` を直接参照する feature。`domain` 経由のトランジティブ依存だけでは Kotlin 側でコンパイル通らない）
- `commonTest` 依存（`kotlin.test` / `kotlinx.coroutines.test`）。テストを書く feature module は自前追加

**現在のステータス**:
- `shared/feature/{visit-list,visit-detail}`: coroutines-core のみ
- `shared/feature/{visit-editor,map,cafe-detail}`: coroutines-core + kotlinx-datetime
- `shared/feature/cafe-search`: coroutines-core のみ
- `shared/feature/map`: 唯一の commonTest 持ち（kotlin.test + coroutines.test）

将来 commonTest を持つ feature が増えるようなら、`kmp.feature` Convention Plugin に `commonTest` 依存も組み込む案を検討する（今は 1 件だけなので手動追加で十分）。

---

### 2026-06-16: 設定画面のスコープ確定（サインアウト見送り）+ マップフィルタのタグ UI 化

- 領域: iOS / Docs
- 関連: `iosApp/iosApp/Features/Settings/*`, `iosApp/iosApp/Features/Map/MapTabView.swift`, `iosApp/iosApp/iOSApp.swift`

Phase 5 最初のタスク「設定画面」のスコープと設置場所をユーザー確認のうえ確定した。

**サインアウトを今回のスコープから外す判断**:
- 現状の認証は匿名のみ（`AuthRepositoryIosImpl.observeUserId()` は仕様上サインアウト時の `nil` emit をスコープ外と明記）。匿名アカウントでサインアウトすると、その uid に紐づく Firestore 記録が孤立し実質データ消失する。
- サインアウトが意味を持つのはアカウントアップグレード（匿名 → メール / SNS）実装後。`requirements.md` 8-2 / `tasks.md` Phase 5 でもアップグレードは別タスク。
- よって今回は **テーマ切替（8-1）/ バージョン表示・ライセンス表示（8-3）のみ**実装し、サインアウトはアップグレード実装後のフォローアップに回す。`tasks.md` のタスク名も「設定画面（テーマ切り替え / バージョン表示 / ライセンス表示）」に修正済。

**設置場所と画面構成（ユーザー指定）**:
- 下部 TabBar（マップ / 訪問 / 検索）は現状維持。スライス 6 の TabBar 構成は変えない。
- マップ画面右上に **歯車 → 設定画面（sheet）**。
- マップ画面上部に既存フィルタ（訪問済み / 周辺）を **タグ選択 UI** として配置。`MapTabView.filterToolbar` の Menu トグル（`onShowVisitedToggled` / `onShowNearbyToggled`）を撤去し、マップ上部のタグ（チップ）に再配置する。
- **マップは全画面（`.ignoresSafeArea()`）でステータスバー裏まで表示し、歯車とタグは `ZStack(alignment: .top)` でマップにフローティング重ね**（ナビバーは `.toolbar(.hidden, for: .navigationBar)` で非表示、`NavigationStack` は CafeDetail への push のため維持）。当初 `safeAreaInset` でマップを押し下げる案だったが、ユーザー要望で全画面マップ + オーバーレイに変更。歯車は円形 `.regularMaterial` 背景のフローティングボタン。

**実装上の要点**:
- KMP 変更なし。フィルタ state（`MapViewModel.UIState.showVisited / showNearby`）と Bridge メソッドは既存をそのまま流用。本タスクは iOS 完結（ios-engineer 単独 dispatch）。
- テーマは `enum AppAppearance(system/light/dark)` + `@AppStorage("appAppearance")` を `AppRootView`（`iOSApp.swift`）の `.preferredColorScheme` で適用し、TabView・sheet 含むアプリ全体に効かせる。
- ライセンスは MVP では利用 OSS（Firebase iOS SDK / SQLDelight / Ktor / kotlinx 各種 / SKIE、いずれも Apache-2.0）の静的リスト + ライセンス名表示まで。全文表示は将来タスク。

---

### 2026-06-16: エラートースト共通コンポーネント（errorToast）と非致命エラーの移行

- 領域: iOS
- 関連: `iosApp/iosApp/Components/ErrorToast.swift`（新規）, 各 feature View, `iosApp/iosApp/AppState.swift`, `iosApp/iosApp/iOSApp.swift`

`ui-ux-guidelines.md` のエラー表示方針（非致命=バナー/トースト、致命=alert）に対し従来は全エラーが `.alert` に倒れていた。Phase 5 で共通トースト `View.errorToast(message:onDismiss:)` を新設し、非致命エラーを移行した。

**使い分けの基準**:
- 非致命（同期失敗 / 検索失敗 / 位置取得失敗 / Map POI lookup 失敗 / 起動同期失敗 `lastError`）→ `errorToast`
- 致命（VisitEditor の保存失敗 / 写真保存失敗）→ `.alert` 据え置き
- アクション可能（CafeSearch の位置情報許可拒否 → 設定アプリ誘導）→ `.alert` 据え置き

**複数エラー源の集約パターン（重要）**:
- `.errorToast` は `.overlay(alignment: .top)` で表示するため、1 View に 2 つ付けると上部で衝突する。複数エラー源がある画面は `activeToast`（優先順位付き単一値）に集約してから 1 つだけ付ける。優先度は ViewModel 由来（`bridge.error`）を上位、補助エラー（`poiLookupError` / `locationManager.error`）を下位とする。
- スライス 7-B 当時 `MapTabView` に 2 つの `.alert` を並べていた懸念（「同時発火時の挙動が非決定的」）は、本対応で `activeToast` 集約に統一して解消した。
- View body レベルで全エラー源を保持できる画面（CafeSearch）は計算プロパティ、クロージャ内でしか bridge を参照できない画面（Map の `mapContent(bridge:)`）は `bridge` 引数を取るメソッドで集約する（非対称はやむを得ない）。

**実装上の要点**:
- 自動消去は `.task(id: message)` で実装（message 変化時に前タスク自動キャンセル → タイマーリセット）。4 秒後にキャンセルされていなければ `onDismiss()`。
- VoiceOver は自動消去で読み逃すため `.onChange(of: message)` で `AccessibilityNotification.Announcement` を投稿。`accessibilityReduceMotion` true 時は opacity のみの遷移。
- `AppState.lastError` は従来セットされるだけで未表示（実質バグ）だったため、`clearLastError()` を追加し `AppRootView` に root レベルの `errorToast` を付与して露出させた。
- KMP 変更なし。各 Bridge の既存 `error` / `onErrorDismissed()` をそのまま流用。

### 2026-06-16: App Icon / Launch Screen / 表示名（Phase 5 仕上げ）

- 領域: iOS
- 関連: `iosApp/scripts/generate_app_icon.swift`（新規）, `iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/`, `LaunchBackground.colorset`, `LaunchLogo.imageset`, `iosApp/iosApp/Info.plist`, `iosApp/iosApp.xcodeproj/project.pbxproj`

表示名 = `CoffeeVision`（`CFBundleDisplayName`、bundle ID / `PRODUCT_NAME=coffeevision` は不変）。アイコン・起動画面の画像は **AppKit + SF Symbol をレンダリングする Swift スクリプトで生成**する方針を採用。デザイン変更時は `swift iosApp/scripts/generate_app_icon.swift`（リポジトリルートから実行）で再生成して PNG を上書きコミットする。

**アイコン**: `cup.and.saucer.fill` をコーヒーブラウン縦グラデーション背景の中央に配置。light（ミルクブラウン→エスプレッソ）/ dark（ほぼ黒のダークブラウン）/ tinted（グレースケール地、システムが tint を sourceAtop 合成する前提）の 3 variant を 1024×1024 で出力。`Contents.json` の 3 枠に `filename` で紐付け。マップの訪問済みピン（ブラウン `cup.and.saucer.fill`）とモチーフを揃えた。

**Launch Screen**: storyboard を使わず Info.plist の `UILaunchScreen` 辞書方式（`UIColorName=LaunchBackground` + `UIImageName=LaunchLogo`）を採用。`INFOPLIST_KEY_UILaunchScreen_Generation = YES`（Base.xcconfig 系 2 config）は手動辞書との競合回避のため削除。`UILaunchScreen` 辞書はテキストラベルを置けないため、「CoffeeVision」ワードマークはカップ + 文字を焼き込んだ透過 PNG（`LaunchLogo`）として用意し、ダークモードは `LaunchBackground.colorset`（Any `#5A3A22` / Dark `#1C0F08`）で吸収する。

**残課題**: tinted variant と起動画面の見た目はシミュレータ目視確認がユーザー作業。`LaunchLogo` は現状クリーム 1 枚で `LaunchBackground` のコントラストに依存（dark appearance スロットは未作成、必要ならスクリプトに関数追加で対応可）。`xcodebuild -sdk iphonesimulator` BUILD SUCCEEDED（新規 warning ゼロ）。KMP 変更なし。

### 2026-06-17: アカウント機能（アップグレード / サインアウト / 削除）— 設計判断（Phase 5 仕上げ）

- 領域: KMP + iOS（Dispatch A=KMP 完了、Dispatch B=iOS 予定）
- 関連: `shared/domain/.../model/AuthAccount.kt`, `repository/AuthRepository.kt`, `usecase/DeleteAccountUseCase.kt`, `shared/feature/account/`（新規モジュール）, `shared/framework/.../AppContainerViewModelFactory.kt`, `shared/data-firebase/androidMain/.../AuthRepositoryAndroidImpl.kt`

**プロバイダは Sign in with Apple のみ**（Google は見送り）。`requirements.md` は「メール / SNS（Apple / Google）」と書くが、GoogleSignIn SDK 追加を避け、Apple は審査上必須・追加依存ゼロ（`AuthenticationServices`）のため MVP は Apple 一本。資格情報取得（nonce/SHA256 + `ASAuthorizationController`）と Firebase 操作は iOS Swift（`AuthRepositoryIosImpl`）が担い、KMP は `AuthRepository` interface の抽象操作（`linkWithApple(idToken, rawNonce)` 等）と ViewModel/UseCase のみ持つ。

**アップグレード = link で uid 不変**。`currentUser.link(with:)` は uid を保持するため Firestore / ローカル DB / 写真がそのまま引き継がれ、アプリ全体の uid 再配線が不要。匿名のときだけ提示する。

**サインアウト / 削除 = uid が変わる → 再 bootstrap に収束**。両者とも「Firebase サインアウト/削除 → 新規匿名サインインで `AppState` のブリッジを作り直す」共通経路で扱う（iOS 側 `resetAndRebootstrap()`）。サインアウト後の既存ローカルデータは uid フィルタで自然に隠れるため残置可。削除時のみプライバシー目的で実データ消去。

**削除の責務分担**: `DeleteAccountUseCase`（KMP）= 全 Visit 削除（local+remote、既存 `delete` を `observeAll().first()` スナップショットに対し反復）→ `deleteAuthUser()`。**写真ファイル削除は端末ローカルなので iOS 責務**（KMP から触れない）。順序は「データ → Auth ユーザー」を UseCase が強制。bulk 削除 API 追加は YAGNI で見送り（個別 delete 反復）。

**`observeAccount()` を新設**（既存 `observeUserId` は bootstrap 用に残置）。`AuthAccount(uid, isAnonymous, providerLabel, email)` を流す。iOS の `observeUserId` が持つ「サインアウト時 nil 未 emit」制約は新 `observeAccount` 側で解消する。

**Android 実装**: 検証パリティのため `signOut` / `deleteAuthUser` / `observeAccount` は実装、`linkWithApple` は Apple UI が無いため `UnsupportedOperationException` スタブ（呼び出し元なし）。

**iOS 側残作業（Dispatch B）**: `AuthRepositoryIosImpl` に 4 メソッド追加 / `AppleSignInCoordinator`（nonce+ASAuthorization）/ `AccountView` + `AccountViewModelBridge` / `SettingsView` にアカウント節 / `AppState.resetAndRebootstrap()` + 削除後の `PhotoFileStore` 全消去 / entitlements に Sign in with Apple capability。**Firebase Console での Apple プロバイダ有効化と Apple Developer の App ID 設定はユーザー作業**。

#### 2026-06-17: Dispatch B（iOS 実装）完了時の追補

- `SignInWithAppleButton`（SwiftUI 組み込み）は **rawNonce を外部公開しない**ため、Firebase の nonce 検証付き link/signIn には使えない。`ASAuthorizationController` を `async` ラップした `AppleSignInCoordinator`（CryptoKit で nonce 生成 + SHA256）を自作し、カスタム黒ボタン（`applelogo` SF Symbol、HIG 相当）から呼ぶ方式を採用。→ lessons 追記済。
- サインアウト時の `nil` アカウント emit のため、`FlowBridge.swift` に `CallbackFlowOptional<T>`（`emitSome` / `emitNone` の 2 クロージャ）を追加。`observeAccount()` の `SkieSwiftOptionalFlow<AuthAccount>` 実装で使用。
- `resetAndRebootstrap()` は同一 `AppContainer` インスタンスを再利用する（uid は新規匿名になるが container の `scope` は継続）。各 Bridge の cancel/onDisappear は observation task のみキャンセルし、KMP 側 scope には触れない。
- アクション完了検知（`onDeleteAccountTapped` 後の写真消去 → reset の連携）は `isProcessing` の 0.1s ポーリング（最大 30s タイムアウト）で実装。`@Observable` 変化を Task 内で同期検知する確立した公式 API が iOS 26 時点で無いための妥協。
- entitlements: `PBXFileSystemSynchronizedRootGroup` 環境では `iosApp.entitlements` はファイル同期で認識されるが、`CODE_SIGN_ENTITLEMENTS` は pbxproj の各 build configuration（Debug/Release）に明示追記が必要。`SystemCapabilities` セクションは省略可。
- 親側で `xcodebuild -scheme iosApp -sdk iphonesimulator` を再実行し `** BUILD SUCCEEDED **` を確認（新規 warning ゼロ）。エディタ SourceKit が macOS コンテキストで出す「No such module / unavailable in macOS」診断は偽陽性。
- **将来課題（コードにコメント済・MVP 対象外）**: `linkWithApple` の `credentialAlreadyInUse` 時のサインインフォールバック、`deleteAuthUser` の `requiresRecentLogin` 時の再認証フロー。

#### 2026-06-17: Firebase OAuth コールバック URL / Apple トークン失効について

- **コールバック URL は不要**: 今回はネイティブ Sign in with Apple フロー（`ASAuthorizationController` でデバイス上完結 → `OAuthProvider.appleCredential(withIDToken:rawNonce:)` で Firebase に渡す）のため Web リダイレクトが発生しない。`https://<project>.firebaseapp.com/__/auth/handler` の Return URL 登録や Services ID / OAuth コードフロー設定、カスタム URL スキーム（reversed client ID）はいずれも不要。これらが要るのは Web / Android の Apple サインイン（ネイティブ Apple SDK がない）の場合のみ。
- **Firebase Console の Apple プロバイダは有効化済み**（2026-06-17、ユーザー作業完了）。ネイティブ iOS 用途では「有効化」のみで足り、プロバイダ詳細設定（Services ID / 秘密鍵）は未設定。
- **将来課題: Apple トークン失効（revoke）**: App Store ガイドライン 5.1.1(v) は「Sign in with Apple を使い、かつアカウント削除を提供するアプリは、削除時に Apple トークンの失効も行う」ことを求める。現状の `deleteAuthUser`（`currentUser.delete()`）は Firebase ユーザー + Firestore データは消すが Apple 連携の失効までは行っていない。対応するには ①削除時に Sign in with Apple の authorization code を取得 → `Auth.auth().revokeToken(withAuthorizationCode:)` を呼ぶ、②そのために Firebase Console で Apple プロバイダの OAuth 鍵（Services ID / Team ID / Key ID / 秘密鍵）を登録する、が必要。`tasks.md` バックログ E-1 として管理。

### 2026-06-19: マップタブの現在地 FAB（検索タブ上に配置）

- 領域: iOS のみ（`iosApp/iosApp/Utilities/TabBarFrameReader.swift`〔新規〕, `Features/Map/MapTabView.swift`）。KMP / gradle 変更なし。

**検索タブ（`Tab(role: .search)`）のフレーム取得を private API 名非依存の幾何条件で行う**。iOS 26 の新 TabView では検索ボタンは `_UITabBarAuxiliaryView` 系の private ビューになるが、クラス名へのハードコード依存を避け、`TabBarFrameReader`（`UIViewRepresentable`）が `tabBar.subviews` を「ほぼ正方形（`abs(w-h)<4`）かつ タブバー幅の半分未満」で絞り込み、クラス名に `"Auxiliary"`/`"Search"` を含むものを優先する。`didMoveToWindow` / `layoutSubviews` で再報告し回転追従。UITabBarController は responder chain →（不在なら）windowScene の rootViewController 階層再帰で探索。global frame は `convert(bounds, to: nil)`。

**耐性方針**: 条件が外れて検索タブを特定できない場合は `tabBarSearchFrame == .zero` のままで、FAB を `.overlay` ごと非表示にする（クラッシュせず「FAB が出ないだけ」に縮退）。iOS 26 はベータのため、リリース前に実機で配置を実機確認すること。

**FAB は `MapTabView` 内に閉じる**（スコープ＝マップタブのみ）。`cameraPosition` / `LocationManager` が既に MapTabView 保持のため AppState への状態リフト不要。配置は `GeometryReader` の global フレームで global→local 変換し `.position()`（`x=tabFrame.midX-geo.minX`, `y=tabFrame.minY-geo.minY-8-size/2`, `size=clamp(tabFrame.height,44,64)`）。

**recenter は `lastLocation` 非破壊のフラグ方式**。FAB タップで `pendingRecenter=true` を立て `requestLocation()` を呼び、`.onChange(of: lastLocation?.latitude)` で 1 回だけ 1000m リージョンにセンタリングする。`resetLastLocation()`（nil 化）を使わないことで `setupLocation` の `bridge.onLocationUpdated`（周辺カフェ検索）への副作用をゼロにした。許可済みなら既存 `lastLocation` で即時センタリングも併用。`.denied`/`.restricted` は FAB を `.disabled` + opacity 0.4 で無効化（`recenterToCurrentLocation` の同 case は到達不可前提）。`notDetermined` はタップで許可ダイアログ→許可後の location 更新で自動センタリング。

- 既知の軽微な論点（許容）: タップ後 `requestLocation()` が同一緯度を返すと `onChange` 不発で `pendingRecenter` が残り、次の自然な位置更新で 1 回再センタリングが起きうる。実害なしと判断。
- 検証: `xcodebuild -sdk iphonesimulator -scheme iosApp build` → BUILD SUCCEEDED（新規 warning ゼロ）。シミュレータ / 実機の目視確認（配置・センタリング・拒否時無効・回転追従・初回許可フロー）はユーザー作業。

### 2026-06-19: コーヒー記録主体への再設計（Visit → CoffeeRecord、Phase 7）

- 領域: 全レイヤー（domain / core / data-local / data-firebase / feature × 6 / framework / iosApp / settings.gradle）。事前確定仕様は [`data-model.md`](./data-model.md) 2026-06-19 全面改訂版。`tasks.md` フェーズ 7。

**集約ルートを `Visit`（カフェ訪問）から `CoffeeRecord`（コーヒー 1 杯）へ転換する**。ユーザー意図は「カフェ主体ではなくコーヒー主体。カフェまたはセルフ抽出に紐づく」。`CoffeeItem` / `FoodItem` を廃止し、旧 `CoffeeItem` の属性（name / brewMethod / origin / variety / processing / roastLevel / cup）を `CoffeeRecord` に昇格。旧 `Visit` の属性のうち visitedOn / rating / notes / photos を `CoffeeRecord` に移管。

**確定した設計判断（ユーザー承認済み、AskUserQuestion 2026-06-19）**:
- Visit を廃止し Coffee を独立エンティティ化（中間グルーピングを残さない最もシンプルな形）
- 旧 Visit 属性はコーヒー単位へ移管、カフェ訪問概念は廃止。`ambiance` と `FoodItem` は構造化フィールドとしては廃止し自由メモ `notes` に吸収（フードを別管理したい要件が再燃したら別途検討）
- カフェは nullable（`cafe: Cafe?`）。null = セルフ抽出。「ソース種別（自宅/職場等）」フィールドは持たず最小構成（将来の絞り込み要件が出たら追加）
- クリーンブレイク（データ移行コードを書かない）。未リリースのため実ユーザーデータなし前提。SQLDelight はマイグレーション不要、テスト端末はアプリ削除→再インストール

**トレードオフ / 影響**:
- **`VisitedCafe` は名前を維持**し集計元だけ `CoffeeRecord`（cafe != null）に変更。`map` / `cafe-detail` の iOS 参照が広く、ドメイン意味変更（「訪問」→「記録のあるカフェ」）のみに留めるため。改名（`RecordedCafe` 等）は将来の任意タスク
- **Firestore は `coffees` コレクション + photos 埋め込み配列**（旧: `visits` + 子サブコレクション 3 種）。1 杯あたり photos は数枚でメタデータのみのため 1MB 上限に余裕。これにより observe の子 N+1 取得と WriteBatch 差分 delete が不要になり、Android（`RemoteCoffeeDataSourceAndroidImpl`）/ iOS（`RemoteCoffeeDataSourceIosImpl.swift`）が大幅簡素化。将来 1 記録に大量写真を許す要件が出たらサブコレクションに戻す
- **feature モジュールをリネーム**（`visit-list/detail/editor` → `coffee-*`）。クリーンブレイクで未リリースのため名残を残さない方が保守上良い。中身は全面改訂が必須なのでリネームの追加コストは小（ディレクトリ移動 + settings/framework の文字列置換）。`shared/framework/build.gradle.kts` の `export(...)` と `api(...)` の **両方** を typesafe accessor（`projects.shared.feature.coffeeList` 等）で更新する必要あり（片方だと型が Swift に出ない）
- **`observeByCafe` / 集計の null cafe 扱い**: `selectByCafe` は SQL 等値マッチで null を自然除外（意図通り＝セルフ抽出はカフェ詳細・マップに出ない）。`ObserveVisitedCafesUseCase` は明示的に `cafe != null` フィルタを入れる（NPE 回避）。`CafeDetailViewModel` は `it.cafe?.placeId == placeId`

**dispatch 順序**: 3 ロール体制。commonMain の公開 API（`CoffeeRecord` / `CoffeeRepository` / ViewModel / ファクトリ名）を Phase 1 で凍結し `:shared:framework:assembleSharedLogicXCFramework` 成功（= SKIE ヘッダ生成）を iOS 着手の前提にする。Phase 2（data-firebase Android）と Phase 3（iOS）は Phase 1 完了後に並行可能。

**SKIE 生成名の注意**: 旧 `Visit` は SQLDelight が同名行型を生成する衝突回避で Swift 側 `Visit_` だった（サマリ参照）。`CoffeeRecord` は SQLDelight 行型名（`Coffee_record` 等）と異なるため `_` は付かない見込みだが、Phase 1 後に生成ヘッダで実際の Swift 型名を確認してから iOS 実装を書く。

### 2026-06-19: コーヒー評価を 0.5 刻み Double に（ハーフスター）

- 領域: 全レイヤー（domain / data-local / data-firebase / feature / iosApp）。`docs/data-model.md` の rating 記述を更新済み。

`CoffeeRecord.rating` を `Int`(1..5) → **`Double`(0.5..5.0、0.0=未評価)** に変更し、星入力を 0.5 刻みにした。

- **表現**: 0.5 の倍数は IEEE 754 double で厳密表現できるため、DB(REAL)/Firestore(number) 往復・等値判定とも安全。`VisitedCafe.averageRating` は元から Double で不変
- **バリデーション**（`CoffeeEditorViewModel`）: `rating < 0.5 || rating > 5.0 || (rating * 2) % 1.0 != 0.0` で 0.5 刻みを強制（`*2` してから整数判定）
- **Firestore 後方互換**: rating を Double で書くが、旧 Int 保存ドキュメントは SDK から Long/NSNumber で届くため、Android は `(Number).toDouble()`、iOS は `(Double) ?? (NSNumber).doubleValue ?? 0.0` で受ける。マイグレーション不要
- **iOS ハーフスター入力**: `StarRatingView` を Double 化。表示は `star.fill` / `star.leadinghalf.filled` / `star` を rating 比較で出し分け。入力は星を左右 2 分割した透明タップ領域（`StarTapCell`、`GeometryReader` + `Color.clear.onTapGesture`）で左=‐0.5/右=フルを判定。`accessibilityAdjustableAction` は 0.5 刻み、値は「3.5星」表記。`SpatialTapGesture`(iOS17+)/`DragGesture` は連続入力や最小バージョンの懸念で不採用

### 2026-06-19: 分析機能の 3 階層分離と Foundation Models の使いどころ

- 領域: Shared / KMP / iOS / Docs
- 関連: `docs/requirements.md` §9, `docs/data-model.md` §1.6, `docs/tasks.md` フェーズ 8

「これまで登録したコーヒー情報を分析する分析タブを追加。分析には iOS の Foundation Models を使う」という要望を、**3 階層に分離**して設計した。

**確定した設計判断（ユーザー承認済み、AskUserQuestion 2026-06-19）**:
- 主目的 = **統計（階層1）＋ AI 要約（階層3）の両方**
- Foundation Models の役割 = **傾向の要約サマリ** ＋ **対話 Q&A**
- Android（KMP 検証ターゲット）= **分析タブ非表示**（Foundation Models が iOS 専用のため）

**核となる設計原則 — 集計は KMP、解釈は LLM**:
- 階層1（記述統計）/ 階層2（傾向抽出 = 高評価群の共通属性）は **KMP 共通層で決定論的に算出**（`CoffeeStats` / `BuildCoffeeStatsUseCase`）。テスト可能で正確。
- 階層3（自然言語の要約・Q&A）だけ iOS の Foundation Models。**入力は集約済み `CoffeeStats` のみ**で、生レコードは LLM に渡さない。
- 理由: ①正確性（「平均 4.2」を LLM に計算させない）②オンデバイス LLM（約 3B）のコンテキスト窓が狭く全レコードは入らないが集約サマリなら収まる ③再現性・ユニットテスト容易性 ④3 ロール体制に綺麗に割れる（集計 = kmp-engineer、Foundation Models ブリッジ = ios-engineer）。

**プラットフォーム非対称の吸収**:
- `shared/domain` に `CoffeeInsightProvider` インターフェース（`summarize(stats): CoffeeInsight`）を置き、iOS = `LanguageModelSession` 実装、Android = 注入しない（null）。Firebase の `RemoteCoffeeDataSource` と同じ「インターフェースは domain、実装はプラットフォーム別、AppContainer 注入」パターン。
- `AnalysisViewModel` は `CoffeeInsightProvider?` を受け、null なら階層3 を非対応状態にする。Apple Intelligence 無効 / 非対応端末も `SystemLanguageModel.availability` 判定で同じフォールバック（統計のみ表示）。

**対話 Q&A の段階化**:
- v1（Phase B-2）は **ツール無し**で実装する。`CoffeeStats` に `recentHighlights` / `topCafes` を含めて十分リッチにすれば「一番高評価だった店は？」程度はセッションへの文脈注入だけで答えられる。
- v2（Phase B-3）で tool calling（Swift のツールが KMP のクエリ API を呼ぶ）に拡張。初手で KMP 側にクエリ境界を新設するのは過剰。

**フェーズ分割**: A-1 集計（domain + UseCase + test）→ A-2 `feature/analysis` + ViewModel → A-3 分析タブ UI（Swift Charts）→ A-4 Foundation Models 要約。階層2（`favoriteSignals`）と Q&A は Phase B。A-4 は Foundation Models の round-trip を小さな PoC で確認してから本実装に組み込む（KMP / 新規 API ブリッジの鉄則）。「好みのカフェをマップで探す」は要件外（将来）。

### 2026-06-19: Phase A-2 — AnalysisViewModel の insightStatus 設計と AppContainer コンストラクタ拡張

- 領域: KMP / Shared / iOS Bridge
- 関連: `shared/feature/analysis/.../AnalysisViewModel.kt`, `shared/core/.../AppContainer.kt`, `shared/framework/.../AppContainerViewModelFactory.kt`

- **統計と要約を独立ロード状態に**: `AnalysisUiState(stats, isLoading, insight, insightStatus, error)`。統計（階層1）は `ObserveCoffeeStatsUseCase` の Flow で即時反映、要約（階層3）は後追いで `insightProvider?.summarize(stats)` を呼んで埋める。要約が失敗・非対応でも統計画面は完全機能する。
- **`InsightStatus` は `sealed interface` + `data object`**（`Unsupported` / `Idle` / `Loading` / `Loaded` / `Failed`）。SKIE SealedInterop で Swift には `AnalysisViewModelInsightStatus` protocol + 5 実装として届き、`is` チェックで分岐。将来 `Failed(message)` 等の関連値を付ける拡張に強い。`insightProvider == null`（Android / Apple Intelligence 非対応）は初期値 `Unsupported`。
- **`AppContainer` のコンストラクタが 3 系統**: プライマリ（6 引数 = テスト用 scope 注入）/ セカンダリ A（5 引数 = iOS で `CoffeeInsightProvider` 注入、MainScope 内部生成）/ セカンダリ B（4 引数 = Android 互換、`coffeeInsightProvider` null 固定、MainScope 内部生成）。SKIE がデフォルト引数を Swift に出さない制約への対処（既存の scope 隠蔽パターンの踏襲）。**Android の `CoffeeVisionApp.kt` と現状の iOS `AppState.swift` は 4 引数のままで無変更**。iOS は A-4 で `CoffeeInsightProvider` 実装を注入する際に 5 引数へ切り替える。
- **`AnalysisViewModel.onAppear()` は引数なし**（`userId` はコンストラクタ確定）。`makeAnalysisViewModel(userId)` で生成し、TabBar 常時生存パターン（`mapBridge` と同じく `AppState` 1 つ保持）を想定。
- **要約再生成トリガ**: 現状「統計更新のたびに再生成」。リアルタイム同期で連続 emit する場合は LLM 呼び出しコストが上がるため、A-4 でデバウンス / 手動トリガ化を検討する余地あり（要 follow-up）。

### 2026-06-19: Phase A-3 — 分析タブ iOS UI（Swift Charts）

- 領域: iOS
- 関連: `iosApp/iosApp/Features/Analysis/{AnalysisView,AnalysisViewModelBridge}.swift`, `RootTabView.swift`, `AppState.swift`, `PreviewSupport/PreviewSamples.swift`

- **タブ順**: マップ / コーヒー / **分析** / 検索。`Tab(role: .search)` の右端固定を維持し、分析はコーヒーの次。SF Symbol `chart.bar.xaxis`。
- **グラフ種別**: 縦棒（評価ヒストグラム / 焙煎度 / 抽出方法）/ 横棒（産地 = 日本語名が長く横軸向き）/ 折れ線（月次推移）/ カスタムリスト（よく行く店 = ランキング形式）。レイアウトは `ScrollView` + `LazyVStack` のカード方式（グラフが多く Form より適）。
- **空状態**: `stats == nil`（ロード前）OR `totalCount == 0`（記録ゼロ）を空状態、`isLoading` は `ProgressView` で分離。`ContentUnavailableView` でコーヒータブ誘導。
- **Bridge**: `insightStatus` を `any AnalysisViewModelInsightStatus`（existential）で保持。A-3 では常に `Unsupported`（provider 未注入）で UI 非描画だが、A-4 の `is` チェック分岐に備えて型を維持。`AppContainer` は **4 引数のまま無変更**（A-4 で 5 引数化）。`analysisBridge` は `AppState` 1 つ保持（`mapBridge` と同パターン）。
- **enum 日本語化**: `RoastLevel` / `BrewMethod` の `enum.name`（英語）→ 日本語変換ヘルパを `AnalysisView` に内包。既存の他画面（CoffeeDetail 等）の enum 表示は英語のままで、日本語化は元々別タスク扱い。**分析タブが先行して独自ヘルパを持つ形になったため、将来 enum 表示の日本語化を全画面で行う際に共通化する候補**（follow-up）。
- **SKIE 型の注意**: `CoffeeStats` を `Identifiable` 適合させる際 `id: Int32 { totalCount }`（KMP の `Int` は Swift で `Int32`）。

### 2026-06-19: Phase A-4 — Foundation Models による傾向要約（階層3）

- 領域: iOS / KMP Bridge
- 関連: `iosApp/iosApp/Features/Analysis/CoffeeInsightProviderIosImpl.swift`, `AnalysisView.swift`, `AppState.swift`

- **`CoffeeInsightProviderIosImpl`**: Kotlin `CoffeeInsightProvider`（凍結 IF）の SKIE protocol witness 実装。`__summarize(stats:completionHandler:)` の completion handler 形式（`RemoteCoffeeDataSourceIosImpl.__upload`/`.__remove` と同パターン）。内部で `Task { LanguageModelSession.respond(to:generating:) }` → completion 変換。
- **`@Generable` 構造化出力**: `CoffeeInsightOutput(headline, body)` を `@Guide` で長さ・用途制約付き宣言。**SwiftUI `View.body` との名前競合を避けるため private struct に閉じる**（外部公開が要るならフィールド名を `insightBody` 等にリネーム）。
- **prompt 整形**: `buildPrompt(from: CoffeeStats)` で KMP が**集計済みの事実**（総杯数・平均評価・産地トップ・焙煎度/抽出方法・よく行く店・recentHighlights）を日本語テキスト化して渡す。**数値計算は LLM にさせない**（階層分離の原則）。`LanguageModelSession` はリクエストごとに生成（ステートレス。会話 follow-up は Q&A の Phase B-2 で扱う）。
- **可否判定（契約 = 注入時）**: `CoffeeInsightProviderIosImpl.makeIfAvailable()` が `SystemLanguageModel.default.availability == .available` のときだけ実装を返し、不可なら nil。`AppState` で 5 引数 `AppContainer` コンストラクタの `coffeeInsightProvider:` に渡す。nil → `AnalysisViewModel` が `InsightStatus.Unsupported` → 要約カード非表示（統計のみ）。KMP 変更ゼロで graceful degradation。
- **要約カード UI**: `insightCardSection` が `insightStatus` を `is` 分岐。`Unsupported`=`EmptyView()`（タブ高を変えない）/ `Loading` / `Loaded`（headline+body）/ `Failed`（`onRetryInsight()` でリトライ）。
- **follow-up（未対応・実害小）**: ① availability 判定は `AppState.init()` の起動時 1 回のみ。起動後に Apple Intelligence を有効化しても次回起動まで反映されない（動的再チェックは `scenePhase` active で再評価する案、現フェーズ不要）。② 要約再生成が「統計更新のたび」のため、リアルタイム同期の連続 emit で LLM 呼び出しが増える懸念（デバウンス / 手動トリガ化は実機計測後に判断）。③ `unavailable(reason)` の理由別ユーザー案内 UI は未実装（仕様未定）。

### 2026-06-19: ダミーデータ Scheme（開発支援）

- 領域: KMP / iOS / Build
- 関連: `shared/core/.../dev/DummyCoffeeData.kt`, `shared/core/.../AppContainer.kt`, `iosApp/iosApp.xcodeproj/xcshareddata/xcschemes/iosApp (Dummy Data).xcscheme`, `iosApp/iosApp/AppState.swift`

分析タブ等の確認用に、専用 Xcode Scheme で起動したときだけ約 30 件のダミー `CoffeeRecord` が入る仕組み。

- **投入先はローカル DB のみ**: `AppContainer.seedDummyData(userId)` / `clearDummyData(userId)` は private `localCoffeeRepository` 経由で `save` / `delete`。合成 `coffeeRepository`（Firestore 込み）は使わず、**dev データを Firestore に流さない**。`startSync` は remote→local の upsert のみで local を消さないため、ローカルのダミーは sync で消えない。
- **固定 ID で冪等**: `DummyCoffeeData`（`com.noricoffee.dev`）が `dummy-0001`..`dummy-0030` を生成。再 seed は upsert で常に 30 件（増えない）。`clear` は同 ID をローカル削除（実データ = UUID には触れない）。
- **`visitedOn` は動的算出**: `Clock.System.todayIn(...)` から逆算（`object` で呼び出しのたびに今日基準）。固定日付より「常に直近 12 ヶ月」が保証され、月次推移グラフが映える。cafe 有り 20 件（5 カフェ使い回し → `topCafes` に偏り）/ null 10 件、rating=0.0 を 2 件（未評価除外パス確認）。
- **DEBUG 限定 + 環境変数で分離**: Kotlin に DEBUG フラグはないため `DummyCoffeeData` / メソッドは常にコンパイルされるが、呼び出しは iOS の `AppState.bootstrap()` 内 `#if DEBUG` ガード + `ProcessInfo...environment["SEED_DUMMY_DATA"]` 判定に閉じる。**ダミー Scheme（env=1）→ seed / 通常 Scheme（env なし）→ clear**。Release ビルドは seed/clear とも無効。これで「ダミー Scheme でだけ 30 件、通常 Scheme は綺麗」を実現。
- **共有 Scheme をリポジトリ管理化**: `xcshareddata/xcschemes/` が無かったため新規作成し、`iosApp.xcscheme`（通常）+ `iosApp (Dummy Data).xcscheme`（env `SEED_DUMMY_DATA=1` / Build Config Debug）を**明示ファイルとしてコミット**。pbxproj のターゲット UUID `A5D55589987A954070545386` / product `coffeevision.app` を参照。
- **seed/clear の失敗は `print` のみ**（`lastError` に乗せない）。`clear` は通常起動毎に走るため、ユーザー可視エラーにすると通常起動で赤バナーが出かねないため。
- **注意**: `resetAndRebootstrap()`（サインアウト/削除後）も `bootstrap()` 経由で同ブロックを通る。ダミー Scheme でサインアウトすると新 uid に再 seed される（dev 用途として許容）。

### 2026-06-20: テイスティング 5 要素（Elements of Coffee Tasting）

- 領域: 全レイヤー（domain / data-local / data-firebase / feature / core / iosApp）+ Docs
- 関連: `docs/data-model.md` §1.1a / §1.6, `docs/requirements.md` §3 / §9

Blue Bottle「Elements of Coffee Tasting」由来の **甘味 / ボディ / 酸味 / 風味 / 後味** を `CoffeeRecord.tasting: TastingScores` として追加。

**確定した設計判断（ユーザー承認済み、AskUserQuestion 2026-06-20）**:
- **スケール = 1〜10 の強度**（カッピング寄り。UI はスライダー）。総合評価 `rating`（0.5 刻みハーフスター）とは**別軸**。「良し悪し」ではなく強度（酸味 10 = 酸が強い）。
- **任意入力**: 各要素 `Int?`、未入力 = `null`。`tasting` フィールド自体は非 null（全要素 null の `TastingScores()` が「未入力」）。rating の `0.0` sentinel 方式ではなく **nullable Int** を採用（新規フィールドは null の方が明快、星 UI も流用しないため）。
- **分析タブに即反映**: `CoffeeStats.tastingAverages`（各要素 null 除外平均 + `ratedCount`）を追加。AnalysisView に平均の可視化、`CoffeeInsightProviderIosImpl` の prompt にも平均を含める。

**表現**:
- ドメイン: `TastingScores`（5 × `Int?`）を `CoffeeRecord` に埋め込み（nested value object。5 要素が 1 つの概念のため flat 展開より凝集度を優先）。
- SQLDelight: `coffee_record` に 5 列（`sweetness`/`body`/`acidity`/`flavor`/`aftertaste` INTEGER nullable）。Mapper で `TastingScores` に組み立て。
- Firestore: nested map `tasting`。**非 null の要素だけ書き出し / 全 null は `tasting` ごと省略**（nullable コーヒー属性と同じ「キー省略」流儀）。decode で欠如キーは null、空マップ/欠如は `TastingScores()`。

**クリーンブレイク**: 未リリースのため DB 列追加にマイグレーションを書かない（テスト端末はアプリ削除→再インストール）。Firestore は旧ドキュメントに `tasting` が無くても decode が `TastingScores()` で吸収するため後方互換あり。**TestFlight 配布が始まったら SQLDelight マイグレーションが必須**になる（既存ローカル DB にスキーマ不一致でクラッシュするため）。これは tasting 追加に限らず以降の DB 列変更すべてに効く転換点（要 follow-up）。

**スケール型 `Int?`（`Double?` 不採用）**: `rating` は 0.5 刻みで `Double` 化した経緯があるが、テイスティングは整数 1..10 スライダー前提のため中間値の必要がなく `Int?`。バリデーションは `coerceIn(1,10)` クランプ（エラー返却なし）。`CoffeeEditorViewModel` は個別セッター 5 本 + バルク `onTastingChanged(TastingScores)` の両方を公開（iOS の実装自由度のため）。

### 2026-06-20: テイスティングを all-or-nothing 化（5 要素必須）

- 領域: 全レイヤー + Docs
- 関連: `docs/data-model.md` §1.1a / §1.1 / §1.6

[2026-06-20: テイスティング 5 要素] の **各要素独立 nullable** 方式を、**all-or-nothing（テイスティングを付けるなら 5 要素必須）** に変更。ユーザー要望「テイスティングが存在する場合は 5 項目全て必須、`+` ボタンで各種スライダーが一度に表示」。

**型でモデル化（partial を表現不可能に）**:
- `TastingScores` の 5 フィールドを `Int?` → **`Int`（非 null）** に変更。`CoffeeRecord.tasting` を `TastingScores` → **`TastingScores?`（nullable）** に変更。「null = 未記入 / 非 null = 5 要素全部ある」を型が保証。バリデーションのエラー経路が不要になる（部分状態を作れない）。
- SQLDelight の 5 列は nullable のまま（all-null = なし / all-set = あり）。Mapper は **5 列全セットなら `TastingScores`、それ以外 `null`**。
- Firestore は `tasting != null` のとき 5 要素のマップ、null なら省略。decode はキー欠如を防御的に `null` 扱い。
- `CoffeeStats.TastingAverages.ratedCount` を `TastingRatedCount`（要素別）→ **単一 `Int`** に簡素化（all-or-nothing で 5 要素の母数が必ず一致するため）。`TastingRatedCount` 型は削除。

**UX**: `tasting == null` のとき「`+` テイスティングを追加」ボタンのみ。押下で `TastingScores(5,5,5,5,5)`（デフォルト 5）を生成して 5 スライダーを一度に表示。削除ボタンで `null` に戻す。**個別セッターは非 null Int**（`tasting == null` の間は no-op）、追加/削除用に `onTastingAdded()` / `onTastingCleared()` 相当を用意。

**経緯**: 前エントリの独立 nullable は「書きたい要素だけ」を想定したが、テイスティングは 5 軸セットで初めて意味を成す（プロファイルとして比較・平均する）ため、all-or-nothing が要件・分析の両面で正しい。dev データのみ（クリーンブレイク）なので即作り直し。

**dispatch 順序**: KMP（domain→data-local→core(stats/dummy)→feature/coffee-editor→data-firebase）で公開 API を凍結し XCFramework 成功を iOS 着手の前提にする（CoffeeRecord 再設計と同じ流れ）。`CoffeeRecord` のコンストラクタに引数が 1 つ増えるため、`DummyCoffeeData` / 既存テスト / iOS の `CoffeeRecord` 生成箇所すべてが追随対象。

### 2026-06-21: 対話 Q&A v1（単発・digest 文脈注入）の設計確定

- 領域: Shared（contract）→ KMP → iOS
- 関連: `docs/data-model.md` §1.6 / `shared/domain` `CoffeeInsightProvider` / `shared/feature/analysis` `AnalysisViewModel`

分析タブに自然言語 Q&A（「好きな産地は？」等）を追加する。Phase A-4 の傾向要約（`CoffeeInsightProvider.summarize`）の仕組みをそのまま拡張する形に決定。

**インターフェース**: `CoffeeInsightProvider` に `@Throws suspend fun answer(question: String, stats: CoffeeStats): String` を 1 本追加するだけ。`summarize` と同列。iOS は `__answer(question:stats:completionHandler:)` の protocol witness で実装、Android は注入しない（分析タブ非表示）。可否ゲートは要約と共有（`provider != null` なら Q&A も可）。

**v1 のスコープ（あえて削ったもの）**:
- **単発・ステートレス**: 1 問 1 答。`LanguageModelSession` は質問ごとに新規生成、会話履歴を持たない。UI も入力欄 + 直近回答カード 1 枚のみ。チャットスレッド型は不採用（履歴状態 + session ライフサイクル管理が重い）。
- **digest のみ接地**: 生レコード・tool 無し。要約と同じく `CoffeeStats` が唯一の入力（計算は KMP 済み、LLM は解釈と整形のみ）。
- **逐次表示なし**: `streamResponse` → `Flow<String>` 化は「Swift 側で Flow を作る」ハードパス（`kmp-bridge.md`）になるため v1 では採らず suspend 一発で最終 `String` を返す。回答待ちは ProgressView。

**ハルシネーション対策**: instructions で「与えられた統計の範囲でのみ答える / digest に無い情報は『記録からは分かりません』/ 再計算しない / 日本語で簡潔に」と縛る。

**AnalysisViewModel の Q&A 状態**: `QaStatus` sealed（Unsupported/Idle/Asking/Answered/Failed）+ `qaQuestion`/`qaAnswer`、`onQuestionAsked(question)` / `onQaCleared()`、候補質問 `SUGGESTED_QUESTIONS`。`insight` と同じ Job 再起動・null=Unsupported パターンに揃える。空質問・`stats==null`・`provider==null` はガードして no-op。`error` は既存フィールドを共用。

**経緯**: ユーザーは UI=単発Q&A型 / データ接地=tool で生レコード参照も、を選択。ただし tool→KMP 照会の bridge（Swift Tool.call から KMP suspend を await）は新規で要 PoC のため、リスク分割して v1（B-2）= digest 接地のみ、tool calling = B-3（9-4b）に分離した。

### 2026-06-21: Phase B-2 対話 Q&A v1 iOS 実装（digest 文脈注入）

- 領域: iOS
- 関連: `iosApp/iosApp/Features/Analysis/`（`CoffeeInsightProviderIosImpl.swift` / `AnalysisViewModelBridge.swift` / `AnalysisView.swift`）

`__answer(question:stats:completionHandler:)` は `__summarize` と同じ protocol witness パターン。`generateAnswer` で `buildPrompt(from:)`（要約と共用の digest 整形）を流用して digest を提示し、末尾に質問を付ける。`LanguageModelSession` はリクエストごとに新規生成（ステートレス）。回答はプレーンテキスト（`session.respond(to:).content`、`@Generable` 不使用）。instructions にグラウンディング 5 か条（統計範囲のみ / 不明は「記録からは分かりません」/ 再計算しない / 日本語 2〜4 文 / 推測しない）。

- `suggestedQuestions` は `Array(AnalysisViewModel.companion.SUGGESTED_QUESTIONS)` で取得（`as? [String]` は "always succeeds" warning が出るため `Array()` を使う）。
- UI は `QaSectionContainer` 内で `qaStatus` の `is` 分岐（`insightCardSection` と同じパターン）。`Unsupported` は `EmptyView()`、`Asking` は ProgressView（逐次表示なし）、`Answered` は質問+回答+クリア、`Failed` は同じ質問で再送。入力欄は `Answered` でも表示し、新規送信で前カードを上書き。
- `error` は insight 系と共用のため、Q&A 失敗と要約再生成失敗が同時発火するとメッセージが上書きされうる（実運用上は稀、`qaStatus`/`insightStatus` でどちらか判別可。許容）。

### 2026-06-21: 対話 Q&A v2（tool calling / 生レコード参照、9-4b）の設計確定

- 領域: Shared / KMP / iOS
- 関連: `shared/domain`（`CoffeeRecordQuery` 新設）/ `shared/core/AppContainer.kt` / `iosApp/.../Features/Analysis/`（`SearchCoffeeRecordsTool.swift` 新設・`CoffeeInsightProviderIosImpl.swift`）/ `AppState.swift`

digest で答えられない個別レコード単位の問いに対応するため、Foundation Models の `Tool` から KMP の生レコード照会を呼ぶ。確定した設計判断:

- **既存インターフェース・VM・UI は不変の加算的変更**: `CoffeeInsightProvider.answer(question, stats)` のシグネチャは据え置き、iOS 実装が内部で tool を登録するだけ。`AnalysisViewModel` / Q&A UI / domain interface は触らない。これが最もエレガント（v1 の状態機械をそのまま再利用）。
- **単一の柔軟な検索 tool**: `CoffeeRecordQuery.searchRecords(filter)` 1 本。filter は全 String/Double/Int（enum を持ち込まない）で、LLM 生成文字列を KMP 側で寛容マッチ（enum `.name` 大小無視 + 部分一致、産地/カフェ名 部分一致、rating=0.0 は評価範囲外）。複数専用 tool より Foundation Models が安定し KMP も 1 メソッドで済む。
- **userId は KMP 実装が内部解決**: `CoffeeRecordQueryImpl` が `authRepository.signInAnonymouslyIfNeeded()` → `coffeeRepository.observeAll(uid).first()` → Kotlin で filter/sort/limit → `CoffeeRecordSummary`。Swift tool は userId を意識しない。`shared/domain` 内に置き interface のみ依存（テスト容易）、`AppContainer` が `coffeeRecordQuery` で公開。
- **配線は遅延アタッチ（依存サイクル解消）**: provider は AppState で container より先に生成され container 引数になる一方 `coffeeRecordQuery` は container 内で組む。両者を構築時に結べないため `attachRecordQuery(_:)` で container 構築後に後付け（`searchRecords` は `answer` 時 = 初期化完了後にしか使わないため安全）。詳細は kmp-bridge.md。
- **digest 併用ハイブリッド**: tool は digest で足りないときだけ LLM が呼ぶ。プロンプトには引き続き digest を含める。
- ブリッジ方向は v1 の Q&A と逆で **Swift→Kotlin の calling direction**（SKIE が `searchRecords(filter:) async throws` を生成、protocol witness 不要）。実装前に小 PoC で round-trip 確認（CLAUDE.md ブリッジ規約）。

実装後の追記（2026-06-21 KMP 実装完了時）:

- **`limit` ガード**: `CoffeeRecordFilter.limit` は負数・0 を `DEFAULT_LIMIT=10` に、`MAX_LIMIT=100` 超を 100 に clamp する（LLM が不正値を生成した場合の防御）。定数は `CoffeeRecordFilter.companion` に公開。`CoffeeRecordQueryImpl` は `shared/domain` の `model/` ディレクトリに `CoffeeRecordQuery` interface / 2 DTO と同居（UseCase ではなく "Query" 責務として model/ に共置）。
- **`minRating`/`maxRating` は Swift で `KotlinDouble?` になる**: Kotlin の `Double?` は SKIE 経由でも `KotlinDouble?` として見えるため、iOS の `@Generable Arguments` → `CoffeeRecordFilter` 変換で評価値フィールドは `KotlinDouble(value:)` ラップが必要。`String?`（origin/cafeName 等）は直接渡せる。

実装後の追記（2026-06-21 iOS 実装完了時）:

- **iOS 実装の確定形**: `SearchCoffeeRecordsTool: Tool`（`@Generable Arguments` 全 optional、`Tool.Output == String`（`PromptRepresentable` 準拠））を新設。`CoffeeInsightProviderIosImpl` に `attachRecordQuery(_:)` を追加し、`generateAnswer` を「recordQuery あり → `LanguageModelSession(tools:[...])` / nil → digest-only」のハイブリッドに。`makeIfAvailable()` の戻り値型は `any CoffeeInsightProvider?` → 具象 `CoffeeInsightProviderIosImpl?` に変更（attach に具象参照が要るため。`AppContainer` 引数は `any CoffeeInsightProvider?` のままで互換）。`AppState` は provider を具象型で受け、container 構築後に `attachRecordQuery(container.coffeeRecordQuery)`。`SearchCoffeeRecordsTool.swift` の import に `@preconcurrency` を付け Sendable 警告を抑制。
- **instructions の v1→v2 差分**: 「digest に無い情報は『記録からは分かりません』」→「`searchCoffeeRecords` で照会してから答える / ツール結果に含まれない情報は推測・補完しない」。limit（既定 10）超のレコードは「全部教えて」に対し上限内しか返らない仕様上の限界が残る。
- **`localizedBrewMethod`/`localizedRoastLevel` が 3 箇所に重複**（`AnalysisView.swift` / `CoffeeInsightProviderIosImpl.swift` / `SearchCoffeeRecordsTool.swift`）。今回は影響最小のため複製を許容。将来 `iosApp/iosApp/Utilities/CoffeeLocalizer.swift` 等に共通化推奨（昇格候補）。

実装直後のバグ修正（2026-06-21 ユーザー実機確認時）:

- **平均評価 0.0 バグ（9-4b と無関係の既存バグ）**: `AnalysisView` / `buildPrompt` で `CoffeeStats`/`CategoryStat`/`CafeStat` の `averageRating`（Swift では `KotlinDouble?`）を `String(format: "%.1f", $0)` に直接渡しており、`%f` が NSNumber を誤読して 0.0 表示。計 8 箇所に `.doubleValue` を補って修正。詳細・汎用化は lessons.md 2026-06-21。
- **Q&A v2 が個別記録の問いに「不明」を返す**: tool・配線・ブリッジは正常で、原因は instructions の「逃げ道」（許可形 + tool 未使用の早期 escape）。instructions を「個別の問いは必ず tool を呼ぶ / 0 件のときだけ見つからないと答える」に命令形で書き換え、tool description も指示的に強化。`generateAnswer` の経路選択と `SearchCoffeeRecordsTool.call`（filter / 取得件数）に診断 `print` を追加し、実機ログで「未呼び出し」か「0 件（マッチ漏れ）」かを切り分け可能にした。
- **追調査（実機ログ）**: digest の「よく行くカフェ」に載るカフェ（例ブルーボトル）は tool 呼び出し成功、digest に載らない低頻度カフェ（例フグレン）は tool 未呼び出しと判明。モデルが **digest を全記録の網羅リストと誤認**し「digest に無い＝記録に無い」と諦める逃げ道が残っていた。instructions に「digest は非網羅の要約／digest に出ない名前でも必ず検索／記録の有無は tool 結果のみで判断」を明示して対処。なお tool 呼び出し時、モデルは digest を使って `cafeName` をフルネーム補完する（"ブルーボトルコーヒー"→"ブルーボトルコーヒー 三軒茶屋"、部分一致で命中）。
- instructions 強化でも不足なら、次の手は **質問の構造化事前抽出 → 決定的 tool 呼び出し**（Swift が固有名詞/期間を検出して tool を直接呼び、結果を digest に追記して LLM は整形のみ）。固有名詞抽出の偽陰性とのトレードオフあり（lessons.md 2026-06-21）。
- **追々調査（実機ログ・第2段）**: instructions 修正後、tool は呼ばれるようになったが今度は **フィールド誤分類**が発覚（"フグレン"=カフェを `origin` に入れて 0 件）。モデルの分類精度に依存しない解として、KMP の `CoffeeRecordQueryImpl` で **`origin`/`cafeName` をフィールド横断 free-text term 化**（`{cafe名/産地/コーヒー名/品種}` の union に部分一致）。公開 API（`CoffeeRecordFilter` の形）は不変のため Swift 追随不要だが、実装が変わるので iOS は通常 Xcode ビルド（override フラグ無し）で framework 再生成して反映する。data-model §1.6 に確定挙動を反映済。

### 2026-06-21: CI Android ジョブでダミー google-services.json を生成

- 領域: Build（`.github/workflows/ci.yml`）
- 関連: `androidApp/build.gradle.kts`（`googleServices` プラグイン + Firebase 依存）

feature/analyze で androidApp に `googleServices` プラグインと Firebase 依存（auth/firestore）を追加した結果、`:androidApp:assembleDebug` が `processDebugGoogleServices` で `google-services.json` を必須とするようになり、PR#2 の Android CI が `File google-services.json is missing.` で失敗した。同ファイルは秘匿情報として gitignore 済みで CI ランナーに存在しない（ローカルには `androidApp/google-services.json` がある）。PR#1 まではプラグイン未適用だったため通っていた。

**対応**: CI の Android ジョブに、Gradle 実行前にダミー `google-services.json` を `androidApp/` へ書き出すステップを追加。

**判断根拠**: Android はリリース対象外の KMP 共通層検証ターゲットで、`assembleDebug` の目的は共通層が Android でコンパイル/リンクできることの確認。実 Firebase 接続は不要なため、google-services プラグインを通すだけのダミー（package_name = `com.noricoffee.coffeevision`、project_number / app_id / api_key はゼロ埋めダミー）で十分とし、**GitHub Secrets 管理を不要にした**。

**トレードオフ**: Secrets に実 `google-services.json` を base64 で置く案より運用が軽い反面、CI で実 Firebase に到達するテスト（Firestore 結合テスト等）は将来も別途仕組みが要る。現状 Android 側に実接続テストは無いため問題なし。

**検証**: ローカルで実ファイルを退避→ダミーに差し替えて `processDebugGoogleServices --rerun-tasks` が BUILD SUCCESSFUL を確認（実ファイルは復元）。push 後の CI で Android / iOS 両ジョブ SUCCESS。

### 2026-06-21: マップ POI フィルタを cafe/bakery のみに限定

- 領域: iOS UI（`iosApp/iosApp/Features/Map/MapTabView.swift`）

ユーザーから「マップにカフェ以外（病院など）が出る」との指摘。アプリ独自ピン（訪問済み茶 / 周辺グレー）は Places API リクエスト側で既に `cafe` 限定済みだが、Apple Maps ベース地図の標準 POI ラベルは `.mapStyle(.standard)` のまま全カテゴリ素通しで描画されていた（フィルタ未適用）。

**対応**:
- `.mapStyle(.standard)` → `.mapStyle(.standard(pointsOfInterest: .including([.cafe, .bakery])))` でベース地図 POI をカフェ・ベーカリーに限定。
- POI タップハンドラ `poiSelectionChanged` の `allowedCategories` を `[.cafe, .restaurant, .bakery]` → `[.cafe, .bakery]` に揃え、表示されない POI をタップ受付しないよう一致させた（`restaurant` 除外）。

**トレードオフ**: 「コーヒーを出すレストラン / ビストロ」を記録したいユースケースが将来出たら `restaurant` 再追加を検討。その際は表示フィルタとタップ許可の両箇所を同時に変更すること（非対称にするとタップ導線がズレる）。`PointOfInterestCategories.including` は iOS 16+ で利用可（最小ターゲット充足）。

### 2026-06-22: Phase B-1 好み判定（FavoriteSignals）の統計仕様確定

- 領域: Shared（spec）→ KMP（実装予定）
- 関連: `docs/data-model.md` §1.6 / `shared/domain` `CoffeeStats.kt` `FavoriteSignals` / `BuildCoffeeStatsUseCase`
- 背景: iOSDC 20分版トーク（二本柱の柱2「複数の評価から好みを判定できるか」）のデモ素材を兼ね、未実装（全 null）だった `FavoriteSignals` を実体化する。トーク自体は KMP 文脈を出さないが、実装は通常どおり `shared/domain` に置く。

**確定した統計方針（素朴な生平均ランキングを採らない理由込み）**:

- **生平均の最大値を「好み」とするのは誤り**: n=1 の 5.0 が n=20 の 4.2 を上回ってしまう（サンプルサイズの罠）。これを 2 段で抑える。
  1. **件数ガード**: `count >= minSampleSize`（既定 3）未満の群は候補にしない（既存設計の踏襲）。
  2. **経験ベイズ収縮**: `shrunkMean = (n·mean + k·globalMean)/(n+k)`（`k=SHRINKAGE_PRIOR_WEIGHT` 既定 5）で全体平均へ寄せ、少数群の極端値を抑えてからランキング。
- **正方向のみ信号化**: `shrunkMean > globalMean` のときだけ `bestX` を立てる（「好み」= 平均超え。下回るなら null）。
- **好みの「軸」= 相関**: テイスティング 5 軸 × `rating` のピアソン相関を取り、`|r|` 最大かつ `|r| >= 0.3`（`CORRELATION_MIN_ABS`）、母数 `>= 5`（`CORRELATION_MIN_SAMPLE`）のときだけ `dominantTastingAxis` を立てる。符号で「高い/低いほど高評価」を言語化に渡す。分散 0 の軸はスキップ。
- **交絡は計算しない（明示的な仕様判断）**: 「産地が好き」か「その産地を出す店が好き」かは個人の観測データでは分離不能。層別で n が枯れ、有意性検定も前提が崩れる。よって多変量・検定は行わず、ヒューリスティックで「弱い傾向」だけを出す。**この『言える範囲を計算で確定し、LLM はその範囲でしか言わない』がトークの核（グラウンディングの実例）**。

**影響 / トレードオフ**:
- `FavoriteSignals` に `dominantTastingAxis: TastingAxisCorrelation?` と `enum TastingAxis` を新設（公開 API 追加）。`CategoryStat` は不変で再利用（`bestX` は生平均＋件数を載せ、収縮値は内部選定キーに留める）→ iOS / SKIE への影響は加算的。
- `k` / 閾値はすべて `companion` 公開でチューニング可。デモ約 30 件のダミーデータ（`DummyCoffeeData`）で `bestX` / `dominantTastingAxis` が非 null になるか実装時に確認する（足りなければダミーを調整）。
- 階層3 連携: `buildPrompt` に好み信号を「弱い傾向＋件数の但し書き」として追記し、instructions で断定を禁じる（iOS 側タスク）。

**dispatch**: `kmp-engineer`（`BuildCoffeeStatsUseCase` の `favoriteSignals` 実体化＋純粋関数ユニットテスト）→ レポート統合後 `ios-engineer`（`buildPrompt` 連携・好みカード表示・デモスクショ）。公開 API 差分（`dominantTastingAxis` / `TastingAxis`）は本ノートで凍結済。

**実装完了の追記（2026-06-22 KMP 実装完了時）**:
- `kmp-engineer` が `shared/domain` に実装完了。公開 API は凍結仕様どおり（`enum TastingAxis` / `data class TastingAxisCorrelation` / `FavoriteSignals.dominantTastingAxis` / companion 定数 `SHRINKAGE_PRIOR_WEIGHT=5` `CORRELATION_MIN_SAMPLE=5` `CORRELATION_MIN_ABS=0.3`）。**仕様ドリフトなし**。
- 検証: `:shared:domain` ユニットテスト 47 件 green（収縮逆転・件数ガード・正方向のみ・相関の符号/閾値/母数/分散0スキップ・タイ時のラベル順）、`assembleSharedLogicXCFramework` BUILD SUCCESSFUL（SKIE 警告は既存の Ktor 名前衝突のみ、追加型起因なし）。
- 実装上の落とし穴 1 件を `tasks/lessons.md` 2026-06-22 に記録（`mapNotNull`+ローカル data class+`maxWith(compareByDescending)` が実行時に全 null。原因未確定、`for` ループで解消、テストで担保）。
- **dominantTastingAxis は符号付き**（r<0＝「低いほど高評価」も最大 |r| なら返す）。「高い/低いほど好む」の出し分けは iOS UI 判断。
- **残: iOS 追随（`ios-engineer` 未 dispatch）**: ① `buildPrompt(from:)` に好み信号（収縮 bestX ＋ dominantTastingAxis）を「弱い傾向＋件数の但し書き」で追記し instructions で断定禁止 ② 分析タブに好みカード表示（任意）③ デモ用スクショ。SKIE 生成名は `TastingAxis`=`@frozen enum`、`TastingAxisCorrelation`=`struct` の見込み。

**iOS 追随完了の追記（2026-06-22）**:
- 領域: iOS / 関連: `iosApp/iosApp/Features/Analysis/CoffeeInsightProviderIosImpl.swift`・`AnalysisView.swift`・`PreviewSupport/PreviewSamples.swift`
- `ios-engineer` が実装完了。`xcodebuild`（iphonesimulator/Debug）BUILD SUCCEEDED、新規 warning ゼロ。
  1. `buildPrompt(from:)` に好み信号セクション（`buildFavoriteSignalsPromptLines`）を追記。`CategoryStat.averageRating`(`KotlinDouble?`)は `.doubleValue` 経由、`TastingAxisCorrelation.correlation`(native `Double`)は直接渡し（lessons.md 2026-06-21 の 0.0 バグ回避）。
  2. instructions に断定禁止グラウンディング（「やや/傾向止まり」「サンプル少なら添え書き」「交絡は断定しない」）。
  3. `FavoriteSignalsCard` / `FavoriteSignalRow` / `TastingAxisSignalRow` を `AnalysisView` に追加。全 null は `EmptyView()`。件数・平均併記、5件未満は「（サンプル少）」注記。
  4. `TastingAxis` の `switch` は `@frozen enum` のため全 case 網羅・`default` なし（追加時にコンパイルエラーで気づける設計）。
- **SourceKit の `No such module 'SharedLogic'` 診断は偽陽性**（XCFramework は gradle 生成のため IDE インデックスがラグる）。`xcodebuild` は成功。
- **親が DummyCoffeeData の閾値充足を検算（追加 dispatch 不要と判断）**: 現行30件・globalMean≈4.0 で 4 信号すべて非 null。`bestOrigin`=Ethiopia(評価済4件/平均4.5・収縮4.22) / `bestRoastLevel`=Light(6件/4.58・収縮4.32) / `bestBrewMethod`=AeroPress(3件/4.5・収縮4.19) / `dominantTastingAxis`=Flavor(tasting20件・評価と強い正相関)。**DummyCoffeeData 調整は不要**。
- **残: デモ用スクショ取得のみ**（要シミュレータ起動。`SEED_DUMMY_DATA=1` の dev Scheme でユーザー実機/シミュレータ確認）。

### 2026-06-22: Phase B-1b 好み判定のペルソナ比較検証戦略

- 領域: Shared（test 戦略）→ KMP（test 実装予定）
- 関連: `shared/domain` commonTest（新規）/ `BuildCoffeeStatsUseCase` / `FavoriteSignals` / `docs/data-model.md` §1.6
- 背景: 既存テストは「収縮が小群を打ち消すか」「相関の符号/閾値」など**機構ごとの単体テスト**。だが「複数の評価から好みを判定できるか」（iOSDC トーク柱2）の正しさは **1 ケースでなく、複数の合成ペルソナを横断して**初めて見える。特に **最大 |r| を 5 軸から拾う設計は多重比較（winner's curse）で偽陽性を生みやすい** ——これを実測で押さえる。**production コード・data-model §1.6 の仕様は変更しない。テスト追加のみ。**

**検証する 2 軸**:
1. **検出力（power / sensitivity）**: 既知の好みを仕込んだペルソナで、対応する信号が出るか。
2. **特異度（specificity / 偽陽性抑制）**: 好みが実在しないペルソナで信号が `null` になるか。**これが最重要**（断定しない設計の根拠を数値で裏付ける）。

**ペルソナ定義（固定シード乱数で決定論生成・テストにコミット）**:
- P1「酸味党」: `acidity` が高いほど rating 高（線形＋小ノイズ）→ `dominantTastingAxis == Acidity`, `r>0`。
- P2「深煎り党」: `roastLevel=Dark` 群が高評価 → `bestRoastLevel == Dark`。
- P3「産地偏重」: 特定 origin が高評価 → `bestOrigin ==` その産地。
- P4「抽出方法党」: 特定 brewMethod が高評価 → `bestBrewMethod ==` それ。
- P5「無相関ノイズ」（**null ペルソナ**）: rating が全属性と独立なランダム → 全フィールド `null` を期待。**偽陽性チェックの本丸**。
- P6「サンプル不足」: 全体件数は多いが各カテゴリ `n < minSampleSize` → カテゴリ信号 null（相関は母数次第）。
- P7「逆相関」: `body` が低いほど高評価 → `dominantTastingAxis.correlation < 0`。

**決定論性**: `BuildCoffeeStatsUseCase` は純粋関数。データは `kotlin.random.Random(seed)` の固定シードで生成し、ground truth に対し label / 軸を exact 一致で assert。

**偽陽性の測定（多重比較の影響を実測）**: P5 を単一固定シードの決定論 assert に加え、**多シード（例 100〜200）で生成して `dominantTastingAxis` / カテゴリ信号が非 null になる割合（偽陽性率）を集計・レポート**する。理論上、n≈30 で 5 軸の max|r|≥0.3 は偶然でも ~40% 起こりうる想定 → 高い実測値が出たら設計の弱点を示す**有用な発見**として扱う。よって **hard-fail は catastrophic な上限（例 60%）だけに留め、実測値を親へレポート**（恣意的な低閾値で偶然 pass させない）。

**この結果の使い道**: 偽陽性率が高ければ Phase B-1c（**多重比較ガード**: サンプル数連動の動的閾値、または相関の信頼区間下限で判定）へ進む判断材料にする。スピアマン化・不確実性提示は優先度低（実測で必要性が出たら）。

**dispatch**: `kmp-engineer`（commonTest 新規ファイルにペルソナ生成ヘルパ＋P1–P7 決定論 assert＋P5 偽陽性率測定）。スコープは `shared/domain` の test のみ、production・docs は不変。閾値判断は親。

**実装完了の追記（2026-06-22）— 偽陽性率の実測発見**:
- 関連: `shared/domain/src/commonTest/.../FavoriteSignalsPersonaTest.kt`（新規・8 テスト）。`:shared:domain:testAndroidHostTest` で新規 8＋既存 47＝計 55 件 green、production 無変更。
- **実測（150 シード, n=30/seed, 無相関ノイズ）**:
  - `dominantTastingAxis` 偽陽性率: **40.0%**（理論予測 ~40% に一致。5 軸 max|r|≥0.3 の多重比較 winner's curse）。
  - **カテゴリ信号（bestBrewMethod/bestRoastLevel/bestOrigin いずれか非 null）偽陽性率: 100.0%**。
- **カテゴリ 100% の本質（親の精査）**: 選定は「最大 shrunkMean の群を `shrunkMean > globalMean` のときだけ信号化」。globalMean は全体平均なので**およそ半数の群が上回り、その最大が選ばれる ＝「複数群の最良が平均を超えるか」はほぼ恒真**。収縮 k=5 は「極端値の大きさ」は抑えるが「これは本物の好みか」のゲートになっていない。**テストの人工物ではなく、複数カテゴリを均等に使う実ユーザーでも構造的に起きる**。
- **検出力は良好**: P1–P4・P7 で仕込んだ好みは正しく検出（酸味党→Acidity r>0、深煎り党→Dark、産地偏重→Ethiopia、抽出方法党、逆相関→Body r<0）。問題は特異度（偽陽性抑制）側に局在。
- **解釈と判断**:
  - tasting 軸の 40% は「弱い傾向止まり＋LLM 断定禁止」の現設計と一応整合（が、改善余地は大）。
  - カテゴリ信号の 100% は「好みを判定できるか」（トーク柱2）への答えとして弱い。**好みが無いユーザーにも必ず『○○がお好みのようです』と出てしまう**＝グラウンディングの土台（言える範囲を計算で確定）が崩れる。
  - → **Phase B-1c（カテゴリ信号の特異度ガード）に進む価値が高い**。最小コストの第一候補は **effect-size 閾値**（`shrunkMean - globalMean > δ`、δ は評価レンジ 0.5..5.0 に対し例えば 0.15〜0.25）。より堅牢にするなら bootstrap 信頼区間下限 > globalMean。tasting 軸はサンプル数連動の動的 |r| 閾値（or CI 下限）。**閾値導入後はこのペルソナ検証で偽陽性率の改善を再測定**（検出力 P1–P4 を割らないこと）。
  - 進めるか / δ 値 / どこまでやるかは**ユーザー判断待ち**（product 品質とトーク narrative のトレードオフ）。

### 2026-06-22: Phase B-1c 好み判定の特異度ガード（effect-size 閾値）— ユーザー承認

- 領域: Shared（spec）→ KMP（実装予定）
- 関連: `docs/data-model.md` §1.6（更新済）/ `BuildCoffeeStatsUseCase` / `FavoriteSignalsPersonaTest`
- 決定（AskUserQuestion 2026-06-22）: **effect-size 閾値で対処**を採用。理由 = B-1b でカテゴリ偽陽性 100%・tasting 軸 40% が判明し、「平均超え」だけでは特異度がゼロ。最小コストで効く「ゼロからの距離」での足切りを選んだ（信頼区間ベースは将来余地）。

**確定した仕様変更（data-model §1.6 に反映済）**:
- **カテゴリ好み**: 信号化条件を `shrunkMean > globalMean` → **`shrunkMean - globalMean > CATEGORY_MIN_EFFECT`（δ）** に変更。δ 候補 0.15〜0.25。
- **テイスティング軸**: 固定 `CORRELATION_MIN_ABS = 0.3` を **サンプル数連動の `CORRELATION_ABS_FLOOR`** に変更（or 併用）。5 軸 max|r| の多重比較ぶん、n が小さいほど締める。
- **公開 API は不変**: `FavoriteSignals` / `CategoryStat` / `TastingAxisCorrelation` の型は変えない。返す `CategoryStat` は従来どおり生平均＋件数（δ・floor は内部の足切りのみ）。→ iOS / SKIE への影響なし。

**確定方法（重要）**: δ と floor の値は **`FavoriteSignalsPersonaTest` で sweep して決める**。受け入れ基準 = ①無相関ノイズの偽陽性率が現状（カテゴリ100% / tasting40%）から大きく改善 ②検出力 P1–P4・P7 を割らない（仕込んだ好みは引き続き検出）。kmp-engineer が候補値で偽陽性率と検出力の表を出し、**親が最終値を確定**して data-model の「候補」表記を実値に更新する。

**dispatch**: `kmp-engineer`（`BuildCoffeeStatsUseCase` に δ・floor を実装＋既存ユニットテスト追随＋ペルソナテストで sweep 表を出力）。production 変更あり、公開 API は不変。docs 更新は親。

**実装完了の追記（2026-06-22）— 確定値と「カテゴリは固定 δ で解けない」発見**:
- 関連: `shared/domain/.../usecase/BuildCoffeeStatsUseCase.kt`・`FavoriteSignalsPersonaTest.kt`。`:shared:domain` 111 件 green、`assembleSharedLogicXCFramework` BUILD SUCCESSFUL、公開 API 不変。
- **確定値**: `CATEGORY_MIN_EFFECT = 0.20`、テイスティング |r| 下限 = `max(0.3, CORRELATION_ABS_FLOOR_C / sqrt(n))`（`CORRELATION_ABS_FLOOR_C = 1.97`、n=30 で実効 ≈0.36）。既存単体テストは effect-size 計算上いずれも δ=0.20 超で**追随変更ゼロ**（bestBrewMethod 高評価 δ=0.28 / roastLevel δ=0.23 / origin δ=0.47）。
- **sweep 結果（150 シード, n=30）**: tasting 偽陽性は c=1.97 で **22%**（c=2.30 なら 8.7%）に改善、検出力 P1–P4・P7 はいずれの候補でも維持。**カテゴリ偽陽性は δ=0.10–0.20 で 100%、0.25 で 95%、0.30 で 87%** とほとんど下がらない。
- **親の精査（重要・エンジニアの『テスト人工物』説への留保）**: カテゴリが下がらないのは数理的に必然。固定オフセット δ は「最良群が偶然平均を超える幅（winner's curse）」がサンプリングのばらつき σ/√n に比例して膨らむのを止められない。実際、K 群・n=6・σ≈1.2 だと最良群の生 gap ≈ 0.57、収縮後 ≈0.31 で δ=0.2 を常に超える。**tasting が改善したのは floor を `c/√n` とばらつき連動にしたからで、カテゴリゲートも本来は n 連動（信頼区間ゲート）にすべき**。「均等割当だから／実データなら下がる」は未実証の仮説（不均等でも小 n 群は収縮で潰れ、大 n 群は SE が縮むだけで winner's curse は別軸）。
- **判断**: δ=0.20 / c=1.97 を**ship**（tasting の実改善＋検出力維持は確実な前進、API 不変で安全）。カテゴリの根治は別タスク（B-1d 候補）に切り出し、まず**現実的な不均等分布の null ペルソナで「本当に問題か」を実測**してから、必要なら n 連動カテゴリゲート（`gap > z·globalStd/√n` のような軽量・決定論・on-device 可な信頼区間近似）を入れる。現時点はカテゴリ信号を「弱い傾向（LLM 断定禁止）」として使う方針で許容。ユーザー判断待ち。

### 2026-06-22: Phase B-1d 前段実測（不均等分布での偽陽性率）→ n 連動ゲート決定

- 領域: KMP / テスト / 関連: `shared/domain/.../FavoriteSignalsPersonaTest.kt`（セクション E、テストのみ・production 不変）
- **実測結果（150 シード, n=30, δ=0.20, c=1.97）**:

  | 指標 | 均等割当 | mild-skew | heavy-skew |
  |---|---|---|---|
  | 平均候補カテゴリ数 | 21.0 | 13.0 | 8.0 |
  | カテゴリ FP 率 | 100.0% | 96.7% | **86.7%** |
  | brewMethod | 98.7% | 75.3% | 54.0% |
  | roastLevel | 98.7% | 70.0% | 28.7% |
  | origin | 82.0% | 83.3% | 58.0% |

- **結論**: 仮説「不均等分布なら下がる」は**部分的にしか真でない**。候補数 21→8（2.6 倍減）でも合計 FP は 13.3pt しか下がらず heavy-skew でも 86.7%。**「均等割当だけが原因（実データなら解消）」は実測で否定**された。固定 δ は winner's curse を止められないという B-1c の精査が裏付けられた。origin はむしろ Ethiopia×12 の支配群で改善しにくい（大 n 群の winner's curse 固定化）。
- **決定（ユーザー承認: AskUserQuestion 2026-06-22「stays high → n 連動ゲートへ」）**: **B-1d 本体 = カテゴリにも n 連動の信頼区間ゲートを導入**する。形は `mean - globalMean > z · globalStd / sqrt(n)`（globalStd = 全評価済 rating の母標準偏差）の一標本 z 検定近似。**選定キーは従来どおり shrunkMean（n=1 外れ値に頑健）、ゲートだけ z 連動に置換**。z は sweep で確定（候補 1.5/2.0/2.5/3.0、必要なら候補数 K の Bonferroni 的補正も評価）。受け入れ基準 = heavy-skew カテゴリ FP を大きく下げつつ検出力 P2–P4（および tasting P1・P7）を割らない。軽量・決定論・on-device 可であること。

### 2026-06-22: Phase B-1d 本体完了 — カテゴリ n 連動 z ゲート（CATEGORY_Z=2.0 確定）

- 領域: KMP / 関連: `shared/domain/.../usecase/BuildCoffeeStatsUseCase.kt`・`FavoriteSignalsPersonaTest.kt`
- **変更**: カテゴリ好み（bestBrewMethod/bestOrigin/bestRoastLevel）の足切りを固定 δ 単独（B-1c）→ **`mean - globalMean > CATEGORY_Z · globalStd / sqrt(n)` AND `shrunkMean - globalMean > δ(0.20)`** の 2 条件 AND に置換。`globalStd` = 全評価済 rating の母標準偏差。`globalStd==0`（全件同値）は z ゲートをスキップしδ下限のみ（ゼロ除算回避）。**選定キーは shrunkMean のまま**、公開 API 不変（`CATEGORY_Z` companion 追加のみ）。
- **確定値 `CATEGORY_Z = 2.0`**。sweep（150 シード, n=30, δ=0.20, floorC=1.97）:

  | z | 均等 FP | mild FP | heavy FP | 検出力 P2–P4 |
  |---|---|---|---|---|
  | 1.5 | 58.7% | 47.3% | 25.3% | 全 OK |
  | **2.0** | **22.0%** | **14.0%** | **9.3%** | 全 OK |
  | 2.5 | 3.3% | 2.0% | 1.3% | 全 OK |
  | 3.0 | 0.0% | 0.0% | 0.0% | 全 OK |

  z=2.0 採用（heavy-skew 9.3% で目標達成・検出力維持・95% CI 慣例値）。z=2.5/3.0 はほぼ 0% にできるが**ペルソナは強い好みを仕込んでいるため z=3.0 でも検出できるだけで、実データの弱い好みを弾きすぎるリスク**があり不採用。均等 22% が残るのは「K 候補から最良を選ぶ」多重比較の構造的残差（完全 0 化には Bonferroni で K 分 z を上げる必要があり実用上過剰）。
- **既存単体テスト追随**: z=2.0 で n=3〜4 の小群は閾値が上がり信号化されないため、検出系 4 テスト（bestBrewMethod_highVolume / bestRoastLevel_nullRoastIsExcluded / bestOrigin_normalization / tieByCountThenLabel）のデータを n=10 に増量。検証意図（高件数高評価の検出・タイブレーク）は維持。`:shared:domain` 113 件 green、`assembleSharedLogicXCFramework` BUILD SUCCESSFUL、新規警告ゼロ。
- **好み判定（B-1）の特異度ワークはこれで一区切り**: tasting 軸 40%→22%（B-1c, c=1.97）、カテゴリ 100%→9.3%（B-1d, z=2.0, heavy-skew）。検出力 P1–P4・P7 は全工程で維持。iOS 追随は不要（API 不変）。

### 2026-06-22: Phase B-4 味覚プロファイル一致カフェのマップ連携（設計確定）

- 領域: Shared（spec）→ KMP → iOS / 関連: `docs/requirements.md` 9-5・`docs/data-model.md` §1.7・`shared/feature/map` `MapViewModel`・`iosApp` `MapTabView`
- 背景: 要件 9-5「好みのカフェをマップで探す」を着手。`FavoriteSignals`（B-1）のカテゴリ好みに一致する高評価記録があるカフェを「あなた好みの一杯があった店」としてマップで強調＋理由表示する。**コンテンツベース推薦の v1**。
- **確定した設計判断（ユーザー承認: AskUserQuestion 2026-06-22 + 後続の将来像 Q&A）**:
  - **一致定義**: カフェに `rating >= 4.0`（`HIGHLIGHTS_MIN_RATING` 再利用）かつ `FavoriteSignals` のカテゴリ好み（bestOrigin/RoastLevel/BrewMethod の非 null）いずれかに一致する記録が 1 件以上。**`dominantTastingAxis`（相関軸）は v1 では一致条件に使わない**（相関は per-record categorical 一致に変換不能・理由表示が曖昧）。
  - **高評価しきい値 4.0 / 味覚相関軸 v1 除外**はユーザーと明示合意済。
  - **将来移行を見据えた境界設計**（重要・将来像 Q&A の結論を反映）: 推薦を `CafeRecommendationProvider`（interface）の裏に置き、`MapViewModel` は中身を知らない。v1 = ローカル決定論実装 `ObserveTasteMatchedCafesUseCase`、将来 9-6 = サーバ（GCP 等）リモート実装に**差し替えるだけ**で UI/VM/FM 言語化層は不変。
  - **reason は `sealed RecommendationReason`** で表現し、v1 の `TasteProfileMatch` に将来 `SimilarUsers(...)` 等を**種類追加**できる形（enum 固定にしない）。
  - **モデルにカフェ訪問を前提化しない**: `RecommendedCafe.cafe` は `Cafe`（placeId＋座標）だけ持ち、未訪問カフェ推薦に拡張できる契約にする。
- **公開 API 追加（加算的）**: `RecommendedCafe` / `RecommendationReason` / `PreferenceMatchAxis` / `CafeRecommendationProvider` / `MapViewModel.UIState.recommendedCafes`。SKIE 越えの新型あり → kmp-engineer レポートの公開差分を親が `kmp-bridge.md` に固定してから iOS dispatch。
- **dispatch**: ①kmp-engineer（domain モデル＋`ObserveTasteMatchedCafesUseCase`＋単体テスト＋`MapViewModel` 状態＋`AppContainer`/`framework` 配線）→ ②親が公開差分を docs/kmp-bridge に固定 → ③ios-engineer（`MapViewModelBridge`＋`MapTabView` 区別ピン・理由表示）→ ④親が統合・commit。

### 2026-06-22: Future Direction — 協調フィルタリング推薦（9-6）と FoundationModel の住み分け

- 領域: アーキテクチャ方針（将来 / 未着手）/ 関連: requirements 9-6・data-model §1.7 `CafeRecommendationProvider`
- 将来像（ユーザー意向）: 複数ユーザーが好みを登録し、**好みが近い他ユーザーの高評価カフェを提案**する（協調フィルタリング）。本エントリは「今は作らないが設計の北極星」として残す。
- **方式の住み分け**: v1（9-5）= コンテンツベース（自分の好み属性 ↔ カフェ）。将来（9-6）= 協調フィルタ（ユーザー間類似度）。両者はハイブリッドで共存し、9-6 は v1 に**追加**で載る（content→collaborative は典型的な発展経路）。
- **味覚の類似度は LLM 不要・決定論**: 好みは既に構造化数値（`tastingAverages` の 5 軸＋カテゴリ別評価分布）＝そのまま特徴ベクトル。cosine 等で決定論的に類似度計算できる。**テキスト埋め込み学習は不要**。これは本アプリの「計算は決定論、LLM は言語化」哲学と一致。
- **FoundationModel は類似度エンジンではない**: Apple の Foundation Models（`LanguageModelSession`）は生成・tool calling 向けで、汎用 embedding を返す公開 API ではない。自由文をベクトル化するなら別フレームワーク（Natural Language の `NLEmbedding`/`NLContextualEmbedding`）だが、構造化データなので基本不要。**FM の役割は将来も「計算済みの推薦結果を一言で言語化」一点**（既存 `CoffeeInsightProvider` のグラウンディング構図と同じ）。
- **横断ベクトル計算はサーバ側（GCP 等）**: 全ユーザーの KNN は本質的にサーバ。**右サイズ重要** — 5〜10 次元・中規模なら重い vector DB は不要で、Firestore のベクトル KNN or Cloud Function の総当たり cosine で十分。大規模／テキスト埋め込みに進むなら Vertex AI Vector Search 等に格上げ。
- **本体の難所は計算でなく基盤**: ①プロファイルベクトルのサーバ集約（現状 per-user・path-uid のみ → 横断読みは別セキュリティモデル）②好み/評価を他者推薦に使う**明示同意/オプトイン**（写真ローカル等の現方針と同じ慎重さ）③カフェ識別子は placeId で共有可能＝協調フィルタの item キーに好都合 ④コールドスタート（少人数では効かない＝だから v1 content-based が先、が正しい順序）。
- **結論**: v1 の `CafeRecommendationProvider` 境界 ＋ `tastingAverages` をベクトル基盤と認識しておけば、GCP のベクトル分析は**純粋に追加**で差し込め、FM 言語化層は最初から将来と共通。

### 2026-06-22: Phase B-4 KMP 実装完了（味覚一致カフェ）

- 領域: KMP / 関連: `shared/domain/.../model/RecommendedCafe.kt`・`.../usecase/ObserveTasteMatchedCafesUseCase.kt`・`shared/feature/map/.../MapViewModel.kt`・`shared/framework/.../AppContainerViewModelFactory.kt`
- `kmp-engineer` が docs §1.7 どおり実装。`:shared:domain` 129 件（うち新規 16）・`:shared:feature:map` 7 件 green、`:androidApp:assembleDebug` / `assembleSharedLogicXCFramework` BUILD SUCCESSFUL。公開 API は加算的（`MapViewModel` 変更は既存不変、生成は `makeMapViewModel` 経由で Bridge 影響なし）。
- **公開 API 差分は `kmp-bridge.md` に固定済**（`sealed RecommendationReason` の `onEnum(of:)` 表現、`PreferenceMatchAxis` の Swift case 名 `.origin`/`.roastLevel`/`.brewMethod`（camelCase。kmp-engineer の初回報告「全小文字」は誤り→ios-engineer が `.swiftinterface` 実地確認で訂正）、`UIState.recommendedCafes`/`recommendedPlaceIds` 追加）。
- **実装判断 / 落とし穴**:
  - `ObserveTasteMatchedCafesUseCase` は `FavoriteSignals` だけ必要だが `BuildCoffeeStatsUseCase` 全体を実行（重複排除優先）。数十件規模で無問題、将来重ければ `FavoriteSignals` 専用軽量 UseCase を分離（YAGNI）。
  - `maxWith(compareByDescending {...})` が意図と逆（最低 rating を返す）バグを発見→`sortedWith(...).first()` で修正、テストで担保。lessons.md 2026-06-22 に汎用化。
  - `PreferenceMatchAxis` の Swift case 名が全小文字に潰れる件は `@ObjCName` で明示も可能だが、iOS が case 名を把握すれば足りるため v1 は KMP 変更せず docs 記載のみ。
- **残: iOS 追随（ios-engineer）**: `MapViewModelBridge` に `recommendedCafes`/`recommendedPlaceIds` 反映 ＋ `MapTabView` に区別ピン・理由表示・凡例。

### 2026-06-22: Phase B-4 iOS 追随完了（味覚一致カフェのマップ表示）

- 領域: iOS / 関連: `iosApp/.../Features/Map/MapViewModelBridge.swift`・`MapTabView.swift`・`PreviewSupport/PreviewSamples.swift`
- `ios-engineer` が実装。`xcodebuild`（iphonesimulator/Debug）**BUILD SUCCEEDED・新規 warning ゼロ**。SourceKit の `No such module 'SharedLogic'` は既知の偽陽性。
  - `MapViewModelBridge` に `recommendedCafes`/`recommendedPlaceIds` を加算的に反映（`Set<String>` は SKIE/KN で Swift `Set<String>` に透過変換、キャスト不要）。
  - `MapTabView`: 好み一致カフェ（`recommendedPlaceIds.contains` で O(1) 判定）をアクセントカラー＋`heart.fill`（38pt）で強調。**通常訪問ピン（茶・NavigationLink）/ 周辺ピン（グレー）は不変**。一致ピンはタップで `RecommendationMatchSheet`（理由一覧＋「このカフェの記録を見る」で詳細 push）を表示。凡例バッジ `RecommendedLegendBadge`（データ不足時は非表示）。
  - **理由表示の UX 判断**: 一致ピンは「即詳細（1 タップ）」でなく「理由シート→詳細（2 タップ）」。"なぜおすすめか" を先に見せる狙い。callout で 1 タップ化は v2 余地（ios-engineer 申し送り）。
  - `PreferenceMatchAxis` の `switch` は `.origin`/`.roastLevel`/`.brewMethod` 全網羅・`default` なし。
- **B-4 v1 完了**: KMP（決定論集計＋プロバイダ境界）＋ iOS（強調・理由表示）。将来 9-6（協調フィルタ）は `CafeRecommendationProvider` のリモート実装差し替えで載る設計（Future Direction 参照）。**残はシミュレータ/実機目視（一致ピン・理由シート・空時非表示・VoiceOver）＝ユーザー作業**。

### 2026-06-23: マップ「周辺」フィルタチップ撤去（周辺ピン常時表示）

- 領域: KMP + iOS / 関連: `shared/feature/map/.../MapViewModel.kt`・`iosApp/.../Features/Map/MapViewModelBridge.swift`・`MapTabView.swift`
- 経緯: 現在地 FAB（カメラを現在地へ recenter）があるため、周辺ピンの表示/非表示トグル（`showNearby`）は冗長というユーザー判断。周辺ピンを常時表示に統一。
- 変更: KMP は `UIState.showNearby` プロパティと `onShowNearbyToggled` を撤去（公開 API の減算的変更）。`nearbyPlaces`/`isLoadingNearby`/`onLocationUpdated` の周辺検索ロジックは不変、トグルだけ撤去。iOS は Bridge の `showNearby`/`onShowNearbyToggled`/state 同期を削除し、`MapTabView` の周辺ピン描画ゲート `if bridge.showNearby` を撤去（常時 `ForEach` 展開）＋「周辺」`FilterChip` 削除。
- 影響/所見: FilterChip 行には「訪問済み」+（好み一致カフェ時のみ）`RecommendedLegendBadge` が残る。`HStack(spacing: 8)` 先頭詰めでレイアウト崩れなし。`訪問済み` トグルは維持（ピンを隠して周辺/一致に集中する用途が残るため）。
- 検証: KMP `:shared:feature:map` compile/test green、iOS `xcodebuild` BUILD SUCCEEDED（新規 warning ゼロ）。目視はユーザー作業。

### 2026-06-23: Places API キーの iOS バンドル ID 制限に Ktor 生 REST を追随

- 領域: KMP（data-places） / 関連: `shared/data-places/src/iosMain/.../PlacesHttpClient.ios.kt`
- 経緯: アプリ上で Places API 疎通確認を実施したところ、API キーに **iOS バンドル ID 制限**（`com.noricoffee.coffeevision`）が設定されていた。Google は `X-Ios-Bundle-Identifier` ヘッダでバンドル ID を判定するが、これを自動付与するのは公式 GMS SDK のみ。本アプリは Ktor(Darwin) で生 REST を叩くため未付与で、そのままでは `403 API_KEY_IOS_APP_BLOCKED`（iosBundleId: `<empty>`）になる。
- 切り分け実証（curl）: ヘッダなし → 403 / `X-Ios-Bundle-Identifier: com.noricoffee.coffeevision` 付き → HTTP 200・20件。よってキー有効・Places API (New) 有効化・課金は正常で、原因はヘッダ欠落のみと確定。
- 修正: `iosMain` の `actual createPlacesHttpClient()` で `defaultRequest { header("X-Ios-Bundle-Identifier", NSBundle.mainBundle.bundleIdentifier) }` を付与。バンドル ID は実行時取得なので署名ビルドで `TEAM_ID` が付いてもズレない。`bundleId == null`（テストホスト等）の場合はヘッダなし。
- **設計判断**: iOS 固有制約は `iosMain` の actual に閉じ、`commonMain` の `PlacesClientImpl` / `createCafeRepository` シグネチャは不変（Android にヘッダを漏らさない）。`PlacesClientImpl` は `httpClient.config { install(ContentNegotiation) }` で再構成するが、`HttpClient.config` は `plusAssign(userConfig)` で元設定（DefaultRequest 含む）を引き継ぐため伝播する（Ktor 3.0.3 ソースで確認）。
- 検証: `:shared:data-places` iOS compile / framework assemble / Android host test green。iosApp を iPhone 17 Pro(iOS 26.1) シミュレータにビルド＆起動成功、ビルド成果物の `CFBundleIdentifier == com.noricoffee.coffeevision`（制限値と完全一致）、`startInitialSync succeeded` を確認。**残: Search タブで実検索して結果表示の目視＝ユーザー作業**。

### 2026-06-23: Places API 疎通の真因は xcconfig のキー上書き（記述順バグ）

- 領域: iOS ビルド設定 / 関連: `iosApp/Configuration/Base.xcconfig`・（併せて）`shared/data-places/.../PlacesHttpClient.ios.kt`・`PlacesClientImpl.kt`
- 経緯: 「アプリ上で Places 疎通確認」で検索が空結果（NoResult）・マップ周辺ピンも出ない。段階的に切り分けた結果、**3つの独立した問題**が重なっていた:
  1. **（真の疎通ブロッカー）API キーが空注入**: `Base.xcconfig` が `#include? "Secrets.xcconfig"`（実キー設定）の**後ろ**に `PLACES_API_KEY =`（空フォールバック）を書いていた。xcconfig は同一キーの最後の代入が勝つため、空文字が実キーを上書きし、アプリは空キーで Places を叩いて 403（API キー無効＝`iosBundleId` フィールドを持たない 403）になっていた。→ フォールバック宣言を include の**前**に移動して解消。インストール済み `.app/Info.plist` の `PLACES_API_KEY` が空→`AIzaSy…`(39字) に変わったことで確認。
  2. **API エラーの握り潰し**: `PlacesListResponse.places = emptyList()` デフォルト ＋ Ktor 既定 `expectSuccess=false` により、403 のエラー JSON が空 places にデコードされ、例外もトーストも出ず「結果0件」に見えていた（=#1 の発覚を遅らせた元凶）。→ `PlacesClientImpl` に `expectSuccess=true` ＋ `HttpResponseValidator.handleResponseExceptionWithRequest` で本文付き `PlacesApiException`（internal）を投げる修正。
  3. **iOS バンドル ID ヘッダ未付与**: キー注入後に効いてくる制限。GMS SDK 以外（Ktor 生 REST）は `X-Ios-Bundle-Identifier` を自動付与しない。→ `iosMain` の `createPlacesHttpClient()` で `NSBundle.mainBundle.bundleIdentifier` を `defaultRequest` ヘッダに付与（前掲エントリ）。
- 切り分けの決め手: ①curl はバンドル ID ヘッダ無→403`API_KEY_IOS_APP_BLOCKED`(iosBundleId:empty) / 有→200。②実機 dylib に `X-Ios-Bundle-Identifier`・`PlacesApiException` 文字列が在ることを `grep -a` で確認（修正がバイナリに反映済の裏取り）。③`.app/Info.plist` の `PLACES_API_KEY` 実値を PlistBuddy で確認（空→注入の前後比較）。④「`iosBundleId` フィールドが無い 403」という症状からキー欠落を特定。
- 検証: `:shared:data-places` compile/test green、xcframework assemble green、iosApp Debug ビルド成功・キー注入確認・上書きインストール起動。**最終の実検索の目視はユーザー作業**。

### 2026-06-23: 周辺カフェ検索の精度修正（encodeDefaults + includedPrimaryTypes）

- 領域: KMP（data-places）+ iOS（map） / 関連: `shared/data-places/.../PlacesClientImpl.kt`・`Dto.kt`・`iosApp/.../Features/Map/MapTabView.swift`
- 経緯: マップ周辺グレーピンに渋谷駅・ハチ公像など非カフェが並んだ。curl で切り分け、2要因が判明:
  1. **kotlinx.serialization の `encodeDefaults=false`（既定）**で `SearchNearbyRequest` のデフォルト値フィールド（`includedTypes` 等）が JSON にエンコードされず、型フィルタ無しの searchNearby になっていた → `PlacesClientImpl` の `Json{}` に `encodeDefaults=true` を追加。`explicitNulls=false` 併用のため null デフォルト（`locationBias=null`）は引き続き省略され意図どおり。
  2. **`includedTypes`（cafe を副次に含む場所）+ prominence 順**だと Tower Records・ホテルが上位に来る → `includedPrimaryTypes=["cafe","coffee_shop"]`（主タイプが cafe）+ `rankPreference="DISTANCE"`（距離順）に変更。curl 実証で OBSCURA COFFEE / スタバ / 星乃珈琲 / PRONTO が近い順に並ぶことを確認。`coffee_shop` を併記するのはチェーン店が `cafe` でなく `coffee_shop` に分類されるケースがあるため。
- iOS 側: 周辺ピンのアイコンを `mappin` → `cup.and.saucer.fill`（グレー円は維持、茶円＝訪問済みと区別）。
- 検証: `:shared:data-places` test green（既存 searchText テストは FakePlacesClient のため影響なし）、xcframework assemble green、iosApp Debug ビルド・上書きインストールで実機表示確認（ユーザー目視 OK）。

### 2026-06-23: マップ近隣表示を Apple POI に一本化（proactive searchNearby 撤去）

- 領域: KMP（feature/map）+ iOS（map） / 関連: `shared/feature/map/.../MapViewModel.kt`・`iosApp/.../Features/Map/MapTabView.swift`・`MapViewModelBridge.swift`
- 経緯: マップを開くたびに Places `searchNearby`（課金 SKU）を 1 回叩いて周辺グレーピンを出していたが、(1) Apple Maps ネイティブ POI（`.mapStyle(pointsOfInterest: .including([.cafe,.bakery]))` で無料表示）と二重表示になり、(2) 同じ店でも Apple POI と Google 座標が微妙にズレる、(3) ユーザー意図と無関係に課金が発生、という問題があった。近隣表示を Apple POI に一本化し、Places はユーザーが Apple POI をタップした時だけ（`onPoiTapped`→`searchText` で Google placeId に解決）使う方針に変更。
- KMP 減算（公開 API 変更）: `MapViewModel.UIState` から `nearbyPlaces` / `isLoadingNearby` を削除、`onLocationUpdated` メソッドと `nearbySearchJob` を削除。`onPoiTapped`/`poiLookupResult`/`visitedCafes`/`recommendedCafes`/`showVisited`/`error` は不変。テストは `nearbyPlaces` assertion を除去。
- iOS 追従: グレーピン `ForEach(nearbyPlaces)` と `nearbyPin`、`isLoadingNearby` ゲートの `loadingBanner`、`setupLocation` 内の `onLocationUpdated` 呼び出し、Bridge の該当プロパティ/メソッドを削除。位置情報は初期カメラ移動・現在地 FAB に引き続き使用。`.mapStyle` の Apple POI 表示と POI タップ経路は保持。
- **`CafeRepository.searchNearby` / `CafeRepositoryImpl` / `PlacesClientImpl.searchNearby` は data 層 capability として保持**（map から呼ばれなくなるだけ。今回 encodeDefaults/includedPrimaryTypes で精度改善した実装はそのまま温存）。→ 現状この capability は未使用（dead capability）。将来再利用しないなら別途撤去候補。
- 検証: `:shared:feature:map` test green（6件）・`:androidApp:assembleDebug` green、iosApp Debug ビルド成功・上書きインストール起動。実機目視（グレーピン消滅・Apple POI 残存・POI タップ→詳細遷移）はユーザー作業。

## 2026-06-23 - CafeSearch: 検索欄テキストをローカル `@State` で管理する（入力ラグ対策）
- 論点: `.searchable` の表示値を `bridge.query`（Kotlin `StateFlow` 経由）にすると、`set → kotlin.onQueryChanged → StateFlow.update → SKIE AsyncSequence emit → apply() → 再描画` の非同期ラウンドトリップが完了するまで TextField に文字が echo されず、実機 debug + Kotlin/Native 非最適化ビルドで入力ラグが顕著になる（実機で「検索タブの入力が重い」と報告）。
- 対策: `CafeSearchView` に `@State private var queryText` を持ち、これを `.searchable` 表示値の真実の源とする。Kotlin への反映は `.onChange(of: queryText)` で `bridge.onQueryChanged` に一方向転送のみ。`bridge.query.isEmpty` を見ていた箇所（表示分岐 ×2 / 検索ボタン disabled / `ContentUnavailableView.search`）も `queryText` に寄せた。
- 一貫性: `onSearchTapped` は Kotlin 内部の `_state.value.query` を使うため、`onChange` の転送完了後にボタン/Submit する通常フローでクエリは従来どおり成立する。**Kotlin 側から `query` をクリア/リセットする経路が将来生じた場合は、`bridge.query` → `queryText` の逆方向反映が別途必要**（現行 ViewModel には該当経路なし）。
- 補足: ユーザーが入力ごとに見た OS ログ（`Received external candidate resultset` / `Result accumulator timeout: 3.0 exceeded` / `containerToPush is nil` 等）は iOS のサジェスト候補集約サブシステム由来の無害ノイズで本件とは別問題。アプリコードからは抑制できない。

## 2026-06-23 - CafeSearch: 「該当なし」を検索確定後のみ表示（UIState.hasSearched）
- 論点: Places は確定実行方式（`onQueryChanged` では API を叩かず `onSearchTapped` で初めて検索）だが、表示側が「`results` 空 && クエリ非空」で `ContentUnavailableView.search` を出していたため、入力中も「該当なし "○○"」が逐次更新表示され、逐次検索しているように見えていた。「`results` が空である理由」を「未検索」と「検索したが 0 件」に区別する必要があった。
- 解決: `CafeSearchViewModel.UIState` に `hasSearched: Boolean = false` を追加（単一の真実の源を ViewModel に置く）。`onQueryChanged` で false、`onSearchTapped` / `onNearbySearchRequested` の**成功完了時のみ** true、失敗時・ローディング開始時は据え置き。iOS は `CafeSearchView` の表示分岐を `queryText.isEmpty` ベースから `hasSearched` ベースへ置換（`results 空 && !hasSearched → 初期プロンプト` / `results 空 && hasSearched && !isLoading → 該当なし` / `else → 結果リスト`）。
- 効果: 入力中は初期プロンプト維持、検索確定して 0 件のときだけ「該当なし」。0 件表示後に 1 文字でも打つと `hasSearched=false` に戻り初期プロンプトへ。ローディング中は `hasSearched=false` のまま第 1 分岐 + ProgressView overlay。
- 補足: `emptyResultsView` の `ContentUnavailableView.search(text: queryText)` の引数は据え置き。検索確定後はタイプしていないため `queryText` == 検索語として成立する。

## 2026-06-23 - PlacesClientImpl.searchText: 地名クエリへのカフェ語補完
- 論点: `searchText` は `includedType="cafe"` で結果をカフェ型に絞る。地名のみ（例「渋谷」「池袋」）を渡すと Text Search が locality 型（「渋谷区」等）に一致させ、cafe フィルタで弾かれて 0 件になる。「コーヒー」「珈琲」はカフェ名/型に直接マッチするので返る。curl 実測で確定（`渋谷`+cafe→0件、`渋谷 カフェ`+cafe→20件、`コーヒー`+cafe→20件、ブランド名「スターバックス カフェ」「ブルーボトル カフェ」も正しく返る）。
- 解決: バイアスなしの `searchText(query: String)`（ユーザーのテキスト検索）経路に限り、private `ensureCafeKeyword(query)` でカフェ語（カフェ/cafe/café/コーヒー/珈琲/coffee、`lowercase()` 比較）を含まないクエリの末尾に `" カフェ"` を補完。含む場合・blank は無補完。
- 対象外: `searchText(query, locationBias)`（地図 POI タップの placeId 解決。bakery 等も解決するため補完すると歪む）と `searchNearby` は変更なし。`includedType="cafe"` は維持。公開 API 変更なし（iOS 変更不要）。
- 補足: Places Text Search はカテゴリ+地域を textQuery（「渋谷 カフェ」）で表現するのが Google 推奨の自然言語パターンであり、補完はハックではなく idiomatic。

## 2026-06-23 - SwiftUI Map の Legal オーナメントは `safeAreaPadding` に追随しない
- 事象: マップ左下の Legal/帰属表記が TabBar 裏に隠れて見切れる。`MapTabView` の `Map` に `.ignoresSafeArea()`（全辺）を付けてフルブリード化しているため、内部 `MKMapView` がオーナメントを置く基準下端セーフエリアが 0 になり画面最下端＝TabBar 裏に来るのが原因。
- 不採用: `.safeAreaPadding(.bottom, X)` で下端を復元する案。SwiftUI の `safeAreaPadding` は `Map` 内部の `MKMapView` オーナメント配置レイヤーに伝播せず、固定大値 200 でもシミュレータで Legal が一切動かないことを確認（= 機構が別レイヤー）。
- 採用: `.ignoresSafeArea(.container, edges: [.top, .horizontal])` に変更。上辺（ステータスバー裏）・左右はフルブリード維持、下辺だけデフォルトのセーフエリア（TabBar 上端）を残すことで `MKMapView` が Legal を TabBar 上端のすぐ上に配置する。シミュレータ（iPhone 17 / OS 26.1）目視で確認済み。
- トレードオフ: 地図下辺が TabBar 上端で止まるため、TabBar 裏まで地図が描画されるフルブリード感（下辺のみ）は喪失。Legal 表示の法的要件を優先。実機での見た目差は要確認。

## 2026-06-24 - KMP 共通層で `runCatching` を使わない方針確定（Skill 観点レビュー）

- 領域: KMP（feature/* ViewModel + core） / 関連: 各 `*ViewModel.kt`・`CoffeeRepositoryImpl.kt`
- 経緯: `kotlin-coroutines-flows` Skill の観点で全 feature をレビューしたところ、`launch { runCatching { ... }.onFailure { _state.update { error } } }` が横断的に存在。`runCatching` は `CancellationException` も握りつぶすため、画面破棄・サインアウト等のキャンセルがエラー扱いになり、ローディングフラグ書き込み競合と協調キャンセルの遮断を起こす。
- 方針: コルーチン内は以下パターンを使う。`CancellationException` を先行 catch でフラグリセット＋再スロー、`Exception` でユーザー向けエラーを表示。
  ```kotlin
  try { /* 処理 */ }
  catch (e: CancellationException) { _state.update { it.copy(isLoading = false) }; throw e }
  catch (e: Exception) { _state.update { it.copy(error = e.message ?: "…") } }
  ```
  `WritePolicy.IgnoreRemoteFailure`（Firestore リトライ委譲で非2xx を意図的に無視）も、`CancellationException` 先行 catch を入れることで `runCatching` を避けられる。公開 API 変更なし（iOS 追随不要）。
- 検証: 全 feature `compileCommonMainKotlinMetadata` / `:shared:framework:compileKotlinIosSimulatorArm64` / 各 `testAndroid` / `:androidApp:assembleDebug` green。
- 関連 lessons: [`tasks/lessons.md`](./tasks/lessons.md)「`runCatching` はコルーチン内で使ってはいけない」。

## 2026-06-24 - `LocalCoffeeRepository` のクエリ context は `Dispatchers.Default`（旧名 `ioContext` を `queryContext` に改名）

- 領域: KMP（data-local） / 関連: `LocalCoffeeRepository.kt`
- 経緯: SQLDelight の `asFlow().mapToList(context)` に渡す context パラメータ名が `ioContext` だったが、実体は `Dispatchers.Default`（`Dispatchers.IO` は JVM/Android 専用で `commonMain` 不可）。名称と実態が乖離して誤読を招くため `queryContext` に改名。`data-firebase/androidMain` の `callbackFlow` 内 JSON デコード（CPU バウンド）も `Dispatchers.IO` → `Dispatchers.Default` に揃えた。公開 API 変更なし。

## 2026-06-24 - 既知の未解決事項（Skill 観点レビューで surfacing、本レビューでは未修正）

レビューで検出したが、設計変更・要件確認を伴うため修正を見送り、申し送りとして記録する。

- ~~**`CoffeeDetailViewModel` / `MapViewModel` のスコープ共有**~~ → **解決済み（後述「ViewModel に所有 viewModelScope + clear() を導入」エントリ参照）**。
- **`AccountView.observeProcessingCompletion` / `MapTabView.locationStream` のポーリング**: `@Observable` の変化を `withObservationTracking` / `.task(id:)` ではなく 0.1s ポーリングで待っている。コメントに「`@Observable` は Task 内の非同期変化検知が遅れることがある」とある（実測由来の判断と思われる）。`AnalysisViewModelBridge.onAppear` と同じ `.task(id:)` パターンへの置換が将来の候補。
- **`AnalysisView` の `InsightStatus` / `QaStatus` 分岐**: iOS 側は `status is …Unsupported` の型チェック連鎖。Kotlin の `sealed interface` に SKIE SealedInterop が効いていれば `switch onEnum(of:)` で網羅性チェックを得られる。SKIE 適用状況の確認が前提（未確認）。
- **`CoffeeEditorView` の `Photo_` 直接組み立て**: `handlePickerSelection` 内で `Kotlinx_datetimeInstant` を直接構築しており、View に軽微なドメイン組み立てロジックが混入。Bridge に `createPhoto(from:)` ファクトリを足せば解消できる軽微な規約逸脱。
- **`ContentView.swift`**: アプリのルートに表示されていない未使用のデモ残骸ファイル。削除候補（要ユーザー確認）。

## 2026-06-24 - ViewModel に「所有 viewModelScope + clear()」を導入（スコープ共有リーク解消）

- 領域: KMP（feature/* 全 ViewModel）+ iOS（全 ViewModelBridge） / 関連: 各 `*ViewModel.kt`・各 `*ViewModelBridge.swift`
- 問題: 全 ViewModel が `AppContainer.scope`（アプリ全体で 1 本の `MainScope`）を共有し、内部の `launch` もそこで実行していた。push/pop 画面（`CafeDetailViewModel` の init collector / `CoffeeDetailViewModel` の onAppear collector）は画面破棄後も app-wide scope に collector が残り**増殖リーク**になっていた（tab 常駐の map/analysis 等は単一インスタンスのため増殖はしないが同根の構造）。
- 確定設計（全 8 feature VM に統一適用）: 注入された `scope` を親として、各 VM が所有スコープを生成する。
  ```kotlin
  private val viewModelScope = CoroutineScope(
      scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
  )
  fun clear() { viewModelScope.cancel() }
  ```
  - `SupervisorJob(parentJob)` で app-wide scope の Job を親に連結 → app teardown 時は子も連鎖キャンセル（構造化並行性を維持）。Dispatcher（Main）は coroutineContext から継承。
  - 内部の `scope.launch` はすべて `viewModelScope.launch` に置換。既存の個別 `observeJob`/`searchJob` 等の管理は温存。
  - **`AppContainerViewModelFactory` のシグネチャは不変**（`scope` を渡す口は同じ。子スコープ生成は VM 内部で完結）。
- iOS 追随: 各 `*ViewModelBridge` の **`deinit` で `kotlin.clear()`** を呼ぶ。push/pop 画面（CoffeeDetail / CafeDetail / CoffeeEditor）は遷移アニメ中にも発火する `onDisappear` ではなく必ず `deinit` で呼ぶ。Bridge は View の `@State` / `AppState` の Optional で保持され、破棄時に `deinit` が走る（`observationTask` は `[weak self]` で循環なし）。Swift 側 `Task.cancel()`（onDisappear）と Kotlin 側 `viewModelScope.cancel()`（deinit）の 2 層構造になる。
- スレッド安全性: `clear()` は `Job.cancel()` のみで kotlinx.coroutines のキャンセルはスレッドセーフ。Kotlin/Native の `deinit`（必ずしも Main ではない）スレッドから呼んでも安全。**ただし将来 `clear()` 内で `@MainActor` 前提の処理を増やすとこの前提が崩れる**ため、`clear()` はスコープ畳みのみに留めること。
- 挙動上の注意: `clear()` 後に `onAppear`/`launch` を呼んでも新規 Job は起動されず no-op。tab 常駐 VM（map/analysis/coffee-list/cafe-search/account）はアプリ teardown（サインアウト時の `AppState.resetAndRebootstrap`）まで `clear()` を呼ばない前提。
- 検証: 全 feature `compileCommonMainKotlinMetadata` / `:shared:framework:compileKotlinIosSimulatorArm64` / `:androidApp:assembleDebug` green、iosApp `xcodebuild` green（新規警告なし）。**実機での push/pop リーク解消（Instruments の Leaks/Allocations で Bridge 解放確認）はユーザー作業として未実施**。
- 関連 lessons: [`tasks/lessons.md`](./tasks/lessons.md)「画面ごとの ViewModel に app-wide scope を共有させない」。

## 2026-06-24 - E-1 アカウント削除時の Apple トークン失効（revoke）実装

- 領域: iOS 単独（KMP / commonMain 変更なし）/ 関連: `AppleSignInCoordinator.swift`・`AuthRepositoryIosImpl.swift`・`AccountView.swift`・`AccountViewModelBridge.swift`
- 背景: App Store ガイドライン 5.1.1(v)「Sign in with Apple を使い、かつアカウント削除を提供するアプリは削除時に Apple トークンも失効する」。`tasks.md` バックログ E-1 → フェーズ 5.2 に移管して実装。
- 確定したアーキテクチャ判断: **iOS 単独タスク**。`revokeToken` / `reauthenticate` / Apple 再サインイン UI はすべて FirebaseAuth iOS SDK + Apple UI の責務であり、KMP の `DeleteAccountUseCase`（記録削除 → `currentUser.delete()`）はプラットフォーム非依存のまま据え置く。Swift 側が「Apple 再サインイン → reauth → revoke」を **KMP 削除 UseCase 呼び出しの前段**でオーケストレーションする。`AuthRepository` interface は無変更。
- なぜ削除時に再サインインするか: `Auth.auth().revokeToken(withAuthorizationCode:)` には Apple の **authorization code（一度きり・約 5 分有効・保存禁止）**が必要。保存できないため削除時に Apple サインインをやり直して取得する。この再サインインで得た credential での `reauthenticate` は、旧 `deleteAuthUser` が将来課題として残していた `requiresRecentLogin` も同時に解消する。
- フロー（Apple 連携 `!isAnonymous && providerLabel == "apple.com"` のときのみ。匿名は従来通り revoke なし）:
  1. `AppleSignInCoordinator.signIn(anchor:)` → `(idToken, rawNonce, authorizationCode)`（戻り値を 3-タプルに拡張。`ASAuthorizationAppleIDCredential.authorizationCode` を `Data → UTF-8 String`）
  2. `AuthRepositoryIosImpl.reauthenticateAndRevokeAppleToken(...)`（非 protocol メソッド）で `currentUser.reauthenticate(with:)` → `Auth.auth().revokeToken(withAuthorizationCode:)`
  3. 既存 `viewModel.onDeleteAccountTapped(userId:)`（KMP 削除）
  4. `PhotoFileStore.deleteAllPhotos()` + `onResetRequested()`
- エラー方針: ユーザーが再サインインをキャンセル（`ASAuthorizationError.canceled`）→ **無音中断**（削除しない）。reauth / revoke 失敗 → **エラー表示して削除中断**（コンプライアンス上 revoke 必須のため、revoke できないなら削除しない）。
- 実装メモ:
  - `AccountViewModelBridge.isProcessing` を stored → computed（`isKmpProcessing || isPreflighting`）に変更。Swift 側 preflight（Apple UI〜revoke）中も同じ処理中オーバーレイを出す。`@Observable` は computed getter 経由の stored 参照を追跡するため再描画は正しく走る。preflight 制御は `onDeletePreflightStarted/Cancelled/Succeeded/Failed` の 4 メソッド。
  - `AuthRepositoryIosImpl` は AccountView 内で `private let authHelper = AuthRepositoryIosImpl()` として new。当該メソッドは `Auth.auth()` グローバル経由でステートレスのため AppState/AppContainer 配線追加は不要。将来テスト可能性が欲しければ専用 protocol + DI に切り出す余地あり。
- **前提（ユーザー作業・revoke 機能成立の必須条件）**: `revokeToken` は Firebase が Apple の revoke エンドポイント（`appleid.apple.com/auth/revoke`）をサーバサイドで叩くため、Firebase Console → Authentication → Apple プロバイダの **OAuth コードフロー設定**の登録が必要。手順: ① Apple Developer で Sign in with Apple 用 Key（.p8）作成 → Key ID / Team ID 控え、② Apple Developer で **Services ID** 作成（Identifier は bundle ID と別の逆ドメイン例 `com.noricoffee.coffeevision.signin`、Configure で Primary App ID = bundle ID / Return URL = `https://coffeevision-a54aa.firebaseapp.com/__/auth/handler`）、③ Firebase Console に **Services ID / Apple Team ID / Key ID / 秘密鍵** の 4 つを入力。**未設定だと `revokeToken` は常にサーバエラー → 実装上は「revoke 失敗 → 削除中断」**になる。App Store 審査前に必須。これは 2026-06-17 エントリ（ネイティブ用途では Apple プロバイダの「有効化」のみで足りる）の例外で、revoke を使うなら鍵 + Services ID 登録まで必要になる点に注意。
  - **Services ID 欄について**: Apple のプロトコル上はネイティブ iOS の authorization code の client_id は bundle ID で、Services ID（Web / Android フロー用 client_id）は本来 revoke に不要。ただし **Firebase Console の OAuth コードフロー設定は 4 項目を 1 セットで検証**し、Team ID を入れると Services ID も必須入力になる（空のままでは保存不可）。よって実運用上は Services ID を作成して入力する必要がある（Console の UI 要件が Apple プロトコルの最小要件に勝る）。

## 2026-06-25 - Sign in with Apple ボタンのダークモード視認性修正

- 領域: iOS / 関連: `AccountView.swift`（`anonymousSection` + Preview 用 `AccountViewDemo`）
- 問題: 「Apple でサインイン」ボタンが背景 `Color.primary.opacity(0.9)` + 前景 `.white` だったため、ダークモードで `Color.primary` が白になり「白背景 + 白文字」で不可視（ユーザー報告で発覚）。
- 修正: 公式 `SignInWithAppleButton` は nonce 管理の都合で使わずカスタム `Button` のままにし、視覚スタイルのみ `@Environment(\.colorScheme)` で明示分岐。ライト = 黒背景 + 白文字、ダーク = 白背景 + 黒文字 + `Color(.separator)` 1pt ボーダー（Apple HIG 慣習）。`startAppleSignIn()` フロー・`.buttonStyle(.plain)`・44pt 以上タップ領域・`accessibilityLabel` は不変。Preview ダミー `AccountViewDemo` にも同スタイルを適用。
- 検証: `xcodebuild -sdk iphonesimulator` BUILD SUCCEEDED・新規 warning ゼロ。ライト/ダーク両モードの目視はユーザー作業。
- 関連 lessons: [`tasks/lessons.md`](./tasks/lessons.md)「ボタン背景に `Color.primary` を使うとダークモードで不可視になる」。
- 余談（別タスク）: `AppleSignInCoordinator` の `presentationAnchor(for:)` 最終フォールバックに残る到達不能な `UIWindow()`（ゼロ引数 init）が iOS 26 deprecated warning を出している。2026-06-24 に主経路は `UIWindow(windowScene:)` 化済だが最終 return が未修正。視認性修正のスコープ外、警告 1 件として残置。
- 検証: `xcodebuild -sdk iphonesimulator -scheme iosApp build` BUILD SUCCEEDED（新規 warning ゼロ）。KMP 変更なし。**シミュレータでは Apple サインイン UI が制限されるため、E-1 フロー全体（再サインイン → reauth → revoke → 削除 → リブート、キャンセル中断、Console 未設定時の revoke 失敗エラー）の動作確認は実機が必須**。

## 2026-06-25 - カフェ検索: テキスト検索にマップ中心の位置バイアスを適用

- 領域: iOS + KMP / 関連: `CafeSearchViewModel`（feature/cafe-search）、`AppState.swift` / `MapTabView.swift` / `CafeSearchViewModelBridge.swift` / `CafeSearchView.swift`
- 背景: 検索タブのテキスト検索は位置バイアスなしで結果が現在地寄りになりやすい。「マップで見ているエリア寄り」にしたいが検索タブに地図は無いため、マップタブのカメラ中心を `AppState` でタブ間共有してバイアスに使う。
- 仕様確定（ユーザー選択）: 候補 3 案（①マップタブに「このエリアを検索」/ ②検索タブに小地図を追加 / ③テキスト検索に位置バイアス）から **③ テキスト検索に位置バイアス（タブ間で中心共有）** を採用。
- 実装:
  - ドメイン層変更なし（既存 `CafeRepository.searchText(query, LocationBias)` を利用）。
  - KMP: `CafeSearchViewModel` に `onSearchTapped(latitude, longitude, radiusMeters)` を追加（既存 `onSearchTapped()` はフォールバックとして維持）。両者 + `onNearbySearchRequested` で重複していた検索本体を `private fun launchSearch(errorMessage, producer)` に共通化（Job キャンセル → isLoading/error/results/hasSearched 遷移 → CancellationException 先行 catch）。SKIE 経由 Swift 名は `onSearchTapped(latitude:longitude:radiusMeters:)`。
  - iOS: `AppState.mapSearchCenter: MapSearchCenter?`（settable observable）をタブ間バスに。`MapTabView` の `.onMapCameraChange(frequency: .onEnd)` で `region` から更新。`CafeSearchView.runSearch()` が中心の有無でバイアスあり/なしを分岐（onSubmit / toolbar 検索ボタン両方を集約）。「現在地で検索」（searchNearby）は対象外で不変。
- radius 算出式（トレードオフ）: `region.span` から `latMeters = latitudeDelta*111_000/2` と `lngMeters = longitudeDelta*111_000*cos(lat)/2` の**大きい方**を半径に採用し `1...50_000` m にクランプ（Places locationBias circle 制約）。Places の locationBias は hard constraint でなく bias なので「広め側に倒す」判断。小さい方だと地図を引いた状態でバイアスが狭すぎて効きが弱まるため不採用。
- mapSearchCenter の nil 初期値: 起動後マップ未表示なら nil → バイアスなし検索にフォールバック（マップを見ていないならバイアスを掛けない、が自然）。現在地デフォルト注入は権限フロー連動が複雑なので見送り。
- 検証: KMP `./gradlew :shared:feature:cafe-search:allTests` BUILD SUCCESSFUL（android/iosSimulatorArm64 各 13 テスト green、新規 2）。iOS `xcodebuild -sdk iphonesimulator -scheme iosApp build` BUILD SUCCEEDED（新規 warning ゼロ）。**実機/シミュレータ目視（地図を別エリアにパン → 検索タブで検索 → そのエリア寄りの結果 / マップ未表示時はバイアスなしフォールバック / CoffeeEditor sheet 経由のコールバックモード不変）はユーザー作業**。
- 余談（別タスク・要追跡）: kmp-engineer が cafe-search の commonTest で `UncompletedCoroutinesError` を発見。所有 viewModelScope（`SupervisorJob` 子スコープ）を持つ VM を `runTest { this }` 配下でテストすると scope が `TestScope` の子として生存し続けてエラーになる。`finally { vm.clear() }` で解消。**cafe-search は修正済だが、同パターン（所有 viewModelScope + clear()）を持つ他 feature の既存テストも同じエラーで落ちている可能性が高い**。横展開調査は別タスク。lessons.md 参照。

## 2026-06-25 - カフェ検索: 現在地系を撤去しテキスト検索のみに整理 + observation 停止バグ修正

- 領域: iOS / 関連: `CafeSearchView.swift`（Kotlin / SharedLogic 変更なし）
- 背景: 上記「マップ中心の位置バイアス」導入後、検索タブに残っていた現在地周辺検索（右上 `location.fill` ボタン + `.onChange(location)` 自動検索）が役割重複し混乱の元になった。ユーザー報告 3 件: ①検索が 1,2 回後に効かなくなる ②開いた時点で（検索前に）現在地周辺が出る ③右上ボタン 2 つ（現在地 / 検索）が冗長・意図不明。
- 【バグ修正・最優先】検索が止まる原因: `CafeSearchView` の `.onDisappear { bridge.cancel() }`。`bridge.cancel()` は Kotlin `StateFlow` の `observationTask` を止める。検索結果タップ → `CafeDetailView` push → 戻る、または他タブ切替 → 戻る、で `onDisappear` が発火し observation が停止。タブルートの `CafeSearchView` は再生成されず `startObservation()` が二度と呼ばれないため、以降 Kotlin の検索結果が Swift に反映されなくなる（「1,2 回はできたが止まる」の正体）。→ `.onDisappear { bridge.cancel() }` を**削除**。observation は `CafeSearchViewModelBridge.deinit` の `kotlin.clear()` まで生かす。タブルートは View 非破棄で observation 永続、sheet モード（CoffeeEditor 経由）は sheet 閉じ → View 破棄 → deinit で自然に回収。
- 仕様確定（ユーザー選択）: 3 案（①現在地系を全撤去 / ②検索ボタンのみ残す / ③現在地検索を残す）から **① 現在地系を全撤去** を採用。
- 撤去内容（`CafeSearchView.swift`）: 右上 toolbar trailing（現在地アイコン + 「検索」ボタンの HStack）を削除（leading「キャンセル」は sheet 用に残置）。`.onChange(of: locationManager.lastLocation?.latitude)` 削除。`@State locationManager` / `showingLocationDeniedAlert` / `handleNearbyTapped()` / 位置情報拒否 alert を削除。`activeToast`（bridge.error + locationManager.error 集約）を削除し `.errorToast(message: bridge.error)` 直書きに。検索発火は `.onSubmit(of: .search) { runSearch() }` のみに集約。初期表示は既存 `hasSearched` ベースのまま（自動現在地検索が消え、確定まで初期プロンプトのみになる）。マップ中心バイアス（`runSearch()` / `mapSearchCenter` / `.onMapCameraChange`）は維持。
- 残置（別タスク）: `CafeSearchViewModelBridge.onNearbySearchRequested` と Kotlin `CafeSearchViewModel.onNearbySearchRequested` は未使用になったが今回は残置。API 削除は別タスクで kmp-engineer dispatch が必要。
- 検証: `xcodebuild -sdk iphonesimulator -scheme iosApp build` BUILD SUCCEEDED（新規 warning ゼロ。`AppIntents` warning は既存）。**実機/シミュレータ確認はユーザー作業**: (a) 検索 → 詳細 push → 戻る → 再検索が反映される（バグ修正の主眼）/ (b) 他タブ往復後も再検索が反映される / (c) 初期は「カフェ名で検索してください」プロンプトのみ / (d) return で検索発火 / (e) CoffeeEditor sheet 経由のカフェ選択が壊れていない。
- 関連 lessons: [`tasks/lessons.md`](./tasks/lessons.md)「タブ常駐 View の `@State` ブリッジ observation を `onDisappear` でキャンセルしない」。

## 2026-06-26 - iOSDC LT: 逆方向変換 PoC（言葉→数値）を Foundation Models で実装

- 領域: iOS（iosApp 内で自己完結・KMP/domain 変更なし）/ 関連: `TastePreferenceExtractor.swift`（新規）・`TastePreferenceConversionView.swift`（新規）・`AnalysisView.swift`（DEBUG 導線追加）
- 背景: iOSDC LT のテーマを「好みの言語化（片方向）」から「数値⇄言葉の双方向変換」に拡張（仕様は `docs/talks/iosdc-2026-foundation-models.md` §5）。順方向（`CoffeeInsightOutput`: データ→言葉）は実装済みのため、逆方向（自由文→構造化データ）を登壇デモ用に新規 PoC 実装。
- 設計: 順方向 `CoffeeInsightProviderIosImpl` と同じ availability ガード（`SystemLanguageModel.default.availability == .available` の `makeIfAvailable()`）・`@available(iOS 26.0, *)`・ステートレス `LanguageModelSession` を踏襲。`@Generable struct TastePreference`（5軸 Int 1〜10 + roast String + summary）を `respond(to:generating:)` で抽出。**順は出力に5軸を持たず（語り口に型）、逆は出力に5軸を持つ（抽出スキーマ）= `@Generable` に5軸が「ある/ない」が変換の向きを表す**（LT S7 の対比ネタの実体）。
- トレードオフ / 論点:
  - **`TastePreference` の `Equatable` 手書き**: `@Generable` マクロは現時点で `Equatable` を自動合成しない。`ExtractionState.done(TastePreference)` を `Equatable` enum の case にするため `==` を手書き（全フィールド比較・`TastePreferenceConversionView.swift`）。将来 `@Generable` が `Equatable` 合成をサポートしたら削除可。
  - **言及のない軸は 5（中庸）** とする instructions 設計。数値は推測可だが大げさにしない方針。実機での抽出品質（数値が収まるか・summary が 20〜40字か）は要実機確認（シミュレータは `availability` が `.available` にならず推論不可）。
  - **導線は `#if DEBUG` + `if #available(iOS 26)` の二重ガード**で分析タブ末尾に配置。本番ナビゲーションへの恒久配線はせず、登壇デモ/スクショ取得用の最小構成（PoC のため）。抽出結果を検索につなぐ処理は未実装（概念で口頭説明）。
- 検証: `xcodebuild -sdk iphonesimulator -scheme iosApp build`（iPhone 17 Pro / iOS 26.1）BUILD SUCCEEDED・新規 warning ゼロ。SourceKit が `No such module SharedLogic`・型チェックタイムアウト等を出すが、既存ファイルにも出る**インデクサ起因の偽陽性**（実 xcodebuild は成功）。**実機での推論動作・抽出品質確認はユーザー作業**。
- 既知の軽微点: `arrow.trianglehead.2.clockwise` の SF Symbol が iOS 26 で表示されるか未確認（SF Symbol 名は文字列のためコンパイルは通る）。表示されなければ `arrow.2.circlepath` 等に差し替え。
- 親メモ: 同種の「@Generable は出力整形にも自然文抽出にも同じ API で使える双方向の道具」という気づきが溜まったら `coding-conventions.md` か `kmp-bridge.md`（FM 節）への昇格を検討。

## 2026-06-29 - フェーズ 10-C: 検索結果マップオーバーレイ

- 領域: KMP（MapViewModel）+ iOS（MapViewModelBridge / AppState / CafeSearchView / MapTabView）
- **設計**: AppState 経由。`AppState.updateMapSearchResults([Cafe])` / `clearMapSearchResults()` → `MapViewModelBridge.onSearchResultsUpdated/Cleared()` → KMP `MapViewModel.onSearchResultsUpdated/Cleared()` → `UIState.searchResultPlaces`。共有リポジトリや ViewModel 間直結は避け、既存の `mapSearchCenter` と同じ AppState 経由パターンを踏襲。
- **UX 方針**: 「マップに表示」明示ボタン方式（自動反映なし）。ルートモード（`onCafeSelected == nil`）かつ検索結果 > 0 のとき toolbar left に表示。コールバックモード（VisitEditor sheet）では表示なし。クエリ変化時（`onChange(of: bridge.query)`）に前の検索結果を自動クリア。タブ離脱時はクリアしない（意図的にマップに表示させた結果を保持）。
- **ピン**: 青 Circle（32pt）+ `mappin.and.ellipse`（shadow あり）。4 種体系: 訪問済み（36pt 茶）/ 好み一致（38pt アクセント）/ 検索結果（32pt 青）/ Apple Maps 標準 POI。重複除去なし（同 placeId のピンは重なる）。
- **クリアタイミングの判断**: `onChange(of: bridge.query)` = Kotlin 側の state 反映後にクリア。`queryText`（ローカル即時）ではなく Kotlin 側を監視することで、入力中の文字ごとにクリアが走らない。

## 2026-06-30 - マップ内検索バー（検索タブ廃止・Google Maps スタイル）

- 領域: iOS
- **背景**: iOS 27 で `Tab(role: .search)` の右端固定動作が廃止され、通常タブと地続きになったため、検索を マップタブ内に移設して Google Maps スタイルの UX に作り替えた。
- **変更概要**: 検索タブ削除 → 3 タブ（マップ・コーヒー・分析）。マップ上部に常時表示の検索バー（TextField + regularMaterial 背景）。検索実行 → 結果リストがマップ上にドロップダウン表示 → 結果タップ → 当該地点へカメラ移動 + 青ピン + 下部カード（`safeAreaInset`）→「詳細を見る」で CafeDetail push。
- **`CafeSearchViewModelBridge` の再利用**: 新たな KMP 変更なし。MapTabView 内で `.task` 初期化時に `appState.container.makeCafeSearchViewModel()` を生成し `@State private var searchBridge` として保持。検索実行は `performMapSearch()` → `appState.mapSearchCenter`（カメラ位置バイアス）を流用。
- **`TabBarFrameReader` 削除**: 検索タブフレームを読み取る `UIViewRepresentable` ハックが不要になったため削除。MapTabView と CoffeeListView の FAB を `overlay(alignment: .bottomTrailing)` + padding 固定に変更。
- **上部コントロール高さ 120pt の固定 Spacer**: 検索バー + フィルタ行高さ合計を 120pt で見込む。Dynamic Type 最大サイズでは不足する可能性あり。実機確認後 `GeometryReader` 動的計測に差し替えを検討。
- **`CafeSearchView` のコールバックモード維持**: エディタ内「カフェを選択」sheet は `init(appState:onCafeSelected:)` を引き続き使用。ルートモード `init(appState:)` は削除。`onCafeSelected` は optional のまま（将来的に非 optional 化余地あり）。
- **削除した AppState API**: `updateMapSearchResults(_:)` / `clearMapSearchResults()`。MapTabView が `appState.mapBridge` を直接呼ぶ。`mapSearchCenter` は MapTabView の `.onMapCameraChange` が引き続き更新。
- 検証: `xcodebuild iphonesimulator` BUILD SUCCEEDED。**シミュレータでの目視確認（検索バー→ドロップダウン→下部カード→詳細遷移）はユーザー作業**。

## 2026-06-30 - フェーズ 10-D: タグフィルター（ドメインモデル変更 + UI）

- 領域: KMP（domain / data-local / data-firebase / feature-editor / feature-map）+ iOS
- **`CoffeeRecord.tags: List<String>`**: デフォルト値 `emptyList()` 付きで追加。SQLDelight スキーマに `tags TEXT NOT NULL DEFAULT ''` を追加（JSON 配列文字列として保存。`photoRefsSerializer` 流用）。Android Firestore Mapper にも `tags` 追加（read/write）。クリーンブレイク対応（アプリ削除→再インストール必須）。`VisitedCafe` にタグを持たせるのではなく `CoffeeRecord` 側に持たせることで、カフェ粒度でなくコーヒー記録粒度でタグ付けする設計を採用。
- **KMP `CoffeeEditorViewModel`**: `CoffeeDraft.tags: List<String>` 追加。`onTagAdded(tag)` / `onTagRemoved(tag)` 追加。`buildRecord/toDraft/defaultDraft` を更新。
- **KMP `MapViewModel`**: Constructor に `coffeeRepository: CoffeeRepository` を追加し DI。`UIState.selectedTags: Set<String>` / `UIState.availableTags: List<String>` 追加。`coffeeRecords` Flow を `visitedCafes` と別途収集し、`applyTagFilter()` を直接呼ぶキャッシュ変数パターンを採用（`combine` に `MutableStateFlow` を含めると `runTest` タイムアウトするため）。`onTagFilterToggled/Cleared()` 追加。
- **iOS `MapViewModelBridge`**: `selectedTags: [String]` / `availableTags: [String]` + `onTagFilterToggled/Cleared()` 追加。Kotlin `Set<String>` は SKIE により Swift `Set<String>` として公開され `Array(state.selectedTags)` で変換。
- **iOS `CoffeeEditorViewModelBridge`**: `tags: [String]` + `onTagAdded/Removed()` 追加。`apply(_:)` に `state.draft.tags` 反映。
- **iOS `CoffeeEditorView`**: テイスティングセクション後に「タグ」セクション追加。既存タグ削除行 + `TextField` + 追加ボタン。`@State private var newTagText` で入力管理。`onSubmit` とボタン両経路で `addTag()` 呼び出し。
- **iOS `MapTabView`**: フィルタ行を `ScrollView(.horizontal)` でラップ。`availableTags` が空でないとき Divider + タグチップ群 + クリアボタン（`xmark.circle`）を追加。
- Swift 側 `CoffeeRecord` コンストラクタ追随: SKIE の制約（Kotlin デフォルト引数は Swift に引き継がれない）で `CoffeeFirestoreMapper.swift` (line 165) と `PreviewSamples.swift` (3 箇所) に `tags: []` / `tags: (data["tags"] as? [String]) ?? []` を明示追加。
- **`MapViewModelPoiLookupTest` 修正**: `combine` + `MutableStateFlow` タイムアウト対策で選択タグ管理をリファクタ後、テスト全 7 件に `coffeeRepository = fakeCoffeeRepo` と `vm.clear()` を追加して `UncompletedCoroutinesError` を解消。
- 検証: `:androidApp:assembleDebug` BUILD SUCCESSFUL、`mapViewModel` / `data-local` テスト PASS、`xcodebuild iphonesimulator` BUILD SUCCEEDED。**シミュレータ目視（タグ入力 / マップフィルタ）はユーザー作業。クリーンブレイクのためアプリ削除→再インストール必須**。

## 2026-06-29 - フェーズ 10-A/B: マップピン再設計 + Places API 追加フィールド

- 領域: iOS（10-A）/ KMP + iOS（10-B）
- **10-A マップピン再設計**: `visitedCafePin` を 32pt→36pt に拡大し、`shadow(color: .brown.opacity(0.4), radius: 4, x: 0, y: 2)` を追加（`recommendedCafePin` と対称）。訪問回数 2 回以上で右上に白背景 + 茶テキストのバッジを `.overlay(alignment: .topTrailing)` で表示（9+ 上限）。3 種ビジュアル体系: 訪問済み（36pt 茶 + カップ + 回数バッジ）/ 好み一致（38pt アクセント + ハート）/ Apple Maps 標準 POI（変更なし）。
- **10-B KMP**: `Cafe` ドメインモデルに `openNow: Boolean?` / `weekdayDescriptions: List<String>` / `phoneNumber: String?` / `priceLevel: String?` / `googleRating: Double?` を **デフォルト値付き** で追加。Places API `FIELD_MASK` / `DETAILS_FIELD_MASK` を拡張（`currentOpeningHours`, `nationalPhoneNumber`, `priceLevel`, `rating`）。SQLDelight スキーマは変更なし（`CoffeeRecord.cafe` スナップショットには新フィールドは含まれず、Places API 結果のみで利用可能）。
- **10-B iOS `CafeDetailView`**: `cafeInfoSection` に営業状態（緑/赤 dot）・Google 評価・価格帯（¥〜¥¥¥¥ 変換）・電話番号（`tel:` Link）を追加。「外部リンク」セクション（公式サイト / Google Maps）・「営業時間」セクション（`weekdayDescriptions` が空でないとき）を追加。セクション順: カフェ情報 → 外部リンク → 営業時間 → コーヒー記録。
- 注意: `foregroundStyle(.accentColor)` は `ShapeStyle` に `.accentColor` メンバが存在しないためコンパイルエラー。`Color.accentColor` を明示する必要がある（プロジェクト全体で統一済み）。
- **クラスタリング（将来課題）**: MapKit SwiftUI の `Map` + `Annotation` は `MKClusterAnnotation` 相当の SwiftUI ネイティブ API を持たない。実装するには `UIViewRepresentable` 経由の `MKMapView` ラッパが必要で、現状の SwiftUI ファースト方針と相反する。ピン密集が実際の問題になった時点で再検討。
- Swift 側 `Cafe` コンストラクタ呼び出し: Kotlin のデフォルト引数は SKIE 越えで Swift デフォルト引数に変換されない。`Cafe` 構築側（`CoffeeFirestoreMapper.swift` / `PreviewSamples.swift`）すべてに `openNow: nil, weekdayDescriptions: [], phoneNumber: nil, priceLevel: nil, googleRating: nil` を明示追加した。

## 2026-06-26 - 冗長な可用性ガード除去 + 逆変換 PoC 導線の表示方針

- 領域: iOS / 関連: `TastePreferenceExtractor.swift`・`TastePreferenceConversionView.swift`・`CoffeeInsightProviderIosImpl.swift`・`SearchCoffeeRecordsTool.swift`・`AnalysisView.swift`・`AppState.swift`
- 背景: アプリは `IPHONEOS_DEPLOYMENT_TARGET = 26.0`（iOS 26 専用）かつ未リリース。Foundation Models 導入時に付けた `@available(iOS 26.0, *)` / `if #available(iOS 26, *)` は全て冗長、PoC を「本番で隠す」目的の `#if DEBUG` も未リリースなら不要、というユーザー方針で sweep。
- 除去: 全ファイルの `@available(iOS 26.0, *)`（型宣言・Preview 連鎖含む）と `if #available(iOS 26, *)` 分岐を除去。`AnalysisView` の逆変換 PoC デモ導線は `#if DEBUG` + iOS 26 else の二重ガードを外し、常時表示の `private var` に統一。`AppState.init` の `#available` ラップクロージャも直接呼び出しに簡略化。
- 残した `#if DEBUG`（意図的）: ①`#Preview` / `PreviewSamples` 等の Xcode Preview 補助（リリースバイナリ除外目的・未リリースでも本来必要）②`AppState` の `seedOrClearDummyData`（`SEED_DUMMY_DATA` dev ツール。RELEASE で毎起動すると `dummy-0001`〜`0030` を削除する破壊的副作用があるため dev 専用に留める）。
- **要追跡（リリース前の意思決定）**: 逆変換 PoC 導線（`TastePreferenceConversionView` への NavLink）は現在 DEBUG ゲートを外し分析タブ最下部に**全ユーザー常時表示**。iOSDC LT デモ用の画面なので、App Store リリース前に「本番に含める / 設定>開発者向けに移動 / 削除」のいずれかを決めること。
- 検証: `xcodebuild -sdk iphonesimulator -scheme iosApp build` BUILD SUCCEEDED（新規 warning ゼロ）。SourceKit の `No such module SharedLogic` 等はインデクサ偽陽性（実ビルド成功）。**分析タブ最下部に PoC 導線が常時表示されることの目視はユーザー作業**。
- 関連 lessons: [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-26「ターゲットを上げたら冗長な @available を即 sweep」。

## 2026-06-30 - フェーズ 12-A: データ共有同意フロー

- 領域: KMP（domain / data-firebase）+ iOS + Firestore Rules
- **背景**: フェーズ 12「コミュニティ/データ共有基盤」の前提として、将来の集計パイプライン（12-B〜D）でユーザーの記録データをサービス改善に活用するための同意フローを実装する。App Store ガイドラインおよびプライバシー規制（GDPR 等）への準拠も目的。
- **consent フラグの保存先**: Firestore `users/{uid}` ルートドキュメント（`analyticsConsent: Boolean`）を採用。理由: ①将来の Firestore Security Rules で「同意済みユーザーの集計コレクションへの書き込み」を条件付きで許可するために Firestore 側に必要 ②デバイス間で同意状態を共有できる（買い替え時に再同意不要）③iOS 端末の `UserDefaults` で管理すると Rules と乖離が生じる。
- **`users/{uid}` ルートドキュメントの既存状況**: 現状 `coffees` サブコレクションしか存在しないため、`users/{uid}` ルートドキュメント自体は未使用。今回が初の利用。Firestore Rules の `{document=**}` ワイルドカードはサブコレクションのみを対象とし、ルートドキュメントへの write には別途 `match /users/{uid}` ルールが必要（Rules 要更新）。
- **初回オンボーディングの判断**: Firestore に `users/{uid}` ドキュメントが「存在しない」= 未同意・初回ユーザーとして扱い、オンボーディング画面を表示。`analyticsConsent: false` が明示的に書き込まれている場合は「非同意済み」として表示しない。iOS の `@AppStorage` は補助的に使わない（Firestore を権威ソースとする）。
- **オンボーディング UI の配置**: 初回起動時に `AppState.bootstrap()` の uid 確定後、`users/{uid}` ドキュメントの存在確認を行い、非存在なら `.sheet` でオンボーディング画面を表示。後から変更できるよう `SettingsView` にも同意トグルを追加。
- **`AuthAccount` への追加**: `analyticsConsent: Boolean = false` フィールドを追加。`observeAccount()` の emit に consent 状態を含める。`observeAnalyticsConsent()` は `observeAccount().map { it?.analyticsConsent ?: false }` でも実装可能だが、`AuthRepository` に独立した Flow として公開してシンプルに使えるようにする。
- **Firestore Rules の更新方針**: `users/{uid}` ルートドキュメントと `{document=**}` サブパスを分けて明示的に記述。将来の集計コレクション向けルール（`analyticsConsent == true` 条件付き書き込み許可）はフェーズ 12-B 以降で追加。
- **プライバシーポリシー URL**: `DataConsentOnboardingView` は placeholder リンクで実装し、App Store 申請前にユーザーが実際の URL に差し替える（`app-store-metadata.md` のチェックリストに明記済み）。

## 2026-06-30 - フェーズ 12-A: `observeAccount()` の flatMapLatest 合成パターン採用

- 領域: KMP（data-firebase androidMain）
- `AuthRepository.observeAccount()` に `analyticsConsent` を組み込む際、`combine(observeAuthState(), observeAnalyticsConsent())` 案ではなく `flatMapLatest` を採用。`combine` では `observeAnalyticsConsent()` が未サインイン時に `close()` すると合成 Flow も終了してしまうため、`flatMapLatest(observeFirebaseUser())` で auth 変化時に Firestore リスナを自動切替する設計を選択。
- `observeAccount()` / `observeAnalyticsConsent()` は内部ヘルパ `observeFirebaseUser()` / `observeConsentForUser(uid)` を共有する構造。Firestore リスナは両メソッドを同時購読すると 2 本立つ（現状問題なし。将来 `shareIn` でホット化して共有することを検討候補）。

## 2026-06-30 - フェーズ 12-A: iOS 側 consent 実装方針

- 領域: iOS（iosApp）
- `AuthRepositoryIosImpl.observeAnalyticsConsent()` は `CallbackFlow<KotlinBoolean>` + `SkieKotlinFlow` でブリッジ（`RemoteCoffeeDataSourceIosImpl.observeChanges` と同パターン）。`SkieSwiftFlow<KotlinBoolean>` を返す。
- `AppState` は `observeAnalyticsConsent()` Flow を直接購読せず、`checkConsentOnboarding(uid:)` で Firestore `getDocument()` を一度呼ぶことでオンボーディング判断を行う（同意 Flow 購読は過剰）。`analyticsConsent` の変化観察は今回スコープ外（Settings の Toggle は imperative な `updateAnalyticsConsent` で済む）。
- オンボーディング Binding: `.sheet(isPresented:)` + `interactiveDismissDisabled()` を組み合わせてスワイプ閉じを防止。閉じはボタン（`onConsentGranted()` / `onConsentDeclined()`）からのみ。
- `AuthRepositoryIosImpl.makeAuthAccount` の `analyticsConsent:` には常に `false` を渡す（observeAccount は Firebase Auth state のみ監視し Firestore を二重購読しない設計）。

---

### 2026-06-30: CoffeeRecordFilter.tastingMin/Max の tasting=null レコードの扱い（Phase 13-A-2）

- 領域: KMP（shared/domain）
- `tastingMin`/`tastingMax` のいずれかが指定されている場合、`record.tasting == null`（テイスティング未記録）のレコードは除外する。`rating=0.0` を評価範囲フィルタから除外するのと同じ思想（未記録を「記録済み」として誤ヒットさせない）。
- 各軸（sweetness/body/acidity/flavor/aftertaste）は独立して評価する（全5軸がそれぞれ範囲内に収まることが条件）。
- Phase 13-A-3 で iOS 側が `TastePreference`（Foundation Models 出力）→ `CoffeeRecordFilter` に変換する際、`tastingMin`/`tastingMax` に `TastingScores(max(1, axis-margin), ...)` / `TastingScores(min(10, axis+margin), ...)` を渡す（margin = 2 予定）。

---

### 2026-06-30: CoffeeRecordFilter 新フィールド追加時の Swift 呼び出し側の全更新が必要（Phase 13-A-3）

- 領域: KMP/iOS ブリッジ
- Kotlin data class に nullable フィールドをデフォルト値付きで追加した場合でも、Kotlin/Native が生成する Obj-C initializer は全パラメーター必須になる（Kotlin のデフォルト引数は Swift に伝播しない）。SKIE 0.10.12 では DefaultArgumentInterop を有効化していないため、`CoffeeRecordFilter(...)` を呼ぶ既存 Swift コード（`SearchCoffeeRecordsTool` 等）に `tastingMin: nil, tastingMax: nil` の追記が必要だった。
- 今後 `CoffeeRecordFilter` に新フィールドを追加する場合、Swift 呼び出し側を網羅的に更新する必要がある。SKIE の DefaultArgumentInterop 有効化（`defaultArgumentInterop { enabled = true }` in `build.gradle.kts`）を検討すると、この問題が自動解消される。
