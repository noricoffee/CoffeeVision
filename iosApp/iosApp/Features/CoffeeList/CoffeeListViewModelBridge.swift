import Observation
import SharedLogic

// MARK: - Identifiable 拡張

extension CoffeeRecord: @retroactive Identifiable {}

// MARK: - MonthSection の Identifiable 拡張

/// `yearMonth`（"YYYY-MM"）が一意なため、これを `id` として利用する。
extension CoffeeListViewModel.MonthSection: @retroactive Identifiable {
    public var id: String { yearMonth }
}

/// `CoffeeListViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - 観測は `observe(userId:)`（構造化 `Task`。`CoffeeListView` の `.task` から呼ぶ）が担う。
///   ブリッジ自身は `Task` を保持しない（B-11）
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
@MainActor
@Observable
final class CoffeeListViewModelBridge {

    private let kotlin: CoffeeListViewModel

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var sections: [CoffeeListViewModel.MonthSection] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    /// 検索クエリ。`.searchable(text:)` の Binding から get/set 両方で使う。
    ///
    /// - `set`: 入力文字を即座に `_searchQuery` へ反映（キーストロークの echo 遅延防止。
    ///   `CafeSearchView` のローカル @State パターンと同じ目的）してから
    ///   `onSearchQueryChanged(query:)` を Kotlin へ転送する。Kotlin 側の再計算結果
    ///   （同じ値のはず）は `apply(_:)` 経由で `_searchQuery` に書き戻され収束する
    var searchQuery: String {
        get { _searchQuery }
        set {
            _searchQuery = newValue
            kotlin.onSearchQueryChanged(query: newValue)
        }
    }
    private var _searchQuery: String = ""

    /// coffeeId → 削除待ちの写真ファイル名。
    ///
    /// `onCoffeeDeleted(id:photoFileNames:)` で登録し、`apply(_:)` で `sections` から
    /// 当該 id が消えたのを確認してから物理削除する（KMP 側の削除が失敗しても写真だけ
    /// 消えてしまう順序バグを避けるため）。KMP 側で削除が失敗しレコードが残存する場合は
    /// pending に残り続ける（孤児ファイルより写真消失の方が害が大きいため、安全側の選択）。
    private var pendingPhotoDeletions: [String: [String]] = [:]

    // MARK: - Init

    init(kotlin: CoffeeListViewModel) {
        self.kotlin = kotlin
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// userId でコーヒー記録の購読を開始する。`CoffeeListView` の `.task` から呼ぶ
    /// （構造化 `Task`）。
    ///
    /// タブ切り替えで View が再表示されるたびに `.task` が再実行されるため、
    /// 複数回呼ばれても構わない（都度新しい購読に張り替わる）。
    func observe(userId: String) async {
        kotlin.onAppear(userId: userId)
        for await state in kotlin.state {
            apply(state)
        }
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
        // SKIE 環境では state.sections は既に [CoffeeListViewModel.MonthSection] として型付けされている
        self.sections = state.sections
        self._searchQuery = state.searchQuery
        self.isLoading = state.isLoading
        self.error = state.error

        resolvePendingPhotoDeletions()
    }

    /// セクション内から消えた id の pending 写真を物理削除し、pending から取り除く。
    private func resolvePendingPhotoDeletions() {
        guard !pendingPhotoDeletions.isEmpty else { return }
        let remainingIds = Set(sections.flatMap(\.records).map(\.id))
        for (coffeeId, fileNames) in pendingPhotoDeletions where !remainingIds.contains(coffeeId) {
            for fileName in fileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            pendingPhotoDeletions.removeValue(forKey: coffeeId)
        }
    }
}
