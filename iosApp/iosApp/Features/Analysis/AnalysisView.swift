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
        // レビュー依頼（要件 9-8 / ASO-1）: 分析タブで傾向信号が初めて出た瞬間に 1 回だけ提示する。
        // `.task` は表示時点で既に readiness.hasAnySignal == true のケース（2 回目以降のタブ訪問。
        // ブリッジは TabBar 常時生存でキャッシュ済みの readiness を即座に読める）をカバーし、
        // `.onChange` は nil/false → true の遷移（初めて信号が出た瞬間）をカバーする。
        // ReviewPrompt 側にマイルストーンフラグがあるため二重呼び出しは無害。
        .task {
            if viewModel.readiness?.hasAnySignal == true {
                await ReviewPrompt.requestIfFirstSignalReached()
            }
        }
        .onChange(of: viewModel.readiness?.hasAnySignal) { _, hasAnySignal in
            guard hasAnySignal == true else { return }
            Task {
                await ReviewPrompt.requestIfFirstSignalReached()
            }
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

}
