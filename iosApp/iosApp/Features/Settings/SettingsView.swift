import SwiftUI

/// アプリ設定画面。sheet で表示する。
///
/// - 表示テーマ切替（`@AppStorage` 経由でアプリ全体に即時反映）
/// - バージョン / ビルド番号の表示
/// - ライセンス一覧への遷移
struct SettingsView: View {

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
    SettingsView()
}
