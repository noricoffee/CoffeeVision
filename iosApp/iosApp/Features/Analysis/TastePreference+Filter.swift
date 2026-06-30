import SharedLogic

// MARK: - TastePreference → CoffeeRecordFilter 変換

extension TastePreference {

    /// `TastePreference`（5軸好みベクトル）を `CoffeeRecordFilter`（KMP）に変換する。
    ///
    /// テイスティングスコア範囲でコーヒー記録を検索するためのフィルターを生成する。
    /// 各軸に `margin` の幅（デフォルト ±2）を持たせることで、厳密一致ではなく近似一致を実現する。
    ///
    /// ## 型変換
    ///
    /// `TastePreference` の各軸は Swift `Int`（64-bit）。
    /// `TastingScores` の各フィールドは Kotlin `Int`（Kotlin/Native → Swift `Int32`）。
    /// 明示的に `Int32` へキャストしてから演算する。
    ///
    /// ## roast の扱い
    ///
    /// - `roast == "unknown"` のとき `roastLevel` を nil にする（焙煎度フィルタを外す）
    /// - それ以外の場合は `roastLevel` に渡す（KMP 側が enum.name に寛容マッチを行う）
    ///
    /// - Parameters:
    ///   - margin: 各軸の許容範囲（デフォルト ±2）
    ///   - limit: 最大取得件数（デフォルト 20）
    /// - Returns: テイスティングスコア範囲を含む `CoffeeRecordFilter`
    func toCoffeeRecordFilter(margin: Int32 = 2, limit: Int32 = 20) -> CoffeeRecordFilter {
        let sw = Int32(sweetness)
        let bd = Int32(body)
        let ac = Int32(acidity)
        let fl = Int32(flavor)
        let af = Int32(aftertaste)

        return CoffeeRecordFilter(
            origin: nil,
            brewMethod: nil,
            roastLevel: roast == "unknown" ? nil : roast,
            cafeName: nil,
            minRating: nil,
            maxRating: nil,
            fromYearMonth: nil,
            toYearMonth: nil,
            tastingMin: TastingScores(
                sweetness: Swift.max(1, sw - margin),
                body: Swift.max(1, bd - margin),
                acidity: Swift.max(1, ac - margin),
                flavor: Swift.max(1, fl - margin),
                aftertaste: Swift.max(1, af - margin)
            ),
            tastingMax: TastingScores(
                sweetness: Swift.min(10, sw + margin),
                body: Swift.min(10, bd + margin),
                acidity: Swift.min(10, ac + margin),
                flavor: Swift.min(10, fl + margin),
                aftertaste: Swift.min(10, af + margin)
            ),
            limit: limit
        )
    }
}
