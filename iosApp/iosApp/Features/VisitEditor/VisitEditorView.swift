import SwiftUI
import SharedLogic
import PhotosUI

// MARK: - シート用 Identifiable ラッパ

/// コーヒーアイテム編集シートのターゲット。
///
/// `.sheet(item:)` と `Identifiable` の組み合わせで、
/// nil = 非表示 / 非 nil = 表示（新規 or 既存）を切り替える。
private enum CoffeeEditingTarget: Identifiable {
    case new
    case existing(CoffeeItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let item): return item.id
        }
    }

    /// シート初期値。新規は nil、編集は既存 CoffeeItem。
    var initial: CoffeeItem? {
        switch self {
        case .new: return nil
        case .existing(let item): return item
        }
    }
}

/// フードアイテム編集シートのターゲット。
private enum FoodEditingTarget: Identifiable {
    case new
    case existing(FoodItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let item): return item.id
        }
    }

    var initial: FoodItem? {
        switch self {
        case .new: return nil
        case .existing(let item): return item
        }
    }
}

// MARK: - VisitEditorView

/// 訪問記録作成 / 編集画面。
///
/// - `VisitListView` / `VisitDetailView` の `.sheet` で開かれる前提のため、自身を `NavigationStack` でラップする
/// - Bridge は遷移ごとに新規生成するため、View 内 `@State` で保持する（AppState にホルダを持たせない）
struct VisitEditorView: View {

    // MARK: - Properties

    let mode: any VisitEditorViewModelMode
    let appState: AppState

    @State private var viewModel: VisitEditorViewModelBridge
    @Environment(\.dismiss) private var dismiss

    @State private var coffeeBeingEdited: CoffeeEditingTarget?
    @State private var foodBeingEdited: FoodEditingTarget?

    /// 新規追加分の写真データ（photoId → JPEG Data）。保存ボタン押下時に Documents に書き出す。
    @State private var pendingImageData: [String: Data] = [:]
    /// Editor 内で削除した既存写真の fileName。保存成功後に Documents から物理削除する。
    @State private var removedFileNames: Set<String> = []
    /// PhotosPicker の選択状態。選択処理後に [] にリセットする。
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    /// 写真保存処理中の error（保存失敗時に alert 表示）。
    @State private var photoSaveError: String?

    // MARK: - Init

    init(mode: any VisitEditorViewModelMode, appState: AppState) {
        self.mode = mode
        self.appState = appState
        _viewModel = State(
            initialValue: VisitEditorViewModelBridge(
                kotlin: appState.container.makeVisitEditorViewModel()
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                cafeSection
                visitSection
                photosSection
                coffeeSection
                foodSection
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                viewModel.onAppear(mode: mode, userId: appState.uid ?? "")
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
            .onChange(of: viewModel.savedVisitId) { _, newValue in
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
            .sheet(item: $coffeeBeingEdited) { target in
                CoffeeItemEditorView(
                    initial: target.initial,
                    onSave: { viewModel.onCoffeeUpserted(item: $0) }
                )
            }
            .sheet(item: $foodBeingEdited) { target in
                FoodItemEditorView(
                    initial: target.initial,
                    onSave: { viewModel.onFoodUpserted(item: $0) }
                )
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

    // MARK: - カフェ Section

    private var cafeSection: some View {
        Section(String(localized: "カフェ")) {
            TextField(
                String(localized: "カフェ名（必須）"),
                text: Binding(
                    get: { viewModel.draft.cafeName },
                    set: { viewModel.onCafeNameChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "カフェ名"))

            TextField(
                String(localized: "住所（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeAddress },
                    set: { viewModel.onCafeAddressChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "住所"))

            TextField(
                String(localized: "Web サイト URL（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeWebsiteUrl },
                    set: { viewModel.onCafeWebsiteUrlChanged($0) }
                )
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(String(localized: "Web サイト URL"))

            TextField(
                String(localized: "Google Maps URL（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeMapsUrl },
                    set: { viewModel.onCafeMapsUrlChanged($0) }
                )
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(String(localized: "Google Maps URL"))
        }
    }

    // MARK: - 訪問 Section

    private var visitSection: some View {
        Section(String(localized: "訪問")) {
            DatePicker(
                String(localized: "訪問日"),
                selection: Binding(
                    get: { localDateToDate(viewModel.draft.visitedOn) },
                    set: { viewModel.onVisitedOnChanged(dateToLocalDate($0)) }
                ),
                displayedComponents: .date
            )
            .accessibilityLabel(String(localized: "訪問日"))

            LabeledContent(String(localized: "評価")) {
                StarRatingView(
                    rating: Int(viewModel.draft.rating),
                    onChange: { viewModel.onRatingChanged(rating: $0) }
                )
            }
            .accessibilityLabel(String(localized: "評価"))

            TextField(
                String(localized: "雰囲気（任意）"),
                text: Binding(
                    get: { viewModel.draft.ambiance },
                    set: { viewModel.onAmbianceChanged($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "雰囲気"))

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

    // MARK: - コーヒー Section

    private var coffeeSection: some View {
        Section(String(localized: "コーヒー")) {
            ForEach(viewModel.draft.coffees) { coffee in
                Button {
                    coffeeBeingEdited = .existing(coffee)
                } label: {
                    CoffeeItemSummaryRow(coffee: coffee)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(coffee.name)
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    let coffees = viewModel.draft.coffees
                    if index < coffees.count {
                        viewModel.onCoffeeRemoved(id: coffees[index].id)
                    }
                }
            }

            Button {
                coffeeBeingEdited = .new
            } label: {
                Label(String(localized: "コーヒーを追加"), systemImage: "plus")
            }
            .accessibilityLabel(String(localized: "コーヒーを追加"))
        }
    }

    // MARK: - フード Section

    private var foodSection: some View {
        Section(String(localized: "フード")) {
            ForEach(viewModel.draft.foods) { food in
                Button {
                    foodBeingEdited = .existing(food)
                } label: {
                    FoodItemSummaryRow(food: food)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(food.name)
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    let foods = viewModel.draft.foods
                    if index < foods.count {
                        viewModel.onFoodRemoved(id: foods[index].id)
                    }
                }
            }

            Button {
                foodBeingEdited = .new
            } label: {
                Label(String(localized: "フードを追加"), systemImage: "plus")
            }
            .accessibilityLabel(String(localized: "フードを追加"))
        }
    }

    // MARK: - 写真 Section

    private var photosSection: some View {
        Section(String(localized: "写真")) {
            if !viewModel.draft.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(viewModel.draft.photos) { photo in
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
        // pendingImageData を Documents に書き出す
        var flushedFileNames: [String] = []
        do {
            for photo in viewModel.draft.photos {
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
        if mode is VisitEditorViewModelModeCreate {
            return String(localized: "新規訪問")
        } else {
            return String(localized: "訪問の編集")
        }
    }

    // MARK: - LocalDate ↔ Date 変換

    /// `Kotlinx_datetimeLocalDate` を Foundation の `Date` に変換する。
    private func localDateToDate(_ localDate: Kotlinx_datetimeLocalDate) -> Date {
        var components = DateComponents()
        components.year = Int(localDate.year)
        components.month = Int(localDate.monthNumber)
        components.day = Int(localDate.dayOfMonth)
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Foundation の `Date` を `Kotlinx_datetimeLocalDate` に変換する。
    private func dateToLocalDate(_ date: Date) -> Kotlinx_datetimeLocalDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Kotlinx_datetimeLocalDate(
            year: Int32(components.year ?? 2026),
            monthNumber: Int32(components.month ?? 1),
            dayOfMonth: Int32(components.day ?? 1)
        )
    }
}

// MARK: - CoffeeItemSummaryRow

/// コーヒーアイテムの一覧行コンポーネント（Editor 内リスト用）。
private struct CoffeeItemSummaryRow: View {
    let coffee: CoffeeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.name)
                .font(.body)
            Text(coffee.brewMethod.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - FoodItemSummaryRow

/// フードアイテムの一覧行コンポーネント（Editor 内リスト用）。
private struct FoodItemSummaryRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name)
                .font(.body)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PhotoThumbnailCell

/// 写真セクション内の 1 枚サムネイルセル（削除ボタン付き）。
private struct PhotoThumbnailCell: View {

    let photo: Photo_
    /// 新規追加分の未保存 JPEG データ（既存写真では nil）。
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

// MARK: - Preview

#Preview {
    Text("VisitEditorView preview placeholder")
}
