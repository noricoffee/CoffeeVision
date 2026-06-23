import Foundation
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
    /// 好み一致カフェ（マップ強調ピン用）。FavoriteSignals 不足時は空。
    private(set) var recommendedCafes: [RecommendedCafe] = []
    /// 好み一致カフェの placeId 集合（ピン強調判定を O(1) にする）。
    private(set) var recommendedPlaceIds: Set<String> = []
    private(set) var showVisited: Bool = true
    private(set) var error: String?

    // MARK: - POI ルックアップ状態

    private(set) var isLookingUpPoi: Bool = false
    private(set) var poiLookupResult: Cafe? = nil
    private(set) var poiLookupError: String? = nil

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

    /// 訪問済みカフェのピン表示 / 非表示を切り替える。
    func onShowVisitedToggled(_ show: Bool) {
        kotlin.onShowVisitedToggled(show: show)
    }

    /// エラーアラートを閉じたときに呼ぶ。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - POI ルックアップアクション

    /// Apple Maps の標準 POI がタップされたときに呼ぶ。
    /// Places API で名前 + 位置バイアスによる照合を開始する。
    func onPoiTapped(name: String, latitude: Double, longitude: Double) {
        kotlin.onPoiTapped(name: name, latitude: latitude, longitude: longitude)
    }

    /// POI ルックアップ結果を画面遷移（push）で消費したあとに呼ぶ。
    /// `poiLookupResult` を nil にリセットして次のタップを受け入れる状態に戻す。
    func onPoiLookupConsumed() {
        kotlin.onPoiLookupConsumed()
    }

    /// POI ルックアップエラーアラートを閉じたときに呼ぶ。
    func onPoiLookupErrorDismissed() {
        kotlin.onPoiLookupErrorDismissed()
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
        self.recommendedCafes = state.recommendedCafes
        self.recommendedPlaceIds = state.recommendedPlaceIds
        self.showVisited = state.showVisited
        self.error = state.error
        self.isLookingUpPoi = state.isLookingUpPoi
        self.poiLookupResult = state.poiLookupResult
        self.poiLookupError = state.poiLookupError
    }
}
