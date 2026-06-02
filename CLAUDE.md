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
- **共通言語**: Kotlin（`shared/*` モジュール群。現状は `sharedLogic` 一枚で、目標構成へ段階的に分割中）
- **iOS UI**: SwiftUI + MVVM（`@Observable`）
- **Android UI**: Compose Multiplatform（`feature/visit-list` を 1 画面だけ表示する検証実装）
- **ローカル DB**: SQLDelight
- **クラウド同期**: Firebase 公式プラットフォーム別 SDK（オフライン永続化に委譲）
- **カフェ検索**: Google Places API

---

## モジュール構成

### 現状（Phase 1 時点）

| モジュール | 役割 |
|----------|------|
| `sharedLogic/` | ドメインモデル・リポジトリ・ViewModel・DB・API クライアント等の共通ロジック（一枚に集約） |
| `sharedUI/` | Compose Multiplatform 将来枠（当面未着手） |
| `iosApp/` | SwiftUI エントリポイント |
| `androidApp/` | Android エントリポイント |

### 目標構成（段階的に移行中）

`sharedLogic` を `shared/core` / `shared/domain` / `shared/data-local` / `shared/data-places` / `shared/data-firebase` / `shared/feature/*` / `shared/framework` に分割し、`build-logic/convention/` で共通設定を集約する構成へ移行します。

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
| タスク一覧 | フェーズ別タスク・進捗管理 | [`docs/tasks.md`](./docs/tasks.md) |

---

## 重要なルール（抜粋）

### アーキテクチャ

- ドメインモデル・ユースケース・リポジトリ・ViewModel はすべて KMP 共通層（現状: `sharedLogic/commonMain` / 目標: `shared/domain` + `shared/feature/*` + `shared/data-*`）に置く
- `feature` 同士の相互依存は禁止。画面遷移は `iosApp` / `androidApp` の Navigation 層で繋ぐ
- iOS / Android 固有実装が必要なものは `expect`/`actual` で表現する（プラットフォーム API ラッパに限定）
- ViewModel は `kotlinx.coroutines` の `StateFlow` で UI 状態を公開する
- Firebase は公式プラットフォーム別 SDK を採用。iOS 実装は `iosApp` 側 Swift、Android 実装は `shared/data-firebase/androidMain`（現状は `sharedLogic/androidMain`）。`shared/domain` の Repository インターフェースで非対称性を吸収する
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
- [ ] 配置先モジュールが正しいか（モデル / UseCase は `domain`、ViewModel は `feature/*`、DB は `data-local`、Firestore は `data-firebase`。Phase 2 以前は `sharedLogic` 一枚に集約）

### Swift（iosApp）

- [ ] View にビジネスロジックが混入していないか
- [ ] `@Observable` の ViewModel を介して共通層（`shared/*` の Kotlin ViewModel）を呼んでいるか
- [ ] Firebase Repository の iOS 実装（`iosApp/FirebaseRepositories/`）は `shared/domain` のインターフェースに準拠しているか
- [ ] システムカラー・Dynamic Type を使用しているか
- [ ] アクセシビリティラベルが付与されているか
- [ ] Kotlin の `suspend`/`Flow` を Swift から扱う際は `docs/kmp-bridge.md` のラッパを通しているか
