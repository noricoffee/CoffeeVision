import Observation
import SharedLogic

/// `MapViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `VisitListViewModelBridge` と同じ `@MainActor @Observable` + init 時購読開始パターン
/// - マップタブは TabBar 常時生存のため `AppState` で 1 つだけ保持する
///   （`visitListBridge` と同等のライフサイクル）
@MainActor
@Observable
final class MapViewModelBridge {

    private let kotlin: MapViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var visitedCafes: [VisitedCafe] = []
    private(set) var nearbyPlaces: [Cafe] = []
    private(set) var showVisited: Bool = true
    private(set) var showNearby: Bool = true
    private(set) var isLoadingNearby: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(viewModel: MapViewModel) {
        self.kotlin = viewModel
        startObservation()
    }

    // MARK: - ライフサイクル

    /// 観測タスクを明示的にキャンセルする。AppState が破棄されるときに呼ぶ。
    func cancel() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    /// 現在地が更新されたときに呼ぶ。周辺カフェを 500m 半径で検索する。
    func onLocationUpdated(lat: Double, lng: Double) {
        kotlin.onLocationUpdated(latitude: lat, longitude: lng)
    }

    /// 訪問済みカフェのピン表示 / 非表示を切り替える。
    func onShowVisitedToggled(_ show: Bool) {
        kotlin.onShowVisitedToggled(show: show)
    }

    /// 周辺カフェのピン表示 / 非表示を切り替える。
    func onShowNearbyToggled(_ show: Bool) {
        kotlin.onShowNearbyToggled(show: show)
    }

    /// エラーアラートを閉じたときに呼ぶ。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func startObservation() {
        let flow = kotlin.state
        observationTask = Task { [weak self] in
            // SKIE により StateFlow が AsyncSequence 化されている
            for await state in flow {
                guard let self else { break }
                self.apply(state)
            }
        }
    }

    private func apply(_ state: MapViewModel.UIState) {
        self.visitedCafes = state.visitedCafes
        self.nearbyPlaces = state.nearbyPlaces
        self.showVisited = state.showVisited
        self.showNearby = state.showNearby
        self.isLoadingNearby = state.isLoadingNearby
        self.error = state.error
    }
}
