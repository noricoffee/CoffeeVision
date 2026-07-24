import SwiftUI
import SharedLogic

// MARK: - PreferenceMatchAxis 表示ラベル

/// 好み一致の軸名の日本語ラベル。
///
/// `RecommendationMatchSheet` と `RecommendedCafeListSheet`（一覧行のサマリ表示）で共有する。
func preferenceMatchAxisLabel(_ axis: PreferenceMatchAxis) -> String {
    switch axis {
    case .origin:
        return String(localized: "産地")
    case .roastLevel:
        return String(localized: "焙煎度")
    case .brewMethod:
        return String(localized: "抽出方法")
    case .processing:
        return String(localized: "精製方法")
    }
}

// MARK: - RecommendationMatchSheet

/// 好み一致カフェの推薦理由を表示するシート。
///
/// - 推薦理由（`RecommendedCafe.matches`）を列挙し、軸ごとに定型文で表示する
/// - 「詳細を見る」でカフェ詳細画面へ push できる
struct RecommendationMatchSheet: View {

    let recommendedCafe: RecommendedCafe
    let onOpenDetail: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダ
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        String(localized: "好み一致"),
                        systemImage: "heart.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.pink)

                    Text(recommendedCafe.cafe.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider()

                // 推薦理由一覧
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(recommendedCafe.matches.enumerated()), id: \.offset) { _, reason in
                            matchRow(reason: reason)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                Divider()

                // 詳細ボタン
                Button(action: onOpenDetail) {
                    HStack {
                        Text(String(localized: "このカフェの記録を見る"))
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(minHeight: 44)
                }
                .foregroundStyle(.primary)
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle(String(localized: "好みのコーヒーがあった店"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityLabel(
            String(localized: "好み一致のカフェ、\(recommendedCafe.cafe.name)。\(accessibilitySummary)")
        )
    }

    // MARK: - 推薦理由行

    @ViewBuilder
    private func matchRow(reason: RecommendationReason) -> some View {
        switch onEnum(of: reason) {
        case .tasteProfileMatch(let match):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: axisIcon(match.axis))
                    .font(.body)
                    .foregroundStyle(Color.pink)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(matchTitle(match))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(matchDetail(match))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(matchAccessibilityLabel(match))
        }
    }

    // MARK: - 文言生成

    /// 軸に対応する SF Symbols 名。
    private func axisIcon(_ axis: PreferenceMatchAxis) -> String {
        switch axis {
        case .origin:
            return "globe.asia.australia"
        case .roastLevel:
            return "flame"
        case .brewMethod:
            return "cup.and.saucer"
        case .processing:
            return "leaf.fill"
        }
    }

    /// 推薦理由のタイトル文（例「好みの産地: エチオピア」）。
    private func matchTitle(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = preferenceMatchAxisLabel(match.axis)
        return String(localized: "好みの\(axisLabel): \(match.matchedLabel)")
    }

    /// 推薦理由の補足文（代表記録名 + 評価）。
    private func matchDetail(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let stars = formatRating(match.exampleRating)
        return String(localized: "\(match.exampleRecordName) \(stars)")
    }

    /// アクセシビリティ用ラベル（VoiceOver 読み上げ）。
    private func matchAccessibilityLabel(_ match: RecommendationReasonTasteProfileMatch) -> String {
        let axisLabel = preferenceMatchAxisLabel(match.axis)
        let stars = formatRating(match.exampleRating)
        return String(
            localized: "好みの\(axisLabel) \(match.matchedLabel) を高評価で記録。\(match.exampleRecordName) \(stars)"
        )
    }

    /// 評価値を「★4.5」形式の文字列に変換する。
    private func formatRating(_ rating: Double) -> String {
        // 0.5 刻みのため小数点 1 桁で表示
        let formatted = String(format: "%.1f", rating)
        return "★\(formatted)"
    }

    /// シート全体のアクセシビリティサマリ（VoiceOver 用）。
    private var accessibilitySummary: String {
        recommendedCafe.matches.compactMap { reason -> String? in
            switch onEnum(of: reason) {
            case .tasteProfileMatch(let match):
                return matchAccessibilityLabel(match)
            }
        }.joined(separator: "。")
    }
}
