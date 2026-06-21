import Foundation
@preconcurrency import FoundationModels
@preconcurrency import SharedLogic

// MARK: - SearchCoffeeRecordsTool

/// Foundation Models の `Tool`（function calling）実装。
///
/// `CoffeeInsightProvider.answer` が受け取る質問の中で、
/// `CoffeeStats` の digest だけでは答えられない個別レコード単位の問い
///（「○○カフェで飲んだコーヒーは？」「先月飲んだのは？」「エチオピアの記録は？」など）
/// に対して、KMP 側の `CoffeeRecordQuery.searchRecords` を呼び出して照会する。
///
/// ## 設計方針
///
/// - "計算は KMP・LLM は解釈と整形のみ" 原則を踏襲し、絞り込みは KMP 側で行う
/// - `Arguments` の全フィールドは optional。LLM が不要なフィールドを省略できる
/// - `brewMethod` / `roastLevel` の引数は英語 enum 名（例: "HandDrip"）を LLM に指示する
///   KMP 側の実装が寛容マッチ（大小無視 + 部分一致）を行う
/// - `minRating` / `maxRating` は `KotlinDouble(value:)` でラップして KMP に渡す
/// - ツール呼び出し結果はコンパクトな日本語行形式で返す（LLM がそのまま回答に組み込める）
///
/// ## KotlinDouble について
///
/// `CoffeeRecordFilter` の `minRating` / `maxRating` は Kotlin の `Double?` だが、
/// SKIE 後の Swift シグネチャでは `KotlinDouble?` になる。
/// LLM が生成する Swift の `Double` を `KotlinDouble(value:)` でラップして渡す。
@available(iOS 26.0, *)
struct SearchCoffeeRecordsTool: Tool {

    let name = "searchCoffeeRecords"
    let description = """
        個別のコーヒー記録について聞かれたら必ずこのツールを使う。
        特定のカフェ・産地・焙煎度・抽出方法・評価範囲・期間などに関する質問は、必ずこのツールで実際の記録を検索してから回答すること。
        ツールを呼ばずに「分かりません」と答えることは禁止。
        digest（統計サマリ）だけで答えられる質問（総杯数・平均評価・最多産地など全体傾向）にはこのツールを使わなくてよい。
        """

    // MARK: - Arguments

    @Generable
    struct Arguments {
        /// 産地（部分一致、大小文字無視）。例: "エチオピア"、"Kenya"
        @Guide(description: "絞り込む産地名。部分一致で検索する。例: 'エチオピア'、'Kenya'")
        var origin: String?

        /// 抽出方法の英語 enum 名。例: "HandDrip"、"Espresso"、"FrenchPress"、"AeroPress"、"NelDrip"、"Syphon"、"ColdBrew"、"Other"
        @Guide(description: "絞り込む抽出方法。英語 enum 名で指定する。HandDrip / Espresso / FrenchPress / AeroPress / NelDrip / Syphon / ColdBrew / Other のいずれか")
        var brewMethod: String?

        /// 焙煎度の英語 enum 名。例: "Light"、"Medium"、"City"、"FullCity"、"French"
        @Guide(description: "絞り込む焙煎度。英語 enum 名で指定する。Light / Cinnamon / Medium / High / City / FullCity / French / Italian のいずれか")
        var roastLevel: String?

        /// カフェ名（部分一致）。例: "Blue Bottle"、"スターバックス"
        @Guide(description: "絞り込むカフェ名。部分一致で検索する。例: 'Blue Bottle'、'スターバックス'")
        var cafeName: String?

        /// 最低評価（0.5〜5.0）。指定なし = 絞り込みなし。
        @Guide(description: "最低評価（0.5〜5.0 の範囲で指定。0.0 = 未評価 sentinel のため 0.5 以上を使うこと）")
        var minRating: Double?

        /// 最高評価（0.5〜5.0）。指定なし = 絞り込みなし。
        @Guide(description: "最高評価（0.5〜5.0 の範囲で指定）")
        var maxRating: Double?

        /// 期間の開始年月（YYYY-MM 形式、この月以降を含む）。例: "2026-01"
        @Guide(description: "絞り込む開始年月（YYYY-MM 形式、この月以降を含む）。例: '2026-01'")
        var fromYearMonth: String?

        /// 期間の終了年月（YYYY-MM 形式、この月まで含む）。例: "2026-06"
        @Guide(description: "絞り込む終了年月（YYYY-MM 形式、この月まで含む）。例: '2026-06'")
        var toYearMonth: String?

        /// 取得件数（1〜100。指定なし = 10 件。KMP 側でクランプする）。
        @Guide(description: "取得する最大件数（1〜100。既定 10 件）")
        var limit: Int?
    }

    // MARK: - Dependencies

    private let recordQuery: CoffeeRecordQuery

    init(recordQuery: CoffeeRecordQuery) {
        self.recordQuery = recordQuery
    }

    // MARK: - call

    /// LLM が tool を呼び出したときに実行される。
    ///
    /// `Arguments` → `CoffeeRecordFilter` へ変換 → KMP の `searchRecords` を呼び出し
    /// → `[CoffeeRecordSummary]` をコンパクトな日本語テキスト行に整形して返す。
    ///
    /// `Tool.Output` は `PromptRepresentable` に準拠していればよく、`String` を採用する。
    func call(arguments: Arguments) async throws -> String {
        // Arguments → CoffeeRecordFilter に変換
        let filter = CoffeeRecordFilter(
            origin: arguments.origin,
            brewMethod: arguments.brewMethod,
            roastLevel: arguments.roastLevel,
            cafeName: arguments.cafeName,
            minRating: arguments.minRating.map { KotlinDouble(value: $0) },
            maxRating: arguments.maxRating.map { KotlinDouble(value: $0) },
            fromYearMonth: arguments.fromYearMonth,
            toYearMonth: arguments.toYearMonth,
            limit: Int32(arguments.limit ?? 10)
        )

        print("[CoffeeVision] SearchCoffeeRecordsTool.call: origin=\(arguments.origin ?? "nil"), cafeName=\(arguments.cafeName ?? "nil"), brewMethod=\(arguments.brewMethod ?? "nil"), roastLevel=\(arguments.roastLevel ?? "nil"), from=\(arguments.fromYearMonth ?? "nil"), to=\(arguments.toYearMonth ?? "nil")")

        let summaries = try await recordQuery.searchRecords(filter: filter)

        print("[CoffeeVision] SearchCoffeeRecordsTool.call: 取得件数=\(summaries.count)")

        guard !summaries.isEmpty else {
            return "該当するコーヒー記録は見つかりませんでした。"
        }

        let lines = summaries.map { summary in
            formatSummary(summary)
        }

        let resultText = """
        検索結果（\(summaries.count) 件）:
        \(lines.joined(separator: "\n"))
        """

        return resultText
    }

    // MARK: - Private helpers

    /// `CoffeeRecordSummary` をコンパクトな日本語行に整形する。
    ///
    /// 例: `エチオピア イルガチェフェ / ○○カフェ / ハンドドリップ / ミディアム / ★4.5 / 2026-05-12`
    private func formatSummary(_ summary: CoffeeRecordSummary) -> String {
        var parts: [String] = [summary.name]

        if let cafeName = summary.cafeName {
            parts.append(cafeName)
        } else {
            parts.append("セルフ抽出")
        }

        parts.append(localizedBrewMethod(summary.brewMethod))

        if let roastLevel = summary.roastLevel {
            parts.append(localizedRoastLevel(roastLevel))
        }

        if summary.rating >= 0.5 {
            parts.append(String(format: "★%.1f", summary.rating))
        } else {
            parts.append("未評価")
        }

        parts.append(summary.visitedOn)

        return parts.joined(separator: " / ")
    }

    // MARK: - ローカライズヘルパ

    private func localizedBrewMethod(_ name: String) -> String {
        switch name {
        case "Espresso":    return "エスプレッソ"
        case "HandDrip":    return "ハンドドリップ"
        case "NelDrip":     return "ネルドリップ"
        case "FrenchPress": return "フレンチプレス"
        case "AeroPress":   return "エアロプレス"
        case "Syphon":      return "サイフォン"
        case "ColdBrew":    return "コールドブリュー"
        case "Other":       return "その他"
        default:            return name
        }
    }

    private func localizedRoastLevel(_ name: String) -> String {
        switch name {
        case "Light":     return "ライト"
        case "Cinnamon":  return "シナモン"
        case "Medium":    return "ミディアム"
        case "High":      return "ハイ"
        case "City":      return "シティ"
        case "FullCity":  return "フルシティ"
        case "French":    return "フレンチ"
        case "Italian":   return "イタリアン"
        default:          return name
        }
    }
}
