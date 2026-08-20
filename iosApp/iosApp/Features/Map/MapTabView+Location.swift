import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

// MARK: - MapTabView 位置・カメラ関連（M-4 機械的移動）

/// 現在地取得・現在地 FAB・初期カメラ設定を担う `extension`。
///
/// ロジックは `MapTabView.swift` から純粋移動したもの（挙動変更なし）。移動対象が参照する
/// `MapTabView` 本体側の `@State`（`cameraPosition` / `locationManager` / `didSetInitialCamera` /
/// `pendingRecenter`）は、別ファイルの `extension` から参照できるよう `private` を外して internal
/// 化している（`swiftui-view-splitting.md` 参照）。
extension MapTabView {

    // MARK: - 現在地 FAB

    /// bottom-trailing 固定の「現在地に戻る」FAB。
    ///
    /// - `.denied` / `.restricted` 時は淡色 + 無効化
    /// - それ以外は押下で `recenterToCurrentLocation()` を呼ぶ
    var currentLocationFAB: some View {
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
    func recenterToCurrentLocation() {
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

    // MARK: - 位置情報セットアップ

    func setupLocation(bridge: MapViewModelBridge) async {
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
    func locationStream() -> AsyncStream<CLLocationCoordinate2D> {
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
    func setInitialCameraFromVisitedCafes(_ visitedCafes: [VisitedCafe]) {
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
