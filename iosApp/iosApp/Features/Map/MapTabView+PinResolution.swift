import CoreLocation
import SharedLogic

// MARK: - MapTabView ピン競合解決（M-1 で別ファイルへ機械的に移動）

extension MapTabView {

    /// おすすめカフェ（curated）ピンの可視範囲マージン（`mapSearchCenter.radiusMeters` に対する倍率）。
    ///
    /// パン時にピンが画面端で遅れて出るのを避けるための先読み分。`shouldShowAreaSearchButton` が
    /// 「中心移動 > 半径 × 0.3」で「このエリアを検索」を出す設計より手前で先読みが効く値にしている。
    static let curatedVisibilityMargin: Double = 1.3

    // MARK: - 「保存済み」ピン競合解決（フェーズ 15-A）

    /// 訪問済みカフェの placeId 集合（ピン競合解決の基準。優先度最上位）。
    func visitedPlaceIds(_ bridge: MapViewModelBridge) -> Set<String> {
        Set(bridge.visitedCafes.map { $0.cafe.placeId })
    }

    /// 行きたい店の placeId 集合（検索結果ピンの競合解決に使う。表示トグルの状態に関わらず全件対象）。
    func savedPlaceIds(_ bridge: MapViewModelBridge) -> Set<String> {
        Set(bridge.savedCafes.map { $0.cafe.placeId })
    }

    /// 表示対象の行きたい店（訪問済みと競合するものを除外。優先順位: 訪問済み > 行きたい）。
    func displayedSavedCafes(_ bridge: MapViewModelBridge) -> [SavedCafe] {
        let visited = visitedPlaceIds(bridge)
        return bridge.savedCafes.filter { !visited.contains($0.cafe.placeId) }
    }

    /// 表示対象の検索結果ピン（訪問済み / 行きたいと競合するものを除外。優先順位: 訪問済み > 行きたい > 検索結果）。
    func displayedSearchResultPlaces(_ bridge: MapViewModelBridge) -> [Cafe] {
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
    /// ズームゲート: Apple 周辺ピン（`AppleNearbyCafeLoader.schedule`）と同じしきい値
    /// `AppleNearbyCafeLoader.zoomGateRadiusMeters`（可視半径 3000m）を再利用し、
    /// `appState.mapSearchCenter` の直近確定値がしきい値を超える（ズームアウトしている）場合は
    /// 空配列を返して非表示にする（東京全域規模の引きの地図で常時表示になり煩雑という確認
    /// フィードバックへの対応）。独自のしきい値は新設しない（M-2 でしきい値の定義元を
    /// `AppleNearbyCafeLoader` へ集約）。
    /// 可視範囲フィルタ（2026-08-09 追加、MU-1）:
    /// ズームゲートを通ると `curatedCafes` 全件（実データ 421 件）が `Annotation` に載り、
    /// **画面外のピンまで SwiftUI の View として構築されていた**（実測で 1 回の body 評価あたり
    /// curated ピン 210 個）。`mapSearchCenter` からの距離で可視範囲外を落とす。
    ///
    /// **基準に `latestVisibleRegion`（可視領域の矩形）を使ってはいけない。** 矩形の方が正確だが、
    /// `latestVisibleRegion` は現在 body から読まれておらず（「このエリアを検索」実行時に
    /// `performAreaSearch` へ渡すだけ）、`onMapCameraChange` で**無条件代入**されている。
    /// これを body で読むと**新しいカメラ依存が生まれる** — 2026-08-09 のウォッチドッグ障害は
    /// 「カメラ → ピン表示数 → カメラ」の循環が原因だったため、依存方向を増やさないことを優先する
    /// （`MKCoordinateRegion` は `Equatable` 非準拠で同値ガードも書きにくい）。
    /// `mapSearchCenter` は本メソッドがズームゲートで既に読んでおり、`isEquivalent`（1m 許容）の
    /// 同値ガードも入っているため、依存を増やさずに済む。詳細は lessons 2026-08-09。
    ///
    /// 矩形と半径のズレ（横長の地図で角が漏れる）は、`radiusMeters` が `max(latMeters, lngMeters)`
    /// = 可視領域の外接半径相当であるため**半径側が広く出る**方向であり、実用上は可視領域を包含する。
    func displayedCuratedCafes(_ bridge: MapViewModelBridge) -> [CuratedCafe] {
        guard let center = appState.mapSearchCenter,
              center.radiusMeters <= AppleNearbyCafeLoader.zoomGateRadiusMeters else {
            return []
        }
        let visited = visitedPlaceIds(bridge)
        let saved = savedPlaceIds(bridge)
        let searched = Set(bridge.searchResultPlaces.map { $0.placeId })
        let visibilityLimitMeters = center.radiusMeters * Self.curatedVisibilityMargin
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return bridge.curatedCafes.filter {
            // placeId 競合の除外を先に評価して、距離計算の回数を短絡で減らす
            guard !visited.contains($0.placeId),
                  !saved.contains($0.placeId),
                  !searched.contains($0.placeId) else {
                return false
            }
            let distance = centerLocation.distance(
                from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            )
            return distance <= visibilityLimitMeters
        }
    }

    /// `CuratedCafe` から詳細画面遷移用の最小 `Cafe` を構築する。
    ///
    /// 揮発フィールド（評価 / 営業時間等）は保持していないため nil / 空のまま渡し、
    /// 詳細画面の既存 getDetails リフレッシュ（`googleRating == null` 条件）に解決を委ねる。
    func minimalCafe(from curated: CuratedCafe) -> Cafe {
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
            userRatingCount: nil,
            photoAttributions: []
        )
    }
}
