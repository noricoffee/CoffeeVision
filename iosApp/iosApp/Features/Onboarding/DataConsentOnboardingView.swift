import SwiftUI

/// 初回起動時に表示するデータ共有同意オンボーディング画面。
///
/// - 「同意する」→ AppState.onConsentGranted() → シート dismiss
/// - 「今はしない」→ AppState.onConsentDeclined() → シート dismiss
///
/// プライバシーポリシー URL は App Store 提出前に差し替えること（現在はプレースホルダー）。
struct DataConsentOnboardingView: View {

    var appState: AppState

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            scrollContent
            actionButtons
        }
        .background(Color(.systemBackground))
    }

    // MARK: - スクロールエリア

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                descriptionSection
                purposeSection
                privacyLinkSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("アプリ改善へのご協力のお願い")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CoffeeVision では、アプリをより良くするために、コーヒー記録の統計情報（コーヒーの種類、評価傾向など）を匿名で収集する場合があります。")
                .font(.body)
                .foregroundStyle(.primary)
            Text("個人を特定できる情報は含まれません。また、いつでも設定から変更できます。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("収集する情報の目的")
                .font(.headline)
                .foregroundStyle(.primary)
            purposeRow(icon: "chart.bar.fill", text: "飲んだコーヒーの傾向分析（豆・産地・抽出方法）")
            purposeRow(icon: "star.fill", text: "評価の傾向からアプリ機能の優先度を決定")
            purposeRow(icon: "lock.fill", text: "個人を特定しない匿名データのみ使用")
        }
    }

    private func purposeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private var privacyLinkSection: some View {
        Link(destination: URL(string: "https://example.com/privacy")!) {
            HStack(spacing: 4) {
                Text("プライバシーポリシーを読む")
                    .font(.footnote)
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
            }
            .foregroundStyle(.blue)
        }
        .accessibilityLabel(String(localized: "プライバシーポリシーを開く"))
    }

    // MARK: - アクションボタン

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Divider()
            VStack(spacing: 8) {
                Button {
                    appState.onConsentGranted()
                } label: {
                    Text("同意してアプリを改善する")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .accessibilityLabel(String(localized: "データ共有に同意してアプリを改善する"))

                Button {
                    appState.onConsentDeclined()
                } label: {
                    Text("今はしない")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .accessibilityLabel(String(localized: "データ共有をスキップ"))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    DataConsentOnboardingView(appState: AppState())
}

#Preview("Dark") {
    DataConsentOnboardingView(appState: AppState())
        .preferredColorScheme(.dark)
}
