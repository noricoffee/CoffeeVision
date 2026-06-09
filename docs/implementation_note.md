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
- `AppContainer` は **scope なしの 3 引数セカンダリコンストラクタ** を通常用途（Swift / アプリ起動）とし、4 引数版（scope 注入可）はテスト用途に限定する。SKIE が Kotlin デフォルト引数を Swift に引き出さないため、プライマリのデフォルト値 `= MainScope()` は持たせず用途をコンストラクタ単位で分けている
- Visit 子コレクション（`coffeeItems` / `foodItems` / `photos`）の Firestore 同期は **WriteBatch + 差分削除**（既存子 ID を取得 → 新配列に含まれないものを batch.delete）で原子化。observe は **案 A**（親 visit リスナ 1 本 + 子は snapshot 受信ごとに `getDocuments` 並列）。`sortOrder` はドメインモデルに持たせず、upload 時に配列 index で採番 / decode 時はソートに使ってから破棄。nullable は `null` を入れずキーごと省略。`Photo.localPath` は端末固有値のため Firestore には保存しない
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `storage.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。Firestore は path uid のみ検証で 2026-06-06 にデプロイ済。Storage Rules はファイルのみ存在し未デプロイ（新規プロジェクトの Storage 有効化が Blaze プラン必須のため、Phase 3 で写真機能と同時に有効化）
- `build-logic/convention/` の Convention Plugin（`kmp.library` / `kmp.feature` / `android.library`）は **precompiled script plugin 方式**（`src/main/kotlin/*.gradle.kts`）。`gradlePlugin { plugins.register(...) }` は置かず、`kotlin-dsl` の自動 plugin id 生成に任せる。`build-logic/settings.gradle.kts` で `versionCatalogs.from(files("../gradle/libs.versions.toml"))` を宣言して同一カタログを共有
- `kmp.library` は `jvmToolchain(N)` を付けない。開発機 JDK バージョン依存の罠（Toolchain auto-provisioning 未設定でビルドが落ちる）を避け、`compilerOptions.jvmTarget = JvmTarget.JVM_11` だけで Android 側 JVM target を指定する
- `shared/core` には `AppContainer` と `VisitRepositoryImpl` が居る。`api(projects.shared.dataLocal)` 経由で `AppDatabase` / `LocalVisitRepository` を取り込み、`api(projects.shared.dataFirebase)` で Firebase Repository インターフェースを再公開する。Result / Logger / Dispatcher ラッパは必要が出てきたフェーズで追加（YAGNI）
- `shared/data-local` が SQLDelight プラグイン + `AppDatabase` 宣言の単独管理者。Mapper / DriverFactory expect/actual / LocalVisitRepository を含む。`VisitRepositoryImplTest` は `createInMemoryTestSqlDriver` の expect/actual がここに閉じている制約から、振る舞いの所属（`shared/core`）ではなく `data-local` の commonTest に置く妥協配置
- `shared/data-firebase` は `build.gradle.kts` + Firebase BoM 依存のみの空殻。Android Firebase 実装は未移送（着手は Android Firebase 実装着手時）。iOS 実装は `iosApp` Swift で継続
- 旧 `sharedLogic` モジュールは 2026-06-08 Phase 2.5 PR3 で完全削除済。iOS 向け umbrella は `shared/framework`（baseName / XCFramework 名ともに `SharedLogic`、Swift `import SharedLogic` のまま）。`commonMain.dependencies { api(projects.shared.{core,domain,dataLocal,dataFirebase,feature.visitList}) }` + `framework { export(...) }` 明示 + `linkerOpts("-lsqlite3")`。`assembleSharedLogicXCFramework` で XCFramework 生成、`embedAndSignAppleFrameworkForXcode` を Xcode の Run Script から呼び出し。`sharedUI` も `api(projects.shared.framework)` 経由でこれらを取り込む
- `settings.gradle.kts` の include は `:androidApp` / `:sharedUI` / `:shared:core` / `:shared:domain` / `:shared:data-local` / `:shared:data-firebase` / `:shared:framework` / `:shared:feature:visit-list` / `:shared:feature:visit-detail` / `:shared:feature:visit-editor` の 10 件。`data-places` は Phase 4、`feature/cafe-search` は Phase 4 以降
- `AppContainer` の ViewModel ファクトリ（`makeVisitListViewModel()` など）は **`shared/framework` の拡張関数として配置**する。`kmp.feature` が `feature -> core` を `api` で自動配線するため `core` から `feature` を参照すると循環依存になる。`framework` は全 shared モジュールを `api` で持つ最上位レイヤーなので循環なし。Swift からは Obj-C category として `appContainer.makeVisitListViewModel()` で呼べる。今後 feature を追加するたびにファクトリ拡張を `shared/framework/.../AppContainerViewModelFactory.kt` に追記する
- iOS Bridge は `@MainActor @Observable` クラス + `Task { for await s in kotlin.state { apply(s) } }` パターン（`kmp-bridge.md` §推奨パターン）で実装。SKIE 0.10.12 環境では `UIState.visits` は Swift 側で既に `[Visit_]` 型として取得できるため、`as? [Visit_]` キャストは不要（書くと "always succeeds" / "no effect" 警告）
- Bridge の生存スコープは画面ライフサイクルに応じて 2 パターンを使い分ける: **一覧画面（VisitList）は `AppState` で 1 つ保持**（uid 確定後に 1 度だけ生成、画面再描画でも再生成しない）。**詳細画面（VisitDetail）/ 編集画面（VisitEditor）は View 内の `@State` で遷移ごとに生成・破棄**（それぞれ `appState.container.makeVisitDetailViewModel()` / `makeVisitEditorViewModel()` を呼ぶ、`AppState` にホルダは置かない）。「一覧 = 常時 1 つ」と「Detail / Editor = push/sheet ごとに新規」のライフサイクルの違いを設計に反映している
- `AppState` は bootstrap（匿名サインイン + startInitialSync）と `visitListBridge` 保持に責務を絞り、書き込み系のダミー動作（旧 `writeDummyVisit()` / `Status.writing` / `lastWroteVisitId`）は VisitEditor 完成と同時に削除済。新規 / 編集の動線は `VisitEditorView` の sheet 起動が単一エントリ

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
- `architecture.md` の例コードは `baseName = "SharedFramework"` だが、実装上 Swift 互換性を優先して `SharedLogic` を採用（docs と乖離する判断、docs 側の更新が要る）

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
