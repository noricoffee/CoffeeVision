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
/// - ピンタップで `CafeDetailView` へ push する（NavigationStack は Tab 配下 RootTabView が提供）
/// - 現在地取得は `LocationManager` 経由
struct MapTabView: View {

    var appState: AppState

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationManager = LocationManager()
    @State private var didSetInitialCamera = false

    // MARK: - Body

    var body: some View {
        Group {
            if let bridge = appState.mapBridge {
                mapContent(bridge: bridge)
                    .navigationTitle(String(localized: "マップ"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { filterToolbar(bridge: bridge) }
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
                    .alert(
                        String(localized: "エラー"),
                        isPresented: Binding(
                            get: { bridge.error != nil },
                            set: { if !$0 { bridge.onErrorDismissed() } }
                        )
                    ) {
                        Button(String(localized: "OK")) { bridge.onErrorDismissed() }
                    } message: {
                        Text(bridge.error ?? "")
                    }
                    .task {
                        await setupLocation(bridge: bridge)
                    }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - マップコンテンツ

    @ViewBuilder
    private func mapContent(bridge: MapViewModelBridge) -> some View {
        Map(position: $cameraPosition) {
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
        .mapStyle(.standard)
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

    // MARK: - フィルタツールバー

    @ToolbarContentBuilder
    private func filterToolbar(bridge: MapViewModelBridge) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle(
                    String(localized: "訪問済みを表示"),
                    isOn: Binding(
                        get: { bridge.showVisited },
                        set: { bridge.onShowVisitedToggled($0) }
                    )
                )
                Toggle(
                    String(localized: "周辺を表示"),
                    isOn: Binding(
                        get: { bridge.showNearby },
                        set: { bridge.onShowNearbyToggled($0) }
                    )
                )
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .accessibilityLabel(String(localized: "表示フィルタ"))
            }
        }
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
