import CoreLocation
import Observation

/// CoreLocation のワンショット位置取得ラッパ。
///
/// - `requestLocation()` で 1 回限りの位置取得を要求する（継続監視は使わない）
/// - 権限未確定の場合は `requestWhenInUseAuthorization()` を呼び、
///   `locationManagerDidChangeAuthorization` で許可されたら自動で再取得する
/// - `lastLocation` を `@Observable` プロパティとして公開し、SwiftUI の `.onChange` で検知できる
/// - `CLLocationCoordinate2D` は `Equatable` 非準拠のため、View 側では `latitude` で観測する
///
/// ## 不変条件
///
/// **生成しただけでは位置取得は走らない。** `requestLocation()` を呼んだときだけ走る。
/// `@State private var locationManager = LocationManager()` は View struct の init のたびに
/// 式が評価される（SwiftUI は最初の 1 つだけ採用して残りを捨てる）ため、生成が副作用を
/// 持つと捨てられるインスタンスまで GPS を叩くことになる。詳細は [hasPendingRequest]。
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

    /// [requestLocation] が権限未確定のまま**保留**になっているか。
    ///
    /// `locationManagerDidChangeAuthorization` は権限が変化したときだけでなく
    /// **`manager.delegate = self` を代入した時点でも発火する**（CoreLocation の仕様）。
    /// そのためハンドラ側に「許可済みなら取得する」と素直に書くと、
    /// **インスタンスを生成しただけで GPS 取得が 1 回走る**。
    ///
    /// このフラグは「ユーザー起点の要求が権限ダイアログ待ちで保留されている」ことだけを表し、
    /// ハンドラはそれが立っているときにのみ再取得する。実測では修正前、マップタブの
    /// 起動 1 回につき GPS 要求が 2 回（`setupLocation` の 1 回 + 生成由来の 1 回）走っていた。
    private var hasPendingRequest = false

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
    ///
    /// **位置取得が走るのはこのメソッドを呼んだときだけ**（生成しただけでは走らない）。
    /// その保証は [hasPendingRequest] が担っている。
    func requestLocation() {
        error = nil
        switch authorizationStatus {
        case .notDetermined:
            // 許可後に locationManagerDidChangeAuthorization から取得を再開するため、
            // 「ユーザーが要求した」ことを記録しておく
            hasPendingRequest = true
            manager.requestWhenInUseAuthorization()
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

    /// 権限変化の通知。**`manager.delegate = self` の代入時にも発火する**点に注意。
    ///
    /// そのため「許可済みなら取得する」と書いてはいけない（生成が副作用になる）。
    /// 取得を再開するのは [requestLocation] が権限ダイアログ待ちで保留していたときだけ。
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // `manager`（非 Sendable）自体は `assumeIsolated` の closure に渡さない。
        // `CLAuthorizationStatus`（Sendable な値型）だけを取り出して境界を越える。
        let newStatus = manager.authorizationStatus
        let shouldResume = MainActor.assumeIsolated { () -> Bool in
            self.authorizationStatus = newStatus
            guard self.hasPendingRequest else { return false }
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.hasPendingRequest = false
                return true
            case .denied, .restricted:
                // 拒否で確定したので待たない（保留したままだと次の権限変化で不意に取得が走る）
                self.hasPendingRequest = false
                return false
            case .notDetermined:
                // まだダイアログ表示中。保留を維持する
                return false
            @unknown default:
                return false
            }
        }
        if shouldResume {
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
