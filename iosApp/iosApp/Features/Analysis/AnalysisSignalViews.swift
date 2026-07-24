import SharedLogic
import SwiftUI

// MARK: - FavoriteSignalsCard

/// 好み信号（`FavoriteSignals`）を表示するカード。
///
/// 断定 UI にしない設計：
/// - 「やや」「参考」「傾向」等の弱い表現のみ使用
/// - 件数を併記してサンプルサイズを明示
/// - 交絡（「産地が好き」か「店が好き」か）は判別不能のため注記表示
struct FavoriteSignalsCard: View {

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
struct AnalysisReadinessProgressCard: View {

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
