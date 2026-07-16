---
name: ui-components-patterns
description: 共通 SwiftUI コンポーネント（TagChip / StarRatingView）、AccentColor アセット形式、ローカルキャッシュ・段階読み込みの実装パターン
metadata:
  type: project
---

## 共通 `TagChip` コンポーネント（フェーズ 16 で新設、`Components/TagChip.swift`）

- マップ / 一覧で使う「選択トグル可能なチップ」は `TagChip`（`label:systemImage:isOn:count:tint:action:`、選択時 `tint`（既定 `.accentColor`）塗り、`count` 指定で右上に件数バッジ）と、非インタラクティブな凡例表示用 `TagLegendChip`（`label:systemImage:tint:`）の 2 種に共通化済み。新しいフィルタ/凡例 UI が必要になったらここに追加する（画面ごとに private struct を再実装しない）。
- `tint` は 2026-07-16（マップ「好み一致」チップのタップ対応）で追加したオプショナルパラメータ。選択時の塗り・バッジ配色すべてが `tint` に連動する。意味付けされた概念色（`docs/ui-ux-guidelines.md` の色セマンティクス表: 好み一致=pink 等）を持つチップは `accentColor` を流用せず明示的に `tint:` を渡す。
- **`.offset(x:y:)` でバッジ等をはみ出させる実装は、`ScrollView` 内では上/右端がクリップされる**（`offset` は描画位置だけ動かし、親へ伝わるレイアウトサイズには寄与しないため）。対策は「はみ出す量ぶんの padding をコンポーネント自身に対称に確保する」パターン: 上下は `isOn` 状態に関わらず同じ padding（0 or 対称値）にして、はみ出す辺（上・右）は非対称に、対辺（下・左）はゼロのままにする。実例: `TagChip` の `badgeReservedInsets`（`count` があるときだけ `top:6, trailing:6, bottom:6` を確保）。

## Xcode AccentColor（カスタムカラー）の Contents.json は hex バイト文字列（`"0x8B"`）形式（2026-07-07、フェーズ 16 で確認）

- `Assets.xcassets/*.colorset/Contents.json` の `components` は 10 進小数（`"1.000"`）ではなく `red`/`green`/`blue` それぞれ `"0xRR"` 形式の 8bit hex 文字列で書く（`alpha` のみ `"1.000"` 形式）。ダーク対応は `colors` 配列に `"appearances": [{"appearance": "luminosity", "value": "dark"}]` を付けた 2 つ目のエントリを追加する（`idiom: universal` のまま）。手書きで問題なくビルドに反映される。

## `.buttonStyle(condition ? .borderedProminent : .bordered)` は型不一致でビルドエラー（2026-07-07、フェーズ 16 保存ボタン切替で確認）

- `BorderedProminentButtonStyle` と `BorderedButtonStyle` は別の具象型のため、三項演算子で `some ButtonStyle` に代入しようとすると `type 'ButtonStyle' has no member 'borderedProminent'/'bordered'` になる。見た目だけ変える（tint 切替）なら 1 つの style + `.tint(condition ? .indigo : nil)` で済ませるのが簡単。**style 自体を切り替える必要がある場合**は `@ViewBuilder` 関数にして `if condition { Button(...).buttonStyle(.borderedProminent) } else { Button(...).buttonStyle(.bordered) }` と分岐ごと丸ごと書き分ける（`CafeDetailView.saveButton` 参照。ラベル View は `let label = Label(...)` で 1 箇所に共通化できる）。

## 「未評価に戻せる」UI は accessibilityAdjustableAction の decrement 下限 + 明示クリアボタンの二重導線にする（2026-07-13、StarRatingView nullable rating 対応で確認）

- `rating: Double?` 化した `StarRatingView` は、read-only モードで `nil` のとき星を出さず `Text("未評価")`（`.foregroundStyle(.secondary)`）を表示する（星 0 個表示は「1つも星がない低評価」と誤読されるため避ける）。
- 編集モードのクリア手段は 2 経路用意すると VoiceOver / タップ操作の両方をカバーできる: ① `accessibilityAdjustableAction` の `.decrement` を rating 0.5 未満に到達したら `nil` を返すよう実装（スワイプ操作の自然な延長）、② 星の右側に `xmark.circle.fill` の明示クリアボタン（`rating != nil` のときだけ表示、`.frame(minWidth: 44, minHeight: 44)` で 44pt 確保）。星の HStack 全体は `accessibilityElement(children: .ignore)` でグループ化しつつ、クリアボタンは**その外側**の別要素にする（グループに巻き込むと VoiceOver から個別にフォーカスできなくなるため）。
- `some View` を返す computed var 内で `if/else` 分岐を書くには `@ViewBuilder` 属性が必須（`body` プロパティ自体は View プロトコル要件により暗黙で付与されるが、任意の computed var には付かない）。

## UserDefaults + JSON（Codable）ローカルキャッシュは `enum` static メソッド + private struct Entry で完結する（2026-07-13、`ApplePoiNegativeCache` 新設で確認）

- 既存 `PhotoFileStore`（ファイル I/O 版）と同じ「全 `static` メソッドの enum、インスタンス不要」パターンを UserDefaults 版でも踏襲できる。`private struct Entry: Codable` を型内に閉じ込め、`loadEntries()`/`saveEntries(_:)` の private ヘルパで JSON エンコード/デコードを行う最小構成で十分（件数上限が小さい—数百件程度—なら線形走査で過剰設計にならない）。
- Apple の POI（`MKMapItem`）は安定 ID を持たないため、名前完全一致 + 座標近接（`CLLocation.distance(from:)`）の複合キーで dedup / 一致判定するのが定番（`displayedAppleNearbyCafes` の既存 40m 近接排除と同じ手法、キャッシュ側は 30m を採用）。

## 横スクロール（LazyHStack）内の「さらに表示」段階読み込みは `@State var visibleCount` + Item enum への追加 case で完結する（2026-07-13、CafePhotoHeader 写真ヘッダーで確認）

- KMP 側データ（`cafe.photoReferences` 等）はそのまま `prefix(visibleCount)` で間引くだけでよく、Kotlin 側に変更は不要（純粋な表示制御は View 内 `@State` に閉じる）。
- `isEmpty`（呼び出し側がヘッダー全体を隠すかの判定）は**元データ基準**にし、`visibleCount` に依存させない。段階読み込みの表示上限（例: 全体で最大 10 件）とは別に判定すること。
- 「さらに表示」ボタンは既存セルと同じ `Identifiable` enum（`Item`）に `case loadMore` を追加し、`items` 配列の末尾（次セクションの手前）に条件付きで挿入するのが素直。ボタン自体は `.frame(width:height:)` を既存の写真セルと揃えれば ScrollView 内でレイアウトが崩れない。

## 詳細画面（対象 1 レコード）の削除は「pending 写真ファイル名を Optional 1 個で保持」+ `isDeleted` フラグで pop する（2026-07-16、コーヒー詳細削除で確認）

- `CoffeeListViewModelBridge` の `pendingPhotoDeletions: [String: [String]]`（複数レコード分の辞書）と同じ安全順序（KMP 削除成功確認後にのみ物理削除）だが、詳細画面は対象が常に 1 件なので `pendingPhotoFileNames: [String]?` の単一 Optional で足りる。`onDeleteTapped()` 呼び出し時点で `coffee?.photos.compactMap(\.fileName)` を控えてから Kotlin 側を呼び、`apply(_:)` で `state.isDeleted == true` を見て解放する。
- View 側は `@Environment(\.dismiss)` + `.onChange(of: viewModel.isDeleted) { _, v in if v { dismiss() } }` で一覧へ pop。`content` の `@ViewBuilder` 分岐は **`isDeleted` を最優先で判定**し `ProgressView()` を返す（dismiss アニメーションが効くまでの一瞬に「見つかりません」の `ContentUnavailableView` がちらつくのを防ぐ）。
- リスト側の長押し `.contextMenu` からの削除確認は `confirmationDialog(_:isPresented:titleVisibility:presenting:actions:message:)`（`presenting:` 付きオーバーロード）を使うと、`@State private var deletionTarget: CoffeeRecord?` を `Binding(get: { != nil }, set: { if !$0 { nil にする } })` で `isPresented` に渡しつつ、`actions`/`message` クロージャに non-optional な対象データを渡せる。スワイプ削除（確認なし）とは別導線として共存させる。

## `ShareLink` で「生成 → 共有」の 2 フェーズ導線を作るときは enum 状態（idle/exporting/ready(URL)）で Section 内容を丸ごと差し替える（2026-07-07、設定画面データエクスポートで確認）

- `ShareLink` はボタン自体をタップした瞬間にしか share sheet を出せない（値を先に非同期生成してから自動でシートを開く API はない）。「タップでエクスポート実行 → 完了したら共有」の要件は、`Button`（idle）→ `ProgressView`（exporting）→ `ShareLink(item:)`（ready）と同じ `Section` 内で `switch` して差し替える 2 段階 UI にするのが素直（`SettingsView.exportSection` 参照）。エラーは別途 `@State private var exportError: String?` + `.alert` で拾う。
- 一時ファイル書き出しは `FileManager.default.temporaryDirectory.appendingPathComponent(name)` + `String.write(to:atomically:encoding:)` で十分（専用ストア不要）。
- suspend な UseCase 呼び出しを View 直下の `Task` から呼ぶ既存パターンは `Task { @MainActor in ... }` で統一されている（`AccountView` 参照）。
