---
paths:
  - "iosApp/**"
  - "**/*.swift"
---

# Swift / iOS 実装規約（要点）

正本は [`docs/coding-conventions.md`](../../docs/coding-conventions.md) / [`docs/ui-ux-guidelines.md`](../../docs/ui-ux-guidelines.md) / [`docs/kmp-bridge.md`](../../docs/kmp-bridge.md)。ここは常時確認する要点のみ。

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う。SwiftUI View は `<機能名>View` と命名する
- `switch` は全ケースを網羅する（`default` は極力使わない）
- 観測タスクの破棄はブリッジの `deinit` 起点（`kotlin.clear()`）。タブ常駐 View では `.onDisappear` で observation を cancel しない

## UI/UX（iOS）

- カラーはシステムカラー（`.primary` / `Color(.systemBackground)` など）を優先する。反転するセマンティックカラーを背景に使うときは前景も連動させる
- フォントは Dynamic Type スタイル（`.body` / `.headline` など）を使用する
- スペーシングは 8pt グリッドを基準にする
- タップ可能な要素の最小サイズは 44×44pt を確保する
- SF Symbols をアイコンとして使用する
- アクセシビリティラベルをすべてのインタラクティブ要素に付与する

## コード生成時のチェックリスト

- [ ] View にビジネスロジックが混入していないか
- [ ] `@Observable` の ViewModel を介して共通層（`shared/*` の Kotlin ViewModel）を呼んでいるか
- [ ] Firebase Repository の iOS 実装（`iosApp/iosApp/FirebaseRepositories/`）は `shared/domain` のインターフェースに準拠しているか
- [ ] システムカラー・Dynamic Type を使用しているか
- [ ] アクセシビリティラベルが付与されているか
- [ ] Kotlin の `suspend`/`Flow` を Swift から扱う際は `docs/kmp-bridge.md` のラッパを通しているか
