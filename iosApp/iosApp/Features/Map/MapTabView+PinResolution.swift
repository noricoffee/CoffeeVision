import SharedLogic

// MARK: - MapTabView ピン競合解決（M-1 で別ファイルへ機械的に移動）

extension MapTabView {

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
    func displayedCuratedCafes(_ bridge: MapViewModelBridge) -> [CuratedCafe] {
        guard let radiusMeters = appState.mapSearchCenter?.radiusMeters,
              radiusMeters <= AppleNearbyCafeLoader.zoomGateRadiusMeters else {
            return []
        }
        let visited = visitedPlaceIds(bridge)
        let saved = savedPlaceIds(bridge)
        let searched = Set(bridge.searchResultPlaces.map { $0.placeId })
        return bridge.curatedCafes.filter {
            !visited.contains($0.placeId) && !saved.contains($0.placeId) && !searched.contains($0.placeId)
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
            userRatingCount: nil
        )
    }
}
