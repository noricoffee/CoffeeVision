import SwiftUI

/// データ利用同意オンボーディングの直後に表示する広告プレプロンプト（requirements.md §11-4）。
///
/// - 「広告により無料で提供している」旨を説明したうえで、続けて ATT（App Tracking Transparency）
///   の許諾ダイアログへ接続する
/// - この画面自体には許諾/拒否の選択肢は無い（実際の可否判断は直後に出る OS 標準ダイアログで行う）。
///   「続ける」タップで `AppState.onAdPrePromptContinue()` を呼び、ATT ダイアログ表示へ進む
struct AdPrePromptView: View {

    var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            scrollContent
            actionButton
        }
        .background(Color(.systemBackground))
    }

    // MARK: - スクロールエリア

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                descriptionSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 48))
                .foregroundStyle(.brown)
                .accessibilityHidden(true)
            Text("広告について")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CoffeeVision は無料でご利用いただくため、アプリ内に広告を表示しています。")
                .font(.body)
                .foregroundStyle(.primary)
            Text("次の画面で表示される許可をいただけると、よりご興味に近い広告を表示できます。許可しない場合も、これまでどおりアプリはすべての機能をご利用いただけます。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - アクションボタン

    private var actionButton: some View {
        VStack(spacing: 12) {
            Divider()
            Button {
                appState.onAdPrePromptContinue()
            } label: {
                Text("続ける")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .accessibilityLabel(String(localized: "広告についての説明を確認して続ける"))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    AdPrePromptView(appState: AppState())
}
