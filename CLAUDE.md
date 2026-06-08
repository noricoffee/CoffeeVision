# CoffeeVision — Claude 向けプロジェクト設定

このファイルは Claude Code が毎回自動的に読み込むプロジェクト設定です。
以下の方針・規約を常に前提としてコードを生成・レビューしてください。

---

# 基礎ルール（すべてのタスクに適用）

## ワークフロー・オーケストレーション

### 1. Plan Mode Default（プランモードをデフォルトに）

- 非自明なタスク（3 ステップ以上、またはアーキテクチャの意思決定）には必ずプランモードに入ること
- 何かがうまくいかなくなったら、すぐに止めて再計画する。そのまま進め続けない
- 構築だけでなく、検証ステップにもプランモードを使う
- 曖昧さを減らすために、詳細な仕様を最初に書く

### 2. Subagent Strategy（サブエージェント戦略）

- メインのコンテキストウィンドウをクリーンに保つため、サブエージェントを積極的に活用する
- リサーチ・探索・並列分析はサブエージェントにオフロードする
- 複雑な問題には、サブエージェントを通じてより多くの計算リソースを投入する
- サブエージェント 1 つにつきタスクは 1 つ（集中した実行のため）

#### CoffeeVision の 3 ロール体制

このプロジェクトでは Swift / Kotlin の実装は専用サブエージェントに委譲し、メインセッション（= 親）が仕様の番人として全体を統制する 3 ロール体制を取る。

| ロール | 実体 | 書き込みスコープ | 主な責務 |
|--------|------|------------------|---------|
| **親** | メインセッション（このファイルに従う Claude） | `docs/**` / `CLAUDE.md` / `.claude/**` / プロジェクト全体の調整 | 仕様の意思決定、docs 更新、`lessons.md` 記録、サブエージェント間の橋渡し、PR / commit |
| **`ios-engineer`** | `.claude/agents/ios-engineer.md` | `iosApp/**` のみ | Swift / SwiftUI 実装、ブリッジの Swift 側、iOS Firebase 実装、ビルド検証 |
| **`kmp-engineer`** | `.claude/agents/kmp-engineer.md` | `shared*/**` / `androidApp/**` / `gradle*` / `build-logic/**` | Kotlin Multiplatform 実装、共通 ViewModel、SQLDelight、Android Firebase、Gradle |

##### 親（メインセッション）の責務

- **仕様・docs 更新の独占権**: `docs/**` / `CLAUDE.md` / `lessons.md` / `implementation_note.md` を更新できるのは親だけ。サブエージェントから上がってきた「親への依頼」を吸収して反映する
- **dispatch 判断**: 実装タスクが Swift だけで完結するなら `ios-engineer` に、Kotlin だけなら `kmp-engineer` に Agent ツールで委譲する。両方に跨るタスクは分解する
- **KMP ブリッジの仲介**: Swift ⇄ Kotlin の境界は `iOS=Swift`, `KMP=Kotlin` で分担。`commonMain` の公開 API 変更が出たら、親が「インターフェースの合意書」を docs に固めてから両エージェントに dispatch する
- **整合性チェック**: 両サブエージェントが返したレポートを突き合わせ、`commonMain` API 変更と iOS Bridge の追随が齟齬なくマージされているか確認する
- **実装ノートの記録**: サブエージェントレポートに含まれる「仕様 / トレードオフの論点」のうち、`requirements.md` に上げるほどではないが残しておくべき判断・影響・経緯を [`docs/implementation_note.md`](./docs/implementation_note.md) に追記する。タイトル + 本文だけで十分（影響 / トレードオフ / 経緯は必要なときだけ）
- **実装ノートの整理**: 定期的に同種エントリが溜まったら正規 doc（`coding-conventions.md` / `kmp-bridge.md` / `architecture.md` / `lessons.md` 等）へ昇格させ、ノートから削除する。「現在生きてる方針サマリ」も更新する。判断基準は実装ノート内の運用ルールを参照
- **commit / PR**: コードを書いたサブエージェントではなく親が最終 commit する（仕様変更と実装変更を分けたい場合はその限りでない）

##### dispatch の基本形

```
1. 親がタスクを受ける（ユーザーまたは自発）
2. 親が `docs/tasks.md` に計画項目を追加
3. 親が必要なら docs を先に整える（仕様の事前確定）
4. 親が Agent ツールで ios-engineer / kmp-engineer に委譲
   - サブエージェントへの指示には「触ってよいスコープ」「期待される成果物」「関連 docs のパス」を明示
5. サブエージェントが構造化レポートを返す
6. 親がレポートを評価し、
   - 「親への依頼」を docs / 別サブエージェントへの dispatch に変換
   - 要件未満の決定・影響・トレードオフ・経緯を `docs/implementation_note.md` に追記
   - 汎用的に学んだ落とし穴があれば `docs/tasks/lessons.md` に追記
   - `docs/tasks.md` のチェックボックスを更新
7. 必要に応じて 4 に戻る
```

##### サブエージェントが守ること（参考）

両サブエージェントの定義ファイル（`.claude/agents/ios-engineer.md` / `.claude/agents/kmp-engineer.md`）に詳細を記載。要点：

- `docs/**` / `CLAUDE.md` への書き込みは禁止（スコープ外は親に依頼で返す）
- 必読 docs を毎回 Read してから着手
- 同じアプローチで 2 回失敗したら止めて親にレポート
- 最終レスポンスは「実装した内容 / 検証結果 / 仕様トレードオフ / 親への依頼 / 未解決」の構造化 Markdown で返す

##### よくある dispatch パターン

- **新機能の追加**: 親が docs で仕様確定 → `kmp-engineer` でドメインモデル + ViewModel → `ios-engineer` で SwiftUI + Bridge → 親がレポート 2 件を統合 → commit
- **既存機能のバグ修正（片側完結）**: 該当側のサブエージェントに直接 dispatch
- **KMP ブリッジ周りの変更**: `kmp-engineer` で `commonMain` API + `@Throws` / `sealed` 調整 → レポートの公開 API 差分を親が docs に固定 → `ios-engineer` で Bridge 追随
- **モジュール分割（Phase 2.x）**: 親が分割計画を `docs/architecture.md` / `docs/tasks.md` で確定 → `kmp-engineer` に dispatch → 親が integration 検証

### 3. Self-Improvement Loop（自己改善ループ）

- ユーザーからの修正があったら必ず `docs/tasks/lessons.md` にパターンを記録する
- 同じミスを繰り返さないためのルールを自分のために書く
- セッション開始時に、関連プロジェクトの教訓を見直す

### 4. Verification Before Done（完了前の検証）

- 動作を証明せずにタスクを完了済みにしない
- 必要に応じて、`main` と自分の変更の差分を確認する
- 「スタッフエンジニアはこれを承認するか？」と自問する
- テストを実行し、ログを確認し、正確性を実証する
- **UI 挙動バグの修正**: ビルド成功 ≠ 修正完了。ユーザーにシミュレータ / 実機での確認を促す
- **同じ系統のアプローチで 2 回失敗したら必ずプランモードに入り、根本原因を再調査する**
- **KMP の Swift ⇄ Kotlin ブリッジ部分**: 小さな PoC で動作確認してから本実装に組み込む

### 5. Demand Elegance（エレガンスを求める）

- 非自明な変更では「より洗練された方法はないか？」と立ち止まって考える
- 修正がハック的に感じたら「今知っていることをすべて踏まえて、エレガントな解決策を実装する」
- 単純・明快な修正にはこれをスキップする。過剰設計しない
- 提示する前に、自分の作業に自ら異議を唱える

### 6. Autonomous Bug Fixing（自律的なバグ修正）

- バグレポートが来たら: すぐに直す。手取り足取りを求めない
- ログ・エラー・失敗テストを指摘し、それを解決する
- ユーザーからのコンテキスト切り替えはゼロ
- 方法を指示されずとも、失敗している CI テストを修正しに行く

---

## タスク管理

1. **Plan First**: チェック可能な項目を `docs/tasks.md` に書く
2. **Verify Plan**: 実装を始める前に確認する
3. **Track Progress**: 完了したら随時チェックマークを付ける
4. **Explain Changes**: 各ステップで高レベルのサマリーを示す
5. **Document Results**: `docs/tasks.md` にレビューセクションを追加する
6. **Capture Lessons**: 修正後に `docs/tasks/lessons.md` を更新する

---

## 核となる原則

- **Simplicity First（シンプルさ優先）**: すべての変更をできる限りシンプルに。影響するコードを最小限に
- **No Laziness（怠けるな）**: 根本原因を探る。一時的な修正はしない。シニアデベロッパーの基準で
- **Minimal Impact（最小限の影響）**: 変更は必要なものだけに触れる。バグを持ち込まない

---

# プロジェクト固有ルール（CoffeeVision）

## プロジェクト概要

- **アプリ名**: CoffeeVision
- **コンセプト**: 訪れたカフェでのコーヒー・フード体験を記録・振り返るためのモバイルアプリ
- **プラットフォーム**: iOS（リリース対象）/ Android（KMP 共通レイヤーの検証ターゲット、リリース対象外）
- **アーキテクチャ**: Kotlin Multiplatform（KMP）+ ネイティブ UI
- **共通言語**: Kotlin（`shared/*` モジュール群。Phase 2.5 で `core` / `domain` / `data-local` / `data-firebase` / `framework` に分割済、`data-places` / `feature/*` は Phase 3 以降で追加予定）
- **iOS UI**: SwiftUI + MVVM（`@Observable`）
- **Android UI**: Compose Multiplatform（`feature/visit-list` を 1 画面だけ表示する検証実装）
- **ローカル DB**: SQLDelight
- **クラウド同期**: Firebase 公式プラットフォーム別 SDK（オフライン永続化に委譲）
- **カフェ検索**: Google Places API

---

## モジュール構成

### 現状（Phase 2.5 完了時点）

| モジュール | 役割 |
|----------|------|
| `build-logic/convention/` | KMP / Android 共通設定の Convention Plugin |
| `shared/core/` | `AppContainer` / `VisitRepositoryImpl`（合成実装）/ Dispatcher・Logger ラッパ枠 |
| `shared/domain/` | ドメインモデル + Repository インターフェース + UseCase |
| `shared/data-local/` | SQLDelight スキーマ / Mapper / DriverFactory / `LocalVisitRepository` |
| `shared/data-firebase/` | Android Firebase 実装の置き場（現状は空殻、本格移送は Android Firebase 着手時） |
| `shared/framework/` | iOS 向け Umbrella（`SharedLogic.xcframework` を出力、SKIE 適用先） |
| `sharedUI/` | Compose Multiplatform 将来枠（当面未着手） |
| `iosApp/` | SwiftUI エントリポイント + Swift Firebase 実装 |
| `androidApp/` | Android エントリポイント（検証ターゲット） |

### 目標構成（Phase 3 以降で追加）

Phase 3 で `shared/feature/*`（`visit-list` / `visit-detail` / `visit-editor` 等）、Phase 4 で `shared/data-places` を追加予定。

詳細・移行ステップは [`docs/architecture.md`](./docs/architecture.md) を参照してください。

---

## 必読ドキュメント

コードの生成・変更を行う際は、必ず以下の方針に従ってください。

| ドキュメント | 内容 | パス |
|-------------|------|------|
| アーキテクチャ方針 | KMP の構成、レイヤー分割、状態管理 | [`docs/architecture.md`](./docs/architecture.md) |
| コーディング規約 | Kotlin / Swift 双方の命名・実装ルール | [`docs/coding-conventions.md`](./docs/coding-conventions.md) |
| UI/UX ガイドライン | SwiftUI（iOS）の HIG ベース UI 設計方針 | [`docs/ui-ux-guidelines.md`](./docs/ui-ux-guidelines.md) |
| 要件定義 | 機能一覧・画面一覧・非機能要件 | [`docs/requirements.md`](./docs/requirements.md) |
| データモデル | Visit / CoffeeItem / FoodItem の Kotlin / SQLDelight / Firestore 表現 | [`docs/data-model.md`](./docs/data-model.md) |
| KMP ブリッジ | Swift ⇄ Kotlin 相互運用ルール、`expect`/`actual`、Flow / suspend の扱い | [`docs/kmp-bridge.md`](./docs/kmp-bridge.md) |
| 実装ノート | 要件未満の実装上の決定・影響・トレードオフ・経緯の時系列ログ（親のみ更新） | [`docs/implementation_note.md`](./docs/implementation_note.md) |
| タスク一覧 | フェーズ別タスク・進捗管理 | [`docs/tasks.md`](./docs/tasks.md) |

---

## 重要なルール（抜粋）

### アーキテクチャ

- ドメインモデル・ユースケース・リポジトリ・ViewModel はすべて KMP 共通層（`shared/domain` + `shared/feature/*`（Phase 3 以降）+ `shared/data-*`）に置く
- `feature` 同士の相互依存は禁止。画面遷移は `iosApp` / `androidApp` の Navigation 層で繋ぐ
- iOS / Android 固有実装が必要なものは `expect`/`actual` で表現する（プラットフォーム API ラッパに限定）
- ViewModel は `kotlinx.coroutines` の `StateFlow` で UI 状態を公開する
- Firebase は公式プラットフォーム別 SDK を採用。iOS 実装は `iosApp` 側 Swift、Android 実装は `shared/data-firebase/androidMain`。`shared/domain` の Repository インターフェースで非対称性を吸収する
- Firestore の同期はオフライン永続化に委ね、独自の同期キューは書かない
- ローカル DB（SQLDelight）は検索・オフライン参照を高速化する用途で利用する

### コーディング規約

- Kotlin: 公式 [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html) に従う
- Swift: [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う
- ViewModel は `<機能名>ViewModel`、SwiftUI View は `<機能名>View` と命名する
- UI イベントは ViewModel のメソッド（`on○○Tapped` 等）で受ける
- `switch` / `when` の `default` / `else` は極力使わず、全 case を網羅する

### UI/UX（iOS）

- カラーはシステムカラー（`.primary` / `Color(.systemBackground)` など）を優先する
- フォントは Dynamic Type スタイル（`.body` / `.headline` など）を使用する
- スペーシングは 8pt グリッドを基準にする
- タップ可能な要素の最小サイズは 44×44pt を確保する
- SF Symbols をアイコンとして使用する
- アクセシビリティラベルをすべてのインタラクティブ要素に付与する

---

## コード生成時のチェックリスト

### Kotlin（KMP 共通層）

- [ ] ドメインモデルは `data class`、UI 状態は `data class` または `sealed interface`
- [ ] ViewModel は `StateFlow<UIState>` を 1 本だけ公開しているか
- [ ] 副作用は `suspend` 関数または `Flow` として定義されているか
- [ ] `commonMain` で書ける処理を `iosMain` / `androidMain` に漏らしていないか
- [ ] `when` で全ケースを網羅しているか
- [ ] 配置先モジュールが正しいか（モデル / UseCase は `domain`、ViewModel は `feature/*`（Phase 3 以降。現状は `core` 経由）、DB は `data-local`、Firestore は `data-firebase`）

### Swift（iosApp）

- [ ] View にビジネスロジックが混入していないか
- [ ] `@Observable` の ViewModel を介して共通層（`shared/*` の Kotlin ViewModel）を呼んでいるか
- [ ] Firebase Repository の iOS 実装（`iosApp/FirebaseRepositories/`）は `shared/domain` のインターフェースに準拠しているか
- [ ] システムカラー・Dynamic Type を使用しているか
- [ ] アクセシビリティラベルが付与されているか
- [ ] Kotlin の `suspend`/`Flow` を Swift から扱う際は `docs/kmp-bridge.md` のラッパを通しているか
