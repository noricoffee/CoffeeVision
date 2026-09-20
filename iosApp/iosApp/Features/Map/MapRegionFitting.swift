import CoreLocation
import MapKit

/// 複数の座標を画面に収めるカメラ region を求めるユーティリティ（SL-9）。
///
/// 訪問済みカフェへの初期カメラ合わせ（`MapTabView+Location.setInitialCameraFromVisitedCafes`）と、
/// テキスト検索結果へのカメラフィット（`MapSearchController.fitCameraToSearchResults`）が
/// padding 係数・span 下限まで含めて同一計算をしていたため 1 本に括り出した。
/// 単一件数時のズーム距離だけが用途ごとに異なる（訪問済み 2000m / 検索結果 800m）ので引数で受ける。
enum MapRegionFitting {

    /// bounding box の各辺に与える余白倍率（1.3 = 片側 15% 相当）。
    private static let paddingFactor = 1.3

    /// span の下限（度）。座標が密集していても一定のズームアウトを保つ。
    private static let minimumSpanDegrees = 0.01

    /// 与えられた座標すべてが収まる region を返す。
    ///
    /// - Parameters:
    ///   - coordinates: 対象座標。空なら `nil` を返す（呼び出し側でフォールバックを決める）。
    ///   - singleCoordinateMeters: 座標が 1 件だけのときに使う正方 region の一辺（メートル）。
    /// - Returns: 座標が 0 件なら `nil`、1 件なら `singleCoordinateMeters` 四方の region、
    ///            2 件以上なら bounding box に `paddingFactor` を掛けた region。
    static func region(
        fitting coordinates: [CLLocationCoordinate2D],
        singleCoordinateMeters: CLLocationDistance
    ) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                latitudinalMeters: singleCoordinateMeters,
                longitudinalMeters: singleCoordinateMeters
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLng = min(minLng, coordinate.longitude)
            maxLng = max(maxLng, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * paddingFactor, minimumSpanDegrees),
            longitudeDelta: max((maxLng - minLng) * paddingFactor, minimumSpanDegrees)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
