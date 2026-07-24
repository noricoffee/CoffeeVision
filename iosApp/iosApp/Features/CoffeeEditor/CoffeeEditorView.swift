import SwiftUI
import SharedLogic
import PhotosUI
import CoreLocation

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

    @State var viewModel: CoffeeEditorViewModelBridge
    @Environment(\.dismiss) private var dismiss

    @State var isCafeSearchPresented: Bool = false
    @State var newTagText: String = ""

    /// 現在地カフェサジェスト用の位置情報（新規作成モードのみ・許可済みのときだけ利用）。
    @State private var locationManager = LocationManager()

    /// 新規追加分の写真データ（photoId → JPEG Data）。保存ボタン押下時に Documents に書き出す。
    @State var pendingImageData: [String: Data] = [:]
    /// Editor 内で削除した既存写真の fileName。保存成功後に Documents から物理削除する。
    @State var removedFileNames: Set<String> = []
    /// PhotosPicker の選択状態。選択処理後に [] にリセットする。
    @State var selectedPickerItems: [PhotosPickerItem] = []
    /// 写真保存処理中の error（保存失敗時に alert 表示）。
    @State var photoSaveError: String?

    // MARK: - 産地ドロップダウン

    /// 「その他」選択中かどうか（国名自由入力 TextField の表示制御。2026-07-22 産地ドロップダウン化）。
    @State var isOtherOriginActive: Bool = false

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
                tagsSection
                visitSection
                photosSection
            }
            .trackScreen("coffee_editor")
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                viewModel.onAppear(mode: mode, userId: appState.uid ?? "")
                // CafeDetailView から起動した場合はカフェを pre-fill する
                if let cafe = initialCafe {
                    viewModel.onPlacesCafeSelected(cafe: cafe)
                }
                // 現在地カフェサジェスト（要件 2-8）: 新規作成モードかつ許可済みのときだけ取得する。
                // 許可ダイアログは出さない・未許可/未決定は何もしない・取得失敗も無音。
                if mode is CoffeeEditorViewModelModeCreate {
                    switch locationManager.authorizationStatus {
                    case .authorizedWhenInUse, .authorizedAlways:
                        locationManager.requestLocation()
                    case .notDetermined, .denied, .restricted:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .onChange(of: locationManager.lastLocation?.latitude) { _, _ in
                guard mode is CoffeeEditorViewModelModeCreate,
                      let coordinate = locationManager.lastLocation else { return }
                viewModel.onLocationAvailable(latitude: coordinate.latitude, longitude: coordinate.longitude)
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

    /// 複製（Duplicate）は「初期値が違う新規作成」として Create と同じ扱いにする。
    private var navigationTitle: String {
        if mode is CoffeeEditorViewModelModeEdit {
            return String(localized: "記録を編集")
        } else {
            return String(localized: "コーヒーを記録")
        }
    }

    // MARK: - LocalDate ↔ Date 変換

    func localDateToDate(_ localDate: Kotlinx_datetimeLocalDate) -> Date {
        var components = DateComponents()
        components.year = Int(localDate.year)
        components.month = Int(localDate.monthNumber)
        components.day = Int(localDate.dayOfMonth)
        return Calendar.current.date(from: components) ?? Date()
    }

    func dateToLocalDate(_ date: Date) -> Kotlinx_datetimeLocalDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Kotlinx_datetimeLocalDate(
            year: Int32(components.year ?? 2026),
            monthNumber: Int32(components.month ?? 1),
            dayOfMonth: Int32(components.day ?? 1)
        )
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
                    StarRatingView(rating: nil)
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
