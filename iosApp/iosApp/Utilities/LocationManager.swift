import CoreLocation
import Observation

/// CoreLocation のワンショット位置取得ラッパ。
///
/// - `requestLocation()` で 1 回限りの位置取得を要求する（継続監視は使わない）
/// - 権限未確定の場合は `requestWhenInUseAuthorization()` を呼び、
///   `locationManagerDidChangeAuthorization` で許可されたら自動で再取得する
/// - `lastLocation` を `@Observable` プロパティとして公開し、SwiftUI の `.onChange` で検知できる
/// - `CLLocationCoordinate2D` は `Equatable` 非準拠のため、View 側では `latitude` で観測する
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    /// 現在の位置情報アクセス権限。
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// 最後に取得した座標。取得前・リセット後は `nil`。
    private(set) var lastLocation: CLLocationCoordinate2D?

    /// 位置取得失敗時のエラー。
    private(set) var error: Error?

    // MARK: - Init

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public API

    /// 位置情報を 1 回取得する。
    ///
    /// - 権限未確定の場合は許可ダイアログを表示し、許可後に自動で位置取得を再実行する
    /// - 権限拒否 / 制限の場合は何もしない（View 側で `authorizationStatus` を見て alert を出す）
    func requestLocation() {
        error = nil
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // 許可後は locationManagerDidChangeAuthorization から requestLocation() を再呼び出しする
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            // View 側で authorizationStatus を監視して alert を出す
            break
        @unknown default:
            break
        }
    }

    /// `lastLocation` を nil にリセットする。
    ///
    /// `.onChange(of: locationManager.lastLocation?.latitude)` で同じ座標が来た場合でも
    /// 再トリガしたい場合は、このメソッドを呼んでから `requestLocation()` を呼ぶ。
    func resetLastLocation() {
        lastLocation = nil
    }

    /// `error` を nil にリセットする。alert 閉じ時に View から呼ぶ。
    func clearError() {
        error = nil
    }

    // MARK: - CLLocationManagerDelegate
    //
    // CoreLocation のコールバックは `nonisolated` として宣言する必要がある
    // （`CLLocationManagerDelegate` は素の Obj-C プロトコルで MainActor を認識しないため）。
    // 実際の呼び出しスレッドは、`manager`（`CLLocationManager`）が MainActor 上（`init` 内）で
    // 生成されているため常にメインスレッドになる（Apple 公式ドキュメント: delegate コールバックは
    // `CLLocationManager` を生成したスレッドの RunLoop 上で呼ばれる）。
    // `Task { @MainActor in }` は「非同期にホップする可能性がある」ため、`CLLocationManager`
    // （非 Sendable）を closure でキャプチャすると Swift 6 で警告になる。実態が
    // 常にメインスレッドである以上、同期的に MainActor 分離を仮定する
    // `MainActor.assumeIsolated` の方が正確（`AppleSignInCoordinator.presentationAnchor` と同じ方針）。

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // `manager`（非 Sendable）自体は `assumeIsolated` の closure に渡さない。
        // `CLAuthorizationStatus`（Sendable な値型）だけを取り出して境界を越える。
        let newStatus = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.authorizationStatus = newStatus
        }
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coord = locations.first?.coordinate else { return }
        MainActor.assumeIsolated {
            self.lastLocation = coord
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            self.error = error
        }
    }
}
