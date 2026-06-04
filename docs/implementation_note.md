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

### 2026-06-04: Android applicationId を iOS バンドル ID と揃え `com.noricoffee.coffeevision` に統一

- 領域: Android / Build
- 関連: `androidApp/build.gradle.kts`, `androidApp/src/main/kotlin/com/noricoffee/coffeevision/MainActivity.kt`

iOS バンドル ID は `com.noricoffee.coffeevision` だが、Android の `applicationId` / `namespace` は `com.noricoffee` のままになっていた。Firebase Console へのアプリ登録時に齟齬の原因になるため、Android 側を `com.noricoffee.coffeevision` に揃えた。

- `androidApp/build.gradle.kts` の `namespace` / `applicationId` を更新
- `MainActivity.kt` を `com.noricoffee.coffeevision` パッケージへ git mv（履歴保持）
- `App()` Composable は `sharedUI` の `com.noricoffee.App` にあるため、明示的に import 追加

`sharedLogic` のライブラリ namespace（`com.noricoffee.sharedLogic`）と `commonMain` の Kotlin パッケージ（`com.noricoffee.*`）は **applicationId とは別概念** のため、そのまま維持する。共通ライブラリのパッケージは複数アプリから再利用できる名前空間として残しておくのが自然。

トレードオフ: 既存ファイルが少ないうちに統一できたため、影響範囲は MainActivity 1 ファイルのみ。Firebase Console の Android アプリ登録時は新 package で登録すること。
