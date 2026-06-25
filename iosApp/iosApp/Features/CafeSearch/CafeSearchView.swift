import SwiftUI
import SharedLogic

/// カフェ検索画面。
///
/// 2 つの起動モードをサポートする:
///
/// 1. **コールバックモード**（`onCafeSelected` あり）: `VisitEditorView` の `.sheet` で起動される。
///    検索結果タップで `onCafeSelected` を呼び出す。既存の挙動を維持する。
///
/// 2. **ルートモード**（`onCafeSelected` なし）: Search タブのルート画面として起動される。
///    `NavigationStack` 内で `CafeDetailView` に push する。
///    RootTabView の NavigationStack が push の親になる。
struct CafeSearchView: View {

    // MARK: - Properties

    @State private var bridge: CafeSearchViewModelBridge
    /// 検索欄の表示テキスト。ローカル状態で即時 echo し、Kotlin StateFlow への非同期ラウンドトリップに依存しない。
    @State private var queryText: String = ""
    @Environment(\.dismiss) private var dismiss

    /// コールバックモードのみ非 nil。nil のときはルートモード（NavigationLink で push）。
    let onCafeSelected: ((Cafe) -> Void)?

    /// 写真サムネ表示に使うローダー。`AppState` から取得する。
    let photoLoader: PlacePhotoLoader

    /// アプリ全体の状態（マップカメラ中心の位置バイアス取得に使う）。
    let appState: AppState

    // MARK: - Init

    /// コールバックモード（VisitEditorView の sheet 経由）。
    init(appState: AppState, onCafeSelected: @escaping (Cafe) -> Void) {
        _bridge = State(
            initialValue: CafeSearchViewModelBridge(
                kotlin: appState.container.makeCafeSearchViewModel()
            )
        )
        self.photoLoader = appState.placePhotoLoader
        self.appState = appState
        self.onCafeSelected = onCafeSelected
    }

    /// ルートモード（Search タブのルート画面として直接起動）。
    init(appState: AppState) {
        _bridge = State(
            initialValue: CafeSearchViewModelBridge(
                kotlin: appState.container.makeCafeSearchViewModel()
            )
        )
        self.photoLoader = appState.placePhotoLoader
        self.appState = appState
        self.onCafeSelected = nil
    }

    // MARK: - Body

    var body: some View {
        Group {
            if bridge.results.isEmpty && !bridge.hasSearched {
                // 未検索状態（入力中・ローディング中含む）は初期プロンプトを表示。
                // isLoading == true のときも here に落ちるが、overlay の ProgressView が重なる。
                emptyInitialView
            } else if bridge.results.isEmpty && !bridge.isLoading {
                // 検索確定後かつ 0 件のときだけ「該当なし」を表示。
                emptyResultsView
            } else {
                resultsList
            }
        }
        .navigationTitle(String(localized: "カフェを検索"))
        .navigationBarTitleDisplayMode(.inline)
        // queryText をローカル @State にすることで、1 文字入力のたびに
        // Kotlin StateFlow → SKIE AsyncSequence → apply() を経由する非同期ラウンドトリップを
        // 表示経路から切り離し、キーストロークの echo 遅延を解消する。
        // Kotlin 側への転送は onChange で一方向に行う。
        .searchable(text: $queryText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "カフェ名で検索"))
        .onChange(of: queryText) { _, new in
            bridge.onQueryChanged(new)
        }
        .onSubmit(of: .search) {
            runSearch()
        }
        .toolbar {
            // コールバックモードのみキャンセルボタンを表示（sheet 閉じるため）
            if onCafeSelected != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "キャンセル")) {
                        dismiss()
                    }
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
        // 非致命エラー（検索失敗）はトーストで表示
        .errorToast(message: bridge.error) {
            bridge.onErrorDismissed()
        }
    }

    // MARK: - Actions

    /// テキスト検索を発火する統一エントリポイント。
    ///
    /// `appState.mapSearchCenter` があれば位置バイアス付き検索を行い、
    /// なければバイアスなし検索（既存動作）にフォールバックする。
    /// `.onSubmit(of: .search)` から呼ぶ。
    private func runSearch() {
        if let center = appState.mapSearchCenter {
            bridge.onSearchTapped(
                latitude: center.latitude,
                longitude: center.longitude,
                radiusMeters: center.radiusMeters
            )
        } else {
            bridge.onSearchTapped()
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
        ContentUnavailableView.search(text: queryText)
    }

    // MARK: - 結果リスト

    @ViewBuilder
    private var resultsList: some View {
        if let callback = onCafeSelected {
            // コールバックモード: タップでコールバックを呼ぶ
            List(bridge.results, id: \.placeId) { cafe in
                Button {
                    callback(cafe)
                } label: {
                    CafeRow(cafe: cafe, loader: photoLoader)
                }
                .accessibilityLabel(cafe.name)
            }
        } else {
            // ルートモード: タップで CafeDetailView に push
            List(bridge.results, id: \.placeId) { cafe in
                NavigationLink(
                    value: CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                ) {
                    CafeRow(cafe: cafe, loader: photoLoader)
                }
                .accessibilityLabel(cafe.name)
            }
        }
    }
}

// MARK: - CafeRow

/// カフェ検索結果の 1 行。左側に 56pt サムネ + 右側に名前（headline）+ 住所（secondary）を表示する。
///
/// `loader` が nil の場合（Preview 用）はサムネが常にプレースホルダ表示になる。
private struct CafeRow: View {

    let cafe: Cafe
    let loader: PlacePhotoLoader?

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル（56pt 正方形・角丸 8pt）
            Group {
                if let photoName = cafe.photoReferences.first, !photoName.isEmpty {
                    PlacePhotoThumbnail(
                        photoName: photoName,
                        maxWidthPx: 200,
                        loader: loader
                    )
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // テキスト情報
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

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview (結果あり)

#Preview("検索結果あり") {
    let sampleCafes = PreviewSamples.sampleCafes
    NavigationStack {
        // loader nil でサムネはプレースホルダ表示（Preview 環境では PlacePhotoLoader 不要）
        List(sampleCafes, id: \.placeId) { cafe in
            Button {
                // 選択デモ（何もしない）
            } label: {
                CafeRow(cafe: cafe, loader: nil)
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
