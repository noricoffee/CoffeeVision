import Observation
import SharedLogic

/// `CoffeeDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - 観測は `observe(coffeeId:userId:)`（構造化 `Task`。`CoffeeDetailView` の `.task` から呼ぶ）
///   が担う。ブリッジ自身は `Task` を保持しない（B-11）
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 詳細画面は画面遷移ごとに新規インスタンスを生成するため
///   `CoffeeDetailView` 内の `@State` で保持する（AppState にはホルダプロパティを持たせない）
@MainActor
@Observable
final class CoffeeDetailViewModelBridge {

    private let kotlin: CoffeeDetailViewModel

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

    /// `coffeeId` に対応するコーヒー記録の購読を開始する。`CoffeeDetailView` の `.task` から呼ぶ
    /// （構造化 `Task`）。
    func observe(coffeeId: String, userId: String) async {
        kotlin.onAppear(coffeeId: coffeeId, userId: userId)
        for await state in kotlin.state {
            apply(state)
        }
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
        // `@Observable` は値を比較せず、代入するだけで observer に変更を通知するため、
        // 同値の再代入で無駄な body 再評価が走る。実際に変わった分だけ通知する（SL-3）。
        // `CoffeeRecord` は Kotlin の `data class` で Obj-C 側に `equals()` 由来の `isEqual:` を
        // 持つため `==` が値比較になる。
        if coffee != state.coffee {
            coffee = state.coffee
        }
        if isLoading != state.isLoading {
            isLoading = state.isLoading
        }
        if error != state.error {
            error = state.error
        }
        if isDeleted != state.isDeleted {
            isDeleted = state.isDeleted
        }

        if state.isDeleted, let fileNames = pendingPhotoFileNames {
            for fileName in fileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            pendingPhotoFileNames = nil
        }
    }
}
