import Foundation
import Observation
import SharedLogic

/// アプリ全体の状態ホルダ。
///
/// - 起動時に Swift 側で `AuthRepositoryIosImpl` / `RemoteVisitDataSourceIosImpl` を組み立て、
///   Kotlin の `AppContainer` に注入する
/// - `AppContainer.startInitialSync()` を呼び、得られた uid を保持する
/// - `visitListBridge` を lazy で 1 回だけ生成し、VisitListView に渡す
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
    /// `RootView` は uid が確定してから VisitListView を表示するため、
    /// このプロパティが nil のまま参照されることはない。
    private(set) var visitListBridge: VisitListViewModelBridge?

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
        self.container = AppContainer(
            sqlDriver: sqlDriver,
            remoteVisitDataSource: remoteDataSource,
            authRepository: authRepo,
            // TODO(スライス 2): xcconfig / Info.plist 経由で実 API キーを注入する
            placesApiKey: ""
        )
    }

    /// 匿名サインイン + 同期購読を起動する。`RootView` の `.task` から呼ぶ。
    ///
    /// 成功時に `visitListBridge` を 1 度だけ生成する。
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
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

}
