---
name: swiftui-view-splitting
description: 巨大 SwiftUI View（God View）を独立 View 構造体 / extension へ分割するときの落とし穴（アクセスレベル、状態オーナーシップの選び方）
metadata:
  type: project
---

## `private` メソッド/プロパティを別ファイルの `extension` へ移すと呼び出し元からアクセス不能になる（2026-07-24、MapTabView M-1 分割で確認）

- Swift の `private` は「同一ソースファイル内」の宣言・extension からしか見えない（`fileprivate` も同様にファイル単位）。既存 View 内の `private func` 群を「本体は元のファイルに残し、一部メソッドだけ `extension MapTabView { ... }` として別ファイルへ移動」すると、元ファイル側の呼び出し箇所（例: `mapContent` 内の `ForEach(displayedSavedCafes(bridge), ...)`）がコンパイルエラーになる。
- 対策: 別ファイルの extension から参照される private メンバ（メソッドだけでなく `private static let` 定数も含む）は、アクセスレベルを外す（デフォルトの internal にする）。モジュール外には出ないので公開 API 化のリスクはない。「なぜ private を外したか」を一言コメントで残しておくと、後から見て「うっかり公開範囲を広げた」と誤解されない。
- 同型の罠: `private static let` な定数（ズームゲート半径など）を extension 側の計算ロジックが参照するケースでも同じ理由でアクセスレベル変更が必要。

## 「複数の消費者が同じ算出値を必要とする」状態は、値を必要とする全消費者の共通の親に残し、子 View へは算出済みの値を渡す（2026-07-24、検索結果下部シートの高さ計算で確認）

- 下部ドラッグシート（peek/expanded 2 detent）の「現在の高さ」は、シート自身の描画（`frame(height:)`）だけでなく、親 View 側の別要素（現在地 FAB のボトムインセット計算）からも参照されていた。
- 素朴に「detent 状態とサイズ計算はシート固有だからシート View に全部移す」をやると、親が高さを知る手段がなくなり、コールバックで高さ変化を親へ通知する仕組みを新設する必要が出て複雑化する。
- **採用した設計**: detent の `@State`（enum）とドラッグ量の `@State`、そこから導出する `currentHeight`/`baseHeight`/`expandedHeight` の computed property は**親 View に残す**。子 View（抽出したシート）へは ①算出済みの高さ値（`let`）と ②detent/ドラッグ量の `@Binding` のみを渡す。子はジェスチャー処理で `@Binding` を書き換えるだけで、サイズ計算のロジックは持たない。
- 判断基準: 「ある状態を複数の箇所が読む」場合、状態を子へ完全に移譲して親へコールバックで伝播させる（イベント逆流）よりも、**状態を共通の祖先に残して子には computed value を down-flow で渡す**ほうが単純（SwiftUI の一方向データフローに沿う）。移譲 + コールバックはどうしても同期のタイムラグやバグの温床になりやすい。
- 定数（`peekHeight` / `expandedFraction`）は概念的にシートに属するため、**子 View の `static let` として定義し、親はそれを参照する**（`MapSearchResultsSheet.peekHeight` 等）ことで、値の重複定義を避けつつ「シートの見た目定数はシートが所有する」を保てる。

## 「View 内 `@State` の fetch ロジック」を `@Observable` サービスクラスへ隔離するときの型・共有しきい値の扱い（2026-07-24、MapTabView M-2 分割で確認）

- 元が View 内 `@State`（`private(set)` 相当は無くただの `@State var`）で `Task` デバウンス + async fetch を持っていたロジックを `@Observable final class` へ切り出すときは、**クラスごと `@MainActor` にする**と元の挙動（暗黙 MainActor の View から呼ばれていた）を最小差分で保てる。個々のメソッドや `Task` 内に `@MainActor` を散らす必要がない。
- 外部からは読み取り専用にしたい配列は `private(set) var`、View 側は `@State private var loader = XxxLoader()` で保持する（`@Observable` は `@State` 属性を配列プロパティ自体には付けない — クラスインスタンスの保持側にのみ `@State` が要る）。
- **複数箇所（別ファイルの extension を含む）が参照する `static let` しきい値**をサービスクラスへ集約するときは、参照元のシンボルを `Self.xxx` → `NewClass.xxx` に張り替えるだけで済む（アクセスレベルは `static let`（デフォルト internal）のままでよく、`private static let` にする必要はない — モジュール内 extension から見えれば足りる）。「なぜこのクラスに定義したか」（例: 2 種のピンが同じズームゲートを共用する設計意図）をコメントで明記しておくと、後から見て発見しにくくならない。
- dedup（既存座標との近接除外）のような「他の状態（bridge 由来の座標一覧）に依存する算出」は、サービスクラスのメソッドに **算出済みの引数（`[CLLocationCoordinate2D]`）として渡す**設計にすると、サービスクラスが View 側の bridge 型に依存せずに済む（`swiftui-view-splitting.md` の「down-flow」原則をサービスクラス分離にも適用できる）。

## 参照: [ui-components-patterns.md](ui-components-patterns.md) の「排他的な複数種シート」パターンとは独立の論点

上記は「1 つの View を複数の小さい View 構造体に割る」ときの状態設計の話で、`ui-components-patterns.md` の enum item シートパターン（表示状態の排他制御）とは別の関心事。
