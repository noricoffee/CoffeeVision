import Foundation
import Observation
import SharedLogic

/// アプリ全体の状態ホルダ。
///
/// - 起動時に Swift 側で `AuthRepositoryIosImpl` / `RemoteVisitDataSourceIosImpl` を組み立て、
///   Kotlin の `AppContainer` に注入する
/// - `AppContainer.startInitialSync()` を呼び、得られた uid を保持する
/// - `visitListBridge` / `mapBridge` を lazy で 1 回だけ生成し、各 View に渡す
@MainActor
@Observable
final class AppState {

    private(set) var container: AppContainer
    private(set) var uid: String?
    private(set) var status: Status = .idle
    private(set) var lastError: String?

    /// VisitListView 用の ViewModel ブリッジ。
    ///
    /// `@Observable` マクロは `lazy var` をサポートしないため `Optional` で初期化し、
    /// `bootstrap()` 完了後に 1 度だけ生成する。
    private(set) var visitListBridge: VisitListViewModelBridge?

    /// MapTabView 用の ViewModel ブリッジ。
    ///
    /// マップタブは TabView 常時生存のため `visitListBridge` と同等のライフサイクルで管理する。
    /// `bootstrap()` 完了後（uid 確定後）に 1 度だけ生成する。
    private(set) var mapBridge: MapViewModelBridge?

    enum Status: Equatable {
        case idle
        case signingIn
        case ready
        case failed
    }

    init() {
        let sqlDriver = DatabaseDriverFactory().create()
        let authRepo = AuthRepositoryIosImpl()
        let remoteDataSource = RemoteVisitDataSourceIosImpl()
        // Configuration/Base.xcconfig → Info.plist の $(PLACES_API_KEY) 経由で取得する。
        // Secrets.xcconfig が存在しない場合（CI 環境等）は空文字フォールバック。
        // 空文字の場合もアプリは起動するが Places API 呼び出しは 401 を返す。
        let placesApiKey = (Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String) ?? ""
        self.container = AppContainer(
            sqlDriver: sqlDriver,
            remoteVisitDataSource: remoteDataSource,
            authRepository: authRepo,
            placesApiKey: placesApiKey
        )
    }

    /// 匿名サインイン + 同期購読を起動する。`RootView` の `.task` から呼ぶ。
    ///
    /// 成功時に `visitListBridge` と `mapBridge` を 1 度だけ生成する。
    /// 既に生成済み（bootstrap 再呼び出し）の場合は再生成しない。
    func bootstrap() async {
        status = .signingIn
        do {
            let uid = try await container.startInitialSync()
            self.uid = uid
            self.status = .ready
            // VisitListViewModelBridge を 1 度だけ生成する
            if visitListBridge == nil {
                visitListBridge = VisitListViewModelBridge(kotlin: container.makeVisitListViewModel())
            }
            // MapViewModelBridge を 1 度だけ生成する（uid が必要）
            if mapBridge == nil {
                mapBridge = MapViewModelBridge(viewModel: container.makeMapViewModel(userId: uid))
            }
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

}
