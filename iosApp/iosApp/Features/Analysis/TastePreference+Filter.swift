import SharedLogic

// MARK: - TastePreference 拡張

extension TastePreference {

    // MARK: - Places API 検索補完キーワード

    /// `TastePreference` をカフェ検索補完キーワードに変換する。
    ///
    /// 各軸のスコア（1〜10）と `roast` から Places API に渡す検索キーワード群を生成する。
    /// スコア 7 以上を「高い」、4 以下を「低い」として特徴語を付与する。
    /// 戻り値は空白区切りの日本語キーワード文字列（例: "フルーティ 浅煎り 酸味"）。
    /// 特徴なし（スコアがすべて中間）のときは空文字を返す。
    var searchKeywords: String {
        var terms: [String] = []
        if sweetness >= 7 { terms.append("甘い") }
        if acidity >= 7 { terms += ["フルーティ", "酸味"] }
        if body >= 7 { terms.append("コク") }
        if body <= 3 { terms.append("あっさり") }
        if aftertaste >= 7 { terms.append("余韻") }
        switch roast {
        case let r where r.lowercased().contains("light"):
            terms += ["浅煎り", "スペシャルティ"]
        case let r where r.lowercased().contains("medium"):
            terms.append("中煎り")
        case let r where r.lowercased().contains("dark"):
            terms += ["深煎り", "エスプレッソ"]
        default:
            break
        }
        return terms.joined(separator: " ")
    }

    // MARK: - CoffeeRecordFilter 変換

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
