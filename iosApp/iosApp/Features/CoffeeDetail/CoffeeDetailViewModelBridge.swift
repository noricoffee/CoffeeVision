import Observation
import SharedLogic

/// `CoffeeDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear(coffeeId:userId:)` / `onDisappear()` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 詳細画面は画面遷移ごとに新規インスタンスを生成するため
///   `CoffeeDetailView` 内の `@State` で保持する（AppState にはホルダプロパティを持たせない）
@MainActor
@Observable
final class CoffeeDetailViewModelBridge {

    private let kotlin: CoffeeDetailViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var coffee: CoffeeRecord?
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    private(set) var isDeleted: Bool = false

    /// [onDeleteTapped] 呼び出し時点の写真ファイル名。KMP 側の削除成功（[isDeleted]）が
    /// `apply(_:)` で確認できてから物理削除する（削除失敗時に写真だけ消えるのを防ぐため。
    /// `CoffeeListViewModelBridge` の pending 方式と同じ安全順序、対象が 1 レコードのみのため
    /// 辞書ではなく単一の Optional で保持する）。
    private var pendingPhotoFileNames: [String]?

    // MARK: - Init

    init(kotlin: CoffeeDetailViewModel) {
        self.kotlin = kotlin
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`coffeeId` に対応するコーヒー記録の購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// 複数回呼ばれても二重購読しない。
    func onAppear(coffeeId: String, userId: String) {
        kotlin.onAppear(coffeeId: coffeeId, userId: userId)
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

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    /// 削除を確定する。呼び出し時点の写真ファイル名を控えてから Kotlin 側の削除を実行し、
    /// KMP 側の削除成功（`apply(_:)` で `isDeleted == true` を確認）後にのみ物理削除する。
    func onDeleteTapped() {
        let fileNames = coffee?.photos.compactMap(\.fileName) ?? []
        if !fileNames.isEmpty {
            pendingPhotoFileNames = fileNames
        }
        kotlin.onDeleteTapped()
    }

    // MARK: - Private

    private func apply(_ state: CoffeeDetailViewModel.UIState) {
        self.coffee = state.coffee
        self.isLoading = state.isLoading
        self.error = state.error
        self.isDeleted = state.isDeleted

        if state.isDeleted, let fileNames = pendingPhotoFileNames {
            for fileName in fileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            pendingPhotoFileNames = nil
        }
    }
}
