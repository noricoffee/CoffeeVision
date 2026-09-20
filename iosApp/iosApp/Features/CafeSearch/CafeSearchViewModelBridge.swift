import Observation
import SharedLogic

/// `CafeSearchViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - 観測は `observe()`（構造化 `Task`）が担う。ブリッジ自身は `Task` を保持しない（B-11）
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 生成箇所は 2 つ: `CafeSearchView` の `@State`（sheet 起動ごとに新規生成・破棄。
///   `.task { await bridge.observe() }` で観測開始）と `MapSearchController.searchBridge`
///   （`MapTabView` の `.task` から `MapSearchController.setupAndObserve(makeViewModel:)`
///   経由で生成・観測開始。`MapTabView` の `.task` が再実行されるたびに `observe()` が
///   再購読される）
@MainActor
@Observable
final class CafeSearchViewModelBridge {

    private let kotlin: CafeSearchViewModel

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var query: String = ""
    private(set) var results: [Cafe] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    /// 検索が一度でも確定実行されたかどうか。
    /// `onQueryChanged` で false に戻り、`onSearchTapped` / `onNearbySearchRequested` の
    /// 成功完了で true になる（Kotlin 側の `UIState.hasSearched` を反映）。
    private(set) var hasSearched: Bool = false

    // MARK: - Init

    init(kotlin: CafeSearchViewModel) {
        self.kotlin = kotlin
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// state 購読を開始する。呼び出し元の `.task` から呼ぶ（構造化 `Task`）。
    func observe() async {
        for await state in kotlin.state {
            apply(state)
        }
    }

    // MARK: - ユーザーアクション

    /// 検索クエリを更新する。検索は実行しない（`onSearchTapped` で実行）。
    func onQueryChanged(_ query: String) {
        kotlin.onQueryChanged(query: query)
    }

    /// 検索を実行する。現在の `query` で Places API を叩く（位置バイアスなし）。
    func onSearchTapped() {
        kotlin.onSearchTapped()
    }

    /// 位置バイアス付きで検索を実行する。
    ///
    /// マップタブのカメラ中心を位置バイアスとして渡し、指定エリア寄りの結果を返させる。
    /// Kotlin 側の `onSearchTapped(latitude:longitude:radiusMeters:)` に転送する。
    ///
    /// - Parameters:
    ///   - latitude: 位置バイアスの緯度（`MapSearchCenter.latitude`）
    ///   - longitude: 位置バイアスの経度（`MapSearchCenter.longitude`）
    ///   - radiusMeters: 位置バイアスの半径（メートル、1...50_000）
    func onSearchTapped(latitude: Double, longitude: Double, radiusMeters: Double) {
        kotlin.onSearchTapped(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    /// エラーアラートを閉じる。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    /// 現在地周辺のカフェを検索する。`CafeSearchViewModel.onNearbySearchRequested` に転送する。
    ///
    /// - Parameters:
    ///   - latitude: 現在地の緯度（CoreLocation から取得）
    ///   - longitude: 現在地の経度（CoreLocation から取得）
    func onNearbySearchRequested(latitude: Double, longitude: Double) {
        kotlin.onNearbySearchRequested(latitude: latitude, longitude: longitude)
    }

    /// 指定エリア（マップ表示範囲）に応じた半径でカフェを検索する。「このエリアを検索」から呼ぶ。
    ///
    /// - Parameters:
    ///   - latitude: 検索中心の緯度（マップの表示範囲の中心）
    ///   - longitude: 検索中心の経度（マップの表示範囲の中心）
    ///   - radiusMeters: 検索半径（メートル）。マップの表示範囲から算出して渡す
    func onNearbySearchRequested(latitude: Double, longitude: Double, radiusMeters: Double) {
        kotlin.onNearbySearchRequested(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    // MARK: - Private

    private func apply(_ state: CafeSearchViewModel.UIState) {
        // `@Observable` は値を比較せず、代入するだけで observer に変更を通知するため、
        // 同値の再代入で無駄な body 再評価が走る。実際に変わった分だけ通知する（SL-3）。
        // `Cafe` は Kotlin の `data class` で Obj-C 側に `equals()` 由来の `isEqual:` を
        // 持つため `==` が値比較になる。
        if query != state.query {
            query = state.query
        }
        if results != state.results {
            results = state.results
        }
        if isLoading != state.isLoading {
            isLoading = state.isLoading
        }
        if error != state.error {
            error = state.error
        }
        if hasSearched != state.hasSearched {
            hasSearched = state.hasSearched
        }
    }
}
