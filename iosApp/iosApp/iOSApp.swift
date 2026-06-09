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
            RootView(appState: appState)
        }
    }
}

// MARK: - RootView

/// uid の確定状況に応じてローディング表示と VisitListView を切り替えるルートビュー。
///
/// - uid == nil（サインイン中 / 失敗）: ProgressView + 状態テキスト
/// - uid != nil: VisitListView を表示
///
/// `visitListBridge` は AppState 内で lazy に 1 度だけ生成されるため、
/// RootView の再描画で ViewModel が作り直されることはない。
@MainActor
private struct RootView: View {

    var appState: AppState

    var body: some View {
        if let bridge = appState.visitListBridge, appState.uid != nil {
            VisitListView(viewModel: bridge, appState: appState)
        } else {
            loadingView
                .task {
                    await appState.bootstrap()
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
