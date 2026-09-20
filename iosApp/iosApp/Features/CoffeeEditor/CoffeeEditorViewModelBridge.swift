import Observation
import SharedLogic

/// `CoffeeEditorViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 画面遷移ごとに新規インスタンスを生成するため `CoffeeEditorView` 内の `@State` で保持する
/// - ライフサイクルは 2 メソッドに分かれる（他ブリッジと異なり `onAppear` と `observe` を
///   1 本化していない）。理由: `CoffeeEditorView` の `.task` は `onAppear` 相当の同期初期化の
///   **後に** カフェ pre-fill / 現在地サジェストの追加処理を挟んでから observation へ入る必要が
///   あり、`observe()` 自体は `kotlin.state` を purge するまで返らない（呼び出し元をブロックする）
///   ため、両方を 1 メソッドに畳むとその追加処理が実行されなくなる:
///   - `onAppear(mode:userId:)`: 同期。`kotlin.onAppear` を転送するだけ
///   - `observe()`: 非同期。state 購読のみ（構造化 `Task`。B-11）
@MainActor
@Observable
final class CoffeeEditorViewModelBridge {

    private let kotlin: CoffeeEditorViewModel

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var draft: CoffeeEditorViewModel.CoffeeDraft = CoffeeEditorViewModel.companion.defaultDraft()
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var error: String?
    private(set) var savedCoffeeId: String?
    private(set) var tags: [String] = []
    private(set) var suggestedCafes: [Cafe] = []
    private(set) var tagInput: String = ""
    private(set) var suggestedTags: [String] = []

    // MARK: - Init

    init(kotlin: CoffeeEditorViewModel) {
        self.kotlin = kotlin
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`mode` と `userId` を受け取り初期 draft を設定する（同期処理のみ）。
    ///
    /// `CoffeeEditorView` の `.task` から、カフェ pre-fill / 現在地サジェストより前に呼ぶ。
    func onAppear(mode: any CoffeeEditorViewModelMode, userId: String) {
        kotlin.onAppear(mode: mode, userId: userId)
    }

    /// state 購読を開始する。`CoffeeEditorView` の `.task` から `onAppear` の後に呼ぶ
    /// （構造化 `Task`。B-11）。
    func observe() async {
        for await state in kotlin.state {
            apply(state)
        }
    }

    /// 画面非表示時に呼ぶ。Kotlin 側の進行中 Job（load / save / タグカタログ購読）をキャンセルする。
    ///
    /// observation（`observe()`）の停止は `.task` の構造化キャンセルに委ねるため、ここでは触らない。
    func onDisappear() {
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

    /// 評価を変更する。`nil` = 未評価に戻す（2026-07-12 B-4 nullable 化）。
    func onRatingChanged(rating: Double?) {
        kotlin.onRatingChanged(rating: rating.map { KotlinDouble(value: $0) })
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

    /// エリア / 農園（任意自由入力）を変更する。origin から分離（2026-07-22 追加）。
    func onRegionChanged(_ region: String) {
        kotlin.onRegionChanged(region: region)
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

    func onBrewRecipeChanged(_ brewRecipe: String) {
        kotlin.onBrewRecipeChanged(brewRecipe: brewRecipe)
    }

    // MARK: - テイスティング転送（all-or-nothing）

    /// テイスティングを追加する。KMP 側でデフォルト値 TastingScores(5,5,5,5,5) が生成される。
    func onTastingAdded() {
        kotlin.onTastingAdded()
    }

    /// テイスティングを削除する（draft.tasting を nil に戻す）。
    func onTastingCleared() {
        kotlin.onTastingCleared()
    }

    /// 甘味を変更する。draft.tasting が nil の場合は no-op。
    func onSweetnessChanged(_ value: Int32) {
        kotlin.onSweetnessChanged(value: value)
    }

    /// ボディを変更する。draft.tasting が nil の場合は no-op。
    func onBodyChanged(_ value: Int32) {
        kotlin.onBodyChanged(value: value)
    }

    /// 酸味を変更する。draft.tasting が nil の場合は no-op。
    func onAcidityChanged(_ value: Int32) {
        kotlin.onAcidityChanged(value: value)
    }

    /// 風味を変更する。draft.tasting が nil の場合は no-op。
    func onFlavorChanged(_ value: Int32) {
        kotlin.onFlavorChanged(value: value)
    }

    /// 後味を変更する。draft.tasting が nil の場合は no-op。
    func onAftertasteChanged(_ value: Int32) {
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

    // MARK: - 現在地カフェサジェスト（要件 2-8）

    /// 現在地座標が取得できたときに呼ぶ。Create モード かつ cafe 未選択のときのみ KMP 側でサジェストが反映される。
    func onLocationAvailable(latitude: Double, longitude: Double) {
        kotlin.onLocationAvailable(latitude: latitude, longitude: longitude)
    }

    /// サジェストチップをタップした際に呼ぶ。
    func onSuggestedCafeSelected(cafe: Cafe) {
        kotlin.onSuggestedCafeSelected(cafe: cafe)
    }

    // MARK: - 保存 / エラー転送

    func onSaveTapped() {
        kotlin.onSaveTapped()
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - タグ操作転送

    func onTagAdded(_ tag: String) {
        kotlin.onTagAdded(tag: tag)
    }

    func onTagRemoved(_ tag: String) {
        kotlin.onTagRemoved(tag: tag)
    }

    /// タグ入力欄が変化したときに呼ぶ（過去タグサジェストの絞り込み。要件 2-13）。
    func onTagInputChanged(_ text: String) {
        kotlin.onTagInputChanged(text: text)
    }

    // MARK: - Private

    private func apply(_ state: CoffeeEditorViewModel.UIState) {
        self.draft = state.draft
        self.isLoading = state.isLoading
        self.isSaving = state.isSaving
        self.error = state.error
        self.savedCoffeeId = state.savedCoffeeId
        self.tags = state.draft.tags
        self.suggestedCafes = state.suggestedCafes
        self.tagInput = state.tagInput
        self.suggestedTags = state.suggestedTags
    }
}
