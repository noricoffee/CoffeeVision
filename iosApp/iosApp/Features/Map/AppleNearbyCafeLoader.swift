import MapKit
import CoreLocation
import Observation
import SharedLogic

// MARK: - AppleNearbyCafeLoader

/// 周辺カフェ（Apple 検索由来）の取得を担う `@Observable` サービス。
///
/// `MapTabView`（M-2、2026-07-24 分割リファクタ）から Apple POI fetch のロジックを隔離したもの。
/// `MKLocalPointsOfInterestRequest` + `MKLocalSearch` で表示範囲内のカフェを Apple 地図データから
/// 常時取得する（ズーム依存の標準 POI ラベルに代わる自前ピン。フェーズ 17）。
/// デバウンス（300ms）・キャンセル・ズームゲート・スロットリング耐性・ネガティブキャッシュ・
/// 名前ヒューリスティック除外の挙動は移設前（`MapTabView`）と完全に同一。
///
/// `MapTabView`（暗黙 MainActor の View）から呼ばれていた挙動を保つため `@MainActor` にする。
@MainActor
@Observable
final class AppleNearbyCafeLoader {

    /// ズームゲートしきい値（この可視半径[m]を超えたら fetch せず既存ピンをクリアする）。
    ///
    /// `MapTabView+PinResolution.swift`（`displayedCuratedCafes`）からも同一しきい値を共用するため
    /// internal のまま維持する（Apple 周辺ピンと curated ピンが同じズームゲートを使う設計意図。
    /// M-2 でしきい値の定義元を本クラスへ集約）。
    static let zoomGateRadiusMeters: Double = 3000

    /// `MKLocalPointsOfInterestRequest` で取得した周辺カフェ（低強調ピン用）。
    ///
    /// dedup（既存ピンとの座標近接除外）前の生データ。表示用の一覧は `displayed(excluding:)` を使う。
    private(set) var cafes: [ApplePoiCafe] = []

    /// 直近の Apple 検索 fetch Task（デバウンス / キャンセル用）。
    private var fetchTask: Task<Void, Never>? = nil

    /// カメラ移動確定ごとに Apple 検索由来の周辺カフェ fetch をスケジュールする。
    ///
    /// 直近の fetch Task をキャンセルしてから 300ms 待機し、連続パンを 1 回の検索へまとめる。
    /// 可視半径がしきい値（`zoomGateRadiusMeters`）を超える場合は fetch せず既存ピンを
    /// クリアする（都市スケールでの氾濫防止。しきい値以下では全ズーム域でピンが出る）。
    func schedule(center: MapSearchCenter) {
        fetchTask?.cancel()
        guard center.radiusMeters <= Self.zoomGateRadiusMeters else {
            cafes = []
            return
        }
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await fetch(center: center)
        }
    }

    /// ネガティブキャッシュへ登録済みの Apple POI をピン一覧から即時除去する。
    ///
    /// `poiLookupError`（「該当なし」）を受けた呼び出し元が、`ApplePoiNegativeCache.add` と
    /// セットで呼ぶ（周辺カフェピンのノイズ除去、2026-07-13）。
    func removeCafe(id: String) {
        cafes.removeAll { $0.id == id }
    }

    /// 表示対象の Apple 検索由来カフェ。
    ///
    /// 既存ピン（訪問済み / 保存済み / 検索結果 / おすすめ（curated））のいずれかと座標近接
    /// （約 40m 以内）のものを除外する（優先順位: 訪問済み > 保存済み > 検索結果 > おすすめ（curated）
    /// > Apple 検索由来。名前一致はローカライズで不安定なため使わない）。既存ピンの座標一覧は
    /// 呼び出し元（`MapTabView`）が `bridge` から構築して渡す。
    func displayed(excluding existingLocations: [CLLocationCoordinate2D]) -> [ApplePoiCafe] {
        let proximityThresholdMeters: CLLocationDistance = 40
        let existing = existingLocations.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        return cafes.filter { cafe in
            let location = CLLocation(latitude: cafe.coordinate.latitude, longitude: cafe.coordinate.longitude)
            return !existing.contains { $0.distance(from: location) <= proximityThresholdMeters }
        }
    }

    /// 名前ヒューリスティックで除外すべき Apple POI かどうかを判定する。
    ///
    /// 除外キーワード一覧は `ApplePoiFilterConfig`（Firebase Remote Config 外部注入、2026-07-13）を参照する。
    private func isExcludedByNameHeuristic(_ name: String) -> Bool {
        ApplePoiFilterConfig.excludedNameKeywords.contains { name.contains($0) }
    }

    /// `MKLocalPointsOfInterestRequest`（`MKLocalSearch` 経由）で表示範囲内のカフェを
    /// Apple 地図データから取得する。失敗時は低優先度の補助表示のため静かに処理するのみで、
    /// トースト等のユーザー通知は出さない。長時間のパン・ズームで Apple 側にスロットリングされた
    /// 場合（`MKError.loadingThrottled`）は一時的な失敗であり次の fetch で回復するため、
    /// 空白より古いピンを残す方が自然と判断し `cafes` を保持する。それ以外のエラーは
    /// 従来どおりクリアする（周辺カフェピンのスロットリング耐性、2026-07-18）。
    /// ベーカリー（`.bakery`）は Google Places 側の解決（`onPoiTapped` → `searchNearby`、
    /// `includedPrimaryTypes=[cafe, coffee_shop]`）に一致せずタップ解決できないため取得対象から
    /// 除外している（「表示＝解決可能」を揃える。フェーズ 17-B）。
    ///
    /// 名前ヒューリスティック除外（法人本社等）とネガティブキャッシュ（過去に「該当なし」
    /// だった POI）の両方でノイズを除去する（周辺カフェピンのノイズ除去、2026-07-13）。
    private func fetch(center: MapSearchCenter) async {
        let request = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            radius: center.radiusMeters
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            let newCafes = response.mapItems.compactMap { item -> ApplePoiCafe? in
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
            // 差分がないときは代入しない（`@Observable` は値を比較せず代入だけで変更を通知する
            // ため、同一内容の再代入は無駄な body 再評価になる）。
            if newCafes != cafes {
                cafes = newCafes
            }
        } catch {
            guard !Task.isCancelled else { return }
            if let mkError = error as? MKError, mkError.code == .loadingThrottled {
                // 一時的なスロットリング: 次の fetch で回復するため既存ピンを保持する。
                return
            }
            cafes = []
        }
    }
}
