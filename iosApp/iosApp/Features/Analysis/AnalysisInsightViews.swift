import SwiftUI

// MARK: - InsightLoadingCard

/// 要約生成中（`Idle` / `Loading` 状態）に表示するカード。
struct InsightLoadingCard: View {
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
struct InsightLoadedCard: View {
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
struct InsightFailedCard: View {
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
