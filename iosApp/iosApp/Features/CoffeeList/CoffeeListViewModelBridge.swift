import Observation
import SharedLogic

// MARK: - Identifiable 拡張

extension CoffeeRecord: @retroactive Identifiable {}

/// `CoffeeListViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear` / `onDisappear` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
@MainActor
@Observable
final class CoffeeListViewModelBridge {

    private let kotlin: CoffeeListViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var coffees: [CoffeeRecord] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    /// coffeeId → 削除待ちの写真ファイル名。
    ///
    /// `onCoffeeDeleted(id:photoFileNames:)` で登録し、`apply(_:)` で `coffees` から
    /// 当該 id が消えたのを確認してから物理削除する（KMP 側の削除が失敗しても写真だけ
    /// 消えてしまう順序バグを避けるため）。KMP 側で削除が失敗しレコードが残存する場合は
    /// pending に残り続ける（孤児ファイルより写真消失の方が害が大きいため、安全側の選択）。
    private var pendingPhotoDeletions: [String: [String]] = [:]

    // MARK: - Init

    init(kotlin: CoffeeListViewModel) {
        self.kotlin = kotlin
    }

    deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。userId でコーヒー記録の購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// タブ切り替えなどで複数回呼ばれても二重購読しない。
    func onAppear(userId: String) {
        kotlin.onAppear(userId: userId)
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
    }

    // MARK: - ユーザーアクション

    /// コーヒー記録を削除する。紐付く写真ファイルは、KMP 側の削除が確認できてから
    /// `apply(_:)` 内で物理削除する（削除失敗時に写真だけ消えるのを防ぐため）。
    func onCoffeeDeleted(id: String, photoFileNames: [String]) {
        if !photoFileNames.isEmpty {
            pendingPhotoDeletions[id] = photoFileNames
        }
        kotlin.onCoffeeDeleted(id: id)
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: CoffeeListViewModel.UIState) {
        // SKIE 環境では state.coffees は既に [CoffeeRecord] として型付けされている
        self.coffees = state.coffees
        self.isLoading = state.isLoading
        self.error = state.error

        resolvePendingPhotoDeletions()
    }

    /// `coffees` から消えた id の pending 写真を物理削除し、pending から取り除く。
    private func resolvePendingPhotoDeletions() {
        guard !pendingPhotoDeletions.isEmpty else { return }
        let remainingIds = Set(coffees.map(\.id))
        for (coffeeId, fileNames) in pendingPhotoDeletions where !remainingIds.contains(coffeeId) {
            for fileName in fileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            pendingPhotoDeletions.removeValue(forKey: coffeeId)
        }
    }
}
