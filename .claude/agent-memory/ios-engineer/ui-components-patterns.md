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

## `List` 内の `Button`+`Label` はアイコンだけ `tint`/`buttonStyle` を無視して `accentColor` になる（2026-08-07、`CafeDetailView.saveButton` UX-4 修正で実機シミュレータ再現確認）

- `List { Section { Button(action:) { Label("保存する", systemImage: "bookmark") }.buttonStyle(.bordered).tint(.indigo) } }` は、**文字は tint（indigo）で描かれるがアイコンだけ accentColor（ブランド茶）のまま**になる。`.buttonStyle(.borderedProminent)`（塗り潰し背景）でも同様にアイコンだけ茶色になり、文字（白）と食い違う。`List` の外（`.safeAreaInset` オーバーレイ等）に同じコードを置くと発生しない — `List`/`Form` 特有の挙動。
- **対策は `.tint()` に頼らず `Label` に `.foregroundStyle(色)` を明示すること**（`Label` 全体に付ければ Text/Image 両方に伝播し、tint 経由の暗黙色付けをバイパスできる）。`.tint()` は塗り・枠線の色には引き続き必要（`.buttonStyle` の背景/枠線が参照するため、`foregroundStyle` だけでは代替できない）。
- 検証手法: `iosApp/iosApp/iOSApp.swift` の `WindowGroup` の中身を一時的に再現用 View に差し替え、`xcodebuild build` → `xcrun simctl install/launch` → `xcrun simctl io <udid> screenshot` で実機同然の描画を確認できる（Xcode Preview の CLI 手段が無い環境での代替）。確認後は必ず `git checkout -- iosApp/iosApp/iOSApp.swift` で revert し、スクラッチ用 `.swift` ファイルも削除すること（差分に残さない）。

## `.buttonStyle(condition ? .borderedProminent : .bordered)` は型不一致でビルドエラー（2026-07-07、フェーズ 16 保存ボタン切替で確認）

- `BorderedProminentButtonStyle` と `BorderedButtonStyle` は別の具象型のため、三項演算子で `some ButtonStyle` に代入しようとすると `type 'ButtonStyle' has no member 'borderedProminent'/'bordered'` になる。見た目だけ変える（tint 切替）なら 1 つの style + `.tint(condition ? .indigo : nil)` で済ませるのが簡単。**style 自体を切り替える必要がある場合**は `@ViewBuilder` 関数にして `if condition { Button(...).buttonStyle(.borderedProminent) } else { Button(...).buttonStyle(.bordered) }` と分岐ごと丸ごと書き分ける（`CafeDetailView.saveButton` 参照。ラベル View は `let label = Label(...)` で 1 箇所に共通化できる）。

## 「未評価に戻せる」UI は accessibilityAdjustableAction の decrement 下限 + 明示クリアボタンの二重導線にする（2026-07-13、StarRatingView nullable rating 対応で確認。2026-07-26 にレイアウトシフト修正で更新）

- `rating: Double?` 化した `StarRatingView` は、read-only モードで `nil` のとき星を出さず `Text("未評価")`（`.foregroundStyle(.secondary)`）を表示する（星 0 個表示は「1つも星がない低評価」と誤読されるため避ける）。
- 編集モードのクリア手段は 2 経路用意すると VoiceOver / タップ操作の両方をカバーできる: ① `accessibilityAdjustableAction` の `.decrement` を rating 0.5 未満に到達したら `nil` を返すよう実装（スワイプ操作の自然な延長）、② 星の右側に `xmark.circle.fill` の明示クリアボタン（`.frame(minWidth: 44, minHeight: 44)` で 44pt 確保）。星の HStack 全体は `accessibilityElement(children: .ignore)` でグループ化しつつ、クリアボタンは**その外側**の別要素にする（グループに巻き込むと VoiceOver から個別にフォーカスできなくなるため）。
- **クリアボタンは `if rating != nil { Button {...} }` で条件的に生成せず、常に生成した上で `.opacity(rating != nil ? 1 : 0)` + `.disabled(rating == nil)` + `.accessibilityHidden(rating == nil)` にする**（2026-07-26 修正）。`if` で View を出し入れすると、ボタンが持つ `.frame(minWidth: 44, minHeight: 44)` の分だけ親 `HStack` の幅が rating の有無で変わり、`LabeledContent` 等の右寄せスロットで星の位置が左右にシフトするバグになる（ユーザー報告で発覚）。同種の「固定 frame を持つ子 View を条件付きで HStack/VStack に出し入れる」実装は同じ落とし穴になりやすいので、常時レイアウトに乗せた上で `.opacity`/`.disabled`/`.accessibilityHidden` で見た目と操作性だけ切り替える。
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

## 自前の下部ドラッグシート（2 detent）: ハンドル行は `Button` にせず `onTapGesture` + `.gesture(DragGesture(coordinateSpace: .global))` で組む（2026-07-22 発振バグ修正で確認。旧記述を置き換え）

- native `.sheet` を避けて `.overlay(alignment: .bottom)` の自前 View で peek/expanded 2 detent を実装するとき、ドラッグハンドル行を `Button` + `.simultaneousGesture(DragGesture())` にすると、**ドラッグ中に高さがブレる（自己発振する）**。原因: `DragGesture()` は既定で `.local` 座標系で、ハンドル行はドラッグ対象の高さ（`.frame(height: currentHeight)`）に連動してシート全体（＝ハンドル行自身）が画面上で上下に動く。`.local` の `translation` は「動く View 自身」を基準に測るため、指の画面上の位置が同じでもフレームごとに読み値がズレて `height = base - translation` が発散する。
- **修正パターン**: ①ハンドル行は `Button` をやめてプレーンな View + `.contentShape(Rectangle())` + `.onTapGesture { toggle }` + `.accessibilityAddTraits(.isButton)` + `.accessibilityAction { toggle }`（VoiceOver ダブルタップ用）にする。② リサイズ用ドラッグは `.gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global))` にする（`.global` は画面固定座標なので View 自身の移動に影響されない）。`minimumDistance` を置くことでタップ（移動量ゼロ）と `onTapGesture` が競合しない。
- `onChanged` で `@State dragTranslation` を更新する際、範囲外（peek 未満 / expanded 超過）に伸びる分もそのまま代入すると、height 側の `min/max` クランプに隠れて translation だけ過剰蓄積し、指を戻すときにデッドゾーン（一定量戻すまで反応しない）が出る。**`onChanged` の時点で translation 自体を `[base - expandedHeight, base - peekHeight]` にクランプ**しておく（`docs/kmp-bridge.md` 対象外の純 SwiftUI 論点）。
- スナップ判定は `onEnded` の `predictedEndTranslation`（速度込みの慣性込み終端）を使い、`(peekHeight + expandedHeight) / 2` の中点との比較で detent を決める。
- expanded detent の高さ（画面高の N%）は `GeometryReader` を対象 View の `.background(...)` として重ね、`onAppear` + `.onChange(of: proxy.size)` で `@State CGSize` に写し取ってから通常の計算プロパティで使う（GeometryReader の `body` 内で直接 `@State` を書き換えると "modifying state during view update" になるため避ける。`.onChange` 経由なら安全）。
- ドラッグ操作はリスト本体の `ScrollView` には付けない（ハンドル行だけに限定）。シート全体に付けると一覧のスクロールジェスチャーと競合する。
- 汎用教訓: **自身の `.frame(height:)`/位置が drag の入力そのものにフィードバックする（View が動く）ケースでは `DragGesture` を `.global` にする**。逆に `.offset()` で見た目だけ動かし `onEnded` の最終値しか使わない用途（例: `ErrorToast` のスワイプ消去）は `.local`（既定）のままで問題ない（`onChanged` で連続的に自己の位置を書き換えないため発振しない）。

## `ShareLink` で「生成 → 共有」の 2 フェーズ導線を作るときは enum 状態（idle/exporting/ready(URL)）で Section 内容を丸ごと差し替える（2026-07-07、設定画面データエクスポートで確認）

- `ShareLink` はボタン自体をタップした瞬間にしか share sheet を出せない（値を先に非同期生成してから自動でシートを開く API はない）。「タップでエクスポート実行 → 完了したら共有」の要件は、`Button`（idle）→ `ProgressView`（exporting）→ `ShareLink(item:)`（ready）と同じ `Section` 内で `switch` して差し替える 2 段階 UI にするのが素直（`SettingsView.exportSection` 参照）。エラーは別途 `@State private var exportError: String?` + `.alert` で拾う。
- 一時ファイル書き出しは `FileManager.default.temporaryDirectory.appendingPathComponent(name)` + `String.write(to:atomically:encoding:)` で十分（専用ストア不要）。
- suspend な UseCase 呼び出しを View 直下の `Task` から呼ぶ既存パターンは `Task { @MainActor in ... }` で統一されている（`AccountView` 参照）。

## tap-to-seek スライダー: 標準 `Slider` を描画専用にして透明レイヤーの `DragGesture(minimumDistance: 0)` で駆動する（2026-08-06、テイスティングスライダー改修で確認）

- 標準 `Slider` はトラックタップを無視し thumb のドラッグしか受け付けない。「見た目は標準 Slider のまま、トラックのどこをタップしても即座にジャンプ＋そのままドラッグ追従」を実現するには、**標準 `Slider` を捨てず** `ZStack` に重ねて `.allowsHitTesting(false)` にし（＝外部の `value` をそのまま表示するだけの描画専用コンポーネントに変える）、同じ frame の `Color.clear` に `DragGesture(minimumDistance: 0)` を付けてタップ・ドラッグ両方をそのレイヤー 1 つで処理する。native の thumb ドラッグ自体を活かす必要はない（自前ジェスチャーがタップ開始位置＝thumb 位置のケースも含めて全部代替する）。
- **thumb 半径のインセット補正が要る**: トラックの実効幅は View 幅そのものではなく、thumb の中心が左右それぞれ半径ぶん内側までしか動けない分だけ狭い。補正しないと 1/10 のような端の値に到達できない・端で値が飛ぶ。CI/エージェント環境では実機ピクセル計測が困難なため、システムスライダーの標準的なつまみサイズ（28pt 直径 / 14pt 半径）を明示定数化してコメントで根拠と調整の余地を残すのが現実的な落とし所（Apple の正式仕様書に明記された値ではなく経験的近似値である旨も明記する）。
- **`Color.clear` のジェスチャーは `.gesture` ではなく `.simultaneousGesture` にする**。`Form`/`List` の行いっぱいに広い当たり判定を持つ `DragGesture(minimumDistance: 0)` を `.gesture` で付けると、そのスライダー行の上から始めた縦スワイプが List 側のスクロール用パンジェスチャーより優先されてしまい、スクロールできなくなる（`minimumDistance: 0` は方向判定の猶予なく即座に認識されるため）。`.simultaneousGesture` にすると List の内部スクロールジェスチャーと同時認識されるようになり、x 座標しか見ない実装なら縦スクロール中に値が実質変化しないため副作用も出ない。
- 標準 Slider が持つ「値変化時の触覚フィードバック」は `.sensoryFeedback(.selection, trigger: value)` で代替できる（`value` は外部から渡された確定値の prop。SwiftUI は trigger の等価性が変わったときだけ発火するため、同じ値に張り付いている間の連続発火を自前で抑制するコードは不要）。`StarRatingView` の `.sensoryFeedback(.selection, trigger: rating)` と同型。
- アクセシビリティは自前コンポーネント側で `.accessibilityElement(children: .ignore)` を付けて単一要素化し、呼び出し元から `.accessibilityLabel`/`.accessibilityValue`/`.accessibilityAdjustableAction` を外付けする（標準 `Slider` に直接これらを付けていた旧実装と同じ「単一要素+外付け修飾子」の形を保つと、置き換え前後で挙動が変わらない）。
- **`.simultaneousGesture` にしても「touch down 直後の `onChanged` でタップ位置の値へ即書き換わる」問題は残る**（レビュー指摘、2026-08-06）。Form/List の行いっぱいを覆う `DragGesture(minimumDistance: 0)` は、縦スクロールしようとして指を置いただけの瞬間にも `onChanged` が発火し値を書き換えてしまう。データが壊れる方向のバグなので「一瞬値が変わって見た目がちらつく」より優先して塞ぐ。**解法はロールバック方式**: `@State var dragStartValue: Int?` にジェスチャー開始時点の値を記憶し、`onChanged` 内で `abs(translation.height) > 10 && abs(translation.height) > abs(translation.width)`（縦方向優勢、しきい値は定数化）を検知したら `isScrollDominant` フラグを立てて以後の更新を止め、`dragStartValue` へ 1 回戻す。横ドラッグはこの条件に触れないため tap-to-seek の追従性は保たれる。「直近で実際に通知した値」を `@State lastNotifiedValue` として持ち、外部 prop（`value`、1 フレーム遅れうる）ではなくこちらと比較して `onChanged` の重複呼び出しを抑える（ロールバック通知にも同じ dedup ゲートを使い回せる）。
- **状態リセットを `onEnded` だけに頼ると固着（デッドロック）する**（レビュー指摘、2026-08-06）。SwiftUI は他のジェスチャー（List のスクロール用パン）に競り負けて `DragGesture` の認識自体がキャンセルされた場合 `onEnded` を呼ばない。`.simultaneousGesture` で共存させている以上この経路は現実的に起こる。`onEnded` だけでリセットしていると、キャンセルされた回の `isScrollDominant = true` / `dragStartValue != nil` が残ったまま次のタッチに持ち越り、**そのスライダーが以後まったく操作できなくなる**（「データが勝手に変わる」より悪い壊れ方）。**対策は `onChanged` 側での自己回復**: 毎回のイベントで `abs(translation.width) < 0.1 && abs(translation.height) < 0.1`（touch down 直後は translation が理論上ゼロだが浮動小数点の完全一致は避け微小閾値にする）を「新しいジェスチャーの最初のイベント」とみなし、そこで `dragStartValue`/`isScrollDominant`/`lastNotifiedValue` をまとめて初期化する（`dragStartValue == nil` を条件にした遅延初期化はやめる）。`onEnded` のリセットは保険として残してよいが、正の初期化は `onChanged` 側に置く。

## 一覧行のサムネイルは `PhotoFileStore` に `nonisolated static func async` の縮小デコード API を生やせば、呼び出し側は `.task(id:)` だけで済む（2026-08-07、CoffeeListView UX-7/8 で確認）

- 一覧セルのような「多数行を同時スクロール」する場面で `UIImage(contentsOfFile:)`（フルデコード同期 API）を使うとカクつく。`CGImageSourceCreateWithURL` + `CGImageSourceCreateThumbnailAtIndex`（`kCGImageSourceThumbnailMaxPixelSize` 指定）でデコード時点から縮小するのが定石（`ImageDownsampler` と同じ API・`Data` ではなく `URL` 入力版）。
- **メインスレッドを塞がないために `Task.detached` や専用 `actor` を新設する必要はない**。関数を `@MainActor` の付いていない型（enum の `static func`）の **`async`** にするだけで、宣言上 `nonisolated` になり、`@MainActor` 呼び出し元から `await` すると本体はメインスレッドを離れて実行される（Swift の「nonisolated async は呼び出し元のアクターに関係なくグローバル実行キューで走る」という基本挙動をそのまま使う）。`NSCache` はスレッドセーフなのでキャッシュの排他制御も不要（キーは `"\(fileName)#\(maxPixelSize)"`）。
- 呼び出し側は `@State private var image: UIImage?` + `.task(id: fileName) { image = nil; ...; image = await Store.loadThumbnail(...) }` の 1 パターンで、①初期表示 ②`fileName` 変化時の再取得+旧画像の即時クリア（セル再利用対策）③View 消滅時キャンセル、を全部満たす。`maxPixelSize` は `@Environment(\.displayScale)`（`UIScreen.main` は iOS 26 で deprecated）× pt サイズで求める。
- `PhotoFileStore` の「絶対パスを呼び出し側に露出しない」方針は、サムネイル API 自体を `PhotoFileStore` に生やす（`photosDirectoryURL` の解決を内部に閉じる）ことで自然に守れる。別ユーティリティに分離すると `photosDirectoryURL`（`private` ではなく既存 `static var`）を外から叩く形になり、方針をなぞるための追加の気遣いが要る。

## 排他的な複数種シート + 「表示中だけ連動する強調状態」は `enum: Identifiable` の単一 `@State item` + `.sheet(item:)` に一本化する（2026-07-24、MapTabView 好み一致/保存済みチップ操作モデル改修で確認）

- 「チップ A/B どちらか一方だけ開ける一覧シート」+「シート表示中だけマップ側の強調（他ピン減光）を ON にする」要件は、`isPresentingA`/`isPresentingB`/`emphasisA`/`emphasisB` の 4 `@State` bool で個別管理すると、閉じ忘れ（下スワイプ dismiss 時に強調 bool だけ残る）や排他性の手動維持（相手を false にし忘れる）が起きやすい。`enum Kind: Identifiable { case a, case b; var id: Self { self } }` + `@State var activeSheet: Kind?` + `.sheet(item: $activeSheet) { kind in switch kind { ... } }` に一本化すると、①排他性（同時に 2 種は開けない）と②下スワイプ dismiss 時の自動リセット（`activeSheet` が自動的に `nil` に戻る）の両方が構造的に保証される。
- 強調状態を参照する既存の opacity / size 計算箇所（`recommendedEmphasisActive` 等）を大量に触りたくない場合は、削除した `@State var xEmphasisActive: Bool` と**同名の computed property**（`activeSheet == .x`）を追加すれば、呼び出し側は無改修で済む。
- チップのタップアクションは「常にそのシートを開く」（`activeSheet = .x`、既に開いていれば SwiftUI 側が no-op）に一本化でき、旧来の「ON→タップで強調解除のみ・一覧は再表示されない」トグル分岐（if/else）が丸ごと不要になる。
