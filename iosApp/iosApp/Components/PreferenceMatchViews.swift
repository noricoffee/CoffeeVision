import SwiftUI
import SharedLogic

// MARK: - PreferenceMatchAxis 表示ラベル

/// 好み一致の軸名の日本語ラベル。
///
/// `PreferenceMatchRow`（カフェ詳細 / 旧マップシート）と `RecommendedCafeListSheet`
/// （一覧行のサマリ表示）で共有する。
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

// MARK: - PreferenceMatchRow

/// 好み一致の推薦理由 1 件分の行。
///
/// マップ（`RecommendedCafePin` タップ→旧シート）とカフェ詳細画面の両方が使う共通部品
/// （`Components/` 配置は `TagChip` と同じ位置づけ）。軸アイコン + 定型文 + 補足（代表記録名 + 評価）。
struct PreferenceMatchRow: View {

    let reason: RecommendationReason

    var body: some View {
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
}

// MARK: - Preview

#Preview("好み一致セクション（List 内 / Label ヘッダの色確認）") {
    List {
        Section {
            ForEach(
                Array(PreviewSamples.sampleRecommendedCafes[0].matches.enumerated()),
                id: \.offset
            ) { _, reason in
                PreferenceMatchRow(reason: reason)
            }
        } header: {
            Label(String(localized: "好み一致"), systemImage: "heart.fill")
                .foregroundStyle(.pink)
        }
    }
}
