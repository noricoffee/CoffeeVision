import Foundation
@preconcurrency import FoundationModels
@preconcurrency import SharedLogic

// MARK: - SearchByTasteProfileTool

/// 「こんな味のコーヒー」という自然言語から 5 軸好みベクトルを抽出し、
/// テイスティングスコア範囲で記録を検索する Foundation Models Tool。
///
/// `SearchCoffeeRecordsTool`（キーワード検索）と並列に
/// `CoffeeInsightProviderIosImpl.generateAnswer` に登録する。
///
/// ## 動作フロー
///
/// 1. LLM がユーザー発話（「酸味が強くてフルーティな記録は？」等）を判定し本 Tool を呼ぶ
/// 2. `TastePreferenceExtractor.extract(from:)` で 5 軸ベクトルに変換
/// 3. `TastePreference.toCoffeeRecordFilter()` で ±2 のスコア範囲フィルターを生成
/// 4. `CoffeeRecordQuery.searchRecords(filter:)` でローカル DB を照会
/// 5. 結果をコンパクトな日本語行形式で LLM に返す
///
/// ## `SearchCoffeeRecordsTool` との使い分け
///
/// - キーワード検索（カフェ名・産地・期間など）→ `SearchCoffeeRecordsTool`
/// - テイスティング特徴の類似検索（甘味・酸味・後味など）→ 本 Tool
struct SearchByTasteProfileTool: Tool {

    let name = "search_by_taste_profile"
    let description = """
        ユーザーが「こんな味のコーヒーが飲みたい」「酸味が強くてフルーティな記録は？」「ライトな後味の…」のように
        コーヒーの味わいの特徴（甘味・酸味・ボディ・風味・後味）を自然言語で表現した場合に呼ぶ。
        テキストから5軸好みベクトルを抽出し、テイスティングスコアが一致する記録を返す。
        カフェ名・産地・期間などを主条件にする場合は searchCoffeeRecords を使うこと。
        """

    // MARK: - Arguments

    @Generable
    struct Arguments {
        /// ユーザーが表現したコーヒーの味わいの説明テキスト（自然言語・日本語）
        @Guide(description: "ユーザーが表現したコーヒーの味わいの説明テキスト（自然言語・日本語）")
        var tasteDescription: String
    }

    // MARK: - Dependencies

    let recordQuery: CoffeeRecordQuery
    let extractor: TastePreferenceExtractor

    // MARK: - call

    /// LLM が本 Tool を呼び出したときに実行される。
    ///
    /// `tasteDescription` → `TastePreference`（5軸） → `CoffeeRecordFilter`（±2 範囲）
    /// → `[CoffeeRecordSummary]` → コンパクトな日本語行形式
    func call(arguments: Arguments) async throws -> String {
        let desc = arguments.tasteDescription
        print("[CoffeeVision] SearchByTasteProfileTool: 味わい説明='\(desc)'")

        let preference = try await extractor.extract(from: desc)
        let filter = preference.toCoffeeRecordFilter()
        let summaries = try await recordQuery.searchRecords(filter: filter)

        print("[CoffeeVision] SearchByTasteProfileTool: 取得件数=\(summaries.count)")

        if summaries.isEmpty {
            return "指定の味わい特徴（甘味:\(preference.sweetness) ボディ:\(preference.body) 酸味:\(preference.acidity) 風味:\(preference.flavor) 後味:\(preference.aftertaste)）±2 の範囲に一致するテイスティング記録はありませんでした。テイスティングを入力していない記録は対象外です。"
        }

        var lines = ["味わい特徴（甘味:\(preference.sweetness) ボディ:\(preference.body) 酸味:\(preference.acidity) 風味:\(preference.flavor) 後味:\(preference.aftertaste)）に近い記録:"]
        for summary in summaries {
            var parts = ["・\(summary.name)"]
            if let cafeName = summary.cafeName { parts.append("(\(cafeName))") }
            if let origin = summary.origin { parts.append("産地:\(origin)") }
            let ratingStr = summary.rating < 0.5 ? "未評価" : String(format: "%.1f", summary.rating)
            parts.append("評価:\(ratingStr)")
            lines.append(parts.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }
}
