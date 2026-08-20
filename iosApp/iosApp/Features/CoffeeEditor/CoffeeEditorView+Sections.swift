import SwiftUI
import SharedLogic
import PhotosUI

// MARK: - CoffeeEditorView Form Sections

extension CoffeeEditorView {

    // MARK: - カフェ Section（任意）

    var cafeSection: some View {
        Section {
            // カフェ選択ボタン
            Button {
                isCafeSearchPresented = true
            } label: {
                Label(
                    viewModel.draft.cafeName.isEmpty
                        ? String(localized: "カフェを選択（任意）")
                        : String(localized: "カフェを変更"),
                    systemImage: "magnifyingglass"
                )
            }
            .accessibilityLabel(String(localized: "カフェを検索"))

            // 現在地カフェサジェスト（要件 2-8）: 新規作成モードで許可済み・cafe 未選択のときだけ
            // KMP 側から反映される。カフェ選択後は自動で空になる。
            if !viewModel.suggestedCafes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.suggestedCafes, id: \.placeId) { cafe in
                            Button {
                                viewModel.onSuggestedCafeSelected(cafe: cafe)
                            } label: {
                                Label(cafe.name, systemImage: "location.fill")
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(String(localized: "近くのカフェ: \(cafe.name)"))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // カフェ選択済みの場合は名前・住所を表示
            if !viewModel.draft.cafeName.isEmpty {
                TextField(
                    String(localized: "カフェ名"),
                    text: Binding(
                        get: { viewModel.draft.cafeName },
                        set: { viewModel.onCafeNameChanged($0) }
                    )
                )
                .accessibilityLabel(String(localized: "カフェ名"))

                if !viewModel.draft.cafeAddress.isEmpty {
                    Text(viewModel.draft.cafeAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 未選択時はセルフ抽出として保存される旨を表示
                Label(String(localized: "未選択の場合はセルフ抽出として保存されます"), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "カフェ（任意）"))
        }
    }

    // MARK: - コーヒー Section

    var coffeeSection: some View {
        Section(String(localized: "コーヒー")) {
            TextField(
                String(localized: "コーヒー名（必須）"),
                text: Binding(
                    get: { viewModel.draft.name },
                    set: { viewModel.onNameChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "コーヒー名"))

            Picker(String(localized: "抽出方法"), selection: Binding(
                get: { viewModel.draft.brewMethod },
                set: { viewModel.onBrewMethodChanged($0) }
            )) {
                ForEach(BrewMethod.allCases, id: \.name) { method in
                    Text(method.localizedLabel)
                        .tag(method)
                }
            }
            .accessibilityLabel(String(localized: "抽出方法"))

            // 産地ドロップダウン（国選択。2026-07-22 自由入力 → ドロップダウン化）
            //
            // Picker の選択肢は「未選択」+「ブレンド」+ CoffeeOriginCatalog.countries + 「その他」。
            // catalog に無い legacy 値（Edit モードの旧自由入力データ）は選択肢の末尾に動的追加し、
            // Menu の現在値表示が壊れないようにフォールバックする。
            Picker(String(localized: "産地（任意）"), selection: originSelection) {
                Text(String(localized: "未選択")).tag("")
                Text(CoffeeOriginCatalog.shared.BLEND).tag(CoffeeOriginCatalog.shared.BLEND)
                ForEach(CoffeeOriginCatalog.shared.countries, id: \.self) { country in
                    Text(country).tag(country)
                }
                if let legacyOrigin {
                    Text(legacyOrigin).tag(legacyOrigin)
                }
                Text(CoffeeOriginCatalog.shared.OTHER).tag(CoffeeOriginCatalog.shared.OTHER)
            }
            .accessibilityLabel(String(localized: "産地"))

            // 「その他」選択時のみ国名の自由入力欄を表示する。literal「その他」は保存しない
            if isOtherOriginActive {
                TextField(
                    String(localized: "国名を入力"),
                    text: Binding(
                        get: { viewModel.draft.origin },
                        set: { viewModel.onOriginChanged($0) }
                    )
                )
                .accessibilityLabel(String(localized: "産地（その他・国名を入力）"))
            }

            TextField(
                String(localized: "エリア（任意）"),
                text: Binding(
                    get: { viewModel.draft.region },
                    set: { viewModel.onRegionChanged($0) }
                ),
                prompt: Text(String(localized: "イルガチェフェ"))
            )
            .accessibilityLabel(String(localized: "エリア"))

            TextField(
                String(localized: "品種（任意）"),
                text: Binding(
                    get: { viewModel.draft.variety },
                    set: { viewModel.onVarietyChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "品種"))

            Picker(String(localized: "精製方法"), selection: Binding(
                get: { viewModel.draft.processing },
                set: { viewModel.onProcessingChanged($0) }
            )) {
                Text(String(localized: "未設定")).tag(nil as ProcessingMethod?)
                ForEach(ProcessingMethod.allCases, id: \.name) { method in
                    Text(method.localizedLabel).tag(method as ProcessingMethod?)
                }
            }
            .accessibilityLabel(String(localized: "精製方法"))

            Picker(String(localized: "焙煎度"), selection: Binding(
                get: { viewModel.draft.roastLevel },
                set: { viewModel.onRoastLevelChanged($0) }
            )) {
                Text(String(localized: "未設定")).tag(nil as RoastLevel?)
                ForEach(RoastLevel.allCases, id: \.name) { level in
                    Text(level.localizedLabel).tag(level as RoastLevel?)
                }
            }
            .accessibilityLabel(String(localized: "焙煎度"))

            TextField(
                String(localized: "カップ（任意）"),
                text: Binding(
                    get: { viewModel.draft.cup },
                    set: { viewModel.onCupChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "カップ"))

            TextField(
                String(localized: "抽出レシピ（任意）"),
                text: Binding(
                    get: { viewModel.draft.brewRecipe },
                    set: { viewModel.onBrewRecipeChanged($0) }
                ),
                prompt: Text(String(localized: "豆量 / 湯量 / 湯温 / 時間 など")),
                axis: .vertical
            )
            .lineLimit(1...4)
            .accessibilityLabel(String(localized: "抽出レシピ"))
        }
    }

    // MARK: - 産地ドロップダウン ヘルパー

    /// catalog に無い legacy な産地値（Edit モードの旧自由入力データ）。
    /// 「その他」入力中や catalog / ブレンドに一致する値は対象外（Picker の tag 重複を避ける）。
    private var legacyOrigin: String? {
        let origin = viewModel.draft.origin
        guard !origin.isEmpty,
              !isOtherOriginActive,
              !CoffeeOriginCatalog.shared.countries.contains(origin),
              origin != CoffeeOriginCatalog.shared.BLEND
        else {
            return nil
        }
        return origin
    }

    /// 産地 Picker の選択 Binding。「その他」選択中は Picker 上は OTHER 固定表示にし、
    /// 実際の入力は下の TextField（`viewModel.draft.origin` 直結）に委ねる。
    private var originSelection: Binding<String> {
        Binding(
            get: {
                isOtherOriginActive ? CoffeeOriginCatalog.shared.OTHER : viewModel.draft.origin
            },
            set: { newValue in
                if newValue == CoffeeOriginCatalog.shared.OTHER {
                    isOtherOriginActive = true
                    // literal「その他」は保存しない。自由入力欄を空から始める
                    viewModel.onOriginChanged("")
                } else {
                    isOtherOriginActive = false
                    viewModel.onOriginChanged(newValue)
                }
            }
        )
    }

    // MARK: - テイスティング Section

    /// テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）の入力セクション。
    ///
    /// all-or-nothing: `+` ボタン 1 つで 5 スライダーを一括表示（初期値 5）。
    /// 削除ボタンで nil に戻す（＋ボタン表示に戻る）。
    var tastingSection: some View {
        let tasting = viewModel.draft.tasting

        return Section {
            if let tasting = tasting {
                // テイスティングあり: 5 スライダーを表示
                tastingSliderRow(
                    label: String(localized: "甘味"),
                    value: Int(tasting.sweetness),
                    onChanged: { viewModel.onSweetnessChanged(Int32($0)) }
                )
                tastingSliderRow(
                    label: String(localized: "ボディ"),
                    value: Int(tasting.body),
                    onChanged: { viewModel.onBodyChanged(Int32($0)) }
                )
                tastingSliderRow(
                    label: String(localized: "酸味"),
                    value: Int(tasting.acidity),
                    onChanged: { viewModel.onAcidityChanged(Int32($0)) }
                )
                tastingSliderRow(
                    label: String(localized: "風味"),
                    value: Int(tasting.flavor),
                    onChanged: { viewModel.onFlavorChanged(Int32($0)) }
                )
                tastingSliderRow(
                    label: String(localized: "後味"),
                    value: Int(tasting.aftertaste),
                    onChanged: { viewModel.onAftertasteChanged(Int32($0)) }
                )
                // 削除ボタン
                Button(role: .destructive) {
                    viewModel.onTastingCleared()
                } label: {
                    Label(String(localized: "テイスティングを削除"), systemImage: "trash")
                }
                .accessibilityLabel(String(localized: "テイスティングを削除"))
            } else {
                // テイスティングなし: 追加ボタンのみ
                Button {
                    viewModel.onTastingAdded()
                } label: {
                    Label(String(localized: "テイスティングを追加"), systemImage: "plus.circle")
                }
                .accessibilityLabel(String(localized: "テイスティングを追加（5 要素一括）"))
            }
        } header: {
            Text(String(localized: "テイスティング（任意）"))
        } footer: {
            if tasting != nil {
                Text(String(localized: "1（弱）〜 10（強）の強度スケール"))
                    .font(.caption)
            }
        }
    }

    /// テイスティング 1 要素のスライダー行。
    ///
    /// - `value`: 1..10 の整数値
    /// - `onChanged`: 値変更時のコールバック（Int を渡す）
    @ViewBuilder
    private func tastingSliderRow(
        label: String,
        value: Int,
        onChanged: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .frame(minWidth: 44, alignment: .leading)
                Spacer()
                Text("\(value)/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .trailing)
            }
            TappableTastingSlider(value: value, range: 1...10, onChanged: onChanged)
                .accessibilityLabel(label)
                .accessibilityValue(String(localized: "\(label) \(value)/10"))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        onChanged(min(value + 1, 10))
                    case .decrement:
                        onChanged(max(value - 1, 1))
                    @unknown default:
                        break
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(label) \(value)/10"))
    }

    // MARK: - タグ Section

    var tagsSection: some View {
        Section(String(localized: "タグ")) {
            ForEach(viewModel.tags, id: \.self) { tag in
                HStack {
                    Text(tag)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        viewModel.onTagRemoved(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "タグ「\(tag)」を削除"))
                }
            }

            HStack {
                TextField(
                    String(localized: "タグを追加..."),
                    text: Binding(
                        get: { viewModel.tagInput },
                        set: { viewModel.onTagInputChanged($0) }
                    )
                )
                .font(.subheadline)
                .onSubmit {
                    addTag()
                }
                Button(String(localized: "追加")) {
                    addTag()
                }
                .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .font(.subheadline)
            }

            // 過去に使ったタグのサジェスト（要件 2-13）: 使用回数降順・部分一致絞り込み・
            // 付与済み除外・上限 10 件はすべて KMP 側で適用済み。Swift 側でソート/フィルタしない。
            if !viewModel.suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.suggestedTags, id: \.self) { tag in
                            Button {
                                viewModel.onTagAdded(tag)
                            } label: {
                                Label(tag, systemImage: "tag")
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(String(localized: "タグを追加: \(tag)"))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func addTag() {
        let trimmed = viewModel.tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.onTagAdded(trimmed)
    }

    // MARK: - 記録 Section

    var visitSection: some View {
        Section(String(localized: "記録")) {
            DatePicker(
                String(localized: "記録日"),
                selection: Binding(
                    get: { localDateToDate(viewModel.draft.visitedOn) },
                    set: { viewModel.onVisitedOnChanged(dateToLocalDate($0)) }
                ),
                displayedComponents: .date
            )
            .accessibilityLabel(String(localized: "記録日"))

            LabeledContent(String(localized: "評価")) {
                StarRatingView(
                    rating: viewModel.draft.rating?.doubleValue,
                    onChange: { viewModel.onRatingChanged(rating: $0) }
                )
            }
            .accessibilityLabel(String(localized: "評価"))

            TextField(
                String(localized: "メモ（任意）"),
                text: Binding(
                    get: { viewModel.draft.notes },
                    set: { viewModel.onNotesChanged($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "メモ"))
        }
    }

    // MARK: - 写真 Section

    var photosSection: some View {
        Section(String(localized: "写真")) {
            let photos = viewModel.draft.photos
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(photos) { photo in
                            PhotoThumbnailCell(
                                photo: photo,
                                pendingData: pendingImageData[photo.id],
                                onDelete: {
                                    handlePhotoDelete(photo: photo)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 116)
            }

            let remainingCount = CoffeeEditorView.maxPhotoCount - photos.count
            let addLabel = remainingCount > 0
                ? String(localized: "写真を追加")
                : String(localized: "写真は最大\(CoffeeEditorView.maxPhotoCount)枚までです")

            // maxSelectionCount に 0 を渡すと「無制限」の意味になるため、上限到達時も 1 以上を渡し、
            // `.disabled` でピッカー自体を開けなくして枚数を確定させる。
            PhotosPicker(
                selection: $selectedPickerItems,
                maxSelectionCount: max(remainingCount, 1),
                matching: .images
            ) {
                Label(addLabel, systemImage: "plus")
            }
            .disabled(remainingCount <= 0)
            .accessibilityLabel(addLabel)
        }
    }
}

// MARK: - TappableTastingSlider（tap-to-seek 対応スライダー）

/// テイスティングスライダー専用の tap-to-seek コンポーネント。
///
/// 標準 `Slider` はトラック部分のタップを無視し thumb のドラッグしか受け付けないため、
/// 「トラックのどこをタップしても即座にその位置の値へ変わり、そのまま指を滑らせると
/// thumb が追従する」体験を実現するには標準 `Slider` の描画をそのまま使いつつ、
/// ジェスチャーだけを透明なレイヤーに差し替える必要がある。
///
/// 構成:
/// - 標準 `Slider` を `.allowsHitTesting(false)` にして「見た目の描画専用」にする
///   （渡された `value` をそのまま表示するだけで、自身はタッチを受け取らない）
/// - 同じ frame に重ねた `Color.clear` に `DragGesture(minimumDistance: 0)` を付け、
///   タップ（＝距離 0 のドラッグ開始）とドラッグ追従の両方をこのレイヤー 1 つで処理する
/// - Form/List の縦スクロールと共存させるため `.simultaneousGesture` を使う。その代償として
///   touch down 直後の `onChanged` でタップ位置の値へ即書き換わってしまうため、縦方向優勢と
///   判定した時点で以後の更新を止め、ジェスチャー開始時点の値へロールバックする
private struct TappableTastingSlider: View {

    /// 現在値（1...10 などの整数域）
    let value: Int

    /// 値域（step は常に 1 固定）
    let range: ClosedRange<Int>

    /// 値変更時のコールバック。スナップ後の整数値のみが渡される（中間値は流れない）
    let onChanged: (Int) -> Void

    /// 標準 `Slider` のつまみ（knob）の概算直径。
    ///
    /// つまみの中心は左右それぞれこの半径ぶん内側までしか移動できない
    /// （トラックの描画幅 ＝ View 幅そのものではなく、左右に半径ぶん詰まっている）。
    /// この補正をせずに View 幅そのものから値を算出すると、両端（最小値/最大値）に
    /// 到達できない・端付近で値が飛ぶ、という不具合になる。
    /// システムスライダーの標準的なつまみサイズ（約 28pt）を採用した近似値。
    /// 実機/シミュレータで見た目と算出値がズレる場合はここを調整する。
    private static let thumbDiameter: CGFloat = 28

    /// 「縦スクロールしようとしただけ」と判定するしきい値（pt）。
    ///
    /// `DragGesture(minimumDistance: 0)` は touch down の瞬間に `onChanged` が発火するため、
    /// Form を縦スクロールしようとしてスライダー行に指を置いただけでもタップ位置の値へ
    /// 書き換わってしまう。縦方向の移動量がこのしきい値を超え、かつ横方向の移動量より
    /// 大きくなった時点で「スクロール意図」と判定し、以後そのジェスチャーが終わるまで
    /// 値の更新を止めてジェスチャー開始時点の値へ戻す。
    private static let scrollDominanceThreshold: CGFloat = 10

    /// このジェスチャーが始まった時点の値。スクロールと判定したときの復帰先
    @State private var dragStartValue: Int?

    /// このジェスチャーが「縦スクロール」と判定済みかどうか（判定後は値更新を一切行わない）
    @State private var isScrollDominant = false

    /// 直近で `onChanged` に通知した値。SwiftUI の再描画が来る前に複数の `onChanged`
    /// イベントが連続発火しても、外部の `value`（1 フレーム遅れうる）ではなくこちらと
    /// 比較することで、同一ジェスチャー内の重複通知をより確実に避ける
    @State private var lastNotifiedValue: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Slider(
                    value: .constant(Double(value)),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .allowsHitTesting(false)

                // `.simultaneousGesture` を使う（`.gesture` だと Form/List の縦スクロール用パン
                // ジェスチャーより優先されてしまい、スライダー行の上から始めた縦スワイプで
                // スクロールできなくなる）。ただし `.simultaneousGesture` だけでは
                // touch down 直後の `onChanged` でタップ位置の値へ書き換わってしまうため、
                // 縦方向優勢と判定したら値をロールバックする処理を `handleDragChanged` に持たせている
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                handleDragChanged(drag, width: geometry.size.width)
                            }
                            .onEnded { _ in
                                handleDragEnded()
                            }
                    )
            }
        }
        // 44×44pt のタップ領域確保（トラック自体は細いため縦方向のヒット領域を拡張する）
        .frame(height: 44)
        // 標準 Slider が持つ「値が変わった瞬間の触覚フィードバック」を tap-to-seek でも再現する。
        // trigger（value）が実際に変化したときだけ発火するため、同じ値に張り付いている間の連続発火は起きない
        .sensoryFeedback(.selection, trigger: value)
        // 単一の操作要素として扱う（呼び出し元で accessibilityLabel/value/adjustableAction を付与する）
        .accessibilityElement(children: .ignore)
    }

    /// 新しいジェスチャーの最初のイベントとみなす translation のしきい値（pt）。
    ///
    /// SwiftUI は他のジェスチャー（List のスクロール用パン）に競り負けて認識をキャンセルした場合
    /// `onEnded` を呼ばない。`onEnded` だけに状態リセットを頼ると、キャンセルされた次に同じ
    /// スライダーへ触れたときに古い `isScrollDominant`/`dragStartValue` が残り、二度と操作できなく
    /// なる（「データが勝手に変わる」より悪い固着）。そのため **`onChanged` 側で「これは新しい
    /// ジェスチャーの最初のイベントか」を毎回判定し、そこで状態をまとめて初期化する**方式にする。
    /// touch down 直後の最初のイベントは `translation` が理論上ゼロだが、浮動小数点の完全一致比較は
    /// 避け、微小な閾値未満なら「開始イベント」とみなす。
    private static let gestureStartTranslationThreshold: CGFloat = 0.1

    /// ドラッグ中の 1 イベントを処理する。
    ///
    /// - 新しいジェスチャーの最初のイベントで状態（開始値・縦優勢フラグ・直近通知値）をまとめて初期化する
    /// - 縦方向優勢と判定したら以後は値更新をやめ、記憶しておいた開始時の値へ戻す
    /// - それ以外（タップ直後・横方向のドラッグ）は従来どおり即座に位置から値を算出して通知する
    private func handleDragChanged(_ drag: DragGesture.Value, width: CGFloat) {
        let translation = drag.translation
        let isGestureStart = abs(translation.width) < Self.gestureStartTranslationThreshold
            && abs(translation.height) < Self.gestureStartTranslationThreshold
        if isGestureStart {
            dragStartValue = value
            isScrollDominant = false
            lastNotifiedValue = nil
        }

        if !isScrollDominant {
            if abs(translation.height) > Self.scrollDominanceThreshold,
               abs(translation.height) > abs(translation.width) {
                isScrollDominant = true
            }
        }

        if isScrollDominant {
            if let startValue = dragStartValue {
                notify(startValue)
            }
            return
        }

        updateValue(from: drag.location.x, width: width)
    }

    /// ジェスチャー正常終了時の状態リセット。
    ///
    /// これは保険であり、状態の正の初期化は上記 `handleDragChanged` の「ジェスチャー開始判定」側で
    /// 行う（`onEnded` は他のジェスチャーに競り負けてキャンセルされた場合に呼ばれないため、
    /// ここだけに頼ると固着する）。
    private func handleDragEnded() {
        dragStartValue = nil
        isScrollDominant = false
        lastNotifiedValue = nil
    }

    /// タップ/ドラッグ位置の x 座標から値を算出し、通知する。
    private func updateValue(from x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let radius = Self.thumbDiameter / 2
        let usableWidth = max(width - Self.thumbDiameter, 1)
        let clampedX = min(max(x - radius, 0), usableWidth)
        let fraction = clampedX / usableWidth
        let span = Double(range.upperBound - range.lowerBound)
        let newValue = Int((Double(range.lowerBound) + fraction * span).rounded())
        notify(newValue)
    }

    /// 直近の通知値と比較し、実際に変化しているときだけ `onChanged` を呼ぶ。
    private func notify(_ newValue: Int) {
        guard newValue != (lastNotifiedValue ?? value) else { return }
        lastNotifiedValue = newValue
        onChanged(newValue)
    }
}

// MARK: - Preview（TappableTastingSlider: 1 / 5 / 10 のつまみ位置確認）

#Preview("TappableTastingSlider") {
    VStack(alignment: .leading, spacing: 24) {
        ForEach([1, 5, 10], id: \.self) { fixedValue in
            VStack(alignment: .leading, spacing: 4) {
                Text("固定値 \(fixedValue)/10（つまみ位置の目視確認用）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TappableTastingSlider(value: fixedValue, range: 1...10, onChanged: { _ in })
            }
        }

        Divider()

        TappableTastingSliderInteractivePreview()
    }
    .padding()
}

/// 実機/シミュレータでタップ・ドラッグの挙動を試すための対話的プレビュー
private struct TappableTastingSliderInteractivePreview: View {
    @State private var value = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("操作確認用（タップ・ドラッグで値: \(value)/10）")
                .font(.caption)
                .foregroundStyle(.secondary)
            TappableTastingSlider(value: value, range: 1...10, onChanged: { value = $0 })
        }
    }
}

