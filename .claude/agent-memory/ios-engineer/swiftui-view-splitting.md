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

## `@State` で保持する `@Observable` クラスがコールバックで兄弟 `@State`/`@FocusState` を必要とするとき、初期値式に `self` は使えない（2026-07-24、MapTabView M-3 分割で確認）

- `MapSearchController(onRequestCamera: (MKCoordinateRegion) -> Void, onDismissKeyboard: () -> Void)` のように、コントローラのコールバックが View 側の `cameraPosition`（`@State`）や `isSearchFieldFocused`（`@FocusState`）を必要とする設計にすると、`@State private var searchController = MapSearchController(onRequestCamera: { region in cameraPosition = ... }, ...)` という**プロパティ宣言の初期値式は書けない**（Swift は「他の格納プロパティの初期値式」から `self` を参照させない。カスタム `init` で `_cameraPosition.projectedValue` を使う手もあるが、@State の永続ストレージがビューの初回マウントで初めて確立される仕様と絡み合い、挙動の裏取りが困難でリスクが高い）。
- **採用したパターン**: プロパティ宣言では no-op クロージャで仮初期化し（`{ _ in }` / `{}`）、既存の「`.task` で 1 度だけ本生成する」慣習（`searchBridge` 等）に相乗りして、同じ `.task` 内で `searchController.configureCallbacks(onRequestCamera:onDismissKeyboard:)` を呼び本物のクロージャ（`self.cameraPosition` / `self.isSearchFieldFocused` を捕捉）に差し替える。`.task` はそのビュー識度の初回マウント時にのみ実行され、その時点の `self` は正しく永続ストレージへ結び付いた `Binding` 相当の参照を持つため安全（同一ファイル内の「初回のみ」ガード = `searchController.searchBridge == nil` を流用）。
- コントローラ側のクロージャ格納プロパティは `let` ではなく `private var` にし、`init` と `configureCallbacks` の 2 箇所から代入できるようにする。

## `TextField` 等の双方向バインドで `@State` 内の `@Observable` クラスのメンバーへ `$` バインドしたいとき

- `@State private var controller = SomeObservableClass()` を保持する View で、子孫の値（`controller.query` 等）に `TextField(text:)` の `Binding<String>` を渡したい場合、`$controller` は「クラス全体への `Binding<SomeObservableClass>`」にしかならず、`$controller.query` のようなメンバー単位の `Binding` は得られない。**その computed property / 関数のスコープ内で `@Bindable var controller = controller` をローカル宣言**すると、以降の `$controller.query` がメンバー単位の `Binding<String>` として機能する（SwiftUI + Observation の標準パターン）。単純な読み取り・代入（`controller.query = ""` 等）や `.onChange(of: controller.query)` には `@Bindable` は不要（`Binding` を作るときだけ必要）。
- 素の `var searchBarView: some View { ... }`（`@ViewBuilder` 明示なし）の中に `@Bindable var x = ...` というローカル宣言文を足すと、実装が「単一式の暗黙 return」から複数文になるため `return` を明示する必要がある（`@ViewBuilder private func mapContent(...)` のように既に `@ViewBuilder` 付きの関数ならこの制約はない）。

## 行番号ベースの一括削除（`del lines[a:b]`）で範囲を決めるとき、MARK セクション境界を目視だけで決め打ちしない（2026-07-24、MapTabView M-4 分割で確認）

- 「メソッド A 〜 メソッド E を移動する」といった指示で、A の直前の MARK コメントから E の関数末尾までを丸ごと削除範囲にすると、**A〜E の間に無関係なヘルパー（移動対象外）が挟まっているケースを見落とす**。今回は「現在地 FAB」〜「初期カメラ」の間に「周辺カフェ Apple POI 関連ヘルパー」（`existingPinCoordinates` / `appleNearbyPinOpacity`）2 関数が挟まっており、削除範囲に巻き込んで消してしまった（ビルドで `cannot find 'existingPinCoordinates' in scope` 等として顕在化、無関係に見えるトレーリングクロージャ型エラーも巻き添えで出た）。
- 対策: 削除前に、削除範囲内に列挙された移動対象**以外**の `// MARK:` / `private func` / `private var` 宣言がないか grep（`grep -n "MARK:\|private func\|private var" file.swift` を対象行範囲で確認）してから `del lines[a:b]` を実行する。移動対象を 1 つずつ「この関数は指示に列挙されているか」を機械的にチェックリスト照合するのが確実。
- ビルドエラーの「cannot find X in scope」は速攻で気づけるため大事故にはならないが、型検査のカスケードで無関係な行に誤ったエラー（例: `Map(position:) { }` のトレーリングクロージャ型不一致）が出ることがあるので、実際の原因は "in scope" エラーの方を優先して読む。

## 「複数の子ファイルから呼ばれる親のセクション関数 vs. 単一ファイル内でしか使わないヘルパー」を仕分けてから private を外す（2026-07-24、AnalysisView 分割で確認）

- 巨大 View を「本体に残すグループ」と「extension 別ファイルへ出すグループ」に割るとき、後者の中でもさらに「本体（呼び出し元）から直接呼ばれる関数だけ」と「その extension ファイル内の他メンバからしか呼ばれないヘルパー」を区別する。**internal 化が必要なのは前者だけ**。後者はそのまま `private` を維持できる（同じ新ファイル内で完結するため）。
- 具体例（`AnalysisView` の統計チャートセクション分割）: `statisticsScrollView`（本体に残る）が呼ぶ 8 個のセクション関数（`summarySection` / `ratingHistogramSection` / `tastingAveragesSection` / `originRankingSection` / `roastLevelSection` / `brewMethodSection` / `monthlyTrendSection` / `topCafesSection`）だけを `private` → internal に変更し、それらが内部で使う `summaryCard` / `sectionHeader` / `formattedRating` / `localizedRoastLevel` 等のヘルパーや `RoastLevelBarItem` / `roastLevelOrder` は、呼び出し元がすべて同じ新ファイル内に移動するため `private` のまま据え置いた。「一括で全部 internal にする」より安全（意図しない公開範囲拡大を避けられる）。
- 判定手順: 分割前に `grep -n "<関数名>"` で全呼び出し箇所の行番号を洗い出し、呼び出し元が「移動先と同じファイルに収まるか」を機械的に確認してから access level を決める。
- 複数ファイルから参照される View 構造体（`InsightLoadedCard` 等）も同様の基準: 本体の `insightCardSection` と Preview 専用ファイルの両方から呼ばれるものは internal 化必須。単一カードの内部だけで使うサブ View（`FavoriteSignalRow` 等）は private のまま。
- 依存関係が複雑な関数（AI 系セクションを呼ぶ `statisticsScrollView` 自体）は「迷ったら依存が少ない側（呼び出し元が全部同じ場所に留まる側）に寄せて本体に残す」判断が安全（[`docs/coding-conventions.md` §3.4](../../../docs/coding-conventions.md) の分割指針どおり）。

## UI セクションと処理ロジックを「2 つの兄弟 extension ファイル」に分けるとき、相互参照はどちらも internal 化が要る（2026-07-24、CoffeeEditorView 分割で確認）

- `CoffeeEditorView+Sections.swift`（フォーム UI）と `CoffeeEditorView+Photos.swift`（写真の非同期処理）のように**同じ型の extension を役割で 2 ファイルに分ける**場合、`photosSection`（Sections 側）が `handlePhotoDelete`（Photos 側）を呼ぶような**ファイルをまたぐ呼び出し**は、呼ばれる側関数を internal 化しないとコンパイルエラーになる（呼び出し元が「同じ新ファイル」に収まらない一例）。判定は「呼び出し元 1 箇所しかない」ではなく「呼び出し元がどのファイルにあるか」で見る。
- 逆に本体（メインファイル）の `body`/`toolbarContent` から呼ばれる Photos 側の関数（`handlePickerSelection` は `.onChange` から、`saveWithPhotoFlush` は `toolbarContent` から）も同じ理由で internal 化必須。
- `@State` プロパティも同様: 宣言はメインファイルに残し、Sections/Photos 両方の extension から読み書きするもの（`viewModel` / `pendingImageData` など）は、たとえ片方の extension からしか実際には呼ばれなくても、**宣言ファイルと参照ファイルが別なら internal 化が要る**（`private` はファイルスコープであり "呼び出し元の数" ではなく "宣言ファイルと参照ファイルが同じか" で判定する）。

## `extension` の途中に Edit で新しい top-level 型を挿し込むと、後続メンバーが誤ってネストして brace 崩壊する（2026-08-06、テイスティングスライダー tap-to-seek 対応で確認）

- `extension Foo { ... memberA(); memberB(); ... }` の**途中のメンバー（memberA）直後**に「新しい独立した `struct`/`Preview` を追加したい」場合、`old_string` を「memberA の閉じ `}` を含めてそこで extension も閉じ、新 struct を挟んで別ファイルのように続ける」形の `new_string` に置き換えると、**新 struct 以降に置いた閉じ忘れの `}` が、後ろに残っている memberB 以降を意図せず新 struct の内側にネストさせてしまう**（1 つの Edit 呼び出しでは new_string の外側にある「その後に続く元の内容」の位置関係までは制御できないため）。症状は "extraneous '}' at top level" ではなく、むしろ逆に **後方の関数がどこか別の型の内側に閉じ込められてコンパイルは通らないのに、エラーメッセージが発生箇所と無関係な位置に出る**ことがある。
- 安全な手順: ① 新しい top-level 宣言は「対象 extension の**完全な終端（最後のメンバーの後）**」に追加する。extension の途中に置きたい場合でも、まず extension 全体を最後まで維持したまま新宣言をファイル末尾に置き、その後で `tastingSliderRow` のようなメンバー内部から新宣言を参照するだけにすれば、brace 構造を作り直す必要がない。② それでも構造を動かした場合は、`python3 -c "s=open(path).read(); print(s.count('{'), s.count('}'))"` で開き括弧・閉じ括弧の総数が一致するかを機械的に確認してから `Read` で目視確認する（今回は 1 回目の Edit で `}` の過不足に気づかず、`Read` で気づいて `python3` の `del lines[...]` ベースの再構成で修正した）。
- 教訓: 複数メンバーを持つ `extension`/`class`/`struct` の**内部**を Edit で触るときは、`old_string`/`new_string` の中で開き `{` と閉じ `}` の対応を全部自分で完結させ、「ここで型/extension を閉じてまた別のを開く」ような操作は避け、新規宣言は既存ブロックの外側（前後）に追加する方が事故が少ない。

## 参照: [ui-components-patterns.md](ui-components-patterns.md) の「排他的な複数種シート」パターンとは独立の論点

上記は「1 つの View を複数の小さい View 構造体に割る」ときの状態設計の話で、`ui-components-patterns.md` の enum item シートパターン（表示状態の排他制御）とは別の関心事。
