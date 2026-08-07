---
paths:
  - "iosApp/**"
  - "**/*.swift"
---

# Swift / iOS 実装規約（要点）

正本は [`docs/coding-conventions.md`](../../docs/coding-conventions.md) / [`docs/ui-ux-guidelines.md`](../../docs/ui-ux-guidelines.md) / [`docs/kmp-bridge.md`](../../docs/kmp-bridge.md)。ここは常時確認する要点のみ。

- **`iosApp` は Swift 6 言語モード + 既定 MainActor 分離**（2026-08-07 移行。設定は `iosApp/Configuration/Base.xcconfig` が正本で、`project.pbxproj` には `SWIFT_VERSION` を書かない）。**何も書かなければ `@MainActor`** なので、規約は「既定から外れる側」を明示することに尽きる。外し方は 3 つだけ（詳細は coding-conventions §2.5）:
  - **Kotlin interface（Obj-C プロトコル）の実装クラス** → `nonisolated final class`。Kotlin ランタイムが任意スレッドから呼ぶため。可変キャッシュを持つなら `OSAllocatedUnfairLock` + `@unchecked Sendable` をセットで
  - **CPU バウンドな処理を含む `nonisolated async` 関数** → `@concurrent`。**付け忘れても診断が一切出ない**のが最大の罠で、`NonisolatedNonsendingByDefault` 下では素の `nonisolated async` は**呼び出し元アクター上で実行される** — ビルドは通り、メインスレッドで重い処理が走ってスクロールが重くなるだけ。型もテストも助けないので、`async` 関数に重い同期処理を書いた時点で自分で判断する（`PhotoFileStore.loadThumbnail` が実例。lessons 2026-08-07）
  - **MainActor 上でのみ生成・破棄されるクラスの `deinit`** → `isolated deinit`。既定 MainActor 分離下でも `deinit` だけは `nonisolated` になり、非 Sendable プロパティに触れないため。**破棄が MainActor 上で起きる保証がないクラスに使ってはいけない**（`CallbackFlow` は Kotlin ランタイムが任意スレッドで破棄するので `nonisolated` 側。使うと Firestore リスナの解放が MainActor へホップして遅延する）
- 検査を外す手段は**穴の広さで選ぶ**。プロパティ 1 個が非 Sendable なだけなら `nonisolated(unsafe)`、`@Sendable` クロージャの引数型に Kotlin 型が直接現れる場合だけ `@preconcurrency import SharedLogic`（ファイル内の SharedLogic 型すべての検査が外れる）
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う。SwiftUI View は `<機能名>View` と命名する
- **1 ファイル / 1 型が肥大化したら責務分割**（目安: **800 行超**で分割検討。PostToolUse フック `check-file-size.sh` が警告）。SwiftUI View はサブ View の独立構造体化・状態/サービスの `@Observable` 隔離・`extension` 分離で切り出す（`MapTabView` 分割が実例。lessons / implementation_note 2026-07-24）
- `switch` は全ケースを網羅する（`default` は極力使わない）
- 観測タスクの破棄はブリッジの `deinit` 起点（`kotlin.clear()`）。タブ常駐 View では `.onDisappear` で observation を cancel しない
- **`.onChange(of:) { Task { ... } }` を書かない。`.task(id:)` を使う**。`.onChange` から起こす `Task { }` は**非構造化タスク**でビューのライフサイクルに紐づかないため、ビュー消滅後もキャンセルされずに走り続ける（遅延や重い処理を含むと、閉じた画面のための処理・別画面上へのダイアログ提示になる）。`.task(id:)` は **①表示時に 1 回 ②`id` 変化のたびに前タスクをキャンセルして再起動 ③ビュー消滅時にキャンセル** をまとめて満たすので、「初期状態 + 遷移」の両方を 1 本でカバーできる。`await Task.sleep` 等を挟む場合は `try?` がキャンセルを飲み込むので `guard !Task.isCancelled` を明示的に置く（lessons 2026-08-01）

- **`List` / `ScrollView` の中に `DragGesture` を置くときは 3 点セットで設計する**。①`.gesture` は親のスクロール用パンを奪う（共存させるなら `.simultaneousGesture`）②`DragGesture(minimumDistance: 0)` は **touch down の瞬間に `onChanged` が発火する**ので、「タップで即反応」は「触れただけで値が変わる」と同義 — 開始時の値を保持し、縦方向優勢（`|height| > 閾値` かつ `|height| > |width|`）ならスクロール意図と判定してロールバックする ③**ジェスチャーの状態リセットを `onEnded` に置かない**。SwiftUI のジェスチャーは競り負けてキャンセルされると `onEnded` を呼ばないため、「以後の更新を止める」種類の状態は固着して**その要素が二度と反応しなくなる**。`onChanged` 内で開始イベント（`translation` が 0 近傍）を判定して初期化し、`onEnded` は保険に留める。①だけ直すと ②、②だけ直すと ③ が出る構造で、コンパイラは一切守ってくれない（`TappableTastingSlider` が実例。lessons 2026-08-06）
- **ドメインの日付を変換するときに `Calendar.current` / `DateFormatter` の既定ロケールを使わない**。どちらも端末設定（**暦法**は言語・地域とは別軸）に追従するため、和暦端末では西暦年が元号年として解釈される。実測: `LocalDate(2026-08-06)` の表示が `4044-08-06`、Firestore への保存値が `0008-08-06` になり**永続データが壊れた**。`DateComponents(year:month:day:)` を組み立てる / 取り出すコードが目印で、そこは `Calendar(identifier: .gregorian)`（タイムゾーンだけ `TimeZone.current` を維持）に固定する。固定書式の `DateFormatter` には `locale = Locale(identifier: "en_US_POSIX")` を明示（Apple QA1480）。**表示用の書式化**（「今日」「3 日前」等）に `Calendar.current` を使うのは正しい（lessons 2026-08-06）
- **単一言語アプリでも「バンドルの実効言語」は明示する**。`.lproj` / `.xcstrings` を持たなくても、`project.pbxproj` の `developmentRegion` が `en` のままだと iOS が `Locale.current` を英語にフォールバックさせ、**OS が描画する部分（`DatePicker` 等）だけが英語**になる。文字列リテラルが日本語なので画面は日本語に見え、壊れ方がまだらで気づきにくい。検証は**ビルド成果物の `Info.plist` を実読み**する（`plutil -extract KEY xml1 -o -` — **`-o -` を省くと元ファイルを上書き破壊する**）（lessons 2026-08-06）

## UI/UX（iOS）

- カラーはシステムカラー（`.primary` / `Color(.systemBackground)` など）を優先する。反転するセマンティックカラーを背景に使うときは前景も連動させる
- **概念色を持つ UI では `tint` を必ず明示する**。`tint` は環境値で、省略すると**無言で `accentColor`（ブランドの茶）にフォールバック**する — コンパイルエラーにならず、しかも「一応それらしいブランド色」で描画されるため目視レビューもすり抜ける。壊れ方が「明らかに変な色」ではなく「**別の概念の色**」になるのが厄介な点。既定値を持つ自作コンポーネント（`TagChip.tint = .accentColor`）でも同じで、**その既定は中立な用途のためのもの**。概念色の一覧は `docs/ui-ux-guidelines.md`「マップ概念の色セマンティクス」が正本（訪問済み=accent / 保存済み=indigo / 好み一致=pink / 検索結果=blue / おすすめ=orange）。**概念に色を割り当てたら、その概念を描く全箇所を grep で並べて突き合わせる**のが唯一の検出手段（型もテストも助けない）。隣接する行に正しい例があっても差分では気づけない（lessons 2026-08-07）
- **`List` / `Form` の中では `tint` を明示しても `Label` のアイコンだけ効かない**（`accentColor` で描かれる）。`.tint()` は塗り・枠線には効くので**「効いていないわけではない」状態になり切り分けが難しい**。文字とアイコンの色を揃える必要があるなら、`tint` からの継承に頼らず **`Label` に `.foregroundStyle` を明示**する（状態ごとに色が変わるなら、ラベルを `let` で使い回さず分岐ごとに構築し直す）。**コンテナが子の見た目を書き換える型の挙動は子側のコードを読んでも分からない**ので、色が揃わないときは同じ View を `List` の外に置いた対照を実際に描画して比べる（lessons 2026-08-07 続報）
- フォントは Dynamic Type スタイル（`.body` / `.headline` など）を使用する
- スペーシングは 8pt グリッドを基準にする
- タップ可能な要素の最小サイズは 44×44pt を確保する
- **幅・高さを持つ要素を `if` で条件生成しない**（兄弟がシフトする）。常時レイアウトに乗せ、`.opacity` + `.disabled` + `.accessibilityHidden` で見た目と操作性だけを切り替える。特に `LabeledContent` の右寄せスロット / `HStack + Spacer` では要素 1 個の出入りが全兄弟の位置に伝わる。条件が実行中に変わらない（端末能力判定など）場合と、左寄せコンテナ末尾の出入りは対象外（lessons 2026-07-26）
- SF Symbols をアイコンとして使用する（**アプリ内 UI に限る**。ライセンス条項によりアプリアイコン / ロゴには使えない。`AppIcon` / `LaunchLogo` は `iosApp/scripts/generate_app_icon.swift` の自前パス描画）
- アクセシビリティラベルをすべてのインタラクティブ要素に付与する

## コード生成時のチェックリスト

- [ ] View にビジネスロジックが混入していないか
- [ ] `@Observable` の ViewModel を介して共通層（`shared/*` の Kotlin ViewModel）を呼んでいるか
- [ ] Firebase Repository の iOS 実装（`iosApp/iosApp/FirebaseRepositories/`）は `shared/domain` のインターフェースに準拠しているか
- [ ] システムカラー・Dynamic Type を使用しているか
- [ ] アクセシビリティラベルが付与されているか
- [ ] Kotlin の `suspend`/`Flow` を Swift から扱う際は `docs/kmp-bridge.md` のラッパを通しているか
