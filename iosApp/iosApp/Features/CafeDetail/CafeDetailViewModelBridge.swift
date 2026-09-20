import Observation
import SharedLogic

/// `CafeDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - push ごとに新規インスタンスを生成する
/// - `CafeDetailView` 内の `@State` で保持する（AppState にホルダを持たせない）
/// - 観測は `observe()`（構造化 `Task`。`CafeDetailView` の `.task` から呼ぶ）が担う。
///   ブリッジ自身は `Task` を保持しない（B-11）
/// - Phase 7 以降: UIState.coffees は `[CoffeeRecord]`（旧 `[Visit_]` から変更）
@MainActor
@Observable
final class CafeDetailViewModelBridge {

    private let kotlin: CafeDetailViewModel

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var cafe: Cafe?
    /// Kotlin の `List<CoffeeRecord>` は SKIE 経由で Swift では `[CoffeeRecord]` 型
    private(set) var coffees: [CoffeeRecord] = []
    private(set) var isLoading: Bool = true
    /// 「行きたい店」として保存済みか（フェーズ 15-A）。ブックマークボタンの ON/OFF 表示用。
    private(set) var isSaved: Bool = false
    /// このカフェが好み一致である理由。一致なしは空リスト（マップから移設。フェーズ 20）。
    private(set) var matches: [RecommendationReason] = []
    /// 保存 / 解除操作で発生したエラーメッセージ。`onErrorDismissed()` で nil に戻る。
    private(set) var error: String?

    // MARK: - Init

    init(viewModel: CafeDetailViewModel) {
        self.kotlin = viewModel
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// state 購読を開始する。`CafeDetailView` の `.task` から呼ぶ（構造化 `Task`）。
    func observe() async {
        for await state in kotlin.state {
            apply(state)
        }
    }

    // MARK: - ユーザーアクション

    /// 「行きたい」ブックマークボタンのトグル操作を受ける。
    func onSaveToggled() {
        kotlin.onSaveToggled()
    }

    /// エラートーストを閉じたときに呼ぶ。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: CafeDetailViewModel.UIState) {
        // `@Observable` は値を比較せず、代入するだけで observer に変更を通知するため、
        // 同値の再代入で無駄な body 再評価が走る。実際に変わった分だけ通知する（SL-3）。
        // `Cafe` / `CoffeeRecord` は Kotlin の `data class` で Obj-C 側に `equals()` 由来の
        // `isEqual:` を持つため `==` が値比較になる。
        if cafe != state.cafe {
            cafe = state.cafe
        }
        if coffees != state.coffees {
            coffees = state.coffees
        }
        if isLoading != state.isLoading {
            isLoading = state.isLoading
        }
        if isSaved != state.isSaved {
            isSaved = state.isSaved
        }
        // `matches` は同値ガードを入れられない: 要素の `RecommendationReason` は SKIE が
        // Obj-C プロトコルとして生成するため `[any RecommendationReason]` になり `Equatable`
        // 非準拠。実体（`TasteProfileMatch`）は算出のたびに新インスタンスになるので参照比較も
        // 効かない。KMP 側で `matches` を `Equatable` な形にしない限り無条件代入のままにする。
        matches = state.matches
        if error != state.error {
            error = state.error
        }
    }
}
