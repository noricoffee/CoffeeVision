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
    private(set) var error: String?

    /// KMP 側の `isProcessing`（DeleteAccountUseCase 実行中等）と
    /// Swift 側の preflight（Apple 再サインイン → reauth → revoke）を合算した処理中フラグ。
    ///
    /// どちらが true でも処理中オーバーレイを出す。
    var isProcessing: Bool {
        isKmpProcessing || isPreflighting
    }

    /// KMP `AccountViewModel.UIState.isProcessing` の値を保持する。
    private var isKmpProcessing: Bool = false

    /// Apple 再サインイン → reauthenticate → revokeToken の前段処理中かどうか（Swift 側）。
    private var isPreflighting: Bool = false

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
        // Swift 側の preflight エラー（KMP state に持たない）を消去する
        error = nil
        // KMP 側のエラーも消去する（KMP 側は冪等：既に nil なら no-op）
        kotlin.onErrorDismissed()
    }

    // MARK: - 処理完了待ち

    /// `onSignOutTapped()` / `onDeleteAccountTapped(userId:)` 呼び出し直後の完了待ちを二相で行う。
    ///
    /// `@Observable` の変化検知は Task 内で遅れることがあるため、ポーリングで `isProcessing` を確認する。
    /// 呼び出し直後は KMP 側の `isProcessing = true` emission がまだ届いていないことがあり、
    /// これを待たずに `isProcessing == false` を「完了」と誤判定すると、処理中に
    /// 呼び出し側（写真削除・reboot）が走ってしまう。そのため:
    ///   1. まず `isProcessing == true` になるのを待つ（KMP 側が即時同期完了するケースを許容し、
    ///      タイムアウトしても次相へ進む）
    ///   2. 次に `isProcessing == false` になるのを待つ
    ///
    /// - Returns: `true` = エラーなく完了。`false` = タイムアウトまたはエラーあり
    func awaitProcessingCompletion() async -> Bool {
        // 相 1: isProcessing == true になるのを待つ（最大 2 秒、タイムアウトは次相へ進む）
        for _ in 0 ..< 40 {
            if isProcessing { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        // 相 2: isProcessing == false になるのを待つ（最大 30 秒）
        for _ in 0 ..< 300 {
            if !isProcessing {
                return error == nil
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    // MARK: - Apple 削除前段（preflight）制御

    /// Apple 再サインイン / reauth / revokeToken の前段処理を開始する。
    ///
    /// `isProcessing` を true に変え処理中オーバーレイを出す。
    func onDeletePreflightStarted() {
        isPreflighting = true
        error = nil
    }

    /// ユーザーが Apple サインインをキャンセルした場合の後処理。
    ///
    /// `isProcessing` を false に戻す。エラー表示は行わない。
    func onDeletePreflightCancelled() {
        isPreflighting = false
    }

    /// reauth / revokeToken が成功した場合の後処理。
    ///
    /// Swift 側 preflight フラグを false にし、KMP 削除 UseCase の `isProcessing` に引き継ぐ。
    func onDeletePreflightSucceeded() {
        isPreflighting = false
    }

    /// reauth / revokeToken が失敗した場合の後処理。
    ///
    /// `isProcessing` を false に戻し、既存の `.alert` 経路でエラーを表示する。
    func onDeletePreflightFailed(message: String) {
        isPreflighting = false
        error = message
    }

    // MARK: - Private

    private func apply(_ state: AccountViewModel.UIState) {
        self.account = state.account
        self.isKmpProcessing = state.isProcessing
        self.error = state.error
    }
}
