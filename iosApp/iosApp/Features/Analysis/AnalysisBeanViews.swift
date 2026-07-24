import SharedLogic
import SwiftUI

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
struct PreferredBeanTraitsCard: View {

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
struct UnexploredBeanSuggestionsCard: View {

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
