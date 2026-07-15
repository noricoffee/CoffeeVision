import Foundation

/// AdMob アダプティブバナー広告 4 面分のユニット ID。
///
/// `Configuration/Base.xcconfig` → `Info.plist` 経由で注入する（Places API キーと同じ経路。
/// requirements.md §11 確定仕様）。本番 ID 発行前は Google 公式のテスト用バナー広告ユニット ID が
/// `Base.xcconfig` にフォールバックとして設定されているため、`Secrets.xcconfig` に本番 ID を
/// 追加するまではテスト広告で動作する（本番切り替え手順は `Configuration/README.md` 参照）。
enum AdUnitIDs {

    /// カフェ詳細画面のインラインアダプティブバナー（requirements.md §11-1）。
    static let cafeDetail = value(forKey: "ADMOB_BANNER_AD_UNIT_ID_CAFE_DETAIL")

    /// マップ検索ドロップダウンのインラインアダプティブバナー（requirements.md §11-2）。
    static let mapSearchDropdown = value(forKey: "ADMOB_BANNER_AD_UNIT_ID_MAP_SEARCH")

    /// コーヒー記録タブのリスト先頭インラインアダプティブバナー（requirements.md §11-3。
    /// 2026-07-15 上部固定 → リスト先頭インライン配置に変更。定数名は当時のまま維持）。
    static let coffeeListBottomBar = value(forKey: "ADMOB_BANNER_AD_UNIT_ID_COFFEE_LIST")

    /// 分析タブの下部固定アンカーアダプティブバナー（requirements.md §11-3）。
    static let analysisBottomBar = value(forKey: "ADMOB_BANNER_AD_UNIT_ID_ANALYSIS")

    private static func value(forKey key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
