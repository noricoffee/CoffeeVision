import SwiftUI
import SharedLogic

/// 「好み一致」一覧ハーフシート（2026-07-16、好み一致チップのタップ対応）。
///
/// - `recommendedCafes` は `bridge.recommendedCafes` の順序（matches 件数降順 → 代表記録評価降順 →
///   placeId 昇順）をそのまま表示する（呼び出し側で再ソートしない）
/// - 好み一致カフェは定義上すでに記録済みのため、`SavedCafeListSheet` と異なり「記録あり」バッジや
///   `recordedPlaceIds` は不要
/// - タップで `onSelect` を呼ぶ（呼び出し側でシートを閉じてカフェ詳細へ push する）
/// - 推薦に解除操作はないためスワイプアクションは持たない
struct RecommendedCafeListSheet: View {

    let recommendedCafes: [RecommendedCafe]
    let onSelect: (RecommendedCafe) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if recommendedCafes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(recommendedCafes, id: \.cafe.placeId) { recommendedCafe in
                            Button {
                                onSelect(recommendedCafe)
                            } label: {
                                row(recommendedCafe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "好みのコーヒーがあった店"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 行

    private func row(_ recommendedCafe: RecommendedCafe) -> some View {
        let summary = matchSummary(recommendedCafe)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.body)
                .foregroundStyle(Color.pink)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendedCafe.cafe.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let address = recommendedCafe.cafe.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color.pink)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(recommendedCafe.cafe.name)、\(summary)")
        )
    }

    /// 推薦理由のコンパクトなサマリ文（例「産地・焙煎度が好みに一致」）。
    ///
    /// 軸表示ロジックは `RecommendationMatchSheet` の `preferenceMatchAxisLabel` を再利用し、
    /// 一致した軸名を重複除去して列挙する（1 行の要約に留め、詳細は `RecommendationMatchSheet` に譲る）。
    private func matchSummary(_ recommendedCafe: RecommendedCafe) -> String {
        var seenLabels = Set<String>()
        let axisLabels = recommendedCafe.matches.compactMap { reason -> String? in
            switch onEnum(of: reason) {
            case .tasteProfileMatch(let match):
                return preferenceMatchAxisLabel(match.axis)
            }
        }.filter { seenLabels.insert($0).inserted }

        return String(localized: "\(axisLabels.joined(separator: "・"))が好みに一致")
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(String(localized: "好みに一致するカフェがまだありません"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(localized: "コーヒーの記録を重ねると、好みに合う店がここに表示されます"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
