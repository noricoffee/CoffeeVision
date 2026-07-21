import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

// MARK: - PreferenceMatchAxis 表示ラベル

/// 好み一致の軸名の日本語ラベル。
///
/// `RecommendationMatchSheet` と `RecommendedCafeListSheet`（一覧行のサマリ表示）で共有する。
func preferenceMatchAxisLabel(_ axis: PreferenceMatchAxis) -> String {
    switch axis {
    case .origin:
        return String(localized: "産地")
    case .roastLevel:
        return String(localized: "焙煎度")
    case .brewMethod:
        return String(localized: "抽出方法")
    case .processing:
        return String(localized: "精製方法")
    }
}

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
                    .foregroundStyle(Color.pink)
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
        case .processing:
            return "leaf.fill"
        }
    }

    /// 推薦理由のタイトル文（例「好みの産地: エチオピア」）。
    private func matchTitle(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = preferenceMatchAxisLabel(match.axis)
        return String(localized: "好みの\(axisLabel): \(match.matchedLabel)")
    }

    /// 推薦理由の補足文（代表記録名 + 評価）。
    private func matchDetail(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let stars = formatRating(match.exampleRating)
        return String(localized: "\(match.exampleRecordName) \(stars)")
    }

    /// アクセシビリティ用ラベル（VoiceOver 読み上げ）。
    private func matchAccessibilityLabel(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = preferenceMatchAxisLabel(match.axis)
        let stars = formatRating(match.exampleRating)
        return String(
            localized: "好みの\(axisLabel) \(match.matchedLabel) を高評価で記録。\(match.exampleRecordName) \(stars)"
        )
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

// MARK: - ApplePoiCafe

/// Apple 検索（`MKLocalPointsOfInterestRequest`）由来の周辺カフェ。
///
/// まだ記録も保存もしていない「周辺の店」を示す低強調ピンの表示専用モデル。
/// Google `placeId` を持たないため座標文字列を `id` として使う（フェーズ 17）。
private struct ApplePoiCafe: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - MapTabView

/// マップタブのルート画面。
///
/// - MapKit の `Map` に訪問済みカフェ（アクセントカラー）と周辺カフェ（gray）の Annotation を表示する
/// - 上部の Google Maps スタイル検索バーからカフェ名検索を行い、結果ピンをマップに表示する
/// - 検索欄フォーカス中 or 結果表示中は「検索モード」（`isSearchMode`）となり、フィルタチップ行を隠して
///   検索結果ドロップダウンを表示する（重なり防止）。「このエリアを検索」ボタンは検索モード中に
///   地図をパン / ズームした場合のみ結果ドロップダウンの上に出現する（ブラウズモードでは出さない）
/// - 検索結果タップで下部カードを表示し、「詳細を見る」で `CafeDetailView` へ push する
/// - フィルタトグルで各種ピンの表示 / 非表示を切り替える（ブラウズモード時のみ表示）
/// - カスタムピンタップで `CafeDetailView` へ push する（`NavigationLink(value:)` 経由）
/// - 周辺カフェ（Apple 検索由来・低強調ピン）は `MKLocalPointsOfInterestRequest` で表示範囲内を
///   常時取得する（ズーム依存の標準 POI ラベルに代わる自前ピン。フェーズ 17）。タップ →
///   Places ルックアップ → `CafeDetailView` プログラマティック push
/// - 自身が `NavigationStack(path: $navigationPath)` を保持するため RootTabView 側の NavigationStack は不要
/// - 現在地取得は `LocationManager` 経由
/// - 現在地 FAB は bottom-trailing 固定配置でタップで地図中心を現在地・ズーム 1000m にリセットする
struct MapTabView: View {

    var appState: AppState

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationManager = LocationManager()
    @State private var didSetInitialCamera = false

    /// POI ルックアップ結果などのプログラマティック push 用 NavigationPath。
    @State private var navigationPath = NavigationPath()

    /// テイスト検索シートの表示状態。
    @State private var isPresentingTasteSearch = false

    /// FAB タップ後、次の location 更新で 1 回だけ recenter する。
    /// `lastLocation` を nil にしないため、`setupLocation` の周辺カフェ検索に副作用を与えない。
    @State private var pendingRecenter = false

    /// 好み一致ピンタップ時に推薦理由シートで表示する対象。nil = シート非表示。
    @State private var selectedRecommendedCafe: RecommendedCafe? = nil

    // MARK: - 「保存済み」関連 State（フェーズ 15-A / 16）

    /// 「保存済み」チップの強調状態。KMP に対応する状態を持たない純プレゼンテーション状態のため
    /// View 側 `@State` のみで管理する（保存済みピン自体は常時表示。強調中は他ピンを減光する）。
    @State private var savedEmphasisActive: Bool = false

    /// 「行きたい店」一覧ハーフシートの表示状態。
    @State private var isPresentingSavedCafesSheet = false

    // MARK: - 「好み一致」関連 State（2026-07-16、チップのタップ対応）

    /// 「好み一致」チップの強調状態。「保存済み」と同じ操作体系（タップで強調 + 一覧シート、
    /// 再タップで強調解除のみ）。「保存済み」強調とは排他（両方同時に ON にはしない）。
    @State private var recommendedEmphasisActive: Bool = false

    /// 「好み一致」一覧ハーフシートの表示状態。
    @State private var isPresentingRecommendedCafesSheet = false

    // MARK: - 検索関連 State

    /// 検索バーのテキスト入力。
    @State private var searchQuery: String = ""

    /// マップ上部検索バー用の CafeSearch ブリッジ。`.task` で 1 度だけ生成する。
    @State private var searchBridge: CafeSearchViewModelBridge? = nil

    /// 検索ドロップダウンのインラインアダプティブバナー用ローダー（requirements.md §11-2）。
    @State private var searchAdLoader = BannerAdLoader(adUnitID: AdUnitIDs.mapSearchDropdown)

    /// 検索結果ドロップダウンの表示フラグ。
    @State private var showingSearchResults: Bool = false

    /// 検索バー `TextField` のフォーカス状態。
    @FocusState private var isSearchFieldFocused: Bool

    /// 検索結果から選択されたカフェ（下部カード表示用）。nil = カード非表示。
    @State private var selectedSearchCafe: Cafe? = nil

    // MARK: - 「このエリアを検索」関連 State

    /// 最後にエリア検索（またはカメラ初期化）した際のマップ中心。
    ///
    /// - `nil`: まだエリア検索・初期カメラ確定が行われていない（ボタン非表示）
    /// - 非 `nil`: 「このエリアを検索」ボタンの出現判定の基準点
    @State private var lastAreaSearchCenter: MapSearchCenter? = nil

    /// 「このエリアを検索」ボタンの表示フラグ。
    @State private var showAreaSearchButton: Bool = false

    /// 「このエリアを検索」の検索実行中フラグ（ボタンのローディング表示用）。
    @State private var isAreaSearchInFlight: Bool = false

    /// エリア検索が 0 件だったときの軽量案内メッセージ。`errorToast` 経由で表示する。
    @State private var areaSearchEmptyMessage: String? = nil

    // MARK: - 周辺カフェ（Apple 検索由来）関連 State（フェーズ 17）

    /// `MKLocalPointsOfInterestRequest` で取得した周辺カフェ（低強調ピン用）。
    @State private var appleNearbyCafes: [ApplePoiCafe] = []

    /// 直近の Apple 検索 fetch Task（デバウンス / キャンセル用）。
    @State private var appleFetchTask: Task<Void, Never>? = nil

    /// ズームゲートしきい値（この可視半径[m]を超えたら fetch せず既存ピンをクリアする）。
    private static let applePoiZoomGateRadiusMeters: Double = 3000

    /// 直近でタップされた Apple 検索由来ピン。POI ルックアップが「該当なし」だった際に
    /// ネガティブキャッシュへ登録する対象を特定するために保持する（周辺カフェピンのノイズ除去、2026-07-13）。
    @State private var lastTappedApplePoi: ApplePoiCafe? = nil

    /// 名前ヒューリスティックで除外すべき Apple POI かどうかを判定する。
    ///
    /// 除外キーワード一覧は `ApplePoiFilterConfig`（Firebase Remote Config 外部注入、2026-07-13）を参照する。
    private func isExcludedByNameHeuristic(_ name: String) -> Bool {
        ApplePoiFilterConfig.excludedNameKeywords.contains { name.contains($0) }
    }

    // MARK: - 検索モード

    /// 検索モード判定: 検索欄フォーカス中、または検索結果ドロップダウン表示中。
    ///
    /// 検索モード中はフィルタチップ（ブラウズ用アフォーダンス）を隠し、代わりに検索結果リストを
    /// `searchBarView` 直下に表示する。「このエリアを検索」ボタンはブラウズモードでは常に非表示。
    /// 検索モード中でも `showAreaSearchButton`（地図パン検知）が true のときだけ表示する。
    private var isSearchMode: Bool {
        isSearchFieldFocused || showingSearchResults
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let bridge = appState.mapBridge {
                    mapContent(bridge: bridge)
                        .toolbar(.hidden, for: .navigationBar)
                        .sheet(isPresented: $isPresentingSavedCafesSheet) {
                            SavedCafeListSheet(
                                savedCafes: bridge.savedCafes,
                                recordedPlaceIds: bridge.recordedPlaceIds,
                                onSelect: { savedCafe in
                                    isPresentingSavedCafesSheet = false
                                    navigationPath.append(
                                        CafeDetailRoute(
                                            placeId: savedCafe.cafe.placeId,
                                            initialCafe: savedCafe.cafe
                                        )
                                    )
                                },
                                onRemove: { placeId in
                                    bridge.onSavedCafeRemoved(placeId: placeId)
                                }
                            )
                        }
                        .sheet(isPresented: $isPresentingRecommendedCafesSheet) {
                            RecommendedCafeListSheet(
                                recommendedCafes: bridge.recommendedCafes,
                                onSelect: { recommended in
                                    isPresentingRecommendedCafesSheet = false
                                    navigationPath.append(
                                        CafeDetailRoute(
                                            placeId: recommended.cafe.placeId,
                                            initialCafe: recommended.cafe
                                        )
                                    )
                                }
                            )
                        }
                        .sheet(isPresented: $isPresentingTasteSearch) {
                            TasteSearchSheet { keywords in
                                // 補完キーワードを検索クエリに付加して検索実行
                                // performMapSearch() 内で onQueryChanged を呼ぶため、ここでは searchQuery の更新のみ行う
                                let combined = searchQuery.isEmpty
                                    ? keywords
                                    : "\(searchQuery) \(keywords)"
                                searchQuery = combined.trimmingCharacters(in: .whitespaces)
                                performMapSearch()
                            }
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
                        .onChange(of: bridge.poiLookupResult) { _, result in
                            if let cafe = result {
                                lastTappedApplePoi = nil
                                navigationPath.append(
                                    CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                                )
                                bridge.onPoiLookupConsumed()
                            }
                        }
                        // 「該当なし」だった Apple POI をネガティブキャッシュへ登録し、
                        // 以後の一覧から即時除外する（周辺カフェピンのノイズ除去、2026-07-13）。通信エラー等
                        // （isNotFound == false）はキャッシュしない。
                        .onChange(of: bridge.poiLookupError) { _, error in
                            guard let error, error.isNotFound, let tapped = lastTappedApplePoi else { return }
                            ApplePoiNegativeCache.add(name: tapped.name, coordinate: tapped.coordinate)
                            appleNearbyCafes.removeAll { $0.id == tapped.id }
                            lastTappedApplePoi = nil
                        }
                        // 好み一致カフェが 0 件になった（チップ消滅）ら強調 / シートをリセットする。
                        .onChange(of: bridge.recommendedCafes.count) { _, count in
                            if count == 0 {
                                recommendedEmphasisActive = false
                                isPresentingRecommendedCafesSheet = false
                            }
                        }
                        // 検索完了（テキスト検索 / エリア検索の両方）を検知して全件ピン反映する
                        .onChange(of: searchBridge?.isLoading) { _, isLoading in
                            guard isLoading == false, let sb = searchBridge else { return }
                            handleSearchCompletion(sb: sb, mapBridge: bridge)
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
    /// 優先度: `bridge.error`（一般エラー）> `searchBridge.error`（検索失敗）
    /// > `areaSearchEmptyMessage`（エリア検索 0 件案内）> `poiLookupError`（POI 検索失敗）。
    /// `.errorToast` は 1 つしか付けられないため、body から 1 個だけ渡す。
    private func activeToast(bridge: MapViewModelBridge) -> (message: String, dismiss: () -> Void)? {
        if let e = bridge.error {
            return (e, { bridge.onErrorDismissed() })
        }
        if let e = searchBridge?.error {
            return (e, { searchBridge?.onErrorDismissed() })
        }
        if let message = areaSearchEmptyMessage {
            return (message, { areaSearchEmptyMessage = nil })
        }
        if let e = bridge.poiLookupError {
            return (e.message, {
                bridge.onPoiLookupErrorDismissed()
                lastTappedApplePoi = nil
            })
        }
        return nil
    }

    // MARK: - マップコンテンツ

    @ViewBuilder
    private func mapContent(bridge: MapViewModelBridge) -> some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // ユーザー自身の現在地（標準ブルードット + ヘディング）。
                // 位置情報許可が ON（when-in-use / always）のときのみ表示する。
                // `.denied` / `.restricted` / `.notDetermined` では表示せず、既存の
                // 「許可なし時は訪問済みカフェの bounding box にカメラ」挙動と矛盾させない。
                if locationManager.authorizationStatus == .authorizedWhenInUse
                    || locationManager.authorizationStatus == .authorizedAlways {
                    UserAnnotation()
                }

                // 周辺カフェ（Apple 検索由来 / 低強調）ピン。既存ピン（訪問済み / 保存済み / 検索結果 /
                // おすすめ（curated））と座標近接（約 40m 以内）のものは重複排除済み
                // （displayedAppleNearbyCafes）。最初に描画して他ピンの背面に回す。
                ForEach(displayedAppleNearbyCafes(bridge)) { cafe in
                    Annotation(cafe.name, coordinate: cafe.coordinate) {
                        Button {
                            lastTappedApplePoi = cafe
                            bridge.onPoiTapped(
                                name: cafe.name,
                                latitude: cafe.coordinate.latitude,
                                longitude: cafe.coordinate.longitude
                            )
                        } label: {
                            appleNearbyCafePin(cafe: cafe)
                        }
                        .buttonStyle(.plain)
                        .opacity(appleNearbyPinOpacity())
                    }
                }

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
                                // 「好み一致」/「保存済み」チップ強調中は対象以外を一律減光する
                                // （両強調は排他のため同時 true にはならない）。
                                let pinOpacity: Double = recommendedEmphasisActive
                                    ? (isRecommended ? 1.0 : 0.4)
                                    : (savedEmphasisActive ? 0.4 : 1.0)

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

                // 保存済みピン（indigo / bookmark.fill。フェーズ 15-A / 16 で常時表示に変更）
                // 同一 placeId が訪問済みピンと競合する場合は訪問済みを優先するため、
                // visitedPlaceIds(bridge) に含まれるものは除外する（優先順位: 訪問済み > 保存済み > 検索結果）。
                ForEach(displayedSavedCafes(bridge), id: \.cafe.placeId) { savedCafe in
                    if let lat = savedCafe.cafe.latitude?.doubleValue,
                       let lng = savedCafe.cafe.longitude?.doubleValue {
                        Annotation(
                            savedCafe.cafe.name,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        ) {
                            NavigationLink(
                                value: CafeDetailRoute(
                                    placeId: savedCafe.cafe.placeId,
                                    initialCafe: savedCafe.cafe
                                )
                            ) {
                                savedCafePin(savedCafe: savedCafe)
                            }
                            .buttonStyle(.plain)
                            // 「好み一致」チップ強調中は保存済みピンも減光する（保存済みは推薦対象外のため）。
                            .opacity(recommendedEmphasisActive ? 0.4 : 1.0)
                        }
                    }
                }

                // 検索結果ピン（青 / mappin.and.ellipse）
                // タップで下部カードを表示し、NavigationLink ではなく selectSearchResult を呼ぶ
                // 同一 placeId が訪問済み / 保存済みピンと競合する場合はそちらを優先して除外する
                // （優先順位: 訪問済み > 保存済み > 検索結果。表示切替チップの状態に関わらず適用する）
                if !bridge.searchResultPlaces.isEmpty {
                    ForEach(displayedSearchResultPlaces(bridge), id: \.placeId) { cafe in
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
                                .opacity((savedEmphasisActive || recommendedEmphasisActive) ? 0.4 : 1.0)
                            }
                        }
                    }
                }

                // おすすめカフェ（curated / system orange + cup.and.saucer.fill）ピン（フェーズ 19）。
                // Google Maps の POI 強調のように表示切替チップの対象外（トグルなし）だが、
                // Apple 周辺ピンと同じズームゲートでズームアウト時は非表示にする
                // （`displayedCuratedCafes` 参照）。
                // 同一 placeId が訪問済み / 保存済み / 検索結果ピンと競合する場合はそちらを優先して除外する
                // （優先順位: 訪問済み > 保存済み > 検索結果 > おすすめ（curated）。表示切替チップの状態に
                // 関わらず適用する）。タップで直接カフェ詳細へ push する（保存済みピンと同型）。
                ForEach(displayedCuratedCafes(bridge), id: \.placeId) { curated in
                    Annotation(
                        curated.name,
                        coordinate: CLLocationCoordinate2D(latitude: curated.latitude, longitude: curated.longitude)
                    ) {
                        NavigationLink(
                            value: CafeDetailRoute(
                                placeId: curated.placeId,
                                initialCafe: minimalCafe(from: curated)
                            )
                        ) {
                            curatedCafePin(cafe: curated)
                        }
                        .buttonStyle(.plain)
                        // 「好み一致」/「保存済み」チップ強調中はおすすめピンも減光する
                        // （推薦 / 保存対象外のため。検索結果ピンと同じ規則）。
                        .opacity((savedEmphasisActive || recommendedEmphasisActive) ? 0.4 : 1.0)
                    }
                }

            }
            // 標準 POI ラベルは全カテゴリ非表示にする。自前の周辺カフェピン（Apple 検索由来）との
            // 二重表示を防ぎ、ズーム時のラベル氾濫で自前ピンが見にくくなるのを避けるため。
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
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
                let newCenter = MapSearchCenter(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude,
                    radiusMeters: radius
                )
                appState.mapSearchCenter = newCenter

                // 「このエリアを検索」ボタンの出現判定。
                // アンカー未設定（初回カメラ確定時）はボタンを出さず、静かにベースラインとして採用する。
                if let anchor = lastAreaSearchCenter {
                    showAreaSearchButton = shouldShowAreaSearchButton(current: newCenter, anchor: anchor)
                } else {
                    lastAreaSearchCenter = newCenter
                }

                // 周辺カフェ（Apple 検索由来）ピンの再取得をスケジュールする。
                scheduleAppleNearbyFetch(center: newCenter)
            }
            .safeAreaInset(edge: .bottom) {
                if let cafe = selectedSearchCafe {
                    cafeSelectionCard(cafe, bridge: bridge)
                }
            }

            // 上部コントロール（検索バー行 + モードに応じた下段コンテンツ）
            //
            // ブラウズモード: フィルタチップ行のみ（「このエリアを検索」ボタンは出さない）
            // 検索モード:（パンで出現した場合）「このエリアを検索」ボタン + 検索結果ドロップダウン
            // 同一 VStack 内に流し込むことで、ドロップダウンとボタンの重なりを構造的に防ぐ。
            VStack(spacing: 8) {
                searchBarView
                if isSearchMode {
                    if showAreaSearchButton {
                        HStack {
                            Spacer(minLength: 0)
                            areaSearchButton
                            Spacer(minLength: 0)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    searchResultsSection
                } else {
                    filterChipRow(bridge: bridge)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .animation(.default, value: showAreaSearchButton)
            .animation(.default, value: isSearchMode)
            .onChange(of: isSearchFieldFocused) { _, focused in
                // 検索モードに入るタイミングでブラウズ用アフォーダンスを確実に隠す
                if focused {
                    showAreaSearchButton = false
                }
            }
        }
    }

    /// 検索モード中に `searchBarView` の直下へ表示する結果ドロップダウン。
    ///
    /// ローディング中はスピナー、結果があればリストを表示する。0 件かつ非ローディングのときは
    /// 何も表示しない（結果を待つ間の空白を許容し、余計なプレースホルダは出さない）。
    @ViewBuilder
    private var searchResultsSection: some View {
        if let sb = searchBridge {
            if sb.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else if !sb.results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sb.results.enumerated()), id: \.element.placeId) { index, cafe in
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
                            // 3 件目の後にインラインアダプティブバナー 1 枠（結果 3 件未満のときは
                            // 到達しないため非表示。requirements.md §11-2）。
                            if index == 2 {
                                InlineBannerAdView(loader: searchAdLoader, maxHeight: 100)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                if cafe.placeId != sb.results.last?.placeId {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                .focused($isSearchFieldFocused)
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
            // Foundation Models 対応端末のみ表示（検索クエリの有無に関わらず常時表示）
            if TastePreferenceExtractor.makeIfAvailable() != nil {
                Button {
                    isPresentingTasteSearch = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "テイストでカフェを検索"))
                .accessibilityHint(String(localized: "飲みたいコーヒーの味わいを入力してカフェを検索します"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    // MARK: - このエリアを検索

    /// 検索モード中にマップをパン / ズームした後、上部へ出現する floating pill。
    ///
    /// ブラウズモードでは表示されない（検索モード突入 + パン検知の両方を満たしたときのみ呼び出し元が表示する）。
    /// タップで `performAreaSearch()` を呼び、表示範囲内のカフェを一括検索する。
    /// 検索中は `isAreaSearchInFlight` に応じてスピナーへ差し替え、タップを無効化する。
    private var areaSearchButton: some View {
        Button {
            performAreaSearch()
        } label: {
            HStack(spacing: 6) {
                if isAreaSearchInFlight {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                }
                Text(String(localized: "このエリアを検索"))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.accentColor))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isAreaSearchInFlight)
        .accessibilityLabel(String(localized: "このエリアを検索"))
        .accessibilityHint(String(localized: "表示中の地図範囲内のカフェを検索してピン表示します"))
    }

    /// 表示中のマップ範囲でカフェを検索する。「このエリアを検索」ボタンから呼ぶ。
    private func performAreaSearch() {
        guard let sb = searchBridge,
              let center = appState.mapSearchCenter,
              !isAreaSearchInFlight else { return }
        isAreaSearchInFlight = true
        sb.onNearbySearchRequested(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: center.radiusMeters
        )
    }

    /// 現在のマップ中心が前回エリア検索アンカーから閾値以上動いたかを判定する。
    ///
    /// - 中心移動距離がアンカー半径の 30% を超える、または
    /// - 半径比（ズーム変化）が 1.5 倍以上乖離する
    /// のいずれかで `true` を返す（Google Maps 的な「この範囲を再検索」導線の一般的な目安）。
    private func shouldShowAreaSearchButton(current: MapSearchCenter, anchor: MapSearchCenter) -> Bool {
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let anchorLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        let movedDistance = currentLocation.distance(from: anchorLocation)
        let centerMoved = movedDistance > anchor.radiusMeters * 0.3

        let radiusRatio = current.radiusMeters / anchor.radiusMeters
        let zoomChanged = radiusRatio > 1.5 || radiusRatio < (1.0 / 1.5)

        return centerMoved || zoomChanged
    }

    /// 検索完了（`searchBridge.isLoading` が false に変わった時）の共通ハンドラ。
    ///
    /// テキスト検索・「このエリアを検索」の両方の完了を検知し、成功時は結果を全件ピンとして
    /// `mapBridge` に反映する。「このエリアを検索」由来の完了時はさらにアンカーを更新して
    /// ボタンを隠し、0 件だった場合は軽量な案内メッセージを出す。
    private func handleSearchCompletion(sb: CafeSearchViewModelBridge, mapBridge: MapViewModelBridge) {
        let wasAreaSearch = isAreaSearchInFlight
        isAreaSearchInFlight = false

        // hasSearched が false（未検索）、または直近の呼び出しが失敗（error 設定済み）の場合は
        // ピン反映しない。失敗時はボタンを隠さず再試行できる状態のまま残す。
        guard sb.hasSearched, sb.error == nil else { return }

        mapBridge.onSearchResultsUpdated(sb.results)

        if wasAreaSearch {
            if let center = appState.mapSearchCenter {
                lastAreaSearchCenter = center
            }
            showAreaSearchButton = false
            if sb.results.isEmpty {
                areaSearchEmptyMessage = String(localized: "このエリアにカフェが見つかりませんでした")
            }
        }
    }

    // MARK: - 検索アクション

    /// 検索バーの送信時に呼ばれる。位置バイアスがあれば付与する。
    ///
    /// 結果の全件ピン反映は `.onChange(of: searchBridge?.isLoading)`（→ `handleSearchCompletion`）が
    /// 検索完了を検知して行う。ここでは「このエリアを検索」ボタンをテキスト検索直後は
    /// 出さないよう非表示にするのみ。
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
        showAreaSearchButton = false
    }

    /// 検索選択状態をクリアし、マップオーバーレイもリセットする。フォーカスも解除しブラウズモードへ戻す。
    private func clearSearchSelection() {
        selectedSearchCafe = nil
        showingSearchResults = false
        isSearchFieldFocused = false
        appState.mapBridge?.onSearchResultsCleared()
    }

    /// 検索結果（ドロップダウンまたはピン）からカフェを選択する。
    ///
    /// ピン集合（全検索結果）はそのまま維持し、下部カードの表示とマップ中心移動のみ行う
    /// （ピン集合と選択状態の関心を分離するため、ここでは `onSearchResultsUpdated` を呼ばない）。
    /// ドロップダウンを閉じ、フォーカスも解除してブラウズモードへ戻す。
    private func selectSearchResult(_ cafe: Cafe) {
        selectedSearchCafe = cafe
        showingSearchResults = false
        isSearchFieldFocused = false
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

    private func cafeSelectionCard(_ cafe: Cafe, bridge: MapViewModelBridge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let photoName = cafe.photoReferences.first {
                    PlacePhotoThumbnail(
                        photoName: photoName,
                        maxWidthPx: 150,
                        loader: appState.placePhotoLoader
                    )
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
                    cafeCardInfoRow(cafe, bridge: bridge)
                }
                Spacer(minLength: 0)
                Button {
                    // ピン集合（全検索結果）は維持し、カードの選択のみ解除する
                    selectedSearchCafe = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "閉じる"))
            }
            HStack(spacing: 12) {
                Button {
                    navigationPath.append(
                        CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                    )
                    // ピン集合（全検索結果）は維持し、カードの選択のみ解除する
                    selectedSearchCafe = nil
                } label: {
                    Text(String(localized: "詳細を見る"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(String(localized: "\(cafe.name) の詳細を見る"))

                Button {
                    bridge.onCafeSaveToggled(cafe: cafe)
                } label: {
                    Image(systemName: isCafeSaved(cafe, bridge: bridge) ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.indigo)
                .sensoryFeedback(.selection, trigger: isCafeSaved(cafe, bridge: bridge))
                .accessibilityLabel(
                    isCafeSaved(cafe, bridge: bridge)
                        ? String(localized: "行きたい店から削除")
                        : String(localized: "行きたい店に追加")
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
    }

    private func cafeCardInfoRow(_ cafe: Cafe, bridge: MapViewModelBridge) -> some View {
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
                    Text(ratingText(rating: rating, count: cafe.userRatingCount?.intValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let level = cafe.priceLevel {
                Text(mapPriceLevelText(level))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let visits = visitCount(for: cafe, bridge: bridge) {
                HStack(spacing: 2) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                    Text(String(localized: "\(visits)杯"))
                        .font(.caption)
                }
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    /// 「★4.5 (128件)」形式の評価テキスト。件数が nil または 0 のときは括弧を省略する。
    private func ratingText(rating: Double, count: Int?) -> String {
        let ratingStr = String(format: "%.1f", rating)
        if let count, count > 0 {
            return "\(ratingStr) (\(count)件)"
        }
        return ratingStr
    }

    /// カードの保存状態（`bridge.savedCafes` の placeId 一致で判定）。
    private func isCafeSaved(_ cafe: Cafe, bridge: MapViewModelBridge) -> Bool {
        bridge.savedCafes.contains { $0.cafe.placeId == cafe.placeId }
    }

    /// このカフェの記録杯数（`bridge.visitedCafes` の placeId 一致。0 件 or 未訪問なら nil）。
    private func visitCount(for cafe: Cafe, bridge: MapViewModelBridge) -> Int? {
        guard let visited = bridge.visitedCafes.first(where: { $0.cafe.placeId == cafe.placeId }) else {
            return nil
        }
        let count = Int(visited.visitCount)
        return count > 0 ? count : nil
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

    // MARK: - 「保存済み」ピン競合解決（フェーズ 15-A）

    /// 訪問済みカフェの placeId 集合（ピン競合解決の基準。優先度最上位）。
    private func visitedPlaceIds(_ bridge: MapViewModelBridge) -> Set<String> {
        Set(bridge.visitedCafes.map { $0.cafe.placeId })
    }

    /// 行きたい店の placeId 集合（検索結果ピンの競合解決に使う。表示トグルの状態に関わらず全件対象）。
    private func savedPlaceIds(_ bridge: MapViewModelBridge) -> Set<String> {
        Set(bridge.savedCafes.map { $0.cafe.placeId })
    }

    /// 表示対象の行きたい店（訪問済みと競合するものを除外。優先順位: 訪問済み > 行きたい）。
    private func displayedSavedCafes(_ bridge: MapViewModelBridge) -> [SavedCafe] {
        let visited = visitedPlaceIds(bridge)
        return bridge.savedCafes.filter { !visited.contains($0.cafe.placeId) }
    }

    /// 表示対象の検索結果ピン（訪問済み / 行きたいと競合するものを除外。優先順位: 訪問済み > 行きたい > 検索結果）。
    private func displayedSearchResultPlaces(_ bridge: MapViewModelBridge) -> [Cafe] {
        let visited = visitedPlaceIds(bridge)
        let saved = savedPlaceIds(bridge)
        return bridge.searchResultPlaces.filter {
            !visited.contains($0.placeId) && !saved.contains($0.placeId)
        }
    }

    // MARK: - おすすめカフェ（curated）ピン競合解決（フェーズ 19）

    /// 表示対象のおすすめカフェ（訪問済み / 行きたい / 検索結果と競合するものを除外。
    /// 優先順位: 訪問済み > 行きたい > 検索結果 > おすすめ（curated）。表示切替チップの状態に関わらず適用する）。
    ///
    /// ズームゲート: Apple 周辺ピン（`scheduleAppleNearbyFetch`）と同じしきい値
    /// `applePoiZoomGateRadiusMeters`（可視半径 3000m）を再利用し、`appState.mapSearchCenter` の
    /// 直近確定値がしきい値を超える（ズームアウトしている）場合は空配列を返して非表示にする
    /// （東京全域規模の引きの地図で常時表示になり煩雑という確認フィードバックへの対応）。
    /// 独自のしきい値は新設しない。
    private func displayedCuratedCafes(_ bridge: MapViewModelBridge) -> [CuratedCafe] {
        guard let radiusMeters = appState.mapSearchCenter?.radiusMeters,
              radiusMeters <= Self.applePoiZoomGateRadiusMeters else {
            return []
        }
        let visited = visitedPlaceIds(bridge)
        let saved = savedPlaceIds(bridge)
        let searched = Set(bridge.searchResultPlaces.map { $0.placeId })
        return bridge.curatedCafes.filter {
            !visited.contains($0.placeId) && !saved.contains($0.placeId) && !searched.contains($0.placeId)
        }
    }

    /// `CuratedCafe` から詳細画面遷移用の最小 `Cafe` を構築する。
    ///
    /// 揮発フィールド（評価 / 営業時間等）は保持していないため nil / 空のまま渡し、
    /// 詳細画面の既存 getDetails リフレッシュ（`googleRating == null` 条件）に解決を委ねる。
    private func minimalCafe(from curated: CuratedCafe) -> Cafe {
        Cafe(
            placeId: curated.placeId,
            name: curated.name,
            address: nil,
            latitude: KotlinDouble(value: curated.latitude),
            longitude: KotlinDouble(value: curated.longitude),
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: nil,
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil,
            userRatingCount: nil
        )
    }

    // MARK: - フィルタチップ行

    private func filterChipRow(bridge: MapViewModelBridge) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(
                    label: String(localized: "訪問済み"),
                    systemImage: "cup.and.saucer.fill",
                    isOn: bridge.showVisited
                ) {
                    bridge.onShowVisitedToggled(!bridge.showVisited)
                }

                // 「好み一致」チップ（1 件以上あるときのみ表示。2026-07-16 タップ対応）
                // 「保存済み」と同じ操作体系: タップで強調 ON + 一覧シート表示。強調中の再タップは強調解除のみ。
                // 「保存済み」強調とは排他のため、ON にする際は必ず相手側を OFF にする。
                if !bridge.recommendedCafes.isEmpty {
                    TagChip(
                        label: String(localized: "好み一致"),
                        systemImage: "heart.fill",
                        isOn: recommendedEmphasisActive,
                        count: bridge.recommendedCafes.count,
                        tint: .pink
                    ) {
                        if recommendedEmphasisActive {
                            recommendedEmphasisActive = false
                        } else {
                            recommendedEmphasisActive = true
                            savedEmphasisActive = false
                            isPresentingRecommendedCafesSheet = true
                        }
                    }
                }

                // 「保存済み」チップ（1 件以上あるときのみ表示。フェーズ 15-A / 16）
                // タップで強調 ON + 一覧シート表示。強調中の再タップは強調解除のみ。
                if !bridge.savedCafes.isEmpty {
                    TagChip(
                        label: String(localized: "保存済み"),
                        systemImage: "bookmark.fill",
                        isOn: savedEmphasisActive,
                        count: bridge.savedCafes.count
                    ) {
                        if savedEmphasisActive {
                            savedEmphasisActive = false
                        } else {
                            savedEmphasisActive = true
                            recommendedEmphasisActive = false
                            isPresentingSavedCafesSheet = true
                        }
                    }
                }

                // タグフィルタチップ（availableTags が空でないとき）
                if !bridge.availableTags.isEmpty {
                    Divider()
                        .frame(height: 24)

                    ForEach(bridge.availableTags, id: \.self) { tag in
                        TagChip(
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

    /// 訪問済みカフェピン（アクセントカラー / 訪問回数バッジ付き）。
    ///
    /// - 2 回以上訪問した場合は右上コーナーに訪問回数バッジを表示する
    /// - 10 回以上は "9+" と表示して 1 桁に収める
    private func visitedCafePin(visitedCafe: VisitedCafe) -> some View {
        let count = Int(visitedCafe.visitCount)
        let badgeText = count >= 10 ? "9+" : "\(count)"

        return ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 36, height: 36)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
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
                        .foregroundStyle(Color.accentColor)
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

    /// 保存済み（行きたい）店ピン（indigo + bookmark。フェーズ 15-A）。
    ///
    /// 既存 3 種ピン（訪問済み=accentColor / 好み一致=pink / 検索結果=blue）と区別できる
    /// 色（indigo）を採用し、`bookmark.fill` で「保存済み」を示す。
    /// 「保存済み」チップ強調中はひとまわり大きく表示する（フェーズ 16）。
    private func savedCafePin(savedCafe: SavedCafe) -> some View {
        let size: CGFloat = savedEmphasisActive ? 38 : 34

        return ZStack {
            Circle()
                .fill(Color.indigo)
                .frame(width: size, height: size)
                .shadow(color: Color.indigo.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "bookmark.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(String(localized: "\(savedCafe.cafe.name) 保存済み"))
    }

    /// 好み一致カフェピン（pink + ハート）。
    ///
    /// 通常訪問済みピン（アクセントカラー）よりひとまわり大きく表示して視覚的に区別する。
    private func recommendedCafePin(visitedCafe: VisitedCafe) -> some View {
        ZStack {
            Circle()
                .fill(Color.pink)
                .frame(width: 38, height: 38)
                .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 2)
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

    /// おすすめカフェ（curated）ピン（system orange + cup.and.saucer.fill。フェーズ 19 意匠変更）。
    ///
    /// Google Maps の「人気 POI 強調」表現に寄せ、Apple 周辺ピン（`appleNearbyCafePin`）と
    /// **同じカフェアイコン**（`cup.and.saucer.fill`）を使ったうえで、サイズ（34pt。Apple 周辺ピンの
    /// 28pt よりひとまわり大きい）と色の彩度だけで「同じカフェだが特に推されている」ことを
    /// 表現する。色は既存 5 色（accentColor / pink / indigo / blue / secondaryLabel）と被らない
    /// システムカラー `Color.orange` をそのまま使う（黒ミックスなし）。訪問済みピン（`accentColor`
    /// = 茶 #8B5A2B）と一目で区別できるよう明るいオレンジを維持する判断（シミュレータ確認
    /// フィードバックで黒ミックス濃色は茶に寄って見分けにくいと判定されたため）。
    /// トグルなし。ズームゲート（`applePoiZoomGateRadiusMeters`）を Apple 周辺ピンと共用し、
    /// 可視領域が一定以上広い（ズームアウトした）ときは非表示にする（`displayedCuratedCafes` 参照）。
    private func curatedCafePin(cafe: CuratedCafe) -> some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.orange.opacity(0.5), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(String(localized: "\(cafe.name)、おすすめのカフェ"))
    }

    /// 周辺カフェ（Apple 検索由来）ピン。まだ記録も保存もしていない店を示す低強調ピン。
    ///
    /// 既存 4 種ピン（訪問済み=accentColor / 保存済み=indigo / 検索結果=blue / 好み一致=pink）より
    /// 明確に控えめな意匠（小径 24pt + ミュートしたセカンダリ配色）にする（フェーズ 17）。
    private func appleNearbyCafePin(cafe: ApplePoiCafe) -> some View {
        ZStack {
            Circle()
                .fill(Color(.secondaryLabel))
                .frame(width: 28, height: 28)
                // 白フチ + 影で地図の情報密度に負けず見つけやすくする（意味ピンより一段下の強調は維持）
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(Color(.systemBackground))
        }
        .accessibilityLabel(String(localized: "\(cafe.name)、周辺のカフェ"))
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

    // MARK: - 周辺カフェ（Apple 検索由来）フェッチ（フェーズ 17）

    /// カメラ移動確定ごとに Apple 検索由来の周辺カフェ fetch をスケジュールする。
    ///
    /// 直近の fetch Task をキャンセルしてから 300ms 待機し、連続パンを 1 回の検索へまとめる。
    /// 可視半径がしきい値（`applePoiZoomGateRadiusMeters`）を超える場合は fetch せず既存ピンを
    /// クリアする（都市スケールでの氾濫防止。しきい値以下では全ズーム域でピンが出る）。
    private func scheduleAppleNearbyFetch(center: MapSearchCenter) {
        appleFetchTask?.cancel()
        guard center.radiusMeters <= Self.applePoiZoomGateRadiusMeters else {
            appleNearbyCafes = []
            return
        }
        appleFetchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await fetchAppleNearbyCafes(center: center)
        }
    }

    /// `MKLocalPointsOfInterestRequest`（`MKLocalSearch` 経由）で表示範囲内のカフェを
    /// Apple 地図データから取得する。失敗時は低優先度の補助表示のため静かに処理するのみで、
    /// トースト等のユーザー通知は出さない。長時間のパン・ズームで Apple 側にスロットリングされた
    /// 場合（`MKError.loadingThrottled`）は一時的な失敗であり次の fetch で回復するため、
    /// 空白より古いピンを残す方が自然と判断し `appleNearbyCafes` を保持する。それ以外のエラーは
    /// 従来どおりクリアする（周辺カフェピンのスロットリング耐性、2026-07-18）。
    /// ベーカリー（`.bakery`）は Google Places 側の解決（`onPoiTapped` → `searchNearby`、
    /// `includedPrimaryTypes=[cafe, coffee_shop]`）に一致せずタップ解決できないため取得対象から
    /// 除外している（「表示＝解決可能」を揃える。フェーズ 17-B）。
    ///
    /// 名前ヒューリスティック除外（法人本社等）とネガティブキャッシュ（過去に「該当なし」
    /// だった POI）の両方でノイズを除去する（周辺カフェピンのノイズ除去、2026-07-13）。
    private func fetchAppleNearbyCafes(center: MapSearchCenter) async {
        let request = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            radius: center.radiusMeters
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            appleNearbyCafes = response.mapItems.compactMap { item -> ApplePoiCafe? in
                let coordinate = item.location.coordinate
                let name = item.name ?? String(localized: "カフェ")
                guard !isExcludedByNameHeuristic(name) else { return nil }
                guard !ApplePoiNegativeCache.contains(name: name, coordinate: coordinate) else { return nil }
                return ApplePoiCafe(
                    id: "\(coordinate.latitude)_\(coordinate.longitude)",
                    name: name,
                    coordinate: coordinate
                )
            }
        } catch {
            guard !Task.isCancelled else { return }
            if let mkError = error as? MKError, mkError.code == .loadingThrottled {
                // 一時的なスロットリング: 次の fetch で回復するため既存ピンを保持する。
                return
            }
            appleNearbyCafes = []
        }
    }

    /// 既存ピンの座標一覧（訪問済み / 保存済み / 検索結果 / おすすめ（curated）。表示トグルの状態に
    /// 関わらず全件。Apple ピンの重複排除に使う。フェーズ 19 で curated を追加）。
    private func existingPinCoordinates(_ bridge: MapViewModelBridge) -> [CLLocationCoordinate2D] {
        let visited = bridge.visitedCafes.compactMap { vc -> CLLocationCoordinate2D? in
            guard let lat = vc.cafe.latitude?.doubleValue, let lng = vc.cafe.longitude?.doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let saved = bridge.savedCafes.compactMap { sc -> CLLocationCoordinate2D? in
            guard let lat = sc.cafe.latitude?.doubleValue, let lng = sc.cafe.longitude?.doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let searched = bridge.searchResultPlaces.compactMap { cafe -> CLLocationCoordinate2D? in
            guard let lat = cafe.latitude?.doubleValue, let lng = cafe.longitude?.doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let curated = bridge.curatedCafes.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        return visited + saved + searched + curated
    }

    /// 表示対象の Apple 検索由来カフェ。
    ///
    /// 既存ピン（訪問済み / 保存済み / 検索結果 / おすすめ（curated））のいずれかと座標近接
    /// （約 40m 以内）のものを除外する（優先順位: 訪問済み > 保存済み > 検索結果 > おすすめ（curated）
    /// > Apple 検索由来。名前一致はローカライズで不安定なため使わない）。
    private func displayedAppleNearbyCafes(_ bridge: MapViewModelBridge) -> [ApplePoiCafe] {
        let proximityThresholdMeters: CLLocationDistance = 40
        let existingLocations = existingPinCoordinates(bridge).map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        return appleNearbyCafes.filter { cafe in
            let location = CLLocation(latitude: cafe.coordinate.latitude, longitude: cafe.coordinate.longitude)
            return !existingLocations.contains { $0.distance(from: location) <= proximityThresholdMeters }
        }
    }

    /// Apple 検索由来ピンの不透明度。
    ///
    /// 既存 4 種より明確に低強調な意匠に加え、「保存済み」/「好み一致」チップ強調中は 0.4 まで減光する。
    private func appleNearbyPinOpacity() -> Double {
        if savedEmphasisActive || recommendedEmphasisActive { return 0.4 }
        return 1.0
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
