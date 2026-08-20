import Charts
import SharedLogic
import SwiftUI

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
                // 好み信号カード（階層2）
                let signals = stats.favoriteSignals
                let hasAnySignal = signals.bestOrigin != nil
                    || signals.bestRoastLevel != nil
                    || signals.bestBrewMethod != nil
                    || signals.bestProcessing != nil
                    || signals.dominantTastingAxis != nil
                if hasAnySignal {
                    FavoriteSignalsCard(signals: signals)
                }

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
                            stats.averageRating.map { String(format: "%.1f", $0.doubleValue) } ?? "—",
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

                // テイスティング平均
                previewTastingSection(stats: stats)

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

    @ViewBuilder
    private func previewTastingSection(stats: CoffeeStats) -> some View {
        let avgs = stats.tastingAverages
        if avgs.ratedCount > 0,
           let sweetness = avgs.sweetness?.doubleValue,
           let body = avgs.body?.doubleValue,
           let acidity = avgs.acidity?.doubleValue,
           let flavor = avgs.flavor?.doubleValue,
           let aftertaste = avgs.aftertaste?.doubleValue {
            VStack(alignment: .leading, spacing: 8) {
                Text("テイスティング平均（強度 1〜10）").font(.headline)
                previewTastingChart(data: [
                    ("甘味", sweetness),
                    ("ボディ", body),
                    ("酸味", acidity),
                    ("風味", flavor),
                    ("後味", aftertaste),
                ])
            }
        }
    }

    @ViewBuilder
    private func previewTastingChart(data: [(String, Double)]) -> some View {
        Chart(data, id: \.0) { item in
            BarMark(
                x: .value("強度", item.1),
                y: .value("要素", item.0)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXScale(domain: 0...10)
        .frame(height: 200)
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

// MARK: - 好みカード単体プレビュー

#Preview("好みカード - シグナルあり") {
    ScrollView {
        VStack(spacing: 16) {
            FavoriteSignalsCard(signals: PreviewSamples.sampleCoffeeStats.favoriteSignals)
        }
        .padding(16)
    }
}

#Preview("好みカード - 産地のみ") {
    ScrollView {
        FavoriteSignalsCard(signals: FavoriteSignals(
            bestBrewMethod: nil,
            bestOrigin: CategoryStat(label: "エチオピア", count: 3, averageRating: KotlinDouble(value: 4.5)),
            bestRoastLevel: nil,
            bestProcessing: nil,
            dominantTastingAxis: nil,
            minSampleSize: 3
        ))
        .padding(16)
    }
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
