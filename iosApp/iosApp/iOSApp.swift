import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import FirebaseFirestore
import GoogleMobileAds
import SharedLogic

@main
struct iOSApp: App {

    @State private var appState: AppState

    init() {
        FirebaseApp.configure()

        // Crashlytics は同意不要で常時収集する（Info.plist にはフラグを立てず、ここで明示有効化する）。
        // Performance は Info.plist にフラグを立てていないため、SDK 既定（常時 ON）のまま。
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Firestore のオフライン永続化を明示的に有効化（Modern API: PersistentCacheSettings）。
        // デフォルトでも ON だが、永続化が効いている状態を起動ログから確認できるよう明示設定する。
        // sizeBytes は NSNumber 必須。FirestoreCacheSizeUnlimited 相当を渡す。
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited)
        )
        Firestore.firestore().settings = settings
        print("[CoffeeVision] Firestore persistent cache enabled")

        // Remote Config の fetch + activate（POI 名前フィルタ・レビュー依頼キルスイッチ等、
        // 全キー共通）。同意フローとは無関係に取得してよく、失敗・未取得時は各機能側の
        // フォールバックに委ねるため fire-and-forget でよい。
        Task {
            await RemoteConfigBootstrap.fetchAndActivate()
        }

        // Google Mobile Ads SDK は同意フロー（ATT）の結果を待たずアプリ起動時に開始する
        // （公式推奨: 起動直後の呼び出しでセッション最初の広告リクエストのレイテンシを下げる）。
        // 個々の広告リクエストが NPA を要求するかどうかは ATT 許諾状態を都度参照して判断する
        // （`BannerAdLoader.makeRequest()`）ため、SDK 起動自体を待たせる必要はない。
        MobileAds.shared.requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        MobileAds.shared.start()

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
    /// 未設定時の既定は `.light`（OS のダーク設定には追従させない。ユーザーが設定画面で
    /// `system` / `dark` を選んだ場合のみそちらに切り替わる）。
    @AppStorage("appAppearance") private var appearanceRaw = AppAppearance.light.rawValue

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
                .sheet(isPresented: Binding(
                    get: { appState.showConsentOnboarding },
                    set: { if !$0 { appState.showConsentOnboarding = false } }
                )) {
                    DataConsentOnboardingView(appState: appState)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
                }
                .sheet(isPresented: Binding(
                    get: { appState.showAdConsentFlow },
                    set: { if !$0 { appState.showAdConsentFlow = false } }
                )) {
                    AdPrePromptView(appState: appState)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
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
