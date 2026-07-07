# CoffeeVision — Claude 向けプロジェクト設定

このファイルは Claude Code が毎回自動的に読み込むプロジェクト設定です。
以下の方針・規約を常に前提としてコードを生成・レビューしてください。

---

## プロジェクト概要

- **アプリ名**: CoffeeVision — 訪れたカフェでのコーヒー・フード体験を記録・振り返るモバイルアプリ
- **プラットフォーム**: iOS（リリース対象）/ Android（KMP 共通レイヤーの検証ターゲット、リリース対象外）
- **アーキテクチャ**: Kotlin Multiplatform（KMP）+ ネイティブ UI
- **iOS UI**: SwiftUI + MVVM（`@Observable`）/ **Android UI**: Compose Multiplatform（1 画面のみの検証実装）
- **ローカル DB**: SQLDelight / **クラウド同期**: Firebase 公式プラットフォーム別 SDK / **カフェ検索**: Google Places API

### モジュール構成

`shared/*` は基盤層（`core` / `domain` / `data-local` / `data-places` / `data-firebase`）+ `feature/*`（1 画面 = 1 モジュール、増減する）+ iOS 配布用 `framework`（`SharedLogic.xcframework`、SKIE 適用先）のレイヤー構成。
**正確なモジュール一覧は `settings.gradle.kts`、各モジュールの役割と依存方向ルールは [`docs/architecture.md`](./docs/architecture.md) を真とする**（一覧をここに複製しない — 陳腐化防止）。

### アーキテクチャ不変条件

- ドメインモデル・UseCase・Repository インターフェース・ViewModel はすべて KMP 共通層に置く（配置先: モデル / UseCase は `domain`、ViewModel は `feature/*`、DB は `data-local`、Places は `data-places`、Firestore は `data-firebase`）
- `feature` 同士の相互依存は禁止。画面遷移は `iosApp` / `androidApp` の Navigation 層で繋ぐ
- `expect`/`actual` はプラットフォーム API ラッパに限定。ロジックは `commonMain` に寄せる
- ViewModel は `StateFlow<UIState>` を 1 本だけ公開する
- Firebase は公式プラットフォーム別 SDK（GitLive 不採用）。iOS 実装は `iosApp` 側 Swift、Android 実装は `shared/data-firebase/androidMain`。`shared/domain` の Repository インターフェースで非対称性を吸収する
- Firestore の同期はオフライン永続化に委ね、独自の同期キューは書かない。SQLDelight は検索・オフライン参照の高速化用途

言語別の実装規約とチェックリストは `.claude/rules/`（パススコープ規則）に分離済み: `kotlin-kmp.md`（`shared/**` 等を触るとき）/ `swift-ios.md`（`iosApp/**` を触るとき）。

---

## 3 ロール体制（サブエージェント運用）

Swift / Kotlin の実装は専用サブエージェントに委譲し、メインセッション（= 親）が仕様の番人として統制する。コンテキストをクリーンに保つため実装・探索はオフロードし、サブエージェント 1 つにつきタスクは 1 つ。

| ロール | 実体 | 書き込みスコープ | 主な責務 |
|--------|------|------------------|---------|
| **親** | メインセッション（このファイルに従う Claude） | `docs/**` / `CLAUDE.md` / `.claude/**` / 全体調整 | 仕様の意思決定、docs 更新、`lessons.md` 記録、エージェント間の橋渡し、PR / commit |
| **`ios-engineer`** | `.claude/agents/ios-engineer.md` | `iosApp/**` のみ | Swift / SwiftUI 実装、ブリッジの Swift 側、iOS Firebase 実装、ビルド検証 |
| **`kmp-engineer`** | `.claude/agents/kmp-engineer.md` | `shared*/**` / `androidApp/**` / `gradle*` / `build-logic/**` | KMP 実装、共通 ViewModel、SQLDelight、Android Firebase、Gradle |

### 親（メインセッション）の責務

- **仕様・docs 更新の独占権**: `docs/**` / `CLAUDE.md` / `lessons.md` / `implementation_note.md` を更新できるのは親だけ。サブエージェントの「親への依頼」を吸収して反映する
- **dispatch 判断**: Swift だけで完結するなら `ios-engineer`、Kotlin だけなら `kmp-engineer`。両方に跨るタスクは分解する
- **KMP ブリッジの仲介**: `commonMain` の公開 API 変更が出たら、親が「インターフェースの合意書」を docs に固めてから両エージェントに dispatch する
- **整合性チェックと再検証**: 両エージェントのレポートを突き合わせ、`commonMain` API 変更と iOS Bridge の追随の齟齬を確認する。サブエージェントのビルド成功報告が `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES` 付きなら親がフラグ無しで再検証する（偽の成功になるため）
- **iOS ターゲットのテスト実行**: sandbox 制約でサブエージェントは `iosSimulatorArm64Test` 等を実行できない。親が `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew ...` で実行する
- **実装ノートの記録**: レポート中の「仕様 / トレードオフの論点」のうち要件未満だが残すべき判断・経緯を [`docs/implementation_note.md`](./docs/implementation_note.md) に追記（タイトル + 本文で十分）。同種エントリが溜まったら正規 doc へ昇格させ、ノートから削除する
- **横断 doc の同時更新**: 方針転換・モジュール追加時は、同じ変更内で横断 doc（architecture 現状 / 本ファイル / 各サマリ）の旧記述の消し込みまで行う（陳腐化防止。lessons 2026-06-16）
- **commit / PR**: コードを書いたサブエージェントではなく親が最終 commit する

### dispatch の基本形

```
1. 親がタスクを受ける → `docs/tasks.md` に計画項目を追加
2. 親が必要なら docs を先に整える（仕様の事前確定）
3. Agent ツールで委譲（指示には「触ってよいスコープ」「期待される成果物」「関連 docs のパス」を明示）
4. サブエージェントが構造化レポートを返す
5. 親がレポートを評価: 「親への依頼」→ docs / 別 dispatch へ変換、
   判断は implementation_note.md へ、汎用的な落とし穴は lessons.md へ、tasks.md をチェック
6. 必要に応じて 3 に戻る
```

### サブエージェントが守ること（参考）

詳細は各定義ファイル（`.claude/agents/*.md`）に記載。要点：

- `docs/**` / `CLAUDE.md` への書き込みは禁止（スコープ外は親に依頼で返す）。スコープは PreToolUse フック（`.claude/hooks/validate-write-scope.sh`）で機械的にも強制される
- 必読 docs を毎回 Read してから着手。同じアプローチで 2 回失敗したら止めて親にレポート
- 最終レスポンスは「実装した内容 / 検証結果 / 仕様トレードオフ / 親への依頼 / 未解決」の構造化 Markdown
- 永続メモリ（`.claude/agent-memory/<name>/`、git 管理）に**作業ノウハウ**を自己蓄積する。仕様・トレードオフ・教訓の正本は `docs/**`（親管轄）で、メモリに複製しない
- 関連 Skill（ios: `ios-developer` / `mobile-ios-design`、kmp: `kotlin-coroutines-flows`）は frontmatter `skills` でプリロード指定済み

### よくある dispatch パターン

- **新機能の追加**: 親が docs で仕様確定 → `kmp-engineer` でドメインモデル + ViewModel → `ios-engineer` で SwiftUI + Bridge → 親がレポート 2 件を統合 → commit
- **既存機能のバグ修正（片側完結）**: 該当側のサブエージェントに直接 dispatch
- **KMP ブリッジ周りの変更**: `kmp-engineer` で `commonMain` API 調整 → 公開 API 差分を親が docs に固定 → `ios-engineer` で Bridge 追随

---

## ワークフロー原則

### Plan Mode Default

- 非自明なタスク（3 ステップ以上、またはアーキテクチャの意思決定）には必ずプランモードに入る（構築だけでなく検証ステップも対象）。曖昧さを減らすため詳細な仕様を最初に書く。仕様の曖昧さが残るときは `grilling` skill で意思決定を 1 問ずつ詰めてから確定する
- うまくいかなくなったら止めて再計画する。**同じ系統のアプローチで 2 回失敗したら必ずプランモードに入り、根本原因を再調査する**

### Verification Before Done

- 動作を証明せずにタスクを完了済みにしない。テストを実行し、ログを確認し、「スタッフエンジニアはこれを承認するか？」と自問する。KMP / iOS 変更後の具体的な検証手順は `verify-kmp-ios` skill に従う
- **UI 挙動バグの修正**: ビルド成功 ≠ 修正完了。ユーザーにシミュレータ / 実機での確認を促す
- **KMP の Swift ⇄ Kotlin ブリッジ部分**: 小さな PoC で動作確認してから本実装に組み込む

### Self-Improvement Loop

- ユーザーからの修正があったら `docs/tasks/lessons.md` にパターンを記録し、セッション開始時に関連する教訓を見直す
- **バグパターンを lessons に記録したら、その場で同型箇所の横断点検（grep）までやり切り、点検結果も残す**（lessons 2026-07-03）。記録時は `record-lesson` skill の手順に従う

### タスク管理

- 着手前にチェック可能な項目を `docs/tasks.md` に書き、完了したら随時チェックを付ける。各ステップで高レベルのサマリーを示す

### 核となる原則

- **Simplicity First**: すべての変更をできる限りシンプルに。影響するコードを最小限に
- **No Laziness**: 根本原因を探る。一時的な修正はしない。シニアデベロッパーの基準で
- **Minimal Impact**: 変更は必要なものだけに触れる。バグを持ち込まない
- **Demand Elegance**: 非自明な変更で修正がハック的に感じたら、立ち止まってより洗練された方法を探す（単純な修正では過剰設計しない）
- **Autonomous Bug Fixing**: バグレポートが来たらすぐ直す。ログ・エラー・失敗テストを自分で特定して解決し、手取り足取りを求めない。原因が非自明・再現困難なバグは `diagnosing-bugs` skill の診断ループに従う

---

## 必読ドキュメント

コードの生成・変更を行う際は、必ず以下の方針に従ってください。

| ドキュメント | 内容 | パス |
|-------------|------|------|
| アーキテクチャ方針 | KMP の構成、レイヤー分割、状態管理 | [`docs/architecture.md`](./docs/architecture.md) |
| コーディング規約 | Kotlin / Swift 双方の命名・実装ルール | [`docs/coding-conventions.md`](./docs/coding-conventions.md) |
| UI/UX ガイドライン | SwiftUI（iOS）の HIG ベース UI 設計方針 | [`docs/ui-ux-guidelines.md`](./docs/ui-ux-guidelines.md) |
| 要件定義 | 機能一覧・画面一覧・非機能要件 | [`docs/requirements.md`](./docs/requirements.md) |
| データモデル | CoffeeRecord / Cafe / Photo / BeanProfile の Kotlin / SQLDelight / Firestore 表現 | [`docs/data-model.md`](./docs/data-model.md) |
| KMP ブリッジ | Swift ⇄ Kotlin 相互運用ルール、`expect`/`actual`、Flow / suspend の扱い | [`docs/kmp-bridge.md`](./docs/kmp-bridge.md) |
| 実装ノート | 要件未満の実装上の決定・影響・トレードオフ・経緯の時系列ログ（親のみ更新） | [`docs/implementation_note.md`](./docs/implementation_note.md) |
| タスク一覧 | フェーズ別タスク・進捗管理 | [`docs/tasks.md`](./docs/tasks.md) |
| App Store メタデータ | App Store Connect 提出用の原稿・プライバシー申告・提出前チェックリスト | [`docs/app-store-metadata.md`](./docs/app-store-metadata.md) |
