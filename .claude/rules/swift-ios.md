---
paths:
  - "iosApp/**"
  - "**/*.swift"
---

# Swift / iOS 実装規約（要点）

正本は [`docs/coding-conventions.md`](../../docs/coding-conventions.md) / [`docs/ui-ux-guidelines.md`](../../docs/ui-ux-guidelines.md) / [`docs/kmp-bridge.md`](../../docs/kmp-bridge.md)。ここは常時確認する要点のみ。

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う。SwiftUI View は `<機能名>View` と命名する
- **1 ファイル / 1 型が肥大化したら責務分割**（目安: **800 行超**で分割検討。PostToolUse フック `check-file-size.sh` が警告）。SwiftUI View はサブ View の独立構造体化・状態/サービスの `@Observable` 隔離・`extension` 分離で切り出す（`MapTabView` 分割が実例。lessons / implementation_note 2026-07-24）
- `switch` は全ケースを網羅する（`default` は極力使わない）
- 観測タスクの破棄はブリッジの `deinit` 起点（`kotlin.clear()`）。タブ常駐 View では `.onDisappear` で observation を cancel しない
- **`.onChange(of:) { Task { ... } }` を書かない。`.task(id:)` を使う**。`.onChange` から起こす `Task { }` は**非構造化タスク**でビューのライフサイクルに紐づかないため、ビュー消滅後もキャンセルされずに走り続ける（遅延や重い処理を含むと、閉じた画面のための処理・別画面上へのダイアログ提示になる）。`.task(id:)` は **①表示時に 1 回 ②`id` 変化のたびに前タスクをキャンセルして再起動 ③ビュー消滅時にキャンセル** をまとめて満たすので、「初期状態 + 遷移」の両方を 1 本でカバーできる。`await Task.sleep` 等を挟む場合は `try?` がキャンセルを飲み込むので `guard !Task.isCancelled` を明示的に置く（lessons 2026-08-01）

## UI/UX（iOS）

- カラーはシステムカラー（`.primary` / `Color(.systemBackground)` など）を優先する。反転するセマンティックカラーを背景に使うときは前景も連動させる
- フォントは Dynamic Type スタイル（`.body` / `.headline` など）を使用する
- スペーシングは 8pt グリッドを基準にする
- タップ可能な要素の最小サイズは 44×44pt を確保する
- **幅・高さを持つ要素を `if` で条件生成しない**（兄弟がシフトする）。常時レイアウトに乗せ、`.opacity` + `.disabled` + `.accessibilityHidden` で見た目と操作性だけを切り替える。特に `LabeledContent` の右寄せスロット / `HStack + Spacer` では要素 1 個の出入りが全兄弟の位置に伝わる。条件が実行中に変わらない（端末能力判定など）場合と、左寄せコンテナ末尾の出入りは対象外（lessons 2026-07-26）
- SF Symbols をアイコンとして使用する
- アクセシビリティラベルをすべてのインタラクティブ要素に付与する

## コード生成時のチェックリスト

- [ ] View にビジネスロジックが混入していないか
- [ ] `@Observable` の ViewModel を介して共通層（`shared/*` の Kotlin ViewModel）を呼んでいるか
- [ ] Firebase Repository の iOS 実装（`iosApp/iosApp/FirebaseRepositories/`）は `shared/domain` のインターフェースに準拠しているか
- [ ] システムカラー・Dynamic Type を使用しているか
- [ ] アクセシビリティラベルが付与されているか
- [ ] Kotlin の `suspend`/`Flow` を Swift から扱う際は `docs/kmp-bridge.md` のラッパを通しているか
