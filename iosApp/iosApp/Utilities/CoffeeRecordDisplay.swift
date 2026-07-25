import SharedLogic

// MARK: - CoffeeRecord 表示用ヘルパー

extension CoffeeRecord {

    /// 産地表示用テキスト。`origin` と `region`（エリア/農園）を半角スペースで連結する
    /// （例:「エチオピア イルガチェフェ」）。`region` が空/nil なら `origin` のみ。
    /// 両方 nil/空なら nil（呼び出し側は非表示にする）。
    ///
    /// `region` は分析非対象・表示専用（`docs/data-model.md` §1.3a / `docs/analysis-model.md` §1）。
    var originDisplayText: String? {
        let trimmedOrigin = origin?.trimmingCharacters(in: .whitespaces) ?? ""
        let trimmedRegion = region?.trimmingCharacters(in: .whitespaces) ?? ""

        if trimmedOrigin.isEmpty && trimmedRegion.isEmpty {
            return nil
        } else if trimmedRegion.isEmpty {
            return trimmedOrigin
        } else if trimmedOrigin.isEmpty {
            return trimmedRegion
        } else {
            return "\(trimmedOrigin) \(trimmedRegion)"
        }
    }
}
