import Charts
import SwiftUI
@preconcurrency import SharedLogic

// MARK: - TastePreferenceConversionView

/// 感想テキスト → 5軸ベクトル → テイスティングスコア範囲検索 の本番 UI。
///
/// 自由記述の日本語コーヒー感想を `TastePreference`（5軸ベクトル）に変換し、
/// `CoffeeRecordQuery.searchRecords` で類似記録を検索して結果を一覧表示する。
///
/// ## 設計
///
/// - `TastePreferenceExtractor.makeIfAvailable()` が nil の端末（非対応 / Apple Intelligence 無効）は
///   `availabilityNotice` を表示して機能を出さない（graceful degradation）。
/// - テキスト入力 → 「好みに変換」ボタン → 抽出結果カード → 類似記録一覧。
/// - `coffeeRecordQuery` が nil（Preview 等）でも変換は動作する。検索はスキップする。
@MainActor
struct TastePreferenceConversionView: View {

    // MARK: - 依存

    /// KMP の `CoffeeRecordQuery`。nil のとき記録検索はスキップする。
    let coffeeRecordQuery: CoffeeRecordQuery?

    // MARK: - State

    @State private var inputText: String = ""
    @State private var extractionState: ExtractionState = .idle
    @State private var searchState: SearchState = .idle
    @State private var extractor: TastePreferenceExtractor? = TastePreferenceExtractor.makeIfAvailable()

    // MARK: - Init

    init(coffeeRecordQuery: CoffeeRecordQuery? = nil) {
        self.coffeeRecordQuery = coffeeRecordQuery
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if extractor != nil {
                        inputSection
                        extractionResultSection
                        searchResultSection
                    } else {
                        availabilityNotice
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle(String(localized: "好みで記録を探す"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 入力セクション

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダ
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "コーヒーの感想を自由に書いてみよう"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // サンプルチップ（入力例）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sampleTexts, id: \.self) { sample in
                        Button(action: { inputText = sample }) {
                            Text(sample)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                        .accessibilityLabel(String(localized: "入力例: \(sample)"))
                    }
                }
            }
            .accessibilityLabel(String(localized: "入力例"))

            // テキスト入力エリア
            VStack(spacing: 0) {
                TextField(
                    String(localized: "例: フルーティで軽い、酸味がきれいで後味が長く続く…"),
                    text: $inputText,
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(4...8)
                .padding(12)
                .accessibilityLabel(String(localized: "感想テキスト入力欄"))
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            // 変換ボタン
            Button(action: startExtraction) {
                HStack(spacing: 8) {
                    if extractionState == .extracting {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }
                    Text(extractionState == .extracting
                         ? String(localized: "変換中…")
                         : String(localized: "好みに変換"))
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(
                    extractionButtonDisabled
                        ? Color(.systemGray4)
                        : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
            .disabled(extractionButtonDisabled)
            .accessibilityLabel(extractionState == .extracting
                ? String(localized: "変換中")
                : String(localized: "感想を好みベクトルに変換"))
            .accessibilityHint(String(localized: "Foundation Models でテキストを5軸の数値に変換します"))
        }
    }

    private var extractionButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || extractionState == .extracting
    }

    // MARK: - 抽出結果セクション

    @ViewBuilder
    private var extractionResultSection: some View {
        switch extractionState {
        case .idle:
            EmptyView()

        case .extracting:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(String(localized: "Foundation Models で変換中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(String(localized: "変換中"))

        case .done(let preference):
            TastePreferenceResultCard(preference: preference)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(String(localized: "変換に失敗しました"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "再試行"), action: startExtraction)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityLabel(String(localized: "変換を再試行"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 検索結果セクション

    @ViewBuilder
    private var searchResultSection: some View {
        switch searchState {
        case .idle:
            EmptyView()

        case .searching:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(String(localized: "類似記録を検索中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(String(localized: "類似記録を検索中"))

        case .found(let summaries):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(String(localized: "類似する記録（\(summaries.count) 件）"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(summaries.enumerated()), id: \.offset) { index, summary in
                        TasteSearchResultRow(summary: summary)
                        if index < summaries.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "類似記録 \(summaries.count) 件"))

        case .empty:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(String(localized: "類似する記録が見つかりませんでした"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Text(String(localized: "テイスティングスコアを入力した記録がないか、±2 の範囲に一致する記録がありませんでした。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

        case .unavailable:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(String(localized: "記録の検索に失敗しました"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Foundation Models 非対応端末向け通知

    private var availabilityNotice: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(String(localized: "Foundation Models 未対応"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(String(localized: "この機能は Apple Intelligence が有効な iPhone / iPad（iOS 26 以降）でのみ利用できます。"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Foundation Models 未対応端末のため、好みで記録を探す機能を利用できません"))
    }

    // MARK: - 抽出処理

    private func startExtraction() {
        guard let extractor else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        extractionState = .extracting
        searchState = .idle

        Task { [weak extractor] in
            guard let extractor else { return }
            do {
                let preference = try await extractor.extract(from: text)
                extractionState = .done(preference)
                await searchRecordsAfterExtraction(preference: preference)
            } catch {
                let message = error.localizedDescription
                print("[CoffeeVision] TastePreferenceConversionView: extraction failed: \(error)")
                extractionState = .failed(message)
            }
        }
    }

    private func searchRecordsAfterExtraction(preference: TastePreference) async {
        guard let rq = coffeeRecordQuery else { return }
        searchState = .searching
        do {
            let filter = preference.toCoffeeRecordFilter()
            let summaries = try await rq.searchRecords(filter: filter)
            if summaries.isEmpty {
                searchState = .empty
            } else {
                searchState = .found(Array(summaries))
            }
        } catch {
            print("[CoffeeVision] TastePreferenceConversionView: search failed: \(error)")
            searchState = .unavailable
        }
    }

    // MARK: - 入力例

    private let sampleTexts: [String] = [
        "フルーティで軽い、酸味がきれいで後味が長い",
        "チョコレートのような深いコク、苦みが心地よい",
        "フローラルな香り、甘みがしっかりあって飲みやすい",
        "すっきりしていてあまり主張しない、後味は短め",
    ]
}

// MARK: - ExtractionState

private enum ExtractionState: Equatable {
    case idle
    case extracting
    case done(TastePreference)
    case failed(String)

    static func == (lhs: ExtractionState, rhs: ExtractionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.extracting, .extracting): return true
        case (.done(let a), .done(let b)):
            return a.sweetness == b.sweetness
                && a.body == b.body
                && a.acidity == b.acidity
                && a.flavor == b.flavor
                && a.aftertaste == b.aftertaste
                && a.roast == b.roast
                && a.summary == b.summary
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - SearchState

private enum SearchState {
    case idle
    case searching
    case found([CoffeeRecordSummary])
    case empty
    case unavailable
}

// MARK: - TastePreferenceResultCard

/// `TastePreference` の抽出結果を5軸横棒グラフ + summary で表示するカード。
struct TastePreferenceResultCard: View {

    let preference: TastePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダ
            HStack(spacing: 6) {
                Image(systemName: "wand.and.sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "抽出された好みベクトル"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // summary
            Text(preference.summary)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(String(localized: "サマリ: \(preference.summary)"))

            // 5軸横棒グラフ
            tastingChart

            // 焙煎度バッジ
            roastBadge
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "好みで記録を探す - 抽出結果カード"))
    }

    // MARK: - 5軸横棒グラフ

    private var tastingChart: some View {
        let items = tastingItems
        return VStack(alignment: .leading, spacing: 4) {
            Chart(items, id: \.label) { item in
                BarMark(
                    x: .value(String(localized: "強度"), item.value),
                    y: .value(String(localized: "軸"), item.label)
                )
                .foregroundStyle(barColor(for: item.value))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(item.value)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .accessibilityLabel("\(item.label): \(item.value)")
            }
            .chartXScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: [0, 2, 4, 6, 8, 10]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
            .accessibilityLabel(String(localized: "5軸好みベクトルグラフ（1〜10）"))
        }
    }

    private var tastingItems: [(label: String, value: Int)] {
        [
            (String(localized: "甘味"),   preference.sweetness),
            (String(localized: "ボディ"), preference.body),
            (String(localized: "酸味"),   preference.acidity),
            (String(localized: "風味"),   preference.flavor),
            (String(localized: "後味"),   preference.aftertaste),
        ]
    }

    /// 値に応じてバーの色を変える（中庸=5でグレー、高=アクセント寄り、低=セカンダリ）。
    private func barColor(for value: Int) -> Color {
        if value >= 8 {
            return Color.accentColor
        } else if value >= 6 {
            return Color.accentColor.opacity(0.7)
        } else if value <= 2 {
            return Color(.systemGray4)
        } else {
            return Color.accentColor.opacity(0.45)
        }
    }

    // MARK: - 焙煎度バッジ

    private var roastBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(String(localized: "焙煎度"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(localizedRoast(preference.roast))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "焙煎度: \(localizedRoast(preference.roast))"))
    }

    private func localizedRoast(_ roast: String) -> String {
        switch roast {
        case "Light":     return String(localized: "ライト")
        case "Cinnamon":  return String(localized: "シナモン")
        case "Medium":    return String(localized: "ミディアム")
        case "High":      return String(localized: "ハイ")
        case "City":      return String(localized: "シティ")
        case "FullCity":  return String(localized: "フルシティ")
        case "French":    return String(localized: "フレンチ")
        case "Italian":   return String(localized: "イタリアン")
        case "unknown":   return String(localized: "不明")
        default:          return roast
        }
    }
}

// MARK: - TasteSearchResultRow

/// テイスティング類似検索結果の 1 件を表示する行。
private struct TasteSearchResultRow: View {

    let summary: CoffeeRecordSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.name)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if let cafeName = summary.cafeName {
                    Text(cafeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                if summary.rating >= 0.5 {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(String(format: "%.1f", summary.rating))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(summary.visitedOn)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func buildAccessibilityLabel() -> String {
        var label = summary.name
        if let cafeName = summary.cafeName { label += " \(cafeName)" }
        if summary.rating >= 0.5 { label += String(format: " 評価%.1f", summary.rating) }
        label += " \(summary.visitedOn)"
        return label
    }
}

// MARK: - Preview

#if DEBUG

#Preview("好みで記録を探す - 結果あり") {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TastePreferenceResultCard(preference: previewTastePreference)
            }
            .padding(16)
        }
        .navigationTitle(String(localized: "好みで記録を探す"))
    }
}

private let previewTastePreference = TastePreference(
    sweetness: 4,
    body: 3,
    acidity: 8,
    flavor: 9,
    aftertaste: 7,
    roast: "Light",
    summary: "フルーティで明るい酸味を好む、華やかな風味追求タイプ"
)

#endif
