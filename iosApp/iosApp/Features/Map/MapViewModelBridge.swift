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
    /// 検索タブからのオーバーレイ表示用。空 = 表示なし。
    private(set) var searchResultPlaces: [Cafe] = []
    private(set) var error: String?
    /// 選択中のタグフィルター。
    private(set) var selectedTags: [String] = []
    /// 利用可能なタグの distinct ソート済みリスト。
    private(set) var availableTags: [String] = []
    /// テイストフィルタが active なときのマッチカフェ placeId 集合。空 = フィルタ未設定。
    private(set) var tasteMatchedPlaceIds: Set<String> = []
    /// アクティブなテイストフィルタ下限（nil = 未設定）。
    private(set) var activeTastingMin: TastingScores? = nil
    /// アクティブなテイストフィルタ上限（nil = 未設定）。
    private(set) var activeTastingMax: TastingScores? = nil
    /// 「行きたい店」（savedAt 降順。フェーズ 15-A）。マップピン / 一覧シート用。
    private(set) var savedCafes: [SavedCafe] = []
    /// 記録済み（コーヒー記録が 1 件以上ある）カフェの placeId 集合。一覧シートの「記録あり」バッジ用。
    private(set) var recordedPlaceIds: Set<String> = []

    // MARK: - POI ルックアップ状態

    private(set) var isLookingUpPoi: Bool = false
    private(set) var poiLookupResult: Cafe? = nil
    private(set) var poiLookupError: String? = nil

    // MARK: - Init

    init(viewModel: MapViewModel) {
        self.kotlin = viewModel
        startObservation()
    }

    deinit {
        kotlin.clear()
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

    /// 検索タブから検索結果カフェを受け取り、マップオーバーレイに反映する。
    func onSearchResultsUpdated(_ cafes: [Cafe]) {
        kotlin.onSearchResultsUpdated(cafes: cafes)
    }

    /// 検索タブの結果クリア時にマップオーバーレイをリセットする。
    func onSearchResultsCleared() {
        kotlin.onSearchResultsCleared()
    }

    // MARK: - テイストフィルターアクション

    /// 「今飲みたい味」テイストプロファイルフィルタを更新する。
    /// 両方 nil でフィルタ解除。
    func onTasteProfileChanged(tastingMin: TastingScores?, tastingMax: TastingScores?) {
        kotlin.onTasteProfileChanged(tastingMin: tastingMin, tastingMax: tastingMax)
    }

    // MARK: - タグフィルターアクション

    /// タグフィルターのオン / オフを切り替える。
    func onTagFilterToggled(_ tag: String) {
        kotlin.onTagFilterToggled(tag: tag)
    }

    /// タグフィルターをすべてクリアする。
    func onTagFilterCleared() {
        kotlin.onTagFilterCleared()
    }

    // MARK: - 「行きたい店」アクション（フェーズ 15-A）

    /// 一覧シートでのスワイプ解除操作を受ける。
    func onSavedCafeRemoved(placeId: String) {
        kotlin.onSavedCafeRemoved(placeId: placeId)
    }

    /// マップ下部カードの保存トグルボタンから呼ぶ（フェーズ 16）。
    /// 保存済みなら解除、未保存なら保存する（Kotlin 側で判定）。
    func onCafeSaveToggled(cafe: Cafe) {
        kotlin.onCafeSaveToggled(cafe: cafe)
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
        self.searchResultPlaces = state.searchResultPlaces
        self.selectedTags = Array(state.selectedTags)
        self.availableTags = state.availableTags
        // state.tasteMatchedPlaceIds は SKIE が Set<String> に変換済み（recommendedPlaceIds と同等）。
        // KotlinMutableSet<NSString> として現れる場合は
        // Set(state.tasteMatchedPlaceIds.compactMap { $0 as? String }) に変更する。
        self.tasteMatchedPlaceIds = state.tasteMatchedPlaceIds
        self.activeTastingMin = state.activeTastingMin
        self.activeTastingMax = state.activeTastingMax
        self.savedCafes = state.savedCafes
        self.recordedPlaceIds = state.recordedPlaceIds
    }
}
