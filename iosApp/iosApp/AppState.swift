import Foundation
import Observation
import FirebaseAnalytics
import FirebaseFirestore
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

    /// データ共有同意オンボーディングを表示するか。
    ///
    /// `bootstrap()` 後に Firestore `users/{uid}` ドキュメントが存在しない（初回ユーザー）ときに `true` に設定される。
    /// `onConsentGranted()` / `onConsentDeclined()` で `false` に戻る。
    var showConsentOnboarding: Bool = false

    /// データ共有への同意状態。Firestore `users/{uid}.analyticsConsent` と同期する。
    ///
    /// `didSet` で Firebase Analytics の収集可否（`applyTelemetryConsent(_:)`）へ一元的に反映する。
    /// 代入箇所は `checkConsentOnboarding`（初回読み込み）と `writeAnalyticsConsent`（変更）の 2 箇所のみ。
    /// `init` 時点の既定値代入では `didSet` は発火しないため、起動直後は
    /// `Info.plist` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO` がそのまま効く。
    private(set) var analyticsConsent: Bool = false {
        didSet {
            applyTelemetryConsent(analyticsConsent)
        }
    }

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
        let remoteSavedCafeDataSource = RemoteSavedCafeDataSourceIosImpl()
        // Configuration/Base.xcconfig → Info.plist の $(PLACES_API_KEY) 経由で取得する。
        // Secrets.xcconfig が存在しない場合（CI 環境等）は空文字フォールバック。
        // 空文字の場合もアプリは起動するが Places API 呼び出しは 401 を返す。
        let placesApiKey = (Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String) ?? ""

        // Foundation Models の可否を判定し、利用可能なときだけ Provider を注入する。
        // Apple Intelligence 無効 / 非対応端末では nil を渡す。
        // AnalysisViewModel は provider == nil のとき InsightStatus.Unsupported を返す。
        //
        // 具象型（CoffeeInsightProviderIosImpl）で保持することで、container 構築後に
        // attachRecordQuery(_:) を呼べるようにする（依存サイクル解消のための遅延アタッチ）。
        let providerImpl: CoffeeInsightProviderIosImpl? = CoffeeInsightProviderIosImpl.makeIfAvailable()

        let container = AppContainer(
            sqlDriver: sqlDriver,
            remoteCoffeeDataSource: remoteDataSource,
            remoteSavedCafeDataSource: remoteSavedCafeDataSource,
            authRepository: authRepo,
            placesApiKey: placesApiKey,
            coffeeInsightProvider: providerImpl,
            beanProfileRepository: BeanProfileRepositoryIosImpl()
        )
        self.container = container

        // container 構築後に coffeeRecordQuery を遅延アタッチする。
        // providerImpl が nil（非対応端末）の場合は何もしない。
        providerImpl?.attachRecordQuery(container.coffeeRecordQuery)
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

    // MARK: - データ共有同意

    /// ユーザーがデータ共有に同意したときに呼ぶ。
    func onConsentGranted() {
        showConsentOnboarding = false
        Task { [weak self] in
            await self?.writeAnalyticsConsent(true)
        }
    }

    /// ユーザーがデータ共有を断ったときに呼ぶ。
    func onConsentDeclined() {
        showConsentOnboarding = false
        Task { [weak self] in
            await self?.writeAnalyticsConsent(false)
        }
    }

    /// Settings から同意状態を変更するときに呼ぶ。
    func updateAnalyticsConsent(_ consent: Bool) {
        Task { [weak self] in
            await self?.writeAnalyticsConsent(consent)
        }
    }

    /// 匿名サインイン + 同期購読を起動する。`AppRootView` の `.task` から呼ぶ。
    ///
    /// 成功時に `coffeeListBridge` / `mapBridge` / `accountBridge` を 1 度だけ生成する。
    /// 既に生成済み（bootstrap 再呼び出し）の場合は再生成しない。
    ///
    /// `self.uid` / `self.status = .ready` の代入は関数の最後まで遅らせる。
    /// これらは AppRootView の画面切り替えトリガーであり、先に代入すると
    /// loadingView の `.task` がキャンセルされ、`checkConsentOnboarding` が
    /// `CancellationError` で中断し初回同意オンボーディングが出ない timing バグになるため。
    func bootstrap() async {
        // resetAndRebootstrap() が Task { bootstrap() } を起動しつつ status = .idle にするため、
        // AppRootView の loadingView `.task` からも bootstrap() が走り、
        // startInitialSync() が並行 2 回呼ばれ得る。再入を防ぐ。
        guard status != .signingIn else { return }
        status = .signingIn
        do {
            let uid = try await container.startInitialSync()
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
            await checkConsentOnboarding(uid: uid)
            // 状態の公開はここで最後に行う（uid != nil が RootTabView への切り替えトリガーのため）
            self.uid = uid
            self.status = .ready
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

    // MARK: - Private helpers

    /// Analytics（同意ゲート対象）にのみ同意状態を反映する。
    ///
    /// Crashlytics / Performance は常時収集のためここでは触らない
    /// （安定性・技術品質の正当利益として同意不要と整理済み。詳細は `implementation_note.md` 2026-07-08）。
    private func applyTelemetryConsent(_ consent: Bool) {
        Analytics.setAnalyticsCollectionEnabled(consent)
    }

    /// Firestore `users/{uid}` の存在確認。
    ///
    /// - ドキュメントが存在しない（初回ユーザー）→ オンボーディングを表示
    /// - ドキュメントが存在する → `analyticsConsent` フィールドを読んで状態を更新
    private func checkConsentOnboarding(uid: String) async {
        let docRef = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await docRef.getDocument()
            if snapshot.exists {
                analyticsConsent = snapshot.data()?["analyticsConsent"] as? Bool ?? false
            } else {
                showConsentOnboarding = true
            }
        } catch {
            print("[CoffeeVision] checkConsentOnboarding failed (ignored): \(error)")
        }
    }

    /// Firestore と AppState の両方に analyticsConsent を書き込む。
    private func writeAnalyticsConsent(_ consent: Bool) async {
        analyticsConsent = consent
        do {
            try await container.authRepository.updateAnalyticsConsent(consent: consent)
        } catch {
            print("[CoffeeVision] updateAnalyticsConsent failed: \(error)")
        }
    }

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
