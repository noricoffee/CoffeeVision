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
                qaSection
                readinessProgressSection
                favoriteSignalsSection(stats: stats)
                preferredBeanTraitsSection(stats: stats)
                unexploredBeanSuggestionsSection(stats: stats)
                summarySection(stats: stats)
                ratingHistogramSection(stats: stats)
                tastingAveragesSection(stats: stats)
                originRankingSection(stats: stats)
                roastLevelSection(stats: stats)
                brewMethodSection(stats: stats)
                monthlyTrendSection(stats: stats)
                topCafesSection(stats: stats)
                tasteSearchSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 好みで記録を探す 導線

    /// Foundation Models 非対応端末では表示しない。
    ///
    /// `TastePreferenceExtractor.makeIfAvailable()` でデバイスの Foundation Models 可否を確認し、
    /// 利用可能なときだけ `TastePreferenceConversionView` へのナビゲーション導線を表示する。
    @ViewBuilder
    private var tasteSearchSection: some View {
        if TastePreferenceExtractor.makeIfAvailable() != nil {
            NavigationLink {
                TastePreferenceConversionView(coffeeRecordQuery: appState.container.coffeeRecordQuery)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "好みで記録を探す"))
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(String(localized: "感想 → 5軸ベクトルで類似記録を検索"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "好みで記録を探す画面を開く"))
            .accessibilityHint(String(localized: "感想テキストから5軸好みベクトルを抽出し、類似するテイスティング記録を検索します"))
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

    // MARK: - 対話 Q&A セクション（Phase B-2）

    /// 対話 Q&A セクション。
    ///
    /// `qaStatus is Unsupported` の端末（Apple Intelligence 非対応 / 無効）では非表示。
    /// 対応端末では入力欄 + 候補チップ + 回答カードを表示する。
    @ViewBuilder
    private var qaSection: some View {
        let status = viewModel.qaStatus
        if status is AnalysisViewModelQaStatusUnsupported {
            EmptyView()
        } else {
            QaSectionContainer(viewModel: viewModel, qaStatus: status)
        }
    }

    // MARK: - 好み信号カード（階層2）

    /// 好み信号（`FavoriteSignals`）を表示するカード。
    ///
    /// `bestOrigin` / `bestRoastLevel` / `bestBrewMethod` / `dominantTastingAxis` の
    /// いずれか 1 つ以上が非 null のときのみ表示する。全 null なら `EmptyView()`。
    ///
    /// ## 表示ルール
    /// - 断定 UI にしない：「やや」「参考」「傾向」等の弱い表現のみ使用
    /// - 件数を必ず併記してサンプルサイズを明示する
    /// - 交絡（「産地が好き」か「店が好き」か）は判別不能のため断定しない旨を注記
    @ViewBuilder
    private func favoriteSignalsSection(stats: CoffeeStats) -> some View {
        // 表示条件は KMP 導出の `readiness.hasAnySignal` に一本化する（単一ソース化・15-D）。
        // 従来はここで stats.favoriteSignals の 4 フィールドから再計算しており、
        // readinessProgressSection（非表示条件）との二重定義で将来の乖離リスクがあった。
        // stats != nil の分岐内でのみ到達するため readiness も必ず導出済み。
        if let readiness = viewModel.readiness, readiness.hasAnySignal {
            FavoriteSignalsCard(signals: stats.favoriteSignals)
        }
    }

    // MARK: - 空状態プログレスセクション（要件 9-7）

    /// 傾向信号がまだ出ていないときに、傾向分析が始まるまでの目安を表示するカード。
    ///
    /// 表示条件: `readiness` が非 nil かつ `hasAnySignal == false`。
    /// `totalCount == 0`（記録ゼロ）のときは `readiness` 自体が算出されても
    /// この画面には到達しない（`stats.totalCount > 0` の分岐でのみ `statisticsScrollView` が呼ばれるため）。
    /// 既に傾向信号が出ている（`hasAnySignal == true`）ときはバナーを出さない。
    @ViewBuilder
    private var readinessProgressSection: some View {
        if let readiness = viewModel.readiness, !readiness.hasAnySignal {
            AnalysisReadinessProgressCard(readiness: readiness)
        }
    }

    // MARK: - 好みの豆の傾向セクション（Phase 12-C）

    /// `CoffeeStats.preferredBeanTraits` を表示するセクション。
    ///
    /// 表示条件:
    /// - `stats.preferredBeanTraits` が non-nil
    /// - `dominantFlavorNotes` が非空 または `originHint` が non-nil
    ///
    /// `beanTraitsInsightStatus` に応じて表示を切り替える:
    /// - `Loaded` + insight non-nil: LLM インサイト（headline + body）を表示
    /// - `Loading`: ProgressView
    /// - `Idle` / `Failed` / `Unsupported`: フレーバータグ + サブラベルをフォールバック表示
    @ViewBuilder
    private func preferredBeanTraitsSection(stats: CoffeeStats) -> some View {
        if let traits = stats.preferredBeanTraits,
           !traits.dominantFlavorNotes.isEmpty || traits.originHint != nil {
            PreferredBeanTraitsCard(
                traits: traits,
                insightStatus: viewModel.beanTraitsInsightStatus,
                insight: viewModel.beanTraitsInsight
            )
        }
    }

    // MARK: - 未経験の豆への探索提案セクション（フェーズ 15-E-3 / 要件 9-8）

    /// `CoffeeStats.unexploredBeanSuggestions` を表示するセクション。
    ///
    /// 好み信号（`FavoriteSignals.bestOrigin`）に合致するが、ユーザーがまだ記録していない
    /// `BeanProfile` を提案する。9-5（既訪問店の再訪推薦）に対する新規開拓のナッジ。
    ///
    /// 表示条件: `unexploredBeanSuggestions` が非空のときのみ（BeanProfile 未投入 / 好み信号
    /// 未確定の端末では常に空配列のため、セクションごと非表示になる）。
    @ViewBuilder
    private func unexploredBeanSuggestionsSection(stats: CoffeeStats) -> some View {
        if !stats.unexploredBeanSuggestions.isEmpty {
            UnexploredBeanSuggestionsCard(suggestions: stats.unexploredBeanSuggestions)
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

    // MARK: - テイスティング平均

    /// テイスティング 5 要素の平均を棒グラフで表示するセクション。
    ///
    /// 1 件も設定のない要素（nil）はグラフに含めない。
    /// 全要素 nil なら（記録なし）セクション自体を非表示にする。
    private func tastingAveragesSection(stats: CoffeeStats) -> some View {
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
        let name = localizedRoastLevel(item.label)
        guard item.count > 0 else {
            return String(localized: "\(name): 記録なし")
        }
        var label = "\(name): \(item.count) 件"
        if let avg = item.averageRating {
            label += String(format: "（平均 %.1f 点）", avg)
        }
        return label
    }

    private func roastLevelSection(stats: CoffeeStats) -> some View {
        guard !stats.byRoastLevel.isEmpty else { return AnyView(EmptyView()) }
        let items = fullRoastLevelStats(stats)
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "焙煎度の内訳（浅 → 深）"))
                Chart(items) { item in
                    BarMark(
                        x: .value(String(localized: "件数"), item.count),
                        y: .value(String(localized: "焙煎度"), localizedRoastLevel(item.label))
                    )
                    .foregroundStyle(roastLevelColor(at: item.position))
                    .accessibilityLabel(roastLevelAccessibilityLabel(item))
                }
                .chartYScale(domain: Self.roastLevelOrder.map { localizedRoastLevel($0) })
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

    private func brewMethodSection(stats: CoffeeStats) -> some View {
        guard !stats.byBrewMethod.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(String(localized: "抽出方法の内訳"))
                Chart(stats.byBrewMethod, id: \.label) { item in
                    BarMark(
                        x: .value(String(localized: "件数"), item.count),
                        y: .value(String(localized: "抽出方法"), localizedBrewMethod(item.label))
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        "\(localizedBrewMethod(item.label)): \(item.count) 件"
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

    /// `TastingAxis`（SKIE `@frozen enum`）を日本語ラベルに変換する。
    ///
    /// Blue Bottle「Elements of Coffee Tasting」の 5 軸に対応。
    /// `@frozen enum` のため `default` は使わず全 case を網羅する。
    private func localizedTastingAxis(_ axis: TastingAxis) -> String {
        switch axis {
        case .sweetness:   return "甘味"
        case .body:        return "ボディ"
        case .acidity:     return "酸味"
        case .flavor:      return "風味"
        case .aftertaste:  return "後味"
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

// MARK: - QaSectionContainer

/// 対話 Q&A セクションのコンテナ。
///
/// `qaStatus` に応じて入力欄・候補チップ・回答カードを表示する。
/// `Unsupported` の判定は呼び出し側（`insightCardSection`）で行い、本コンポーネントには渡さない。
@MainActor
private struct QaSectionContainer: View {

    var viewModel: AnalysisViewModelBridge
    let qaStatus: any AnalysisViewModelQaStatus

    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダ
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "Q&A"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // 回答カード（Answered / Asking / Failed）
            if qaStatus is AnalysisViewModelQaStatusAnswered {
                if let question = viewModel.qaQuestion, let answer = viewModel.qaAnswer {
                    QaAnsweredCard(question: question, answer: answer) {
                        viewModel.onQaCleared()
                        inputText = ""
                    }
                }
            } else if qaStatus is AnalysisViewModelQaStatusAsking {
                QaAskingCard(question: viewModel.qaQuestion ?? "")
            } else if qaStatus is AnalysisViewModelQaStatusFailed {
                if let question = viewModel.qaQuestion {
                    QaFailedCard(question: question) {
                        viewModel.onQuestionAsked(question)
                    }
                }
            }

            // 候補チップ（Idle / Failed 時に表示）
            if qaStatus is AnalysisViewModelQaStatusIdle
                || qaStatus is AnalysisViewModelQaStatusFailed {
                QaSuggestedChips(
                    questions: viewModel.suggestedQuestions,
                    onSelected: { q in
                        inputText = ""
                        viewModel.onQuestionAsked(q)
                    }
                )
            }

            // 入力欄 + 送信ボタン（Idle / Answered / Failed 時に表示）
            if qaStatus is AnalysisViewModelQaStatusIdle
                || qaStatus is AnalysisViewModelQaStatusAnswered
                || qaStatus is AnalysisViewModelQaStatusFailed {
                QaInputRow(
                    text: $inputText,
                    onSubmit: {
                        let q = inputText
                        inputText = ""
                        viewModel.onQuestionAsked(q)
                    }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - QaAnsweredCard

/// 回答到着（`Answered` 状態）に表示するカード。
private struct QaAnsweredCard: View {
    let question: String
    let answer: String
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(question)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(String(localized: "Q&A をクリア"))
            }
            Text(answer)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "質問: \(question)。回答: \(answer)"))
    }
}

// MARK: - QaAskingCard

/// 回答生成中（`Asking` 状態）に表示するカード。
private struct QaAskingCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(String(localized: "回答を生成中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "質問: \(question)。回答を生成中"))
    }
}

// MARK: - QaFailedCard

/// 回答生成失敗（`Failed` 状態）に表示するカード。
private struct QaFailedCard: View {
    let question: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(String(localized: "回答の生成に失敗しました"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "再試行"), action: onRetry)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(String(localized: "回答の生成を再試行"))
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - QaSuggestedChips

/// 候補質問チップの横スクロール行。
private struct QaSuggestedChips: View {
    let questions: [String]
    let onSelected: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button(action: { onSelected(question) }) {
                        Text(question)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityLabel(String(localized: "候補: \(question)"))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "候補質問"))
    }
}

// MARK: - QaInputRow

/// 質問入力欄と送信ボタン。
private struct QaInputRow: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "気になることを質問してみよう"), text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSubmit()
                    }
                }
                .accessibilityLabel(String(localized: "質問入力欄"))

            Button(action: {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSubmit()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray4)
                            : Color.accentColor
                    )
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(String(localized: "質問を送信"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
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

// MARK: - FavoriteSignalsCard

/// 好み信号（`FavoriteSignals`）を表示するカード。
///
/// 断定 UI にしない設計：
/// - 「やや」「参考」「傾向」等の弱い表現のみ使用
/// - 件数を併記してサンプルサイズを明示
/// - 交絡（「産地が好き」か「店が好き」か）は判別不能のため注記表示
private struct FavoriteSignalsCard: View {

    let signals: FavoriteSignals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダ
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "好みの傾向（参考）"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // シグナル行
            VStack(alignment: .leading, spacing: 8) {
                if let origin = signals.bestOrigin {
                    FavoriteSignalRow(
                        systemImage: "globe",
                        label: "産地",
                        value: origin.label,
                        count: Int(origin.count),
                        averageRating: origin.averageRating?.doubleValue,
                        accessibilitySuffix: String(localized: "産地")
                    )
                }
                if let roast = signals.bestRoastLevel {
                    FavoriteSignalRow(
                        systemImage: "flame",
                        label: "焙煎度",
                        value: localizedRoastLevelStatic(roast.label),
                        count: Int(roast.count),
                        averageRating: roast.averageRating?.doubleValue,
                        accessibilitySuffix: String(localized: "焙煎度")
                    )
                }
                if let brew = signals.bestBrewMethod {
                    FavoriteSignalRow(
                        systemImage: "cup.and.saucer",
                        label: "抽出方法",
                        value: localizedBrewMethodStatic(brew.label),
                        count: Int(brew.count),
                        averageRating: brew.averageRating?.doubleValue,
                        accessibilitySuffix: String(localized: "抽出方法")
                    )
                }
                if let processing = signals.bestProcessing {
                    FavoriteSignalRow(
                        systemImage: "leaf.fill",
                        label: "精製方法",
                        value: localizedProcessingStatic(processing.label),
                        count: Int(processing.count),
                        averageRating: processing.averageRating?.doubleValue,
                        accessibilitySuffix: String(localized: "精製方法")
                    )
                }
                if let axis = signals.dominantTastingAxis {
                    TastingAxisSignalRow(axis: axis)
                }
            }

            // 注記（交絡の説明）
            Text(String(localized: "傾向はあくまで参考です。件数が少ない場合は信頼性が低く、「その産地が好き」か「その産地を出す店が好き」かは判別できません。"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "好みの傾向カード"))
    }

    // MARK: - 静的ローカライズヘルパ（struct のコンテキスト用）

    private func localizedRoastLevelStatic(_ name: String) -> String {
        switch name {
        case "Light":     return String(localized: "ライト")
        case "Cinnamon":  return String(localized: "シナモン")
        case "Medium":    return String(localized: "ミディアム")
        case "High":      return String(localized: "ハイ")
        case "City":      return String(localized: "シティ")
        case "FullCity":  return String(localized: "フルシティ")
        case "French":    return String(localized: "フレンチ")
        case "Italian":   return String(localized: "イタリアン")
        default:          return name
        }
    }

    private func localizedBrewMethodStatic(_ name: String) -> String {
        switch name {
        case "Espresso":    return String(localized: "エスプレッソ")
        case "HandDrip":    return String(localized: "ハンドドリップ")
        case "NelDrip":     return String(localized: "ネルドリップ")
        case "FrenchPress": return String(localized: "フレンチプレス")
        case "AeroPress":   return String(localized: "エアロプレス")
        case "Syphon":      return String(localized: "サイフォン")
        case "ColdBrew":    return String(localized: "コールドブリュー")
        case "Other":       return String(localized: "その他")
        default:            return name
        }
    }

    private func localizedProcessingStatic(_ name: String) -> String {
        switch name {
        case "Natural":   return String(localized: "ナチュラル")
        case "Washed":    return String(localized: "ウォッシュド")
        case "Honey":     return String(localized: "ハニー")
        case "Anaerobic": return String(localized: "アナエロビック")
        case "Other":     return String(localized: "その他")
        default:          return name
        }
    }
}

// MARK: - AnalysisReadinessProgressCard

/// 分析タブの空状態プログレスカード（要件 9-7）。
///
/// カテゴリ好み信号（産地 / 焙煎度 / 抽出方法）の必要件数までの進捗を主表示にする。
/// 件数が閾値に達しても z ゲート / 相関 floor（`data-model.md` §1.6）で信号が
/// 出ないことがあるため、「傾向分析が**始まる**」という約束しすぎない文言に留める。
///
/// テイスティング相関の必要件数（`correlationThreshold`）は任意の補足情報として
/// 小さく添える（主張しすぎない）。
private struct AnalysisReadinessProgressCard: View {

    let readiness: AnalysisViewModel.AnalysisReadiness

    /// カテゴリ track の残り件数（0 未満にはならない）。
    private var remainingForCategory: Int32 {
        max(0, readiness.categoryThreshold - readiness.ratedCount)
    }

    /// カテゴリ track の進捗（0.0〜1.0）。
    private var categoryProgress: Double {
        guard readiness.categoryThreshold > 0 else { return 1.0 }
        return min(1.0, Double(readiness.ratedCount) / Double(readiness.categoryThreshold))
    }

    /// テイスティング相関 track の残り件数（0 未満にはならない）。
    private var remainingForCorrelation: Int32 {
        max(0, readiness.correlationThreshold - readiness.tastedCount)
    }

    private var primaryMessage: String {
        remainingForCategory > 0
            ? String(localized: "あと \(remainingForCategory) 杯記録すると傾向分析が始まります")
            : String(localized: "もう少し記録すると傾向が見えてきます")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "傾向分析まで"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: categoryProgress)
                .tint(Color.accentColor)
                .accessibilityLabel(String(localized: "傾向分析までの進捗"))
                .accessibilityValue(
                    String(localized: "\(readiness.ratedCount) / \(readiness.categoryThreshold) 杯")
                )

            Text(primaryMessage)
                .font(.body)
                .foregroundStyle(.primary)

            if remainingForCorrelation > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(String(localized: "テイスティングもあと \(remainingForCorrelation) 件入力すると味の相関も分析できます"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - FavoriteSignalRow

/// 好み信号の 1 行（産地 / 焙煎度 / 抽出方法）。
private struct FavoriteSignalRow: View {
    let systemImage: String
    let label: String
    let value: String
    let count: Int
    let averageRating: Double?
    let accessibilitySuffix: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                    Text(String(localized: "がやや高評価"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text("\(count) 件")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let avg = averageRating {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                        Text(String(format: "%.1f", avg))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if count < 5 {
                        Text(String(localized: "（サンプル少）"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func buildAccessibilityLabel() -> String {
        var label = "\(self.label): \(value)、\(count) 件"
        if let avg = averageRating {
            label += String(format: "、平均評価 %.1f 点", avg)
        }
        label += "、やや高評価の傾向（参考）"
        if count < 5 { label += "、サンプル少" }
        return label
    }
}

// MARK: - TastingAxisSignalRow

/// テイスティング軸の好み信号（`TastingAxisCorrelation`）の 1 行。
///
/// `correlation` は native `Double` のため `.doubleValue` 変換不要。
private struct TastingAxisSignalRow: View {
    let axis: TastingAxisCorrelation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(localized: "テイスティング"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(localizedTastingAxis(axis.axis))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                    Text(axis.correlation > 0
                         ? String(localized: "が高いほど高評価の傾向")
                         : String(localized: "が低いほど高評価の傾向"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "相関 r=%.2f・%d 件（参考）", axis.correlation, axis.sampleSize))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func localizedTastingAxis(_ a: TastingAxis) -> String {
        switch a {
        case .sweetness:   return String(localized: "甘味")
        case .body:        return String(localized: "ボディ")
        case .acidity:     return String(localized: "酸味")
        case .flavor:      return String(localized: "風味")
        case .aftertaste:  return String(localized: "後味")
        }
    }

    private func buildAccessibilityLabel() -> String {
        let axisName = localizedTastingAxis(axis.axis)
        let direction = axis.correlation > 0 ? "高いほど" : "低いほど"
        return String(
            format: "テイスティング %@: %@高評価の傾向、相関 r=%.2f、%d 件（参考）",
            axisName, direction, axis.correlation, axis.sampleSize
        )
    }
}

// MARK: - PreferredBeanTraitsCard

/// 好みの豆の傾向を表示するカード（Phase 12-C）。
///
/// `beanTraitsInsightStatus` に応じて 3 パターンを表示する:
/// 1. `Loaded` + insight non-nil: LLM 生成テキストを表示
/// 2. `Loading`: ProgressView
/// 3. `Idle` / `Failed` / `Unsupported`: フレーバーノートのタグ + originHint / roastLevelHint を表示
///
/// ## 断定 UI にしない設計
/// フレーバーノートは過去の記録から機械的に集計した傾向値のため、
/// ヘッダや本文で「好き」と断定する表現は使わない。
private struct PreferredBeanTraitsCard: View {

    let traits: PreferredBeanTraits
    let insightStatus: any AnalysisViewModelInsightStatus
    let insight: CoffeeInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダ
            HStack(spacing: 6) {
                Image(systemName: "leaf")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "好みの豆の傾向"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // ステータス別コンテンツ
            if insightStatus is AnalysisViewModelInsightStatusLoaded,
               let insight {
                // LLM 生成インサイト
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.headline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(insight.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(localized: "好みの豆の傾向: \(insight.headline)。\(insight.body)")
                )
            } else if insightStatus is AnalysisViewModelInsightStatusLoading {
                // 生成中
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(String(localized: "豆の傾向を分析中…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "豆の傾向を分析中"))
            } else {
                // Idle / Failed / Unsupported: フレーバータグ + サブラベルをフォールバック表示
                beanTraitsFallbackContent
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    /// フレーバーノートのタグ + サブラベル（産地・焙煎度）のフォールバック表示。
    @ViewBuilder
    private var beanTraitsFallbackContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // フレーバーノートを Capsule タグで横スクロール表示
            let notes = traits.dominantFlavorNotes
            if !notes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(notes, id: \.self) { note in
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(localized: "フレーバーノート: \(notes.joined(separator: "、"))")
                )
            }

            // 産地・焙煎度・テイスティング軸のサブラベル
            let hasSubLabel = traits.originHint != nil
                || traits.roastLevelHint != nil
                || traits.dominantTastingAxis != nil
            if hasSubLabel {
                HStack(spacing: 16) {
                    if let origin = traits.originHint {
                        Label(origin, systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(String(localized: "産地の傾向: \(origin)"))
                    }
                    if let roast = traits.roastLevelHint {
                        Label(localizedRoastLevel(roast), systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(String(localized: "焙煎度の傾向: \(localizedRoastLevel(roast))"))
                    }
                    if let axis = traits.dominantTastingAxis {
                        Label(localizedTastingAxis(axis), systemImage: "waveform.path")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(String(localized: "重視する軸: \(localizedTastingAxis(axis))"))
                    }
                }
            }
        }
    }

    // MARK: - ローカライズヘルパ（struct コンテキスト用）

    private func localizedRoastLevel(_ name: String) -> String {
        switch name {
        case "Light":     return String(localized: "ライト")
        case "Cinnamon":  return String(localized: "シナモン")
        case "Medium":    return String(localized: "ミディアム")
        case "High":      return String(localized: "ハイ")
        case "City":      return String(localized: "シティ")
        case "FullCity":  return String(localized: "フルシティ")
        case "French":    return String(localized: "フレンチ")
        case "Italian":   return String(localized: "イタリアン")
        default:          return name
        }
    }

    private func localizedTastingAxis(_ axis: TastingAxis) -> String {
        switch axis {
        case .sweetness:   return String(localized: "甘味")
        case .body:        return String(localized: "ボディ")
        case .acidity:     return String(localized: "酸味")
        case .flavor:      return String(localized: "風味")
        case .aftertaste:  return String(localized: "後味")
        }
    }
}

// MARK: - UnexploredBeanSuggestionsCard

/// 未経験の豆への探索提案カード（フェーズ 15-E-3 / 要件 9-8）。
///
/// 好み信号に合致するが、ユーザーがまだ記録していない `BeanProfile` を最大 5 件表示する
/// （件数の上限は KMP 側 `SuggestUnexploredBeansUseCase.SUGGESTED_BEANS_LIMIT` で制御）。
private struct UnexploredBeanSuggestionsCard: View {

    let suggestions: [UnexploredBeanSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "試してみては"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(suggestions.enumerated()), id: \.element.profile.beanId) { index, suggestion in
                    UnexploredBeanSuggestionRow(suggestion: suggestion)
                    if index < suggestions.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "試してみては: まだ飲んでいないおすすめの豆"))
    }
}

// MARK: - UnexploredBeanSuggestionRow

/// 未経験の豆への探索提案の 1 行。
private struct UnexploredBeanSuggestionRow: View {
    let suggestion: UnexploredBeanSuggestion

    private var profile: BeanProfile { suggestion.profile }

    private var reasonText: String {
        String(localized: "好みの\(suggestion.matchedOriginLabel)に近い未体験の豆")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(profile.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if let variety = profile.variety {
                    Text("（\(variety)）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(reasonText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !profile.flavorNotes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(profile.flavorNotes, id: \.self) { note in
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(localized: "フレーバーノート: \(profile.flavorNotes.joined(separator: "、"))")
                )
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func buildAccessibilityLabel() -> String {
        var label = profile.name
        if let variety = profile.variety {
            label += "（\(variety)）"
        }
        label += "、\(reasonText)"
        if !profile.flavorNotes.isEmpty {
            label += "、フレーバー: \(profile.flavorNotes.joined(separator: "、"))"
        }
        return label
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
