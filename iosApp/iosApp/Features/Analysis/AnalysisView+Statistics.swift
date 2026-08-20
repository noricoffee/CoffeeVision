import Charts
import SharedLogic
import SwiftUI

// MARK: - AnalysisView 統計チャートセクション

extension AnalysisView {

    // MARK: - サマリ数値セクション

    func summarySection(stats: CoffeeStats) -> some View {
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
                    value: stats.averageRating.map { String(format: "%.1f", $0.doubleValue) } ?? "—",
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

    func ratingHistogramSection(stats: CoffeeStats) -> some View {
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

    // MARK: - テイスティング平均

    /// テイスティング 5 要素の平均を棒グラフで表示するセクション。
    ///
    /// 1 件も設定のない要素（nil）はグラフに含めない。
    /// 全要素 nil なら（記録なし）セクション自体を非表示にする。
    func tastingAveragesSection(stats: CoffeeStats) -> some View {
        let avgs = stats.tastingAverages
        let ratedCount = avgs.ratedCount

        // all-or-nothing のため 5 要素は同一件数。件数 0 ならセクション非表示
        guard ratedCount > 0,
              let sweetness = avgs.sweetness?.doubleValue,
              let body = avgs.body?.doubleValue,
              let acidity = avgs.acidity?.doubleValue,
              let flavor = avgs.flavor?.doubleValue,
              let aftertaste = avgs.aftertaste?.doubleValue
        else { return AnyView(EmptyView()) }

        let axes: [RadarChartAxis] = [
            RadarChartAxis(
                id: "甘味", label: String(localized: "甘味"), value: sweetness,
                accessibilityLabel: tastingAccessibilityLabel(String(localized: "甘味"), avg: sweetness, count: ratedCount)
            ),
            RadarChartAxis(
                id: "ボディ", label: String(localized: "ボディ"), value: body,
                accessibilityLabel: tastingAccessibilityLabel(String(localized: "ボディ"), avg: body, count: ratedCount)
            ),
            RadarChartAxis(
                id: "酸味", label: String(localized: "酸味"), value: acidity,
                accessibilityLabel: tastingAccessibilityLabel(String(localized: "酸味"), avg: acidity, count: ratedCount)
            ),
            RadarChartAxis(
                id: "風味", label: String(localized: "風味"), value: flavor,
                accessibilityLabel: tastingAccessibilityLabel(String(localized: "風味"), avg: flavor, count: ratedCount)
            ),
            RadarChartAxis(
                id: "後味", label: String(localized: "後味"), value: aftertaste,
                accessibilityLabel: tastingAccessibilityLabel(String(localized: "後味"), avg: aftertaste, count: ratedCount)
            ),
        ]

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "テイスティング平均（強度 1〜10）"))
                TastingRadarChart(axes: axes, maxValue: 10)
            }
        )
    }

    private func tastingAccessibilityLabel(_ label: String, avg: Double, count: Int32) -> String {
        String(format: "%@ 平均 %.1f（%d 件）", label, avg, count)
    }

    // MARK: - 産地ランキング

    func originRankingSection(stats: CoffeeStats) -> some View {
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
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0.doubleValue) } ?? "")
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

    /// 焙煎順（浅 → 深）に固定した `RoastLevel` 1 段階分のグラフ用アイテム。
    ///
    /// `stats.byRoastLevel`（KMP 側は件数降順の契約。この契約自体は変更しない）を
    /// 焙煎順にマージし、記録が 0 件の段階も欠かさず保持する。
    private struct RoastLevelBarItem: Identifiable {
        let id: String  // label（Kotlin RoastLevel.name）
        let label: String
        let position: Int  // 0（Light）〜7（Italian）
        let count: Int
        let averageRating: Double?
    }

    /// Kotlin `RoastLevel`（`shared/domain/.../RoastLevel.kt`）の焙煎順固定配列。
    private static let roastLevelOrder: [String] = [
        "Light", "Cinnamon", "Medium", "High", "City", "FullCity", "French", "Italian",
    ]

    /// `stats.byRoastLevel` を焙煎順の全 8 段階にマージする。欠けている段階は count 0 で補完する。
    private func fullRoastLevelStats(_ stats: CoffeeStats) -> [RoastLevelBarItem] {
        let byLabel = Dictionary(uniqueKeysWithValues: stats.byRoastLevel.map { ($0.label, $0) })
        return Self.roastLevelOrder.enumerated().map { position, label in
            let stat = byLabel[label]
            return RoastLevelBarItem(
                id: label,
                label: label,
                position: position,
                count: Int(stat?.count ?? 0),
                averageRating: stat?.averageRating?.doubleValue
            )
        }
    }

    /// 焙煎順の位置（0〜7）から浅→深のブラウンランプ色を算出する。
    ///
    /// `Color.accentColor`（コーヒーブラウン）を基準に、最も浅い段は白へ、
    /// 最も深い段は黒へ寄せた 2 色を両端とし、8 段階を線形補間する。
    private func roastLevelColor(at position: Int) -> Color {
        let lightest = Color.accentColor.mix(with: .white, by: 0.55)
        let darkest = Color.accentColor.mix(with: .black, by: 0.45)
        let t = Double(position) / Double(Self.roastLevelOrder.count - 1)
        return lightest.mix(with: darkest, by: t)
    }

    private func roastLevelAccessibilityLabel(_ item: RoastLevelBarItem) -> String {
        let name = RoastLevel.localizedLabel(forName: item.label)
        guard item.count > 0 else {
            return String(localized: "\(name): 記録なし")
        }
        var label = "\(name): \(item.count) 件"
        if let avg = item.averageRating {
            label += String(format: "（平均 %.1f 点）", avg)
        }
        return label
    }

    func roastLevelSection(stats: CoffeeStats) -> some View {
        guard !stats.byRoastLevel.isEmpty else { return AnyView(EmptyView()) }
        let items = fullRoastLevelStats(stats)
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "焙煎度の内訳（浅 → 深）"))
                Chart(items) { item in
                    BarMark(
                        x: .value(String(localized: "件数"), item.count),
                        y: .value(String(localized: "焙煎度"), RoastLevel.localizedLabel(forName: item.label))
                    )
                    .foregroundStyle(roastLevelColor(at: item.position))
                    .accessibilityLabel(roastLevelAccessibilityLabel(item))
                }
                .chartYScale(domain: Self.roastLevelOrder.map { RoastLevel.localizedLabel(forName: $0) })
                .frame(height: CGFloat(Self.roastLevelOrder.count) * 32)
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
                .accessibilityLabel(String(localized: "焙煎度の内訳グラフ（浅い順）"))
            }
        )
    }

    // MARK: - 抽出方法分布

    func brewMethodSection(stats: CoffeeStats) -> some View {
        guard !stats.byBrewMethod.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "抽出方法の内訳"))
                Chart(stats.byBrewMethod, id: \.label) { item in
                    BarMark(
                        x: .value(String(localized: "件数"), item.count),
                        y: .value(String(localized: "抽出方法"), BrewMethod.localizedLabel(forName: item.label))
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        "\(BrewMethod.localizedLabel(forName: item.label)): \(item.count) 件"
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0.doubleValue) } ?? "")
                    )
                }
                .frame(height: CGFloat(stats.byBrewMethod.count) * 32)
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
                .accessibilityLabel(String(localized: "抽出方法の内訳グラフ"))
            }
        )
    }

    // MARK: - 月次推移

    func monthlyTrendSection(stats: CoffeeStats) -> some View {
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
                        + (item.averageRating.map { String(format: "（平均 %.1f 点）", $0.doubleValue) } ?? "")
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

    func topCafesSection(stats: CoffeeStats) -> some View {
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
                        Text(String(format: "%.1f", avg.doubleValue))
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
            label += String(format: " 平均評価 %.1f 点", avg.doubleValue)
        }
        return label
    }
}
