import Charts
import SharedLogic
import SwiftUI

// MARK: - Identifiable 拡張

extension CoffeeStats: @retroactive Identifiable {
    public var id: Int32 { totalCount }
}

// MARK: - AnalysisView

/// 分析タブのルートビュー。
///
/// 階層1（記述統計）を Swift Charts で可視化する:
/// - サマリ数値（総杯数 / 評価済み件数 / 平均評価）
/// - 評価ヒストグラム（棒グラフ）
/// - 産地分布（横向き棒グラフ、上位 10 件）
/// - 焙煎度分布（棒グラフ）
/// - 抽出方法分布（棒グラフ）
/// - 月次推移（折れ線グラフ）
/// - よく行く店（リスト）
///
/// 階層3（Foundation Models 要約）は A-4 以降で追加する。A-3 では描画しない。
@MainActor
struct AnalysisView: View {

    var viewModel: AnalysisViewModelBridge
    var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let stats = viewModel.stats, stats.totalCount > 0 {
                    statisticsScrollView(stats: stats)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle(String(localized: "分析"))
            .navigationBarTitleDisplayMode(.large)
        }
        .errorToast(message: viewModel.error) {
            viewModel.onErrorDismissed()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView()
            .accessibilityLabel(String(localized: "統計データを読み込み中"))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(String(localized: "記録がまだありません"), systemImage: "chart.bar")
        } description: {
            Text(String(localized: "コーヒーを記録すると、産地・焙煎度・抽出方法などの傾向が分析されます。"))
        } actions: {
            Text(String(localized: "「コーヒー」タブからコーヒーを記録してみましょう。"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Statistics Scroll View

    private func statisticsScrollView(stats: CoffeeStats) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                insightCardSection
                summarySection(stats: stats)
                ratingHistogramSection(stats: stats)
                originRankingSection(stats: stats)
                roastLevelSection(stats: stats)
                brewMethodSection(stats: stats)
                monthlyTrendSection(stats: stats)
                topCafesSection(stats: stats)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 傾向要約カード（階層3）

    /// Foundation Models によるコーヒー傾向要約カード。
    ///
    /// `insightStatus` に応じて表示を切り替える:
    /// - `Unsupported`: カード自体を非表示（Apple Intelligence 非対応 / 無効端末）
    /// - `Idle` / `Loading`: ローディング表示（生成中）
    /// - `Loaded`: `insight.headline` + `insight.body` を表示
    /// - `Failed`: 控えめなエラー表示 + リトライボタン
    @ViewBuilder
    private var insightCardSection: some View {
        let status = viewModel.insightStatus
        if status is AnalysisViewModelInsightStatusUnsupported {
            // 非対応端末 / Apple Intelligence 無効: カードを出さない
            EmptyView()
        } else if status is AnalysisViewModelInsightStatusLoading
                    || status is AnalysisViewModelInsightStatusIdle {
            InsightLoadingCard()
        } else if status is AnalysisViewModelInsightStatusLoaded,
                  let insight = viewModel.insight {
            InsightLoadedCard(headline: insight.headline, insightBody: insight.body)
        } else if status is AnalysisViewModelInsightStatusFailed {
            InsightFailedCard {
                viewModel.onRetryInsight()
            }
        }
    }

    // MARK: - サマリ数値セクション

    private func summarySection(stats: CoffeeStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "サマリ"))
            HStack(spacing: 0) {
                summaryCard(
                    title: String(localized: "総杯数"),
                    value: "\(stats.totalCount)",
                    unit: String(localized: "杯"),
                    systemImage: "cup.and.saucer"
                )
                Divider()
                    .frame(height: 56)
                summaryCard(
                    title: String(localized: "評価済み"),
                    value: "\(stats.ratedCount)",
                    unit: String(localized: "件"),
                    systemImage: "star"
                )
                Divider()
                    .frame(height: 56)
                summaryCard(
                    title: String(localized: "平均評価"),
                    value: stats.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    unit: stats.averageRating != nil ? String(localized: "点") : "",
                    systemImage: "star.fill"
                )
            }
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
        }
    }

    private func summaryCard(title: String, value: String, unit: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(title): \(value)\(unit)")
    }

    // MARK: - 評価ヒストグラム

    private func ratingHistogramSection(stats: CoffeeStats) -> some View {
        guard !stats.ratingHistogram.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "評価の分布"))
                Chart(stats.ratingHistogram, id: \.rating) { bucket in
                    BarMark(
                        x: .value(String(localized: "評価"), formattedRating(bucket.rating)),
                        y: .value(String(localized: "件数"), bucket.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(String(localized: "評価 \(formattedRating(bucket.rating)) 点: \(bucket.count) 件"))
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel(String(localized: "評価の分布グラフ"))
            }
        )
    }

    // MARK: - 産地ランキング

    private func originRankingSection(stats: CoffeeStats) -> some View {
        guard !stats.originRanking.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "産地の内訳（上位 \(stats.originRanking.count) 件）"))
                Chart(stats.originRanking, id: \.label) { item in
                    BarMark(
                        x: .value(String(localized: "件数"), item.count),
                        y: .value(String(localized: "産地"), item.label)
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        "\(item.label): \(item.count) 件"
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0) } ?? "")
                    )
                }
                .frame(height: max(120, CGFloat(stats.originRanking.count) * 32))
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel(String(localized: "産地の内訳グラフ"))
            }
        )
    }

    // MARK: - 焙煎度分布

    private func roastLevelSection(stats: CoffeeStats) -> some View {
        guard !stats.byRoastLevel.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "焙煎度の内訳"))
                Chart(stats.byRoastLevel, id: \.label) { item in
                    BarMark(
                        x: .value(String(localized: "焙煎度"), localizedRoastLevel(item.label)),
                        y: .value(String(localized: "件数"), item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        "\(localizedRoastLevel(item.label)): \(item.count) 件"
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0) } ?? "")
                    )
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel(String(localized: "焙煎度の内訳グラフ"))
            }
        )
    }

    // MARK: - 抽出方法分布

    private func brewMethodSection(stats: CoffeeStats) -> some View {
        guard !stats.byBrewMethod.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "抽出方法の内訳"))
                Chart(stats.byBrewMethod, id: \.label) { item in
                    BarMark(
                        x: .value(String(localized: "抽出方法"), localizedBrewMethod(item.label)),
                        y: .value(String(localized: "件数"), item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        "\(localizedBrewMethod(item.label)): \(item.count) 件"
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0) } ?? "")
                    )
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel(String(localized: "抽出方法の内訳グラフ"))
            }
        )
    }

    // MARK: - 月次推移

    private func monthlyTrendSection(stats: CoffeeStats) -> some View {
        guard !stats.monthlyTrend.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "月別の記録数"))
                Chart(stats.monthlyTrend, id: \.yearMonth) { item in
                    LineMark(
                        x: .value(String(localized: "月"), item.yearMonth),
                        y: .value(String(localized: "件数"), item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbol(.circle)
                    .accessibilityLabel(
                        "\(item.yearMonth): \(item.count) 件"
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0) } ?? "")
                    )
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 1)) { _ in
                        AxisValueLabel(orientation: .verticalReversed)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel(String(localized: "月別の記録数グラフ"))
            }
        )
    }

    // MARK: - よく行く店

    private func topCafesSection(stats: CoffeeStats) -> some View {
        guard !stats.topCafes.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "よく行くカフェ（上位 \(stats.topCafes.count) 件）"))
                VStack(spacing: 0) {
                    ForEach(Array(stats.topCafes.enumerated()), id: \.element.placeId) { index, cafe in
                        CafeStatRow(rank: index + 1, cafeStat: cafe)
                        if index < stats.topCafes.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        )
    }

    // MARK: - ヘルパ

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func formattedRating(_ rating: Double) -> String {
        rating == Double(Int(rating)) ? String(format: "%.0f", rating) : String(format: "%.1f", rating)
    }

    /// Kotlin の `RoastLevel.name` を日本語に変換する。
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

    /// Kotlin の `BrewMethod.name` を日本語に変換する。
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

// MARK: - InsightLoadingCard

/// 要約生成中（`Idle` / `Loading` 状態）に表示するカード。
private struct InsightLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(localized: "あなたの傾向"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(String(localized: "傾向を分析中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(String(localized: "傾向を分析中"))
    }
}

// MARK: - InsightLoadedCard

/// 要約生成完了（`Loaded` 状態）に表示するカード。
private struct InsightLoadedCard: View {
    let headline: String
    let insightBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "あなたの傾向"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            Text(headline)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(insightBody)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "あなたの傾向: \(headline)。\(insightBody)"))
    }
}

// MARK: - InsightFailedCard

/// 要約生成失敗（`Failed` 状態）に表示するカード。
private struct InsightFailedCard: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(localized: "あなたの傾向"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(String(localized: "傾向の分析に失敗しました"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "再試行"), action: onRetry)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "傾向の分析を再試行"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - CafeStatRow

/// よく行くカフェの 1 行表示コンポーネント。
private struct CafeStatRow: View {

    let rank: Int
    let cafeStat: CafeStat

    var body: some View {
        HStack(spacing: 12) {
            // ランク番号
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(cafeStat.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("\(cafeStat.count) 杯")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let avg = cafeStat.averageRating {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                        Text(String(format: "%.1f", avg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildCafeStatAccessibilityLabel())
    }

    private func buildCafeStatAccessibilityLabel() -> String {
        var label = "\(rank)位 \(cafeStat.name) \(cafeStat.count)杯"
        if let avg = cafeStat.averageRating {
            label += String(format: " 平均評価 %.1f 点", avg)
        }
        return label
    }
}

// MARK: - Preview Support

#if DEBUG

/// Preview 用の分析ビューデモ（Bridge 非依存）。
///
/// `AnalysisViewModelBridge` を直接使わず、`CoffeeStats` をプレビュー用に
/// 注入した同等構造ビューでプレビューを実現する。
@MainActor
private struct AnalysisViewPreviewContent: View {

    let stats: CoffeeStats?
    let isLoading: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let stats, stats.totalCount > 0 {
                    scrollContent(stats: stats)
                } else {
                    emptyState
                }
            }
            .navigationTitle(String(localized: "分析"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func scrollContent(stats: CoffeeStats) -> some View {
        // AnalysisView のスクロールコンテンツを直接再現するのではなく
        // AnalysisView 相当のビューを活用するためのシンプルなラッパ
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // サマリカード
                VStack(alignment: .leading, spacing: 8) {
                    Text("サマリ").font(.headline)
                    HStack(spacing: 0) {
                        summaryCard("総杯数", "\(stats.totalCount)", "杯")
                        Divider().frame(height: 56)
                        summaryCard("評価済み", "\(stats.ratedCount)", "件")
                        Divider().frame(height: 56)
                        summaryCard(
                            "平均評価",
                            stats.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                            stats.averageRating != nil ? "点" : ""
                        )
                    }
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                // 評価ヒストグラム
                if !stats.ratingHistogram.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("評価の分布").font(.headline)
                        Chart(stats.ratingHistogram, id: \.rating) { bucket in
                            BarMark(
                                x: .value("評価", ratingLabel(bucket.rating)),
                                y: .value("件数", bucket.count)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        .frame(height: 160)
                    }
                }

                // 月次推移
                if !stats.monthlyTrend.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("月別の記録数").font(.headline)
                        Chart(stats.monthlyTrend, id: \.yearMonth) { item in
                            LineMark(
                                x: .value("月", item.yearMonth),
                                y: .value("件数", item.count)
                            )
                            .symbol(.circle)
                            .foregroundStyle(Color.accentColor)
                        }
                        .frame(height: 160)
                    }
                }
            }
            .padding(16)
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ratingLabel(_ rating: Double) -> String {
        rating == Double(Int(rating)) ? String(format: "%.0f", rating) : String(format: "%.1f", rating)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("記録がまだありません", systemImage: "chart.bar")
        } description: {
            Text("コーヒーを記録すると、産地・焙煎度・抽出方法などの傾向が分析されます。")
        }
    }
}

#Preview("統計あり") {
    AnalysisViewPreviewContent(
        stats: PreviewSamples.sampleCoffeeStats,
        isLoading: false
    )
}

#Preview("空状態") {
    AnalysisViewPreviewContent(
        stats: nil,
        isLoading: false
    )
}

#Preview("ローディング中") {
    AnalysisViewPreviewContent(
        stats: nil,
        isLoading: true
    )
}

// MARK: - 要約カード単体プレビュー

#Preview("要約カード - Loaded") {
    VStack(spacing: 16) {
        InsightLoadedCard(
            headline: "深煎り好きのカフェ探求者",
            insightBody: "シティロースト以上を好み、全国各地のスペシャルティカフェを積極的に訪れています。ハンドドリップへの深い愛情が記録から伝わります。"
        )
        InsightLoadingCard()
        InsightFailedCard { }
    }
    .padding(16)
}

#Preview("要約カード - Loading") {
    InsightLoadingCard()
        .padding(16)
}

#endif
