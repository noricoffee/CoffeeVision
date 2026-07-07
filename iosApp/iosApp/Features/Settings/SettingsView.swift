import SwiftUI

/// アプリ設定画面。TabBar の「設定」タブとして常設表示する。
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

    /// データエクスポートの進行状態。
    @State private var exportState: ExportState = .idle

    /// エクスポート失敗時のエラーメッセージ（`.alert` 表示用）。
    @State private var exportError: String?

    /// `exportState` が取りうる状態。
    private enum ExportState {
        case idle
        case exporting
        case ready(URL)
    }

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
                exportSection
                themeSection
                appInfoSection
                licensesSection
            }
            .navigationTitle(String(localized: "設定"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                String(localized: "エクスポートに失敗しました"),
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button(String(localized: "OK")) { exportError = nil }
            } message: {
                Text(exportError ?? "")
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

    /// データエクスポートセクション。
    ///
    /// KMP `ExportCoffeeRecordsUseCase` で全記録を JSON 文字列化し、一時ファイルに書き出して
    /// `ShareLink` で共有シートを提示する。写真本体はクラウド同期対象外のため含まれない。
    @ViewBuilder
    private var exportSection: some View {
        Section {
            switch exportState {
            case .idle:
                Button {
                    startExport()
                } label: {
                    Label(String(localized: "データをエクスポート"), systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
                .accessibilityLabel(String(localized: "データをエクスポート"))

            case .exporting:
                HStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "エクスポート中..."))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "エクスポート中"))

            case .ready(let url):
                ShareLink(item: url) {
                    Label(String(localized: "エクスポートファイルを共有"), systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
                .accessibilityLabel(String(localized: "エクスポートファイルを共有"))
            }
        } header: {
            Text(String(localized: "データのエクスポート"))
        } footer: {
            Text(String(localized: "コーヒー記録を JSON 形式で書き出します。写真本体は含まれません。"))
                .font(.caption)
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

    // MARK: - データエクスポート

    /// エクスポートを開始する。
    ///
    /// `uid` が未確定（bootstrap 前）の場合は何もしない
    /// （設定画面はアカウント確定後にしか表示されないため通常到達しない）。
    private func startExport() {
        guard let uid = appState.uid else { return }
        exportState = .exporting
        Task { @MainActor in
            do {
                let json = try await appState.container.exportCoffeeRecordsUseCase.invoke(userId: uid)
                let url = try writeExportFile(json: json)
                exportState = .ready(url)
            } catch {
                exportState = .idle
                exportError = error.localizedDescription
            }
        }
    }

    /// JSON 文字列を一時ディレクトリのファイルへ書き出す。
    ///
    /// ファイル名は `coffeevision-export-YYYYMMDD.json`。
    private func writeExportFile(json: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let fileName = "coffeevision-export-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Preview

#Preview {
    // Preview では AppState が必要だが、bootstrap 前の状態で accountBridge は nil。
    // アカウントセクションは表示されないが UI 全体のプレビューとして機能する。
    SettingsView(appState: AppState())
}
