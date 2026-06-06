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

- CI（GitHub Actions）の iOS 側ビルドコマンドは、`:shared:framework` モジュール未作成のため `:sharedLogic` の iOS framework link タスクで代替している。フェーズ 3.5 で `:shared:framework:assembleSharedFrameworkXCFramework` に差し替える
- `VisitRepository` は `commonMain` で 2 段構成（`RemoteVisitDataSource` interface + `VisitRepositoryImpl` 合成クラス）。プラットフォーム別実装は `RemoteVisitDataSource` だけを書く
- `AppContainer.startInitialSync()` は匿名サインイン → uid 確定 → リモート → ローカル同期購読 を起動コードから 1 行で呼べる。サインアウト時の sync 停止再開は要件発生時に拡張する
- `applicationId` / iOS バンドル ID は `com.noricoffee.coffeevision` で統一する（`sharedLogic` のライブラリ namespace は `com.noricoffee.sharedLogic` のままで OK）
- SKIE 0.10.12 を `sharedLogic` に導入済。**SKIE は呼び出し方向限定**で、Swift で Kotlin interface を実装する側は Obj-C 互換シグネチャ（completion handler / Kotlin Flow 戻り値）を実装する必要がある。Swift で `Flow` を作るには `MutableStateFlow` を直接構築するパターンを第一候補とし、詰まったら `iosMain` にラッパを追加する
- iOS 側 Firebase 実装（`iosApp/iosApp/FirebaseRepositories/`）は Phase 2 で実装済。`SkieSwiftFlow<T>` の Swift 側構築は `_unconditionallyBridgeFromObjectiveC(SkieKotlinFlow(callbackFlow))` 経由（`init(internal:)` が internal アクセスのため直接構築不可）。Visit ドメインモデルは Swift 側で `Visit_`（末尾アンダースコア）として現れる（SQLDelight 生成 `Visit` 行型との衝突回避）
- `AppContainer` は **scope なしの 3 引数セカンダリコンストラクタ** を通常用途（Swift / アプリ起動）とし、4 引数版（scope 注入可）はテスト用途に限定する。SKIE が Kotlin デフォルト引数を Swift に引き出さないため、プライマリのデフォルト値 `= MainScope()` は持たせず用途をコンストラクタ単位で分けている
- Visit 子コレクション（`coffeeItems` / `foodItems` / `photos`）の Firestore 同期は **WriteBatch + 差分削除**（既存子 ID を取得 → 新配列に含まれないものを batch.delete）で原子化。observe は **案 A**（親 visit リスナ 1 本 + 子は snapshot 受信ごとに `getDocuments` 並列）。`sortOrder` はドメインモデルに持たせず、upload 時に配列 index で採番 / decode 時はソートに使ってから破棄。nullable は `null` を入れずキーごと省略。`Photo.localPath` は端末固有値のため Firestore には保存しない
- Firebase Security Rules はリポジトリ管理（`firestore.rules` / `storage.rules` / `firebase.json` / `.firebaserc`）+ `firebase deploy` 運用。Firestore は path uid のみ検証で 2026-06-06 にデプロイ済。Storage Rules はファイルのみ存在し未デプロイ（新規プロジェクトの Storage 有効化が Blaze プラン必須のため、Phase 3 で写真機能と同時に有効化）

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

未確定: `VisitRepository.delete(id)` が userId を取らない問題（Firestore 実装側で uid を逆引きする運用に暫定で寄せている）。必要なら次フェーズでシグネチャを `delete(userId, id)` に変更する。

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
