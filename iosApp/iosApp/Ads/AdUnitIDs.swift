import Foundation

/// AdMob アダプティブバナー広告のユニット ID。
///
/// `Configuration/Base.xcconfig` → `Info.plist` 経由で注入する（Places API キーと同じ経路。
/// requirements.md §11 確定仕様）。本番 ID 発行前は Google 公式のテスト用バナー広告ユニット ID が
/// `Base.xcconfig` にフォールバックとして設定されているため、`Secrets.xcconfig` に本番 ID を
/// 追加するまではテスト広告で動作する（本番切り替え手順は `Configuration/README.md` 参照）。
///
/// コーヒー記録タブ / 分析タブの 2 面は 2026-07-16 にユーザビリティレビューで撤去した
/// （requirements.md §11-3）。カフェ詳細画面 / マップ検索結果一覧のインライン広告 2 面は
/// 全画面下部固定バナー（`globalBottom`、requirements.md §11-5）への集約に伴い 2026-09-20 に
/// 撤去した。いずれも git 履歴で復元可能。
enum AdUnitIDs {

    /// 全画面下部固定アダプティブバナー（requirements.md §11-5）。現在の唯一の広告面。
    static let globalBottom = value(forKey: "ADMOB_BANNER_AD_UNIT_ID_GLOBAL_BOTTOM")

    private static func value(forKey key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
