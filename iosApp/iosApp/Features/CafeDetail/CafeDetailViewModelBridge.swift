import Observation
import SharedLogic

/// `CafeDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `VisitDetailViewModelBridge` と同じパターンで、push ごとに新規インスタンスを生成する
/// - `CafeDetailView` 内の `@State` で保持する（AppState にホルダを持たせない）
/// - Phase 7 以降: UIState.coffees は `[CoffeeRecord]`（旧 `[Visit_]` から変更）
@MainActor
@Observable
final class CafeDetailViewModelBridge {

    private let kotlin: CafeDetailViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var cafe: Cafe?
    /// Kotlin の `List<CoffeeRecord>` は SKIE 経由で Swift では `[CoffeeRecord]` 型
    private(set) var coffees: [CoffeeRecord] = []
    private(set) var isLoading: Bool = true

    // MARK: - Init

    init(viewModel: CafeDetailViewModel) {
        self.kotlin = viewModel
        startObservation()
    }

    deinit {
        kotlin.clear()
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

    private func apply(_ state: CafeDetailViewModel.UIState) {
        self.cafe = state.cafe
        self.coffees = state.coffees
        self.isLoading = state.isLoading
    }
}
