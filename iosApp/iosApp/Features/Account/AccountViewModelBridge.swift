import Observation
import SharedLogic

/// `AccountViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 観測タスクは `onAppear` で開始し `onDisappear` でキャンセルする
@MainActor
@Observable
final class AccountViewModelBridge {

    private let kotlin: AccountViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var account: AuthAccount?
    private(set) var isProcessing: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(viewModel: AccountViewModel) {
        self.kotlin = viewModel
    }

    deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    func onAppear() {
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

    func onDisappear() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    func onAppleCredentialReceived(idToken: String, rawNonce: String) {
        kotlin.onAppleCredentialReceived(idToken: idToken, rawNonce: rawNonce)
    }

    func onSignOutTapped() {
        kotlin.onSignOutTapped()
    }

    func onDeleteAccountTapped(userId: String) {
        kotlin.onDeleteAccountTapped(userId: userId)
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: AccountViewModel.UIState) {
        self.account = state.account
        self.isProcessing = state.isProcessing
        self.error = state.error
    }
}
