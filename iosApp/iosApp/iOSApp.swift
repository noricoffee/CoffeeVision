import SwiftUI
import FirebaseCore
import FirebaseFirestore
import SharedLogic

@main
struct iOSApp: App {

    @State private var appState: AppState

    init() {
        FirebaseApp.configure()

        // Firestore のオフライン永続化を明示的に有効化（Modern API: PersistentCacheSettings）。
        // デフォルトでも ON だが、永続化が効いている状態を起動ログから確認できるよう明示設定する。
        // sizeBytes は NSNumber 必須。FirestoreCacheSizeUnlimited 相当を渡す。
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited)
        )
        Firestore.firestore().settings = settings
        print("[CoffeeVision] Firestore persistent cache enabled")

        // AppState は FirebaseApp.configure() 完了後に組み立てる
        // （内部で Firestore.firestore() を参照するため）。
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(appState: appState)
        }
    }
}

// MARK: - AppRootView

/// uid の確定状況に応じてローディング表示と RootTabView を切り替えるルートビュー。
///
/// - uid == nil（サインイン中 / 失敗）: ProgressView + 状態テキスト
/// - uid != nil かつ coffeeListBridge / mapBridge が準備完了: RootTabView を表示
///
/// `coffeeListBridge` と `mapBridge` は AppState 内で lazy に 1 度だけ生成されるため、
/// AppRootView の再描画で ViewModel が作り直されることはない。
@MainActor
private struct AppRootView: View {

    var appState: AppState

    /// 設定画面で選択されたテーマを永続化するキー。`SettingsView` と同じキーを参照する。
    @AppStorage("appAppearance") private var appearanceRaw = AppAppearance.system.rawValue

    var body: some View {
        if appState.uid != nil,
           appState.coffeeListBridge != nil,
           appState.mapBridge != nil,
           appState.accountBridge != nil {
            RootTabView(appState: appState)
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
                .errorToast(message: appState.lastError) {
                    appState.clearLastError()
                }
        } else {
            loadingView
                .task {
                    await appState.bootstrap()
                }
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
                .errorToast(message: appState.lastError) {
                    appState.clearLastError()
                }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(loadingStatusText)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var loadingStatusText: String {
        switch appState.status {
        case .idle:
            return String(localized: "起動中...")
        case .signingIn:
            return String(localized: "サインイン中...")
        case .ready:
            return String(localized: "準備完了")
        case .failed:
            return String(localized: "起動に失敗しました")
        }
    }
}
