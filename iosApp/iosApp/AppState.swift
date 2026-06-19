import Foundation
import Observation
import SharedLogic

/// アプリ全体の状態ホルダ。
///
/// - 起動時に Swift 側で `AuthRepositoryIosImpl` / `RemoteCoffeeDataSourceIosImpl` を組み立て、
///   Kotlin の `AppContainer` に注入する
/// - `AppContainer.startInitialSync()` を呼び、得られた uid を保持する
/// - `coffeeListBridge` / `mapBridge` / `accountBridge` を `Optional` で保持し、
///   `bootstrap()` 完了後に 1 度だけ生成する
@MainActor
@Observable
final class AppState {

    private(set) var container: AppContainer
    private(set) var uid: String?
    private(set) var status: Status = .idle
    private(set) var lastError: String?

    /// CoffeeListView 用の ViewModel ブリッジ。
    ///
    /// `@Observable` マクロは `lazy var` をサポートしないため `Optional` で初期化し、
    /// `bootstrap()` 完了後に 1 度だけ生成する。
    private(set) var coffeeListBridge: CoffeeListViewModelBridge?

    /// MapTabView 用の ViewModel ブリッジ。
    ///
    /// マップタブは TabView 常時生存のため `coffeeListBridge` と同等のライフサイクルで管理する。
    /// `bootstrap()` 完了後（uid 確定後）に 1 度だけ生成する。
    private(set) var mapBridge: MapViewModelBridge?

    /// AccountView 用の ViewModel ブリッジ。
    ///
    /// Settings → Account の sheet 遷移で使う。`bootstrap()` 完了後に 1 度だけ生成する。
    /// サインアウト / 削除後は `resetAndRebootstrap()` で nil に戻す。
    private(set) var accountBridge: AccountViewModelBridge?

    /// Google Places Photo Media API から写真 URL を取得するローダー。
    ///
    /// uid 不要なので `init` で即座に生成する（`bootstrap()` 前から利用可能）。
    private(set) var placePhotoLoader: PlacePhotoLoader

    enum Status: Equatable {
        case idle
        case signingIn
        case ready
        case failed
    }

    init() {
        let sqlDriver = DatabaseDriverFactory().create()
        let authRepo = AuthRepositoryIosImpl()
        let remoteDataSource = RemoteCoffeeDataSourceIosImpl()
        // Configuration/Base.xcconfig → Info.plist の $(PLACES_API_KEY) 経由で取得する。
        // Secrets.xcconfig が存在しない場合（CI 環境等）は空文字フォールバック。
        // 空文字の場合もアプリは起動するが Places API 呼び出しは 401 を返す。
        let placesApiKey = (Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String) ?? ""
        let container = AppContainer(
            sqlDriver: sqlDriver,
            remoteCoffeeDataSource: remoteDataSource,
            authRepository: authRepo,
            placesApiKey: placesApiKey
        )
        self.container = container
        // uid 不要なので bootstrap() 前から利用可能
        self.placePhotoLoader = PlacePhotoLoader(repository: container.cafeRepository)
    }

    /// 起動時エラー（lastError）を消去する。
    ///
    /// `lastError` は `private(set)` のため外部からの nil 代入はできない。
    /// `AppRootView` の `.errorToast(onDismiss:)` から呼ぶ。
    func clearLastError() {
        lastError = nil
    }

    /// 匿名サインイン + 同期購読を起動する。`AppRootView` の `.task` から呼ぶ。
    ///
    /// 成功時に `coffeeListBridge` / `mapBridge` / `accountBridge` を 1 度だけ生成する。
    /// 既に生成済み（bootstrap 再呼び出し）の場合は再生成しない。
    func bootstrap() async {
        status = .signingIn
        do {
            let uid = try await container.startInitialSync()
            self.uid = uid
            self.status = .ready
            // CoffeeListViewModelBridge を 1 度だけ生成する
            if coffeeListBridge == nil {
                coffeeListBridge = CoffeeListViewModelBridge(kotlin: container.makeCoffeeListViewModel())
            }
            // MapViewModelBridge を 1 度だけ生成する（uid が必要）
            if mapBridge == nil {
                mapBridge = MapViewModelBridge(viewModel: container.makeMapViewModel(userId: uid))
            }
            // AccountViewModelBridge を 1 度だけ生成する
            if accountBridge == nil {
                accountBridge = AccountViewModelBridge(viewModel: container.makeAccountViewModel())
            }
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

    /// サインアウト / アカウント削除後に全ブリッジをリセットして再起動する。
    ///
    /// - `coffeeListBridge` / `mapBridge` / `accountBridge` / `uid` を nil に戻す
    /// - `status = .idle` にして `AppRootView` をローディング表示に切り替える
    /// - 再度 `bootstrap()` を呼んで新規匿名 uid を確定する
    func resetAndRebootstrap() {
        coffeeListBridge?.onDisappear()
        mapBridge?.cancel()
        accountBridge?.onDisappear()

        coffeeListBridge = nil
        mapBridge = nil
        accountBridge = nil
        uid = nil
        status = .idle
        lastError = nil

        Task { [weak self] in
            await self?.bootstrap()
        }
    }
}
