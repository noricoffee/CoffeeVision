import SwiftUI
import MapKit
import SharedLogic

// MARK: - RecommendationMatchSheet

/// 好み一致カフェの推薦理由を表示するシート。
///
/// - 推薦理由（`RecommendedCafe.matches`）を列挙し、軸ごとに定型文で表示する
/// - 「詳細を見る」でカフェ詳細画面へ push できる
struct RecommendationMatchSheet: View {

    let recommendedCafe: RecommendedCafe
    let onOpenDetail: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダ
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        String(localized: "好み一致"),
                        systemImage: "heart.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.pink)

                    Text(recommendedCafe.cafe.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider()

                // 推薦理由一覧
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(recommendedCafe.matches.enumerated()), id: \.offset) { _, reason in
                            matchRow(reason: reason)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                Divider()

                // 詳細ボタン
                Button(action: onOpenDetail) {
                    HStack {
                        Text(String(localized: "このカフェの記録を見る"))
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(minHeight: 44)
                }
                .foregroundStyle(.primary)
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle(String(localized: "好みのコーヒーがあった店"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityLabel(
            String(localized: "好み一致のカフェ、\(recommendedCafe.cafe.name)。\(accessibilitySummary)")
        )
    }

    // MARK: - 推薦理由行

    @ViewBuilder
    private func matchRow(reason: RecommendationReason) -> some View {
        switch onEnum(of: reason) {
        case .tasteProfileMatch(let match):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: axisIcon(match.axis))
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(matchTitle(match))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(matchDetail(match))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(matchAccessibilityLabel(match))
        }
    }

    // MARK: - 文言生成

    /// 軸に対応する SF Symbols 名。
    private func axisIcon(_ axis: PreferenceMatchAxis) -> String {
        switch axis {
        case .origin:
            return "globe.asia.australia"
        case .roastLevel:
            return "flame"
        case .brewMethod:
            return "cup.and.saucer"
        }
    }

    /// 推薦理由のタイトル文（例「好みの産地: エチオピア」）。
    private func matchTitle(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = axisName(match.axis)
        return String(localized: "好みの\(axisLabel): \(match.matchedLabel)")
    }

    /// 推薦理由の補足文（代表記録名 + 評価）。
    private func matchDetail(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let stars = formatRating(match.exampleRating)
        return String(localized: "\(match.exampleRecordName) \(stars)")
    }

    /// アクセシビリティ用ラベル（VoiceOver 読み上げ）。
    private func matchAccessibilityLabel(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = axisName(match.axis)
        let stars = formatRating(match.exampleRating)
        return String(
            localized: "好みの\(axisLabel) \(match.matchedLabel) を高評価で記録。\(match.exampleRecordName) \(stars)"
        )
    }

    /// 軸名の日本語ラベル。
    private func axisName(_ axis: PreferenceMatchAxis) -> String {
        switch axis {
        case .origin:
            return String(localized: "産地")
        case .roastLevel:
            return String(localized: "焙煎度")
        case .brewMethod:
            return String(localized: "抽出方法")
        }
    }

    /// 評価値を「★4.5」形式の文字列に変換する。
    private func formatRating(_ rating: Double) -> String {
        // 0.5 刻みのため小数点 1 桁で表示
        let formatted = String(format: "%.1f", rating)
        return "★\(formatted)"
    }

    /// シート全体のアクセシビリティサマリ（VoiceOver 用）。
    private var accessibilitySummary: String {
        recommendedCafe.matches.compactMap { reason -> String? in
            switch onEnum(of: reason) {
            case .tasteProfileMatch(let match):
                return matchAccessibilityLabel(match)
            }
        }.joined(separator: "。")
    }
}

// MARK: - ナビゲーションルート

/// マップ → カフェ詳細 への push ナビゲーション引数。
struct CafeDetailRoute: Hashable {
    let placeId: String
    let initialCafe: Cafe?

    // MARK: - Hashable / Equatable
    // Cafe は Kotlin data class（Obj-C クラス）のため Swift の Hashable 自動合成が使えない。
    // placeId だけをキーにする。

    static func == (lhs: CafeDetailRoute, rhs: CafeDetailRoute) -> Bool {
        lhs.placeId == rhs.placeId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(placeId)
    }
}

// MARK: - MapTabView

/// マップタブのルート画面。
///
/// - MapKit の `Map` に訪問済みカフェ（brown）と周辺カフェ（gray）の Annotation を表示する
/// - 上部の Google Maps スタイル検索バーからカフェ名検索を行い、結果ピンをマップに表示する
/// - 検索結果タップで下部カードを表示し、「詳細を見る」で `CafeDetailView` へ push する
/// - フィルタトグルで各種ピンの表示 / 非表示を切り替える
/// - カスタムピンタップで `CafeDetailView` へ push する（`NavigationLink(value:)` 経由）
/// - Apple Maps 標準 POI タップ → Places ルックアップ → `CafeDetailView` プログラマティック push
/// - 自身が `NavigationStack(path: $navigationPath)` を保持するため RootTabView 側の NavigationStack は不要
/// - 現在地取得は `LocationManager` 経由
/// - 現在地 FAB は bottom-trailing 固定配置でタップで地図中心を現在地・ズーム 1000m にリセットする
struct MapTabView: View {

    var appState: AppState

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationManager = LocationManager()
    @State private var didSetInitialCamera = false

    /// Apple Maps 標準 POI タップ検知用の選択状態。
    @State private var mapFeatureSelection: MapFeature? = nil

    /// POI ルックアップ結果などのプログラマティック push 用 NavigationPath。
    @State private var navigationPath = NavigationPath()

    /// 設定画面の表示状態。
    @State private var isPresentingSettings = false

    /// テイストフィルタシートの表示状態。
    @State private var isPresentingTasteFilter = false

    /// FAB タップ後、次の location 更新で 1 回だけ recenter する。
    /// `lastLocation` を nil にしないため、`setupLocation` の周辺カフェ検索に副作用を与えない。
    @State private var pendingRecenter = false

    /// 好み一致ピンタップ時に推薦理由シートで表示する対象。nil = シート非表示。
    @State private var selectedRecommendedCafe: RecommendedCafe? = nil

    // MARK: - 検索関連 State

    /// 検索バーのテキスト入力。
    @State private var searchQuery: String = ""

    /// マップ上部検索バー用の CafeSearch ブリッジ。`.task` で 1 度だけ生成する。
    @State private var searchBridge: CafeSearchViewModelBridge? = nil

    /// 検索結果ドロップダウンの表示フラグ。
    @State private var showingSearchResults: Bool = false

    /// 検索結果から選択されたカフェ（下部カード表示用）。nil = カード非表示。
    @State private var selectedSearchCafe: Cafe? = nil


    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let bridge = appState.mapBridge {
                    mapContent(bridge: bridge)
                        .toolbar(.hidden, for: .navigationBar)
                        .sheet(isPresented: $isPresentingSettings) {
                            SettingsView(appState: appState)
                        }
                        .sheet(isPresented: $isPresentingTasteFilter) {
                            TasteMapFilterSheet(bridge: bridge)
                        }
                        .navigationDestination(for: CafeDetailRoute.self) { route in
                            CafeDetailView(
                                placeId: route.placeId,
                                initialCafe: route.initialCafe,
                                appState: appState
                            )
                        }
                        .overlay {
                            if bridge.isLookingUpPoi {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.ultraThinMaterial)
                            }
                        }
                        // 現在地 FAB: bottom-trailing 固定配置
                        .overlay(alignment: .bottomTrailing) {
                            currentLocationFAB
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                        }
                        .errorToast(message: activeToast(bridge: bridge)?.message) {
                            activeToast(bridge: bridge)?.dismiss()
                        }
                        // 好み一致推薦理由シート
                        .sheet(
                            isPresented: Binding(
                                get: { selectedRecommendedCafe != nil },
                                set: { if !$0 { selectedRecommendedCafe = nil } }
                            )
                        ) {
                            if let recommended = selectedRecommendedCafe {
                                RecommendationMatchSheet(
                                    recommendedCafe: recommended
                                ) {
                                    selectedRecommendedCafe = nil
                                    navigationPath.append(
                                        CafeDetailRoute(
                                            placeId: recommended.cafe.placeId,
                                            initialCafe: recommended.cafe
                                        )
                                    )
                                }
                            }
                        }
                        .onChange(of: mapFeatureSelection) { _, newSelection in
                            poiSelectionChanged(newSelection, bridge: bridge)
                        }
                        .onChange(of: bridge.poiLookupResult) { _, result in
                            if let cafe = result {
                                navigationPath.append(
                                    CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                                )
                                bridge.onPoiLookupConsumed()
                                mapFeatureSelection = nil
                            }
                        }
                        // pendingRecenter フラグを監視し、次の location 更新で 1 回だけ recenter する
                        .onChange(of: locationManager.lastLocation?.latitude) { _, _ in
                            if pendingRecenter, let loc = locationManager.lastLocation {
                                pendingRecenter = false
                                withAnimation {
                                    cameraPosition = .region(
                                        MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(
                                                latitude: loc.latitude,
                                                longitude: loc.longitude
                                            ),
                                            latitudinalMeters: 1000,
                                            longitudinalMeters: 1000
                                        )
                                    )
                                }
                            }
                        }
                        .task {
                            // 検索ブリッジを 1 度だけ生成する
                            if searchBridge == nil {
                                searchBridge = CafeSearchViewModelBridge(
                                    kotlin: appState.container.makeCafeSearchViewModel()
                                )
                            }
                            await setupLocation(bridge: bridge)
                        }
                } else {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - エラートースト集約

    /// 複数のエラー源を優先順位付きで単一トーストに集約する。
    ///
    /// `bridge.error`（一般エラー）を `poiLookupError`（POI 検索失敗）より優先する。
    /// `.errorToast` は 1 つしか付けられないため、body から 1 個だけ渡す。
    private func activeToast(bridge: MapViewModelBridge) -> (message: String, dismiss: () -> Void)? {
        if let e = bridge.error {
            return (e, { bridge.onErrorDismissed() })
        }
        if let e = bridge.poiLookupError {
            return (e, { bridge.onPoiLookupErrorDismissed() })
        }
        return nil
    }

    // MARK: - マップコンテンツ

    @ViewBuilder
    private func mapContent(bridge: MapViewModelBridge) -> some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, selection: $mapFeatureSelection) {
                // 訪問済みカフェピン（通常: ブラウン / 好み一致: アクセントカラー+ハート）
                if bridge.showVisited {
                    ForEach(bridge.visitedCafes, id: \.cafe.placeId) { visitedCafe in
                        if let lat = visitedCafe.cafe.latitude?.doubleValue,
                           let lng = visitedCafe.cafe.longitude?.doubleValue {
                            let isRecommended = bridge.recommendedPlaceIds.contains(
                                visitedCafe.cafe.placeId
                            )
                            Annotation(
                                visitedCafe.cafe.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: lat,
                                    longitude: lng
                                )
                            ) {
                                let isTasteActive = !bridge.tasteMatchedPlaceIds.isEmpty
                                let isTasteMatch = bridge.tasteMatchedPlaceIds.contains(
                                    visitedCafe.cafe.placeId
                                )
                                let pinOpacity = isTasteActive && !isTasteMatch ? 0.25 : 1.0

                                Group {
                                    if isRecommended,
                                       let recommended = bridge.recommendedCafes.first(
                                        where: { $0.cafe.placeId == visitedCafe.cafe.placeId }
                                       ) {
                                        // 好み一致ピン: タップで推薦理由シートを表示
                                        Button {
                                            selectedRecommendedCafe = recommended
                                        } label: {
                                            recommendedCafePin(visitedCafe: visitedCafe)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // 通常訪問済みピン: タップでカフェ詳細へ push
                                        NavigationLink(
                                            value: CafeDetailRoute(
                                                placeId: visitedCafe.cafe.placeId,
                                                initialCafe: visitedCafe.cafe
                                            )
                                        ) {
                                            visitedCafePin(visitedCafe: visitedCafe)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .opacity(pinOpacity)
                            }
                        }
                    }
                }

                // 検索結果ピン（青 / mappin.and.ellipse）
                // タップで下部カードを表示し、NavigationLink ではなく selectSearchResult を呼ぶ
                if !bridge.searchResultPlaces.isEmpty {
                    ForEach(bridge.searchResultPlaces, id: \.placeId) { cafe in
                        if let lat = cafe.latitude?.doubleValue,
                           let lng = cafe.longitude?.doubleValue {
                            Annotation(
                                cafe.name,
                                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            ) {
                                Button {
                                    selectSearchResult(cafe)
                                } label: {
                                    searchResultPin(cafe: cafe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

            }
            .mapStyle(.standard(pointsOfInterest: .including([.cafe, .bakery])))
            // 上端（ステータスバー）と左右はフルブリードにしつつ、下端のセーフエリアは保持する。
            // これにより MapKit が Legal/帰属表記を配置する基準が TabBar 上端になり、
            // Legal が TabBar の裏に隠れなくなる。
            .ignoresSafeArea(.container, edges: [.top, .horizontal])
            // カメラ移動完了時にマップ中心を AppState へ書き込む（検索時の位置バイアスに使う）。
            // frequency: .onEnd で頻繁な中間値更新を抑制する。
            .onMapCameraChange(frequency: .onEnd) { context in
                let region = context.region
                // 可視領域の半径相当をメートルで算出する。
                // latitudinalMeters: 緯度 1 度 ≈ 111_000 m、span の半分が半径
                // longitudinalMeters: 緯度に応じた経度 1 度あたりのメートル数で補正
                let latMeters = region.span.latitudeDelta * 111_000 / 2
                let lngMeters = region.span.longitudeDelta
                    * 111_000
                    * cos(region.center.latitude * .pi / 180)
                    / 2
                let rawRadius = max(latMeters, lngMeters)
                // Places API locationBias circle の制約 1...50_000 m にクランプ
                let radius = min(max(rawRadius, 1), 50_000)
                appState.mapSearchCenter = MapSearchCenter(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude,
                    radiusMeters: radius
                )
            }
            .safeAreaInset(edge: .bottom) {
                if let cafe = selectedSearchCafe {
                    cafeSelectionCard(cafe)
                }
            }

            // 上部コントロール（検索バー行 + フィルタチップ行）
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    searchBarView
                    settingsFloatingButton
                }
                filterChipRow(bridge: bridge)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 検索結果ドロップダウン（条件付き表示）
            if showingSearchResults, let sb = searchBridge {
                VStack {
                    // 上部コントロール（検索バー + フィルタ行）分のスペース
                    Spacer().frame(height: 120)

                    ZStack {
                        if sb.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                        } else if !sb.results.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(sb.results, id: \.placeId) { cafe in
                                        Button {
                                            selectSearchResult(cafe)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.blue)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(cafe.name)
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundStyle(.primary)
                                                        .multilineTextAlignment(.leading)
                                                    if let address = cafe.address {
                                                        Text(address)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if cafe.placeId != sb.results.last?.placeId {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - 検索バー

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)
            TextField(String(localized: "カフェ名で検索"), text: $searchQuery)
                .submitLabel(.search)
                .onSubmit { performMapSearch() }
                .onChange(of: searchQuery) { _, newValue in
                    if newValue.isEmpty {
                        clearSearchSelection()
                    }
                }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    clearSearchSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "検索をクリア"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    // MARK: - 検索アクション

    /// 検索バーの送信時に呼ばれる。位置バイアスがあれば付与する。
    private func performMapSearch() {
        guard let sb = searchBridge, !searchQuery.isEmpty else { return }
        sb.onQueryChanged(searchQuery)
        if let center = appState.mapSearchCenter {
            sb.onSearchTapped(
                latitude: center.latitude,
                longitude: center.longitude,
                radiusMeters: center.radiusMeters
            )
        } else {
            sb.onSearchTapped()
        }
        showingSearchResults = true
    }

    /// 検索選択状態をクリアし、マップオーバーレイもリセットする。
    private func clearSearchSelection() {
        selectedSearchCafe = nil
        showingSearchResults = false
        appState.mapBridge?.onSearchResultsCleared()
    }

    /// 検索結果（ドロップダウンまたはピン）からカフェを選択する。
    ///
    /// 下部カードを表示し、マップをそのカフェに中心移動する。
    private func selectSearchResult(_ cafe: Cafe) {
        selectedSearchCafe = cafe
        showingSearchResults = false
        appState.mapBridge?.onSearchResultsUpdated([cafe])
        guard let lat = cafe.latitude?.doubleValue,
              let lng = cafe.longitude?.doubleValue else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
            )
        }
    }

    // MARK: - 選択カフェ 下部カード

    private func cafeSelectionCard(_ cafe: Cafe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let address = cafe.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    cafeCardInfoRow(cafe)
                }
                Spacer()
                Button {
                    selectedSearchCafe = nil
                    appState.mapBridge?.onSearchResultsCleared()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "閉じる"))
            }
            Button {
                navigationPath.append(
                    CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                )
                selectedSearchCafe = nil
                appState.mapBridge?.onSearchResultsCleared()
            } label: {
                Text(String(localized: "詳細を見る"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(String(localized: "\(cafe.name) の詳細を見る"))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
    }

    private func cafeCardInfoRow(_ cafe: Cafe) -> some View {
        HStack(spacing: 8) {
            if let openNow = cafe.openNow?.boolValue {
                HStack(spacing: 4) {
                    Circle()
                        .fill(openNow ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(openNow ? String(localized: "営業中") : String(localized: "終了"))
                        .font(.caption)
                        .foregroundStyle(openNow ? .green : .red)
                }
            }
            if let rating = cafe.googleRating?.doubleValue {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let level = cafe.priceLevel {
                Text(mapPriceLevelText(level))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func mapPriceLevelText(_ level: String) -> String {
        switch level {
        case "PRICE_LEVEL_FREE": return String(localized: "無料")
        case "PRICE_LEVEL_INEXPENSIVE": return "¥"
        case "PRICE_LEVEL_MODERATE": return "¥¥"
        case "PRICE_LEVEL_EXPENSIVE": return "¥¥¥"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "¥¥¥¥"
        default: return ""
        }
    }

    // MARK: - フィルタチップ行

    private func filterChipRow(bridge: MapViewModelBridge) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: String(localized: "訪問済み"),
                    systemImage: "cup.and.saucer.fill",
                    isOn: bridge.showVisited
                ) {
                    bridge.onShowVisitedToggled(!bridge.showVisited)
                }

                // 好み一致カフェが 1 件以上あるときのみ凡例バッジを表示（インタラクションなし）
                if !bridge.recommendedCafes.isEmpty {
                    RecommendedLegendBadge()
                }

                // Foundation Models 利用可能なとき「好みで絞り込む」チップを表示
                if TastePreferenceExtractor.makeIfAvailable() != nil {
                    let isTasteFilterActive = bridge.activeTastingMin != nil
                    FilterChip(
                        label: isTasteFilterActive
                            ? String(localized: "好み絞り込み中")
                            : String(localized: "好みで絞り込む"),
                        systemImage: "sparkles",
                        isOn: isTasteFilterActive
                    ) {
                        isPresentingTasteFilter = true
                    }
                }

                // タグフィルタチップ（availableTags が空でないとき）
                if !bridge.availableTags.isEmpty {
                    Divider()
                        .frame(height: 24)

                    ForEach(bridge.availableTags, id: \.self) { tag in
                        FilterChip(
                            label: tag,
                            systemImage: "tag",
                            isOn: bridge.selectedTags.contains(tag)
                        ) {
                            bridge.onTagFilterToggled(tag)
                        }
                    }

                    if !bridge.selectedTags.isEmpty {
                        Button {
                            bridge.onTagFilterCleared()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "タグフィルターをクリア"))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - ピン UI

    /// 訪問済みカフェピン（茶色 / 訪問回数バッジ付き）。
    ///
    /// - 2 回以上訪問した場合は右上コーナーに訪問回数バッジを表示する
    /// - 10 回以上は "9+" と表示して 1 桁に収める
    private func visitedCafePin(visitedCafe: VisitedCafe) -> some View {
        let count = Int(visitedCafe.visitCount)
        let badgeText = count >= 10 ? "9+" : "\(count)"

        return ZStack {
            Circle()
                .fill(Color.brown)
                .frame(width: 36, height: 36)
                .shadow(color: Color.brown.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            if count >= 2 {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Text(badgeText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.brown)
                }
                .offset(x: 4, y: -4)
            }
        }
        .accessibilityLabel(
            String(localized: "\(visitedCafe.cafe.name) 訪問済み \(visitedCafe.visitCount)回")
        )
    }

    /// 検索結果オーバーレイピン（青 / `mappin.and.ellipse`）。
    private func searchResultPin(cafe: Cafe) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .shadow(color: Color.blue.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "mappin.and.ellipse")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(String(localized: "\(cafe.name) 検索結果"))
    }

    /// 好み一致カフェピン（アクセントカラー + ハート）。
    ///
    /// 通常訪問済みピン（茶）よりひとまわり大きく表示して視覚的に区別する。
    private func recommendedCafePin(visitedCafe: VisitedCafe) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 38, height: 38)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "heart.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(
            String(
                localized: "好み一致のカフェ、\(visitedCafe.cafe.name)。タップして理由を確認"
            )
        )
    }

    // MARK: - 設定フローティングボタン

    private var settingsFloatingButton: some View {
        Button {
            isPresentingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.regularMaterial))
        }
        .accessibilityLabel(String(localized: "設定"))
    }

    // MARK: - 現在地 FAB

    /// bottom-trailing 固定の「現在地に戻る」FAB。
    ///
    /// - `.denied` / `.restricted` 時は淡色 + 無効化
    /// - それ以外は押下で `recenterToCurrentLocation()` を呼ぶ
    private var currentLocationFAB: some View {
        let isDenied = locationManager.authorizationStatus == .denied
            || locationManager.authorizationStatus == .restricted
        return Button {
            recenterToCurrentLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.regularMaterial))
        }
        .accessibilityLabel(String(localized: "現在地に戻る"))
        .disabled(isDenied)
        .opacity(isDenied ? 0.4 : 1.0)
    }

    // MARK: - 現在地センタリング

    /// FAB タップ時に現在地へセンタリング＋ズームリセットする。
    ///
    /// `lastLocation` を nil にしないフラグ方式を採用し、初期カメラ移動との競合を防ぐ。
    private func recenterToCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 既存の lastLocation があればすぐにセンタリング
            if let loc = locationManager.lastLocation {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: loc.latitude,
                                longitude: loc.longitude
                            ),
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        )
                    )
                }
            }
            // さらに最新化のため location を要求し、次の更新で再センタリング
            pendingRecenter = true
            locationManager.requestLocation()

        case .notDetermined:
            // 許可ダイアログ → 許可後は locationManagerDidChangeAuthorization で requestLocation が走る。
            // フラグを立てておき、その location 更新で recenter する。
            pendingRecenter = true
            locationManager.requestLocation()

        case .denied, .restricted:
            // FAB 自体を無効化しているのでここには到達しない想定
            break

        @unknown default:
            break
        }
    }

    // MARK: - POI 選択ハンドラ

    /// Apple Maps 標準 POI タップ時に呼ばれる。
    /// `.cafe` / `.restaurant` / `.bakery` のみ受け入れ、それ以外は selection を nil リセット。
    private func poiSelectionChanged(_ selection: MapFeature?, bridge: MapViewModelBridge) {
        guard let feature = selection else { return }
        guard feature.kind == .pointOfInterest else {
            mapFeatureSelection = nil
            return
        }
        guard let category = feature.pointOfInterestCategory else {
            mapFeatureSelection = nil
            return
        }

        let allowedCategories: Set<MKPointOfInterestCategory> = [.cafe, .bakery]
        guard allowedCategories.contains(category) else {
            mapFeatureSelection = nil
            return
        }

        bridge.onPoiTapped(
            name: feature.title ?? "",
            latitude: feature.coordinate.latitude,
            longitude: feature.coordinate.longitude
        )
    }

    // MARK: - 位置情報セットアップ

    private func setupLocation(bridge: MapViewModelBridge) async {
        // 位置情報許可済みであれば現在地を取得してカメラを移動
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !didSetInitialCamera {
                locationManager.requestLocation()
            }
        case .notDetermined:
            // 許可ダイアログを出す（locationManagerDidChangeAuthorization で許可後に自動取得）
            locationManager.requestLocation()
        case .denied, .restricted:
            // 許可なし：訪問済みカフェがあれば bounding box にカメラを合わせる
            if !didSetInitialCamera {
                setInitialCameraFromVisitedCafes(bridge.visitedCafes)
                didSetInitialCamera = true
            }
        @unknown default:
            break
        }

        // 位置情報が届いたら初期カメラを移動
        for await location in locationStream() {
            if !didSetInitialCamera {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: location.latitude,
                                longitude: location.longitude
                            ),
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        )
                    )
                }
                didSetInitialCamera = true
            }
            break // ワンショット取得のみ
        }
    }

    /// `locationManager.lastLocation` の変化を AsyncSequence として得るヘルパ。
    private func locationStream() -> AsyncStream<CLLocationCoordinate2D> {
        AsyncStream { continuation in
            Task { @MainActor in
                // ポーリングで監視（LocationManager は @Observable のため値変化を検知できる）
                var lastLat: Double? = nil
                for _ in 0 ..< 30 { // 最大 3 秒待機
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    if let loc = locationManager.lastLocation, loc.latitude != lastLat {
                        lastLat = loc.latitude
                        continuation.yield(loc)
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    /// 訪問済みカフェの bounding box に初期カメラを合わせる。なければ東京駅デフォルト。
    private func setInitialCameraFromVisitedCafes(_ visitedCafes: [VisitedCafe]) {
        let coordinates: [CLLocationCoordinate2D] = visitedCafes.compactMap { vc in
            guard let lat = vc.cafe.latitude?.doubleValue,
                  let lng = vc.cafe.longitude?.doubleValue else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        if coordinates.isEmpty {
            // デフォルト: 東京駅
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                    latitudinalMeters: 5000,
                    longitudinalMeters: 5000
                )
            )
        } else if coordinates.count == 1 {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinates[0],
                    latitudinalMeters: 2000,
                    longitudinalMeters: 2000
                )
            )
        } else {
            // bounding box の中心と span を計算
            let lats = coordinates.map { $0.latitude }
            let lngs = coordinates.map { $0.longitude }
            let minLat = lats.min()!
            let maxLat = lats.max()!
            let minLng = lngs.min()!
            let maxLng = lngs.max()!
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
                longitudeDelta: max((maxLng - minLng) * 1.3, 0.01)
            )
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// MARK: - RecommendedLegendBadge

/// 好み一致カフェが存在するときだけ表示する凡例バッジ。
///
/// ハートアイコン＋「好み一致」テキストで、ピンの意味をユーザーに伝える。
/// トグル機能は持たない（v1 は強調 + 理由表示を優先）。
private struct RecommendedLegendBadge: View {

    var body: some View {
        Label(
            String(localized: "好み一致"),
            systemImage: "heart.fill"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.pink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 44, minHeight: 44)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .accessibilityLabel(String(localized: "好み一致のカフェが強調表示されています"))
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - FilterChip

/// マップ上部に表示するフィルタ切替チップ。
///
/// 選択時: `Color.accentColor` で塗り潰す。
/// 非選択時: `.regularMaterial` 背景 + secondary テキスト。
private struct FilterChip: View {

    let label: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? .white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor : Color.clear)
                        .background(
                            Capsule().fill(.regularMaterial)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - FilterChip Preview

#Preview("FilterChip") {
    HStack(spacing: 8) {
        FilterChip(
            label: "訪問済み",
            systemImage: "cup.and.saucer.fill",
            isOn: true
        ) {}

        FilterChip(
            label: "周辺",
            systemImage: "mappin",
            isOn: false
        ) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
