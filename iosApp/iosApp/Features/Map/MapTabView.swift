import SwiftUI
import MapKit
import SharedLogic

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
/// - フィルタトグルで各種ピンの表示 / 非表示を切り替える
/// - カスタムピンタップで `CafeDetailView` へ push する（`NavigationLink(value:)` 経由）
/// - Apple Maps 標準 POI タップ → Places ルックアップ → `CafeDetailView` プログラマティック push
/// - 自身が `NavigationStack(path: $navigationPath)` を保持するため RootTabView 側の NavigationStack は不要
/// - 現在地取得は `LocationManager` 経由
/// - 検索タブ上に「現在地 FAB」を浮かべ、タップで地図中心を現在地・ズーム 1000m にリセットする
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

    /// `TabBarFrameReader` が報告する検索タブの global フレーム。`.zero` は未取得。
    @State private var tabBarSearchFrame: CGRect = .zero

    /// FAB タップ後、次の location 更新で 1 回だけ recenter する。
    /// `lastLocation` を nil にしないため、`setupLocation` の周辺カフェ検索に副作用を与えない。
    @State private var pendingRecenter = false

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
                        .navigationDestination(for: CafeDetailRoute.self) { route in
                            CafeDetailView(
                                placeId: route.placeId,
                                initialCafe: route.initialCafe,
                                appState: appState
                            )
                        }
                        .overlay(alignment: .bottom) {
                            if bridge.isLoadingNearby {
                                loadingBanner
                            }
                        }
                        .overlay {
                            if bridge.isLookingUpPoi {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.ultraThinMaterial)
                            }
                        }
                        // 現在地 FAB: 検索タブボタンの真上に浮かべる
                        .overlay {
                            if tabBarSearchFrame != .zero {
                                GeometryReader { geo in
                                    currentLocationFAB
                                        .position(fabPosition(geo: geo))
                                }
                            }
                        }
                        .background(
                            TabBarFrameReader { frame in
                                tabBarSearchFrame = frame
                            }
                        )
                        .errorToast(message: activeToast(bridge: bridge)?.message) {
                            activeToast(bridge: bridge)?.dismiss()
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
                // 訪問済みカフェピン（ブラウン）
                if bridge.showVisited {
                    ForEach(bridge.visitedCafes, id: \.cafe.placeId) { visitedCafe in
                        if let lat = visitedCafe.cafe.latitude?.doubleValue,
                           let lng = visitedCafe.cafe.longitude?.doubleValue {
                            Annotation(
                                visitedCafe.cafe.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: lat,
                                    longitude: lng
                                )
                            ) {
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
                    }
                }

                // 周辺カフェピン（グレー）
                if bridge.showNearby {
                    ForEach(bridge.nearbyPlaces, id: \.placeId) { cafe in
                        if let lat = cafe.latitude?.doubleValue,
                           let lng = cafe.longitude?.doubleValue {
                            Annotation(
                                cafe.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: lat,
                                    longitude: lng
                                )
                            ) {
                                NavigationLink(
                                    value: CafeDetailRoute(
                                        placeId: cafe.placeId,
                                        initialCafe: cafe
                                    )
                                ) {
                                    nearbyPin
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .including([.cafe, .bakery])))
            .ignoresSafeArea()

            // フローティングコントロール（セーフエリア内に自然に収まる）
            HStack(alignment: .center, spacing: 8) {
                filterChipRow(bridge: bridge)
                Spacer()
                settingsFloatingButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - フィルタチップ行

    private func filterChipRow(bridge: MapViewModelBridge) -> some View {
        HStack(spacing: 8) {
            FilterChip(
                label: String(localized: "訪問済み"),
                systemImage: "cup.and.saucer.fill",
                isOn: bridge.showVisited
            ) {
                bridge.onShowVisitedToggled(!bridge.showVisited)
            }

            FilterChip(
                label: String(localized: "周辺"),
                systemImage: "mappin",
                isOn: bridge.showNearby
            ) {
                bridge.onShowNearbyToggled(!bridge.showNearby)
            }
        }
    }

    // MARK: - ピン UI

    /// 訪問済みカフェピン（茶色 / 訪問回数バッジ付き）。
    private func visitedCafePin(visitedCafe: VisitedCafe) -> some View {
        ZStack {
            Circle()
                .fill(Color.brown)
                .frame(width: 32, height: 32)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(
            String(localized: "\(visitedCafe.cafe.name) 訪問済み \(visitedCafe.visitCount)回")
        )
    }

    /// 周辺カフェピン（グレー）。
    private var nearbyPin: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray3))
                .frame(width: 28, height: 28)
            Image(systemName: "mappin")
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .accessibilityLabel(String(localized: "周辺のカフェ"))
    }

    // MARK: - ローディングバナー

    private var loadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(String(localized: "周辺を検索中..."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 24)
        .accessibilityLabel(String(localized: "周辺を検索中"))
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

    /// 検索タブボタン上に浮かべる「現在地に戻る」FAB。
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

    /// `tabBarSearchFrame`（global）と `GeometryReader` の global フレームから
    /// FAB の local position を計算する。
    private func fabPosition(geo: GeometryProxy) -> CGPoint {
        let geoFrame = geo.frame(in: .global)
        let tabFrame = tabBarSearchFrame
        let size = min(max(tabFrame.height, 44), 64)
        let x = tabFrame.midX - geoFrame.minX
        let y = tabFrame.minY - geoFrame.minY - 8 - size / 2
        return CGPoint(x: x, y: y)
    }

    // MARK: - 現在地センタリング

    /// FAB タップ時に現在地へセンタリング＋ズームリセットする。
    ///
    /// `lastLocation` を nil にしないフラグ方式を採用し、
    /// `setupLocation` の `bridge.onLocationUpdated`（周辺カフェ検索）への副作用を防ぐ。
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

        // 位置情報が届いたら Bridge に通知してカメラを移動
        for await location in locationStream() {
            bridge.onLocationUpdated(
                lat: location.latitude,
                lng: location.longitude
            )
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
