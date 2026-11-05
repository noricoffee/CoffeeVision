import CoreLocation
import SharedLogic

// MARK: - MapTabView ピン競合解決（M-1 で別ファイルへ機械的に移動）
//
// ピン競合解決（訪問済み > 行きたい > 検索結果 > おすすめ（curated）> Apple 周辺）の本体は
// SL-4 で `MapViewModelBridge` 側の派生プロパティ（`displayedSavedCafes` /
// `displayedSearchResultPlaces` / `displayedCuratedCafes` / `existingPinCoordinates`）へ移した。
// body から毎回呼ぶ関数だと、無関係な state 変化でも Set 構築と測地距離計算が走るため
// （`MapViewModelBridge` の「派生ピン集合」節参照）。ここに残すのは View 側の値変換のみ。

extension MapTabView {

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
