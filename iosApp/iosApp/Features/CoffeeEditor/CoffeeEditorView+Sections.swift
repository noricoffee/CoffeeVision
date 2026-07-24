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
                    Text(localizedBrewMethod(method))
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
                    Text(method.name).tag(method as ProcessingMethod?)
                }
            }
            .accessibilityLabel(String(localized: "精製方法"))

            Picker(String(localized: "焙煎度"), selection: Binding(
                get: { viewModel.draft.roastLevel },
                set: { viewModel.onRoastLevelChanged($0) }
            )) {
                Text(String(localized: "未設定")).tag(nil as RoastLevel?)
                ForEach(RoastLevel.allCases, id: \.name) { level in
                    Text(level.name).tag(level as RoastLevel?)
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
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChanged(Int($0.rounded())) }
                ),
                in: 1...10,
                step: 1
            )
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
                TextField(String(localized: "タグを追加..."), text: $newTagText)
                    .font(.subheadline)
                    .onSubmit {
                        addTag()
                    }
                Button(String(localized: "追加")) {
                    addTag()
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                .font(.subheadline)
            }
        }
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.onTagAdded(trimmed)
        newTagText = ""
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

            PhotosPicker(
                selection: $selectedPickerItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Label(String(localized: "写真を追加"), systemImage: "plus")
            }
            .accessibilityLabel(String(localized: "写真を追加"))
        }
    }

    // MARK: - BrewMethod ローカライズ

    func localizedBrewMethod(_ method: BrewMethod) -> String {
        switch method {
        case .handDrip: return String(localized: "ハンドドリップ")
        case .espresso: return String(localized: "エスプレッソ")
        case .nelDrip: return String(localized: "ネルドリップ")
        case .frenchPress: return String(localized: "フレンチプレス")
        case .aeroPress: return String(localized: "エアロプレス")
        case .syphon: return String(localized: "サイフォン")
        case .coldBrew: return String(localized: "コールドブリュー")
        case .other: return String(localized: "その他")
        @unknown default: return method.name
        }
    }
}
