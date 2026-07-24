import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

// MARK: - MapTabView

// `ApplePoiCafe` はピン UI（`MapPins.swift`）と同居させるため同ファイルへ移動済み（M-1）。

/// マップタブのルート画面。
///
/// - MapKit の `Map` に訪問済みカフェ（アクセントカラー）と周辺カフェ（gray）の Annotation を表示する
/// - 上部の Google Maps スタイル検索バーからカフェ名検索を行い、結果ピンをマップに表示する
/// - 検索欄フォーカス中 or 結果表示中は「検索モード」（`isSearchMode`）となり、フィルタチップ行を隠す。
///   検索結果一覧は下部の自前ドラッグシート `searchResultsBottomSheet`（マップ主体 + 下部一覧、
///   2026-07-22 刷新）で提示し、マップは常時パン / ズーム可能なまま結果と併存する。
///   「このエリアを検索」ボタンは検索モード中に地図をパン / ズームした場合のみ結果シートの上に
///   出現する（ブラウズモードでは出さない）
/// - テキスト検索完了時は全結果ピンの bounding box にカメラを自動フィットする（「このエリアを検索」は
///   結果が構造的に画面内のため対象外）
/// - 検索結果（行 or ピン）タップで下部カードを表示し（結果シートとは排他）、選択中のピンは
///   scale 1.3 + 影で強調する。「詳細を見る」で `CafeDetailView` へ push する
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

    // MARK: - 「好み一致」/「保存済み」一覧シート State（2026-07-24、操作モデル改修）

    /// マップ上に開いているカフェ一覧シートの種別。nil = どちらも非表示。
    /// 好み一致 / 保存済みは排他（同時には開かない）。シートの表示＝該当チップの強調 ON に連動する。
    private enum CafeListSheetKind: Identifiable {
        case recommended
        case saved
        var id: Self { self }
    }

    /// チップは「一覧シートを開くアクション」に一本化されており、マップ強調（他ピン減光）は
    /// シート表示中かどうかに連動する。`.sheet(item:)` を使うことで、下スワイプで閉じたときに
    /// 自動的に nil に戻り強調も解除される（排他性・強調解除ともに構造的に保証される）。
    @State private var activeCafeListSheet: CafeListSheetKind? = nil

    /// 「好み一致」強調中か（= 好み一致シート表示中）。既存の opacity / size 計算箇所からの
    /// 参照名を変えないため、computed property として残す。
    private var recommendedEmphasisActive: Bool { activeCafeListSheet == .recommended }

    /// 「保存済み」強調中か（= 保存済みシート表示中）。既存の opacity / size 計算箇所からの
    /// 参照名を変えないため、computed property として残す。
    private var savedEmphasisActive: Bool { activeCafeListSheet == .saved }

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

    /// 選択中の検索結果ピンの placeId（マップ上でのハイライト表示用）。nil = ハイライトなし。
    @State private var highlightedSearchPlaceId: String? = nil

    // MARK: - 検索結果 下部ドラッグシート関連 State（2026-07-22 マップ検索結果刷新）

    /// `SearchSheetDetent` は `MapSearchResultsSheet.swift` に定義（M-1）。
    /// detent 状態・サイズ計算は現在地 FAB のインセット計算（`searchSheetFABBottomInset`）でも
    /// 参照するため、あえて `MapSearchResultsSheet` 側へ移さずここで保持する。

    /// 現在の detent（peek / expanded）。
    @State private var searchSheetDetent: SearchSheetDetent = .peek

    /// ドラッグ中の追従用オフセット（`translation.height`。下方向ドラッグで正）。
    @State private var searchSheetDragTranslation: CGFloat = 0

    /// `mapContent` の ZStack 全体のサイズ（expanded detent の高さ算出に使う）。
    @State private var mapContainerSize: CGSize = .zero

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

    // MARK: - 周辺カフェ（Apple 検索由来）関連 State（フェーズ 17 / M-2 で `AppleNearbyCafeLoader` へ隔離）

    /// Apple 検索由来の周辺カフェ fetch（デバウンス・ネガティブキャッシュ・名前フィルタ・
    /// スロットリング耐性を内包）を担うサービス（`AppleNearbyCafeLoader.swift`、M-2）。
    @State private var appleLoader = AppleNearbyCafeLoader()

    /// 直近でタップされた Apple 検索由来ピン。POI ルックアップが「該当なし」だった際に
    /// ネガティブキャッシュへ登録する対象を特定するために保持する（周辺カフェピンのノイズ除去、2026-07-13）。
    @State private var lastTappedApplePoi: ApplePoiCafe? = nil

    // MARK: - 検索モード

    /// 検索モード判定: 検索欄フォーカス中、または検索結果ドロップダウン表示中。
    ///
    /// 検索モード中はフィルタチップ（ブラウズ用アフォーダンス）を隠し、代わりに検索結果リストを
    /// `searchBarView` 直下に表示する。「このエリアを検索」ボタンはブラウズモードでは常に非表示。
    /// 検索モード中でも `showAreaSearchButton`（地図パン検知）が true のときだけ表示する。
    private var isSearchMode: Bool {
        isSearchFieldFocused || showingSearchResults
    }

    // MARK: - 検索結果 下部ドラッグシート サイジング

    /// expanded detent の高さ（`mapContainerSize` 確定前は peek と同値にフォールバック）。
    private var searchSheetExpandedHeight: CGFloat {
        max(
            MapSearchResultsSheet.peekHeight,
            mapContainerSize.height * MapSearchResultsSheet.expandedFraction
        )
    }

    /// 現在の detent に対応する基準高さ（ドラッグ追従前の値）。
    private var searchSheetBaseHeight: CGFloat {
        searchSheetDetent == .expanded ? searchSheetExpandedHeight : MapSearchResultsSheet.peekHeight
    }

    /// ドラッグ追従を反映した実際の表示高さ（peek〜expanded にクランプ）。
    private var searchSheetCurrentHeight: CGFloat {
        let target = searchSheetBaseHeight - searchSheetDragTranslation
        return min(max(target, MapSearchResultsSheet.peekHeight), searchSheetExpandedHeight)
    }

    /// 結果シートの表示条件: 検索モード中・カフェ未選択・（ローディング中 or 結果あり）。
    private var isShowingSearchResultsSheet: Bool {
        guard isSearchMode, selectedSearchCafe == nil, let sb = searchBridge else { return false }
        return sb.isLoading || !sb.results.isEmpty
    }

    /// 現在地 FAB が結果シートと重ならないよう追加する下端パディング。
    private var searchSheetFABBottomInset: CGFloat {
        isShowingSearchResultsSheet ? searchSheetCurrentHeight : 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let bridge = appState.mapBridge {
                    mapContent(bridge: bridge)
                        .toolbar(.hidden, for: .navigationBar)
                        // 「好み一致」/「保存済み」一覧シート。1 本の `.sheet(item:)` に統合することで
                        // 排他性を構造的に保証し、下スワイプで閉じたときに `activeCafeListSheet` が
                        // 自動的に nil へ戻る（→ 強調も自動 OFF になる。2026-07-24 操作モデル改修）。
                        .sheet(item: $activeCafeListSheet) { kind in
                            switch kind {
                            case .recommended:
                                RecommendedCafeListSheet(
                                    recommendedCafes: bridge.recommendedCafes,
                                    onSelect: { recommended in
                                        activeCafeListSheet = nil
                                        navigationPath.append(
                                            CafeDetailRoute(
                                                placeId: recommended.cafe.placeId,
                                                initialCafe: recommended.cafe
                                            )
                                        )
                                    }
                                )
                            case .saved:
                                SavedCafeListSheet(
                                    savedCafes: bridge.savedCafes,
                                    recordedPlaceIds: bridge.recordedPlaceIds,
                                    onSelect: { savedCafe in
                                        activeCafeListSheet = nil
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
                                .padding(.bottom, 16 + searchSheetFABBottomInset)
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
                            appleLoader.removeCafe(id: tapped.id)
                            lastTappedApplePoi = nil
                        }
                        // 好み一致カフェが 0 件になった（チップ消滅）ら開いている一覧シートを閉じる
                        // （強調は `activeCafeListSheet` に連動して自動的に OFF になる）。
                        .onChange(of: bridge.recommendedCafes.count) { _, count in
                            if count == 0, activeCafeListSheet == .recommended {
                                activeCafeListSheet = nil
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
                // （`appleLoader.displayed(excluding:)`）。最初に描画して他ピンの背面に回す。
                ForEach(appleLoader.displayed(excluding: existingPinCoordinates(bridge))) { cafe in
                    Annotation(cafe.name, coordinate: cafe.coordinate) {
                        Button {
                            lastTappedApplePoi = cafe
                            bridge.onPoiTapped(
                                name: cafe.name,
                                latitude: cafe.coordinate.latitude,
                                longitude: cafe.coordinate.longitude
                            )
                        } label: {
                            AppleNearbyCafePin(cafe: cafe)
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
                                            RecommendedCafePin(visitedCafe: visitedCafe)
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
                                            VisitedCafePin(visitedCafe: visitedCafe)
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
                                SavedCafePin(savedCafe: savedCafe, emphasized: savedEmphasisActive)
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
                                    SearchResultPin(cafe: cafe, isHighlighted: cafe.placeId == highlightedSearchPlaceId)
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
                            CuratedCafePin(cafe: curated)
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
                appleLoader.schedule(center: newCenter)
            }
            .safeAreaInset(edge: .bottom) {
                if let cafe = selectedSearchCafe {
                    CafeSelectionCard(
                        cafe: cafe,
                        bridge: bridge,
                        appState: appState,
                        onClose: {
                            // ピン集合（全検索結果）は維持し、カードの選択のみ解除する。
                            // 検索結果からの選択時は結果一覧の下部ドラッグシートへ戻す
                            // （「一覧に戻る」導線。2026-07-22 マップ検索結果刷新）。
                            selectedSearchCafe = nil
                            highlightedSearchPlaceId = nil
                            if searchBridge != nil {
                                showingSearchResults = true
                            }
                        },
                        onOpenDetail: { cafe in
                            navigationPath.append(
                                CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                            )
                            // ピン集合（全検索結果）は維持し、カードの選択のみ解除する
                            selectedSearchCafe = nil
                            highlightedSearchPlaceId = nil
                        },
                        onToggleSave: { cafe in
                            bridge.onCafeSaveToggled(cafe: cafe)
                        }
                    )
                }
            }

            // 上部コントロール（検索バー行 + モードに応じた下段コンテンツ）
            //
            // ブラウズモード: フィルタチップ行のみ（「このエリアを検索」ボタンは出さない）
            // 検索モード:（パンで出現した場合）「このエリアを検索」ボタンのみ（結果一覧は下部
            // ドラッグシート `searchResultsBottomSheet` へ移設。2026-07-22 マップ検索結果刷新）
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
                } else {
                    MapFilterChipRow(
                        bridge: bridge,
                        recommendedEmphasisActive: recommendedEmphasisActive,
                        savedEmphasisActive: savedEmphasisActive,
                        onOpenRecommended: { activeCafeListSheet = .recommended },
                        onOpenSaved: { activeCafeListSheet = .saved }
                    )
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
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { mapContainerSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in mapContainerSize = newSize }
            }
        )
        .overlay(alignment: .bottom) {
            searchResultsBottomSheet
        }
    }

    // MARK: - 検索結果 下部ドラッグシート（2026-07-22 マップ検索結果刷新。実装は `MapSearchResultsSheet.swift`）

    /// マップ主体 + 下部ドラッグシートで検索結果一覧を提示する（Apple/Google マップ風）。
    ///
    /// detent 状態・サイズ計算（`searchSheetDetent` / `searchSheetDragTranslation` /
    /// `searchSheetCurrentHeight` 等）は現在地 FAB のインセット計算（`searchSheetFABBottomInset`）
    /// でも参照するため本 View 側に残し、`MapSearchResultsSheet` へは算出済みの値を渡す（M-1）。
    @ViewBuilder
    private var searchResultsBottomSheet: some View {
        if let sb = searchBridge, isShowingSearchResultsSheet {
            MapSearchResultsSheet(
                sb: sb,
                searchAdLoader: searchAdLoader,
                currentHeight: searchSheetCurrentHeight,
                baseHeight: searchSheetBaseHeight,
                expandedHeight: searchSheetExpandedHeight,
                detent: $searchSheetDetent,
                dragTranslation: $searchSheetDragTranslation,
                onSelectCafe: { cafe in selectSearchResult(cafe) }
            )
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
    /// テキスト検索由来の完了時は、結果が画面外に落ちないよう全結果ピンへカメラを自動フィットする
    /// （「このエリアを検索」は表示範囲内検索で結果が構造的に画面内のため対象外。2026-07-22）。
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
        } else {
            fitCameraToSearchResults(sb.results)
        }
    }

    /// テキスト検索完了時、全結果ピンの bounding box に収まるようカメラをフィットする。
    ///
    /// 結果 1 件のときは `selectSearchResult` と同じ 800m ズームにフォールバックする。
    /// 座標が取れない結果のみの場合は何もしない（現在のカメラ位置を維持）。
    private func fitCameraToSearchResults(_ results: [Cafe]) {
        let coordinates: [CLLocationCoordinate2D] = results.compactMap { cafe in
            guard let lat = cafe.latitude?.doubleValue, let lng = cafe.longitude?.doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1 {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coordinates[0],
                        latitudinalMeters: 800,
                        longitudinalMeters: 800
                    )
                )
            }
            return
        }

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
        // 1.3 倍（片側 15% 相当）は setInitialCameraFromVisitedCafes と同じ padding 係数。
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.01)
        )
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
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
        highlightedSearchPlaceId = nil
        showingSearchResults = false
        isSearchFieldFocused = false
        appState.mapBridge?.onSearchResultsCleared()
    }

    /// 検索結果（一覧行またはピン）からカフェを選択する。
    ///
    /// ピン集合（全検索結果）はそのまま維持し、下部カードの表示とマップ中心移動のみ行う
    /// （ピン集合と選択状態の関心を分離するため、ここでは `onSearchResultsUpdated` を呼ばない）。
    /// 結果一覧シートを退避し（`showingSearchResults = false`）、選択ピンをハイライトする。
    private func selectSearchResult(_ cafe: Cafe) {
        selectedSearchCafe = cafe
        highlightedSearchPlaceId = cafe.placeId
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

    // MARK: - 周辺カフェ（Apple 検索由来）関連ヘルパ（フェーズ 17 / fetch 本体は M-2 で `AppleNearbyCafeLoader` へ移設）

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
