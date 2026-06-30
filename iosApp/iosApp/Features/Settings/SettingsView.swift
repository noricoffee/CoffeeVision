import SwiftUI

/// アプリ設定画面。sheet で表示する。
///
/// - アカウント管理への遷移（`NavigationLink` → `AccountView`）
/// - 表示テーマ切替（`@AppStorage` 経由でアプリ全体に即時反映）
/// - バージョン / ビルド番号の表示
/// - ライセンス一覧への遷移
struct SettingsView: View {

    /// アカウント画面表示とリブートのために AppState を受け取る。
    ///
    /// AppState は `@Observable` のため、`var` で受け取ると変化追跡が有効になる。
    var appState: AppState

    @Environment(\.dismiss) private var dismiss

    /// `AppRootView` の `preferredColorScheme` と同じキーで同期する。
    @AppStorage("appAppearance") private var appearanceRaw = AppAppearance.system.rawValue

    // MARK: - バージョン情報

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                consentSection
                themeSection
                appInfoSection
                licensesSection
            }
            .navigationTitle(String(localized: "設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完了")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "設定を閉じる"))
                }
            }
        }
    }

    // MARK: - セクション

    /// アカウント管理セクション。
    ///
    /// `accountBridge` が確定済みのときのみ NavigationLink を表示する。
    /// bootstrap 完了前はブリッジが nil のため空セクションになる。
    @ViewBuilder
    private var accountSection: some View {
        if let accountBridge = appState.accountBridge {
            Section(String(localized: "アカウント")) {
                NavigationLink {
                    AccountView(viewModel: accountBridge) {
                        // サインアウト / 削除完了後に AppState をリセットして再起動
                        appState.resetAndRebootstrap()
                        dismiss()
                    }
                } label: {
                    Label(String(localized: "アカウント管理"), systemImage: "person.circle")
                }
                .accessibilityLabel(String(localized: "アカウント管理画面を開く"))
            }
        }
    }

    /// データ共有同意セクション。
    private var consentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appState.analyticsConsent },
                set: { appState.updateAnalyticsConsent($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("アプリ改善への協力")
                    Text("コーヒー記録の統計情報を匿名で収集します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(String(localized: "アプリ改善のためのデータ共有"))
            .accessibilityHint(String(localized: "オンにすると匿名の統計情報を送信します"))
        } header: {
            Text("データとプライバシー")
        }
    }

    /// 表示テーマ切替セクション。
    private var themeSection: some View {
        Section(String(localized: "表示テーマ")) {
            Picker(String(localized: "テーマ"), selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases, id: \.rawValue) { appearance in
                    Text(appearance.displayName)
                        .tag(appearance.rawValue)
                }
            }
            .accessibilityLabel(String(localized: "表示テーマを選択"))
        }
    }

    /// バージョン / ビルド番号セクション。
    private var appInfoSection: some View {
        Section(String(localized: "アプリ情報")) {
            LabeledContent(String(localized: "バージョン"), value: appVersion)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("バージョン \(appVersion)")

            LabeledContent(String(localized: "ビルド"), value: buildNumber)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("ビルド番号 \(buildNumber)")
        }
    }

    /// ライセンス一覧へのナビゲーションセクション。
    private var licensesSection: some View {
        Section {
            NavigationLink(String(localized: "ライセンス")) {
                LicensesView()
            }
            .accessibilityLabel(String(localized: "ライセンス一覧を開く"))
        }
    }
}

// MARK: - Preview

#Preview {
    // Preview では AppState が必要だが、bootstrap 前の状態で accountBridge は nil。
    // アカウントセクションは表示されないが UI 全体のプレビューとして機能する。
    SettingsView(appState: AppState())
}
