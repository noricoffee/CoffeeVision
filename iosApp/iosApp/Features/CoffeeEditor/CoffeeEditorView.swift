import SwiftUI
import SharedLogic
import PhotosUI

// MARK: - CoffeeEditorView

/// コーヒー記録作成 / 編集画面。
///
/// - `CoffeeListView` / `CoffeeDetailView` の `.sheet` で開かれる前提のため、自身を `NavigationStack` でラップする
/// - Bridge は遷移ごとに新規生成するため、View 内 `@State` で保持する（AppState にホルダを持たせない）
/// - cafe は任意（セルフ抽出も可）。カフェ未選択の場合は「セルフ抽出」として保存
struct CoffeeEditorView: View {

    // MARK: - Properties

    let mode: any CoffeeEditorViewModelMode
    let appState: AppState

    /// カフェ詳細画面から起動した場合に pre-fill するカフェ。
    let initialCafe: Cafe?

    @State private var viewModel: CoffeeEditorViewModelBridge
    @Environment(\.dismiss) private var dismiss

    @State private var isCafeSearchPresented: Bool = false

    /// 新規追加分の写真データ（photoId → JPEG Data）。保存ボタン押下時に Documents に書き出す。
    @State private var pendingImageData: [String: Data] = [:]
    /// Editor 内で削除した既存写真の fileName。保存成功後に Documents から物理削除する。
    @State private var removedFileNames: Set<String> = []
    /// PhotosPicker の選択状態。選択処理後に [] にリセットする。
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    /// 写真保存処理中の error（保存失敗時に alert 表示）。
    @State private var photoSaveError: String?

    // MARK: - Init

    /// 通常の CoffeeEditor 起動（カフェ pre-fill なし）。
    init(mode: any CoffeeEditorViewModelMode, appState: AppState, initialCafe: Cafe? = nil) {
        self.mode = mode
        self.appState = appState
        self.initialCafe = initialCafe
        _viewModel = State(
            initialValue: CoffeeEditorViewModelBridge(
                kotlin: appState.container.makeCoffeeEditorViewModel()
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                cafeSection
                coffeeSection
                tastingSection
                visitSection
                photosSection
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                viewModel.onAppear(mode: mode, userId: appState.uid ?? "")
                // CafeDetailView から起動した場合はカフェを pre-fill する
                if let cafe = initialCafe {
                    viewModel.onPlacesCafeSelected(cafe: cafe)
                }
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .alert(
                String(localized: "エラー"),
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.onErrorDismissed() } }
                )
            ) {
                Button(String(localized: "OK")) {
                    viewModel.onErrorDismissed()
                }
            } message: {
                Text(viewModel.error ?? "")
            }
            .onChange(of: viewModel.savedCoffeeId) { _, newValue in
                if newValue != nil {
                    // 保存成功後に Editor 内で削除した既存写真ファイルを物理削除する
                    for fileName in removedFileNames {
                        try? PhotoFileStore.delete(fileName: fileName)
                    }
                    dismiss()
                }
            }
            .onChange(of: selectedPickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await handlePickerSelection(newItems)
                }
            }
            .alert(
                String(localized: "写真の保存に失敗しました"),
                isPresented: Binding(
                    get: { photoSaveError != nil },
                    set: { if !$0 { photoSaveError = nil } }
                )
            ) {
                Button(String(localized: "OK")) { photoSaveError = nil }
            } message: {
                Text(photoSaveError ?? "")
            }
            .sheet(isPresented: $isCafeSearchPresented) {
                NavigationStack {
                    CafeSearchView(appState: appState) { cafe in
                        viewModel.onPlacesCafeSelected(cafe: cafe)
                        isCafeSearchPresented = false
                    }
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - カフェ Section（任意）

    private var cafeSection: some View {
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

    private var coffeeSection: some View {
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

            TextField(
                String(localized: "産地（任意）"),
                text: Binding(
                    get: { viewModel.draft.origin },
                    set: { viewModel.onOriginChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "産地"))

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
        }
    }

    // MARK: - テイスティング Section

    /// テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）の入力セクション。
    ///
    /// all-or-nothing: `+` ボタン 1 つで 5 スライダーを一括表示（初期値 5）。
    /// 削除ボタンで nil に戻す（＋ボタン表示に戻る）。
    private var tastingSection: some View {
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

    // MARK: - 記録 Section

    private var visitSection: some View {
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
                    rating: viewModel.draft.rating,
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

    private var photosSection: some View {
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

    // MARK: - 写真操作

    /// PhotosPicker 選択後の処理。Data 取得 → JPEG 変換 → Photo_ 生成 → VM に通知。
    private func handlePickerSelection(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                continue
            }

            let photoId = UUID().uuidString.lowercased()
            let fileName = "\(photoId).jpg"
            let localPath = "photos/\(fileName)"

            let widthPx = Int32(uiImage.size.width * uiImage.scale)
            let heightPx = Int32(uiImage.size.height * uiImage.scale)

            let epochMillis = Int64(Date().timeIntervalSince1970 * 1000)
            let createdAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
                epochMilliseconds: epochMillis
            )

            let photo = Photo_(
                id: photoId,
                fileName: fileName,
                localPath: localPath,
                remoteUrl: nil,
                width: KotlinInt(value: widthPx),
                height: KotlinInt(value: heightPx),
                createdAt: createdAt
            )

            pendingImageData[photoId] = jpegData
            viewModel.onPhotoUpserted(item: photo)
        }
        selectedPickerItems = []
    }

    /// × ボタン押下時の写真削除処理。
    private func handlePhotoDelete(photo: Photo_) {
        if pendingImageData.removeValue(forKey: photo.id) != nil {
            // 新規追加分: メモリから消すだけ。Documents にはまだ書かれていない
        } else {
            // 既存写真: 保存成功後に物理削除するため fileName を記録
            if let fileName = photo.fileName {
                removedFileNames.insert(fileName)
            }
        }
        viewModel.onPhotoRemoved(id: photo.id)
    }

    /// 保存ボタン押下時の処理。
    /// pendingImageData を Documents に書き出してから VM の onSaveTapped を呼ぶ。
    private func saveWithPhotoFlush() async {
        let currentPhotos = viewModel.draft.photos
        var flushedFileNames: [String] = []
        do {
            for photo in currentPhotos {
                guard let data = pendingImageData[photo.id],
                      let fileName = photo.fileName else { continue }
                try PhotoFileStore.save(data: data, fileName: fileName)
                flushedFileNames.append(fileName)
            }
        } catch {
            // 書き出し失敗: 既に書いた分を rollback してエラー表示
            for fileName in flushedFileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            photoSaveError = error.localizedDescription
            return
        }

        // 全ファイル書き出し成功後に保存
        viewModel.onSaveTapped()
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(String(localized: "キャンセル")) {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(String(localized: "保存")) {
                Task {
                    await saveWithPhotoFlush()
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    // MARK: - ナビゲーションタイトル

    private var navigationTitle: String {
        if mode is CoffeeEditorViewModelModeCreate {
            return String(localized: "コーヒーを記録")
        } else {
            return String(localized: "記録を編集")
        }
    }

    // MARK: - LocalDate ↔ Date 変換

    private func localDateToDate(_ localDate: Kotlinx_datetimeLocalDate) -> Date {
        var components = DateComponents()
        components.year = Int(localDate.year)
        components.month = Int(localDate.monthNumber)
        components.day = Int(localDate.dayOfMonth)
        return Calendar.current.date(from: components) ?? Date()
    }

    private func dateToLocalDate(_ date: Date) -> Kotlinx_datetimeLocalDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Kotlinx_datetimeLocalDate(
            year: Int32(components.year ?? 2026),
            monthNumber: Int32(components.month ?? 1),
            dayOfMonth: Int32(components.day ?? 1)
        )
    }

    // MARK: - BrewMethod ローカライズ

    private func localizedBrewMethod(_ method: BrewMethod) -> String {
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

// MARK: - PhotoThumbnailCell

/// 写真セクション内の 1 枚サムネイルセル（削除ボタン付き）。
private struct PhotoThumbnailCell: View {

    let photo: Photo_
    let pendingData: Data?
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailImage
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .accessibilityLabel(String(localized: "写真を削除"))
            .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "写真"))
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let data = pendingData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let fileName = photo.fileName,
                  let uiImage = PhotoFileStore.loadImage(fileName: fileName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Preview (新規作成 Demo)

#Preview("新規作成 Demo") {
    NavigationStack {
        Form {
            Section {
                Button {} label: {
                    Label(String(localized: "カフェを選択（任意）"), systemImage: "magnifyingglass")
                }
                Label(String(localized: "未選択の場合はセルフ抽出として保存されます"), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "カフェ（任意）"))
            }

            Section(String(localized: "コーヒー")) {
                TextField(String(localized: "コーヒー名（必須）"), text: .constant(""))
                Text("ハンドドリップ").foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text(String(localized: "甘味"))
                    Spacer()
                    Text("7/10").font(.subheadline).foregroundStyle(.secondary)
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                Slider(value: .constant(7), in: 1...10, step: 1)
                HStack {
                    Text(String(localized: "酸味"))
                    Spacer()
                    Image(systemName: "plus.circle").foregroundStyle(Color.accentColor)
                }
            } header: {
                Text(String(localized: "テイスティング（任意）"))
            } footer: {
                Text(String(localized: "1（弱）〜 10（強）の強度スケール。未設定はスキップできます。"))
                    .font(.caption)
            }

            Section(String(localized: "記録")) {
                LabeledContent(String(localized: "記録日")) {
                    Text("2026/06/19")
                }
                LabeledContent(String(localized: "評価")) {
                    StarRatingView(rating: 0.0)
                }
            }

            Section(String(localized: "写真")) {
                Label(String(localized: "写真を追加"), systemImage: "plus")
            }
        }
        .navigationTitle(String(localized: "コーヒーを記録"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "キャンセル")) {}
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "保存")) {}
                    .disabled(true)
            }
        }
    }
}
