import Observation
import SharedLogic

/// `CoffeeEditorViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear(mode:userId:)` / `onDisappear()` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 画面遷移ごとに新規インスタンスを生成するため `CoffeeEditorView` 内の `@State` で保持する
@MainActor
@Observable
final class CoffeeEditorViewModelBridge {

    private let kotlin: CoffeeEditorViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var draft: CoffeeEditorViewModel.CoffeeDraft = CoffeeEditorViewModel.companion.defaultDraft()
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var error: String?
    private(set) var savedCoffeeId: String?

    // MARK: - Init

    init(kotlin: CoffeeEditorViewModel) {
        self.kotlin = kotlin
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`mode` と `userId` を受け取り初期 draft を設定する。
    func onAppear(mode: any CoffeeEditorViewModelMode, userId: String) {
        kotlin.onAppear(mode: mode, userId: userId)
        observationTask?.cancel()
        let flow = kotlin.state
        observationTask = Task { [weak self] in
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

    // MARK: - フィールド更新転送（cafe 関連）

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

    // MARK: - フィールド更新転送（記録本体）

    func onVisitedOnChanged(_ date: Kotlinx_datetimeLocalDate) {
        kotlin.onVisitedOnChanged(date: date)
    }

    func onRatingChanged(rating: Double) {
        kotlin.onRatingChanged(rating: rating)
    }

    func onNotesChanged(_ text: String) {
        kotlin.onNotesChanged(text: text)
    }

    // MARK: - フィールド更新転送（コーヒー属性）

    func onNameChanged(_ name: String) {
        kotlin.onNameChanged(name: name)
    }

    func onBrewMethodChanged(_ brewMethod: BrewMethod) {
        kotlin.onBrewMethodChanged(brewMethod: brewMethod)
    }

    func onOriginChanged(_ origin: String) {
        kotlin.onOriginChanged(origin: origin)
    }

    func onVarietyChanged(_ variety: String) {
        kotlin.onVarietyChanged(variety: variety)
    }

    func onProcessingChanged(_ processing: ProcessingMethod?) {
        kotlin.onProcessingChanged(processing: processing)
    }

    func onRoastLevelChanged(_ roastLevel: RoastLevel?) {
        kotlin.onRoastLevelChanged(roastLevel: roastLevel)
    }

    func onCupChanged(_ cup: String) {
        kotlin.onCupChanged(cup: cup)
    }

    // MARK: - テイスティング転送

    func onSweetnessChanged(_ value: KotlinInt?) {
        kotlin.onSweetnessChanged(value: value)
    }

    func onBodyChanged(_ value: KotlinInt?) {
        kotlin.onBodyChanged(value: value)
    }

    func onAcidityChanged(_ value: KotlinInt?) {
        kotlin.onAcidityChanged(value: value)
    }

    func onFlavorChanged(_ value: KotlinInt?) {
        kotlin.onFlavorChanged(value: value)
    }

    func onAftertasteChanged(_ value: KotlinInt?) {
        kotlin.onAftertasteChanged(value: value)
    }

    // MARK: - 写真操作転送

    func onPhotoUpserted(item: Photo_) {
        kotlin.onPhotoUpserted(item: item)
    }

    func onPhotoRemoved(id: String) {
        kotlin.onPhotoRemoved(id: id)
    }

    // MARK: - Places API 統合

    /// Places API 検索でカフェを選択した際に呼ぶ。
    func onPlacesCafeSelected(cafe: Cafe) {
        kotlin.onPlacesCafeSelected(cafe: cafe)
    }

    // MARK: - 保存 / エラー転送

    func onSaveTapped() {
        kotlin.onSaveTapped()
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: CoffeeEditorViewModel.UIState) {
        self.draft = state.draft
        self.isLoading = state.isLoading
        self.isSaving = state.isSaving
        self.error = state.error
        self.savedCoffeeId = state.savedCoffeeId
    }
}
