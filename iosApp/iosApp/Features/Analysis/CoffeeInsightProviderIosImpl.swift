import Foundation
import FoundationModels
import SharedLogic

// MARK: - CoffeeInsightProviderIosImpl

/// `CoffeeInsightProvider`（Kotlin interface）の iOS 実装。
///
/// Foundation Models（オンデバイス LLM）を用いて `CoffeeStats` から
/// 「あなたの傾向」を 2–3 文で要約する。
///
/// ## 実装概要
///
/// 1. `makeIfAvailable()` で `SystemLanguageModel.default.availability` を確認し、
///    `.available` のときだけ本クラスのインスタンスを返す。それ以外は nil を返す。
/// 2. `summarize(stats:completionHandler:)` は SKIE protocol witness 形式（completion handler）。
///    `CoffeeStats` をコンパクトな日本語テキストに整形 → `LanguageModelSession` に渡す。
/// 3. 生成結果は `@Generable struct CoffeeInsightOutput`（`headline` / `body`）で構造化受け取り。
/// 4. 生成失敗時は completion に error を渡す（AnalysisViewModel 側で `Failed` 扱いになる）。
///
/// ## 注意
///
/// - 本クラスは Apple Intelligence が有効な端末でのみ使用する（nil チェックは注入側で行う）
/// - Foundation Models は iOS 26.0 以降が必要。`@available` ガードで全メソッドを保護する
/// - `summarize` は呼ばれるたびに新しい `LanguageModelSession` を作る（ステートレス）
///
final class CoffeeInsightProviderIosImpl: NSObject, CoffeeInsightProvider {

    // MARK: - State

    /// KMP の `CoffeeRecordQuery`。
    ///
    /// `AppContainer` 構築後に `attachRecordQuery(_:)` で後付けする（依存サイクル解消）。
    /// `nil` のまま `answer` が呼ばれた場合は digest-only セッションにフォールバックする。
    private var recordQuery: CoffeeRecordQuery?

    /// テイスティングスコア範囲検索 Tool 用の `TastePreferenceExtractor`。
    ///
    /// `makeIfAvailable()` で `CoffeeInsightProviderIosImpl` と同時に生成する。
    /// `recordQuery` がアタッチ済みかつ `tasteExtractor` が非 nil のとき、
    /// `SearchByTasteProfileTool` を tools 配列に追加する。
    private var tasteExtractor: TastePreferenceExtractor?

    // MARK: - Factory

    /// `SystemLanguageModel` の可否を確認し、利用可能なときだけインスタンスを返す。
    ///
    /// `.available` 以外（`deviceNotEligible` / `appleIntelligenceNotEnabled` / `modelNotReady`）
    /// の場合は nil を返す。呼び出し元（AppState）は nil を AppContainer に渡す。
    ///
    /// - Returns: `CoffeeInsightProviderIosImpl` のインスタンス（具象型）。
    ///   `AppState` が `attachRecordQuery` を呼べるよう具象型を返す。
    static func makeIfAvailable() -> CoffeeInsightProviderIosImpl? {
        guard SystemLanguageModel.default.availability == .available else {
            print("[CoffeeVision] Foundation Models unavailable: \(SystemLanguageModel.default.availability)")
            return nil
        }
        print("[CoffeeVision] Foundation Models available — creating CoffeeInsightProviderIosImpl")
        let instance = CoffeeInsightProviderIosImpl()
        instance.tasteExtractor = TastePreferenceExtractor()
        return instance
    }

    // MARK: - 遅延アタッチ（依存サイクル解消）

    /// `AppContainer` 構築後に `coffeeRecordQuery` を後付けする。
    ///
    /// `CoffeeInsightProviderIosImpl` は `AppContainer` の constructor argument になるため、
    /// container 構築時には `coffeeRecordQuery` がまだ存在しない。
    /// そのため `bootstrap()` で container 構築後にこのメソッドで後付けする。
    /// `answer(question:stats:)` が呼ばれるのは初期化完了後のため、競合リスクはない。
    func attachRecordQuery(_ query: CoffeeRecordQuery) {
        self.recordQuery = query
    }

    // MARK: - CoffeeInsightProvider protocol witness（SKIE completion handler 形式）

    /// `CoffeeStats` を受け取り、Foundation Models で要約を生成して completion に返す。
    ///
    /// SKIE は protocol 実装側で `suspend fun` の async 版（`summarize(stats:) async throws`）を
    /// extension として生成する。そのため実装側は `__` プレフィックス付きのシグネチャを使う
    /// （`RemoteCoffeeDataSourceIosImpl` の `__upload` / `__remove` と同じパターン）。
    ///
    /// - Parameter stats: 集計済みの `CoffeeStats`。LLM に渡す唯一の入力
    /// - Parameter completionHandler: 成功時 `(insight, nil)`、失敗時 `(nil, error)`
    func __summarize(
        stats: CoffeeStats,
        completionHandler: @escaping @Sendable (CoffeeInsight?, (any Error)?) -> Void
    ) {
        // Swift Concurrency 上で LLM 呼び出しを行い、completion handler に変換する
        Task {
            do {
                let insight = try await self.generateInsight(from: stats)
                completionHandler(insight, nil)
            } catch {
                print("[CoffeeVision] Foundation Models generation failed: \(error)")
                completionHandler(nil, error)
            }
        }
    }

    /// ユーザーの質問に対して Foundation Models で回答を生成して completion に返す（Phase B-2）。
    ///
    /// `summarize` と同じ `__` プレフィックス付き protocol witness パターン。
    /// `LanguageModelSession` はリクエストごとに新規生成（ステートレス / 会話履歴なし）。
    /// 回答はプレーンテキスト（`@Generable` 不使用）で日本語 2〜4 文程度を返す。
    ///
    /// - Parameter question: ユーザーが入力した質問テキスト
    /// - Parameter stats: 集計済みの `CoffeeStats`。digest として LLM に渡す唯一の入力
    /// - Parameter completionHandler: 成功時 `(answer, nil)`、失敗時 `(nil, error)`
    func __answer(
        question: String,
        stats: CoffeeStats,
        completionHandler: @escaping @Sendable (String?, (any Error)?) -> Void
    ) {
        Task {
            do {
                let answer = try await self.generateAnswer(question: question, stats: stats)
                completionHandler(answer, nil)
            } catch {
                print("[CoffeeVision] Foundation Models Q&A failed: \(error)")
                completionHandler(nil, error)
            }
        }
    }

    // MARK: - Private: LLM 生成ロジック

    /// `CoffeeStats` を基に Foundation Models で回答を生成する（Q&A v2）。
    ///
    /// - `recordQuery` がアタッチ済みなら `SearchCoffeeRecordsTool` を登録した tool-calling セッションを使う
    /// - `recordQuery` が nil（アタッチ前 / 非対応）なら digest-only セッションにフォールバックする
    /// - digest（`CoffeeStats`）はどちらのモードでもプロンプトに含める（ハイブリッド）
    /// - `LanguageModelSession` はリクエストごとに生成（ステートレス）
    /// - グラウンディング制約を instructions に明示してハルシネーション抑制
    /// - 回答はプレーンテキスト（`@Generable` 不使用）
    private func generateAnswer(question: String, stats: CoffeeStats) async throws -> String {
        let digest = buildPrompt(from: stats)

        let instructions = """
        あなたはコーヒー記録アプリのアシスタントです。
        ユーザーからコーヒー記録の統計データ（digest）と、個別記録を検索する searchCoffeeRecords ツールが提供されます。

        【digest について必ず理解すること】
        digest はすべての記録の「上位集計の抜粋」です。よく行くカフェは上位数件だけ、よく飲む産地も上位数件だけが載っています。digest に名前が出てこないカフェ・店・産地・銘柄でも、記録は存在します。たとえば「フグレン」が digest に載っていなくても、フグレンの記録がある可能性は十分あります。digest に載っていないことは「記録がない」証拠にはなりません。

        以下のルールを厳守して質問に回答してください:

        1. 特定のカフェ名・店名・産地・銘柄・焙煎度・抽出方法・期間・月など固有の条件が質問に含まれる場合は、digest にその名前が載っているかどうかに関わらず、必ず searchCoffeeRecords を呼び出してから答える。「digest に載っていないから記録がない」と判断してはならない。
        2. 全体の傾向・統計（総杯数・平均評価・よく飲む産地・最多焙煎度など）は digest だけで答えてよい。
        3. 「記録からは見つかりませんでした」と答えてよいのは、searchCoffeeRecords を呼び出した結果が 0 件だったときだけ。ツールを呼ばずにこの表現を使ってはならない。
        4. digest とツール結果に含まれていない情報は推測・補完しない。事実だけを述べる。
        5. 数値の再計算はしない（提示された数値をそのまま引用する）。
        6. 日本語で 2〜4 文程度、簡潔かつ丁寧に答える。
        """

        let prompt = """
        \(digest)

        【質問】
        \(question)
        """

        if let rq = recordQuery {
            // tool-calling セッション（v2）
            var tools: [any Tool] = [SearchCoffeeRecordsTool(recordQuery: rq)]
            if let extractor = tasteExtractor {
                tools.append(SearchByTasteProfileTool(recordQuery: rq, extractor: extractor))
            }
            print("[CoffeeVision] generateAnswer: tool-calling セッション（ツール数=\(tools.count)）で応答します")
            let session = LanguageModelSession(
                tools: tools,
                instructions: instructions
            )
            let response = try await session.respond(to: prompt)
            return response.content
        } else {
            // digest-only セッション（v1 フォールバック：recordQuery 未アタッチ）
            print("[CoffeeVision] generateAnswer: digest-only セッション（recordQuery 未アタッチ）で応答します")
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        }
    }

    /// `CoffeeStats` を基に Foundation Models で要約を生成する。
    ///
    /// - 統計テキストを組み立て、LLM に入力する（計算は KMP 側で済んでいるため LLM に計算させない）
    /// - `@Generable` 構造体 `CoffeeInsightOutput` で構造化出力を受け取る
    /// - `LanguageModelSession` はリクエストごとに生成（会話コンテキスト不要なため）
    private func generateInsight(from stats: CoffeeStats) async throws -> CoffeeInsight {
        let prompt = buildPrompt(from: stats)

        let session = LanguageModelSession(
            instructions: """
            あなたはコーヒー愛好家の記録を温かく前向きに要約するアシスタントです。
            ユーザーのコーヒー記録の統計データを読んで、
            その人のコーヒーへの向き合い方や傾向を 2〜3 文で要約してください。
            headline は 15〜25 文字程度の端的なタイトル、
            body は 50〜100 文字程度の読みやすい日本語の文章にしてください。
            数値の再列挙はせず、傾向・個性・楽しみ方に焦点を当ててください。

            【好み信号を扱う際の必須ルール】
            ・好みの傾向セクションが含まれる場合、その内容は「やや」「傾向がある」等の弱い表現にとどめる。
            ・「好きだ」「間違いない」等の断定表現は使わない。
            ・サンプルが少ない旨の注記がある場合は、その旨を添えるか、その信号に言及しない。
            ・「その産地が好き」か「その産地を出す店が好き」かは判別できないため、断定しない。
            """
        )

        let response = try await session.respond(
            to: prompt,
            generating: CoffeeInsightOutput.self
        )

        return CoffeeInsight(
            headline: response.content.headline,
            body: response.content.body
        )
    }

    /// `CoffeeStats` をコンパクトな日本語テキストに整形する。
    ///
    /// LLM への入力として「集計済み事実」だけを渡す。
    /// 計算は KMP 側で完了しているため LLM に計算させない設計。
    ///
    /// ## 好み信号（`favoriteSignals`）の整形ルール
    ///
    /// - 非 null のシグナルだけを出力（null = 信号なし）
    /// - `CategoryStat.averageRating` は `KotlinDouble?` のため、必ず `.doubleValue` 経由で整形する
    ///   （直接 `String(format:)` に渡すと 0.0 になる — lessons.md 2026-06-21 参照）
    /// - `TastingAxisCorrelation.correlation` は native `Double` なので直接渡してよい
    /// - 件数が少ない場合に「サンプルが少ない」注記をプロンプトに含め、LLM が断定しないよう促す
    private func buildPrompt(from stats: CoffeeStats) -> String {
        var lines: [String] = []

        // 基本統計
        lines.append("【コーヒー記録の概要】")
        lines.append("・総杯数: \(stats.totalCount) 杯")
        if let avg = stats.averageRating {
            lines.append(String(format: "・平均評価: %.1f 点（5 点満点）", avg.doubleValue))
        }

        // 産地トップ（SKIE により [CategoryStat] として型付けされている）
        let topOrigins = stats.originRanking.prefix(3)
        if !topOrigins.isEmpty {
            let originNames = topOrigins.map { $0.label }.joined(separator: "、")
            lines.append("・よく飲む産地: \(originNames)")
        }

        // 焙煎度傾向
        let roastLevels = stats.byRoastLevel
        if let topRoast = roastLevels.max(by: { $0.count < $1.count }) {
            lines.append("・最多焙煎度: \(localizedRoastLevel(topRoast.label))（\(topRoast.count) 杯）")
        }

        // 抽出方法傾向
        let brewMethods = stats.byBrewMethod
        if let topBrew = brewMethods.max(by: { $0.count < $1.count }) {
            lines.append("・最多抽出方法: \(localizedBrewMethod(topBrew.label))（\(topBrew.count) 杯）")
        }

        // よく行く店
        let topCafes = stats.topCafes.prefix(3)
        if !topCafes.isEmpty {
            let cafeNames = topCafes.map { $0.name }.joined(separator: "、")
            lines.append("・よく行くカフェ: \(cafeNames)")
        }

        // 直近のハイライト（高評価記録）
        let highlights = stats.recentHighlights.prefix(3)
        if !highlights.isEmpty {
            let highlightTexts = highlights.compactMap { digest -> String? in
                var parts = [digest.name]
                if let cafeName = digest.cafeName {
                    parts.append("(\(cafeName))")
                }
                return parts.joined(separator: " ")
            }.joined(separator: "、")
            lines.append("・最近の高評価コーヒー: \(highlightTexts)")
        }

        // テイスティング平均（all-or-nothing なので ratedCount > 0 なら 5 要素すべて揃っている）
        let avgs = stats.tastingAverages
        let ratedCount = avgs.ratedCount
        if ratedCount > 0 {
            let tastingParts: [String] = [
                avgs.sweetness.map { String(format: "甘味 %.1f", $0.doubleValue) },
                avgs.body.map { String(format: "ボディ %.1f", $0.doubleValue) },
                avgs.acidity.map { String(format: "酸味 %.1f", $0.doubleValue) },
                avgs.flavor.map { String(format: "風味 %.1f", $0.doubleValue) },
                avgs.aftertaste.map { String(format: "後味 %.1f", $0.doubleValue) },
            ].compactMap { $0 }
            if !tastingParts.isEmpty {
                lines.append("・テイスティング平均（1〜10、\(ratedCount)件）: \(tastingParts.joined(separator: "、"))")
            }
        }

        // 好み信号（階層2）— 弱い傾向としてプロンプトに含める
        // 断定させないよう「参考・確定ではない」「交絡の可能性あり」を明示する
        let signals = stats.favoriteSignals
        let signalLines = buildFavoriteSignalsPromptLines(signals)
        if !signalLines.isEmpty {
            lines.append("")
            lines.append("【好みの傾向（参考・確定ではない弱い信号）】")
            lines.append("※ 以下は統計的な傾向の参考値です。件数が少ない場合は信頼性が低く、")
            lines.append("  「その産地が好き」か「その産地を出す店が好き」かは判別できない交絡があります。")
            lines.append("  言語化する際は「やや」「傾向がある」等の弱い表現にとどめ、断定しないでください。")
            lines.append(contentsOf: signalLines)
        }

        lines.append("")
        lines.append("上記の記録を踏まえ、このコーヒー愛好家の傾向を要約してください。")

        return lines.joined(separator: "\n")
    }

    /// `FavoriteSignals` の各シグナルをプロンプト行に整形して返す。
    ///
    /// null のシグナルは出力しない。
    /// `CategoryStat.averageRating` は `KotlinDouble?` のため `.doubleValue` 経由で整形する。
    /// `TastingAxisCorrelation.correlation` は native `Double` のため直接渡す。
    private func buildFavoriteSignalsPromptLines(_ signals: FavoriteSignals) -> [String] {
        var lines: [String] = []

        if let origin = signals.bestOrigin {
            var line = "・産地: \(origin.label)（\(origin.count) 件"
            if let avg = origin.averageRating {
                line += String(format: "・平均 %.1f", avg.doubleValue)
            }
            line += "）がやや高評価の傾向"
            if origin.count < 5 {
                line += "（サンプル少・参考程度）"
            }
            lines.append(line)
        }

        if let roast = signals.bestRoastLevel {
            var line = "・焙煎度: \(localizedRoastLevel(roast.label))（\(roast.count) 件"
            if let avg = roast.averageRating {
                line += String(format: "・平均 %.1f", avg.doubleValue)
            }
            line += "）がやや高評価の傾向"
            if roast.count < 5 {
                line += "（サンプル少・参考程度）"
            }
            lines.append(line)
        }

        if let brew = signals.bestBrewMethod {
            var line = "・抽出方法: \(localizedBrewMethod(brew.label))（\(brew.count) 件"
            if let avg = brew.averageRating {
                line += String(format: "・平均 %.1f", avg.doubleValue)
            }
            line += "）がやや高評価の傾向"
            if brew.count < 5 {
                line += "（サンプル少・参考程度）"
            }
            lines.append(line)
        }

        if let axis = signals.dominantTastingAxis {
            let axisName = localizedTastingAxis(axis.axis)
            let direction = axis.correlation > 0 ? "高いほど" : "低いほど"
            // correlation は native Double のため .doubleValue 不要
            let line = String(
                format: "・テイスティングでは「%@」が%@高評価の傾向（相関 r=%.2f・%d 件）",
                axisName,
                direction,
                axis.correlation,
                axis.sampleSize
            )
            lines.append(line)
        }

        return lines
    }

    // MARK: - ローカライズヘルパ（AnalysisView と同等）

    /// `TastingAxis`（SKIE `@frozen enum`）を日本語ラベルに変換する。
    ///
    /// Blue Bottle「Elements of Coffee Tasting」の 5 軸に対応。
    /// SKIE EnumInterop により case 名は camelCase（`.sweetness` / `.body` 等）。
    private func localizedTastingAxis(_ axis: TastingAxis) -> String {
        switch axis {
        case .sweetness:   return "甘味"
        case .body:        return "ボディ"
        case .acidity:     return "酸味"
        case .flavor:      return "風味"
        case .aftertaste:  return "後味"
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
}

// MARK: - @Generable 構造化出力型

/// Foundation Models に生成させるコーヒー要約の構造体。
///
/// `@Generable` マクロにより LLM への schema が自動生成される。
/// `@Guide` でフィールドごとの説明と長さ制約をモデルに伝える。
@Generable
private struct CoffeeInsightOutput {
    /// 要約のタイトル（15〜25 文字程度）。コーヒーへの向き合い方を端的に表す。
    @Guide(description: "このユーザーのコーヒーへの向き合い方や個性を表す 15〜25 文字程度のタイトル")
    var headline: String

    /// 要約の本文（50〜100 文字程度）。傾向や楽しみ方を温かく前向きに描写する。
    @Guide(description: "このユーザーのコーヒーの傾向・楽しみ方を 50〜100 文字程度の日本語で描写した文章")
    var body: String
}
