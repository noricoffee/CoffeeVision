import Foundation
import Observation
import SharedLogic

/// マップタブのカメラ中心を検索タブへ共有するための値型。
///
/// `MapTabView` の `.onMapCameraChange` で生成し `AppState.mapSearchCenter` に代入する。
/// `CafeSearchView` はこれを位置バイアスとして `onSearchTapped(latitude:longitude:radiusMeters:)` に渡す。
struct MapSearchCenter {
    let latitude: Double
    let longitude: Double
    /// Places API の locationBias circle 半径（メートル）。`1...50_000` にクランプ済み。
    let radiusMeters: Double
}

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

    /// AnalysisView 用の ViewModel ブリッジ。
    ///
    /// 分析タブは TabBar 常時生存のため `mapBridge` と同等のライフサイクルで管理する。
    /// `bootstrap()` 完了後（uid 確定後）に 1 度だけ生成する。
    private(set) var analysisBridge: AnalysisViewModelBridge?

    /// Google Places Photo Media API から写真 URL を取得するローダー。
    ///
    /// uid 不要なので `init` で即座に生成する（`bootstrap()` 前から利用可能）。
    private(set) var placePhotoLoader: PlacePhotoLoader

    /// マップタブのカメラ中心（検索タブへの位置バイアス共有用）。
    ///
    /// `MapTabView` の `.onMapCameraChange(frequency: .onEnd)` が更新し、
    /// `CafeSearchView` がテキスト検索時の位置バイアスとして参照する。
    /// カメラが未移動の場合は nil（バイアスなし検索にフォールバック）。
    var mapSearchCenter: MapSearchCenter?

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

        // Foundation Models の可否を判定し、利用可能なときだけ Provider を注入する。
        // iOS 26 未満 / Apple Intelligence 無効 / 非対応端末では nil を渡す。
        // AnalysisViewModel は provider == nil のとき InsightStatus.Unsupported を返す。
        //
        // 具象型（CoffeeInsightProviderIosImpl）で保持することで、container 構築後に
        // attachRecordQuery(_:) を呼べるようにする（依存サイクル解消のための遅延アタッチ）。
        let providerImpl: CoffeeInsightProviderIosImpl? = {
            if #available(iOS 26.0, *) {
                return CoffeeInsightProviderIosImpl.makeIfAvailable()
            }
            return nil
        }()

        let container = AppContainer(
            sqlDriver: sqlDriver,
            remoteCoffeeDataSource: remoteDataSource,
            authRepository: authRepo,
            placesApiKey: placesApiKey,
            coffeeInsightProvider: providerImpl
        )
        self.container = container

        // container 構築後に coffeeRecordQuery を遅延アタッチする。
        // providerImpl が nil（非対応端末）の場合は何もしない。
        if #available(iOS 26.0, *) {
            providerImpl?.attachRecordQuery(container.coffeeRecordQuery)
        }
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
            // [DEBUG] ダミーデータの seed / clear（bridge 生成前に実行し、最初の Flow emit からダミーが反映されるようにする）
            // 専用 Scheme「iosApp (Dummy Data)」で起動したときだけ seed、それ以外は clear する。
            // seed / clear は開発用途のため失敗しても致命扱いにせずログのみ出す。
            #if DEBUG
            await seedOrClearDummyData(userId: uid)
            #endif
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
            // AnalysisViewModelBridge を 1 度だけ生成する（uid が必要）
            if analysisBridge == nil {
                analysisBridge = AnalysisViewModelBridge(viewModel: container.makeAnalysisViewModel(userId: uid))
            }
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

    // MARK: - Private helpers

    /// ダミーデータを seed または clear する（DEBUG ビルド専用）。
    ///
    /// - 環境変数 `SEED_DUMMY_DATA == "1"` のとき seed（冪等 upsert）
    /// - それ以外のとき clear（固定 ID `dummy-0001`..`dummy-0030` をローカル削除）
    ///
    /// ローカル DB のみ操作し Firestore には流れない。
    /// 失敗しても致命扱いにせずログのみ出す（開発支援用途のため）。
    @MainActor
    private func seedOrClearDummyData(userId: String) async {
        if ProcessInfo.processInfo.environment["SEED_DUMMY_DATA"] == "1" {
            do {
                try await container.seedDummyData(userId: userId)
                print("[CoffeeVision] seedDummyData succeeded uid=\(userId)")
            } catch {
                print("[CoffeeVision] seedDummyData failed (ignored): \(error)")
            }
        } else {
            do {
                try await container.clearDummyData(userId: userId)
                print("[CoffeeVision] clearDummyData succeeded uid=\(userId)")
            } catch {
                print("[CoffeeVision] clearDummyData failed (ignored): \(error)")
            }
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
        analysisBridge?.cancel()

        coffeeListBridge = nil
        mapBridge = nil
        accountBridge = nil
        analysisBridge = nil
        uid = nil
        status = .idle
        lastError = nil

        Task { [weak self] in
            await self?.bootstrap()
        }
    }
}
