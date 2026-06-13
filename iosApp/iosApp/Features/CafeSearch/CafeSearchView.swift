import SwiftUI
import SharedLogic

/// カフェ検索画面。`VisitEditorView` の `.sheet` で起動される前提。
///
/// - テキスト検索（Places API searchText）と現在地周辺検索（CoreLocation + Nearby Search）を実装
/// - `onCafeSelected` クロージャでカフェを選択し、呼び出し元が sheet を閉じる
struct CafeSearchView: View {

    // MARK: - Properties

    @State private var bridge: CafeSearchViewModelBridge
    @State private var locationManager = LocationManager()
    @State private var showingLocationDeniedAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    let onCafeSelected: (Cafe) -> Void

    // MARK: - Init

    init(appState: AppState, onCafeSelected: @escaping (Cafe) -> Void) {
        _bridge = State(
            initialValue: CafeSearchViewModelBridge(
                kotlin: appState.container.makeCafeSearchViewModel()
            )
        )
        self.onCafeSelected = onCafeSelected
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if bridge.results.isEmpty && bridge.query.isEmpty {
                    emptyInitialView
                } else if bridge.results.isEmpty && !bridge.isLoading {
                    emptyResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle(String(localized: "カフェを検索"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: Binding(
                get: { bridge.query },
                set: { bridge.onQueryChanged($0) }
            ), placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "カフェ名で検索"))
            .onSubmit(of: .search) {
                bridge.onSearchTapped()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "キャンセル")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            handleNearbyTapped()
                        } label: {
                            Image(systemName: "location.fill")
                        }
                        .accessibilityLabel(String(localized: "現在地で検索"))
                        .disabled(bridge.isLoading)

                        Button(String(localized: "検索")) {
                            bridge.onSearchTapped()
                        }
                        .disabled(bridge.query.isEmpty || bridge.isLoading)
                        .accessibilityLabel(String(localized: "検索"))
                    }
                }
            }
            .overlay {
                if bridge.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .accessibilityLabel(String(localized: "検索中"))
                }
            }
            .onChange(of: locationManager.lastLocation?.latitude) { _, _ in
                if let loc = locationManager.lastLocation {
                    bridge.onNearbySearchRequested(
                        latitude: loc.latitude,
                        longitude: loc.longitude
                    )
                }
            }
            .alert(
                String(localized: "エラー"),
                isPresented: Binding(
                    get: { bridge.error != nil },
                    set: { if !$0 { bridge.onErrorDismissed() } }
                )
            ) {
                Button(String(localized: "OK")) {
                    bridge.onErrorDismissed()
                }
            } message: {
                Text(bridge.error ?? "")
            }
            .alert(
                String(localized: "位置情報が利用できません"),
                isPresented: $showingLocationDeniedAlert
            ) {
                Button(String(localized: "設定を開く")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            } message: {
                Text(String(localized: "位置情報の利用を許可するには、設定アプリで CoffeeVision の位置情報サービスを有効にしてください。"))
            }
            .alert(
                String(localized: "位置情報の取得に失敗しました"),
                isPresented: Binding(
                    get: { locationManager.error != nil },
                    set: { if !$0 { locationManager.clearError() } }
                )
            ) {
                Button(String(localized: "OK")) {
                    locationManager.clearError()
                }
            } message: {
                Text(locationManager.error?.localizedDescription ?? "")
            }
            .onDisappear {
                bridge.cancel()
            }
        }
    }

    // MARK: - Actions

    private func handleNearbyTapped() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showingLocationDeniedAlert = true
        default:
            locationManager.resetLastLocation()
            locationManager.requestLocation()
        }
    }

    // MARK: - 空状態（初回表示）

    private var emptyInitialView: some View {
        ContentUnavailableView(
            String(localized: "カフェ名で検索してください"),
            systemImage: "magnifyingglass"
        )
    }

    // MARK: - 空状態（検索済み・結果なし）

    private var emptyResultsView: some View {
        ContentUnavailableView.search(text: bridge.query)
    }

    // MARK: - 結果リスト

    private var resultsList: some View {
        List(bridge.results, id: \.placeId) { cafe in
            Button {
                onCafeSelected(cafe)
            } label: {
                CafeRow(cafe: cafe)
            }
            .accessibilityLabel(cafe.name)
        }
    }
}

// MARK: - CafeRow

/// カフェ検索結果の 1 行。名前（headline）+ 住所（secondary）を表示する。
private struct CafeRow: View {

    let cafe: Cafe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cafe.name)
                .font(.headline)
                .foregroundStyle(.primary)
            if let address = cafe.address, !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview (結果あり)

#Preview("検索結果あり") {
    let sampleCafes = PreviewSamples.sampleCafes
    NavigationStack {
        List(sampleCafes, id: \.placeId) { cafe in
            Button {
                // 選択デモ（何もしない）
            } label: {
                CafeRow(cafe: cafe)
            }
            .accessibilityLabel(cafe.name)
        }
        .navigationTitle(String(localized: "カフェを検索"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "キャンセル")) {}
            }
        }
    }
}

// MARK: - Preview (初回表示 / 空状態)

#Preview("初回表示（空）") {
    NavigationStack {
        ContentUnavailableView(
            String(localized: "カフェ名で検索してください"),
            systemImage: "magnifyingglass"
        )
        .navigationTitle(String(localized: "カフェを検索"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "キャンセル")) {}
            }
        }
    }
}
