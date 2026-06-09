import Observation
import SharedLogic

/// `VisitEditorViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear(mode:userId:)` / `onDisappear()` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - VisitDetail と同様に、画面遷移ごとに新規インスタンスを生成するため
///   `VisitEditorView` 内の `@State` で保持する（AppState にはホルダプロパティを持たせない）
@MainActor
@Observable
final class VisitEditorViewModelBridge {

    private let kotlin: VisitEditorViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var draft: VisitEditorViewModel.VisitDraft = VisitEditorViewModel.companion.defaultDraft()
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var error: String?
    private(set) var savedVisitId: String?

    // MARK: - Init

    init(kotlin: VisitEditorViewModel) {
        self.kotlin = kotlin
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`mode` と `userId` を受け取り初期 draft を設定する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// 複数回呼ばれても二重購読しない。
    func onAppear(mode: any VisitEditorViewModelMode, userId: String) {
        kotlin.onAppear(mode: mode, userId: userId)
        observationTask?.cancel()
        let flow = kotlin.state
        observationTask = Task { [weak self] in
            // SKIE により StateFlow が AsyncSequence 化されている
            for await state in flow {
                guard let self else { break }
                self.apply(state)
            }
        }
    }

    /// 画面非表示時に呼ぶ。観測タスクをキャンセルする。
    func onDisappear() {
        observationTask?.cancel()
        observationTask = nil
        kotlin.onDisappear()
    }

    // MARK: - フィールド更新転送

    func onCafeNameChanged(_ name: String) {
        kotlin.onCafeNameChanged(name: name)
    }

    func onCafeAddressChanged(_ address: String) {
        kotlin.onCafeAddressChanged(address: address)
    }

    func onCafeWebsiteUrlChanged(_ url: String) {
        kotlin.onCafeWebsiteUrlChanged(url: url)
    }

    func onCafeMapsUrlChanged(_ url: String) {
        kotlin.onCafeMapsUrlChanged(url: url)
    }

    func onVisitedOnChanged(_ date: Kotlinx_datetimeLocalDate) {
        kotlin.onVisitedOnChanged(date: date)
    }

    func onAmbianceChanged(_ text: String) {
        kotlin.onAmbianceChanged(text: text)
    }

    func onRatingChanged(rating: Int) {
        kotlin.onRatingChanged(rating: Int32(rating))
    }

    func onNotesChanged(_ text: String) {
        kotlin.onNotesChanged(text: text)
    }

    // MARK: - 子要素操作転送

    func onCoffeeUpserted(item: CoffeeItem) {
        kotlin.onCoffeeUpserted(item: item)
    }

    func onCoffeeRemoved(id: String) {
        kotlin.onCoffeeRemoved(id: id)
    }

    func onFoodUpserted(item: FoodItem) {
        kotlin.onFoodUpserted(item: item)
    }

    func onFoodRemoved(id: String) {
        kotlin.onFoodRemoved(id: id)
    }

    func onPhotoUpserted(item: Photo_) {
        kotlin.onPhotoUpserted(item: item)
    }

    func onPhotoRemoved(id: String) {
        kotlin.onPhotoRemoved(id: id)
    }

    // MARK: - 保存 / エラー転送

    func onSaveTapped() {
        kotlin.onSaveTapped()
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: VisitEditorViewModel.UIState) {
        self.draft = state.draft
        self.isLoading = state.isLoading
        self.isSaving = state.isSaving
        self.error = state.error
        self.savedVisitId = state.savedVisitId
    }
}
