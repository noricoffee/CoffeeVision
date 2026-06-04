import SwiftUI
import FirebaseCore
import FirebaseFirestore
import SharedLogic

@main
struct iOSApp: App {

    /// Phase 3 で本格的な ViewModel ファクトリを追加する想定の Phase 2 検証用 App 状態。
    /// `@State` の初期値は `init()` 内で `FirebaseApp.configure()` 後に設定する必要があるため
    /// 一旦 nil ホルダで宣言し、`init` で確実に注入する。
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
            Phase2VerificationView(state: appState)
        }
    }
}
