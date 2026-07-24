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

    // `cameraPosition` / `locationManager` / `didSetInitialCamera` は `MapTabView+Location.swift`
    // の extension から参照するため internal 化している（M-4）。
    @State var cameraPosition: MapCameraPosition = .automatic
    @State var locationManager = LocationManager()
    @State var didSetInitialCamera = false

    /// POI ルックアップ結果などのプログラマティック push 用 NavigationPath。
    @State private var navigationPath = NavigationPath()

    /// テイスト検索シートの表示状態。
    @State private var isPresentingTasteSearch = false

    /// FAB タップ後、次の location 更新で 1 回だけ recenter する。
    /// `lastLocation` を nil にしないため、`setupLocation` の周辺カフェ検索に副作用を与えない。
    /// `MapTabView+Location.swift` の extension から参照するため internal 化している（M-4）。
    @State var pendingRecenter = false

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

    /// 検索 / エリア検索のデータ state とビジネスロジックを保持するコントローラ(M-3)。
    ///
    /// カメラ移動 / キーボード解除のコールバックは `.task`(初回のみ)で本物に差し替える
    /// (`@State` の初期値式は `self` = `cameraPosition` / `isSearchFieldFocused` を参照できないため。
    /// `MapSearchController.swift` の doc コメント参照)。
    @State private var searchController = MapSearchController(
        onRequestCamera: { _ in },
        onDismissKeyboard: {}
    )

    /// 検索ドロップダウンのインラインアダプティブバナー用ローダー（requirements.md §11-2）。
    @State private var searchAdLoader = BannerAdLoader(adUnitID: AdUnitIDs.mapSearchDropdown)

    /// 検索バー `TextField` のフォーカス状態。
    @FocusState private var isSearchFieldFocused: Bool

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

    /// 直近の `.onMapCameraChange` で得た地図可視領域。「このエリアを検索」実行時の結果フィルタ
    /// 基準として `MapSearchController.performAreaSearch(visibleRegion:)` に渡す（2026-07-24）。
    @State private var latestVisibleRegion: MKCoordinateRegion?

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
        isSearchFieldFocused || searchController.showingResults
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
        guard isSearchMode, searchController.selectedCafe == nil, let sb = searchController.searchBridge else {
            return false
        }
        return sb.isLoading || !searchController.displayedResults.isEmpty
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
                                // performSearch() 内で onQueryChanged を呼ぶため、ここでは query の更新のみ行う
                                let combined = searchController.query.isEmpty
                                    ? keywords
                                    : "\(searchController.query) \(keywords)"
                                searchController.query = combined.trimmingCharacters(in: .whitespaces)
                                searchController.performSearch(center: appState.mapSearchCenter)
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
                        .onChange(of: searchController.searchBridge?.isLoading) { _, isLoading in
                            guard isLoading == false else { return }
                            searchController.handleCompletion(mapBridge: bridge, currentCenter: appState.mapSearchCenter)
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
                            // 検索ブリッジとカメラ / キーボードのコールバックを 1 度だけ配線する。
                            // `@State` の初期値式は `self` を参照できないため、初回の `.task` で
                            // `cameraPosition` / `isSearchFieldFocused` を捕捉したクロージャに差し替える。
                            if searchController.searchBridge == nil {
                                searchController.setup {
                                    appState.container.makeCafeSearchViewModel()
                                }
                                searchController.configureCallbacks(
                                    onRequestCamera: { region in
                                        withAnimation { cameraPosition = .region(region) }
                                    },
                                    onDismissKeyboard: { isSearchFieldFocused = false }
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
        if let e = searchController.searchBridge?.error {
            return (e, { searchController.searchBridge?.onErrorDismissed() })
        }
        if let message = searchController.areaSearchEmptyMessage {
            return (message, { searchController.areaSearchEmptyMessage = nil })
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
                                    searchController.selectResult(cafe)
                                } label: {
                                    SearchResultPin(
                                        cafe: cafe,
                                        isHighlighted: cafe.placeId == searchController.highlightedPlaceId
                                    )
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
                latestVisibleRegion = region
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
                if let anchor = searchController.lastAreaSearchCenter {
                    searchController.showAreaSearchButton = searchController.shouldShowAreaSearchButton(
                        current: newCenter,
                        anchor: anchor
                    )
                } else {
                    searchController.lastAreaSearchCenter = newCenter
                }

                // 周辺カフェ（Apple 検索由来）ピンの再取得をスケジュールする。
                appleLoader.schedule(center: newCenter)
            }
            .safeAreaInset(edge: .bottom) {
                if let cafe = searchController.selectedCafe {
                    CafeSelectionCard(
                        cafe: cafe,
                        bridge: bridge,
                        appState: appState,
                        onClose: {
                            // ピン集合（全検索結果）は維持し、カードの選択のみ解除する。
                            // 検索結果からの選択時は結果一覧の下部ドラッグシートへ戻す
                            // （「一覧に戻る」導線。2026-07-22 マップ検索結果刷新）。
                            searchController.selectedCafe = nil
                            searchController.highlightedPlaceId = nil
                            if searchController.searchBridge != nil {
                                searchController.showingResults = true
                            }
                        },
                        onOpenDetail: { cafe in
                            navigationPath.append(
                                CafeDetailRoute(placeId: cafe.placeId, initialCafe: cafe)
                            )
                            // ピン集合（全検索結果）は維持し、カードの選択のみ解除する
                            searchController.selectedCafe = nil
                            searchController.highlightedPlaceId = nil
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
                    if searchController.showAreaSearchButton {
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
            .animation(.default, value: searchController.showAreaSearchButton)
            .animation(.default, value: isSearchMode)
            .onChange(of: isSearchFieldFocused) { _, focused in
                // 検索モードに入るタイミングでブラウズ用アフォーダンスを確実に隠す
                if focused {
                    searchController.showAreaSearchButton = false
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
        if let sb = searchController.searchBridge, isShowingSearchResultsSheet {
            MapSearchResultsSheet(
                results: searchController.displayedResults,
                isLoading: sb.isLoading,
                searchAdLoader: searchAdLoader,
                currentHeight: searchSheetCurrentHeight,
                baseHeight: searchSheetBaseHeight,
                expandedHeight: searchSheetExpandedHeight,
                detent: $searchSheetDetent,
                dragTranslation: $searchSheetDragTranslation,
                onSelectCafe: { cafe in searchController.selectResult(cafe) }
            )
        }
    }

    // MARK: - 検索バー

    private var searchBarView: some View {
        // `TextField` の双方向バインド（`$searchController.query`）には `@Bindable` が必要
        // （`@Observable` クラスのメンバーへの Binding 取得。SwiftUI + Observation の標準パターン）。
        @Bindable var searchController = searchController
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)
            TextField(String(localized: "カフェ名で検索"), text: $searchController.query)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit { searchController.performSearch(center: appState.mapSearchCenter) }
                .onChange(of: searchController.query) { _, newValue in
                    if newValue.isEmpty {
                        searchController.clearSelection(mapBridge: appState.mapBridge)
                    }
                }
            if !searchController.query.isEmpty {
                Button {
                    searchController.query = ""
                    searchController.clearSelection(mapBridge: appState.mapBridge)
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
    /// タップで `MapSearchController.performAreaSearch(center:)` を呼び、表示範囲内のカフェを一括検索する。
    /// 検索中は `isAreaSearchInFlight` に応じてスピナーへ差し替え、タップを無効化する。
    private var areaSearchButton: some View {
        Button {
            searchController.performAreaSearch(center: appState.mapSearchCenter, visibleRegion: latestVisibleRegion)
        } label: {
            HStack(spacing: 6) {
                if searchController.isAreaSearchInFlight {
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
        .disabled(searchController.isAreaSearchInFlight)
        .accessibilityLabel(String(localized: "このエリアを検索"))
        .accessibilityHint(String(localized: "表示中の地図範囲内のカフェを検索してピン表示します"))
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
}
