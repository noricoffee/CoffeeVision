import Observation
import SharedLogic

/// `AccountViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 観測タスクは `onAppear` で開始し、**破棄は `deinit` 起点**（`cancel()` は `AppState` が
///   ブリッジを捨てるときの明示キャンセル用）。`AccountView` の `.onDisappear` からは
///   キャンセルしない — サインアウト / 削除の完了待ち中に画面を離れると、`apply(_:)` が
///   止まって `isProcessing` が凍結するため（SR-1）
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
    ///
    /// `apply(_:)` による反映のほか、アクション転送メソッド（`onSignOutTapped()` 等）が
    /// 楽観的に `true` を立てる。KMP 側も同じタイミングで同期的に `true` にするため、
    /// 先走りではなく「observation の 1 emit 分の遅れを埋める」だけの操作になる。
    private var isKmpProcessing: Bool = false

    /// Apple 再サインイン → reauthenticate → revokeToken の前段処理中かどうか（Swift 側）。
    private var isPreflighting: Bool = false

    // MARK: - Init

    init(viewModel: AccountViewModel) {
        self.kotlin = viewModel
    }

    isolated deinit {
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

    /// 観測タスクを明示的にキャンセルする。`AppState` が破棄されるときに呼ぶ。
    ///
    /// **`AccountView` の `.onDisappear` からは呼ばない。** 呼ぶと `apply(_:)` が止まり、
    /// `isKmpProcessing` が凍結して処理中オーバーレイと「完了」ボタンの活性が実態からずれる
    /// （`CafeDetailView` と同じ判断。`MapViewModelBridge.cancel()` と同じ役割）。
    func cancel() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    // 以下 3 つは KMP 側が呼び出し時点で**同期的に** `isProcessing = true` にする
    // （`AccountViewModel.markProcessingStarted`）。ただし Swift 側の `isKmpProcessing` は
    // observation の次の emit まで更新されないため、その 1 フレームだけ処理中オーバーレイが
    // 消える。KMP の実態と矛盾しないので、ここで楽観的に立てて隙間を埋める。

    func onAppleCredentialReceived(idToken: String, rawNonce: String) {
        isKmpProcessing = true
        kotlin.onAppleCredentialReceived(idToken: idToken, rawNonce: rawNonce)
    }

    func onSignOutTapped() {
        isKmpProcessing = true
        kotlin.onSignOutTapped()
    }

    func onDeleteAccountTapped(userId: String) {
        isKmpProcessing = true
        kotlin.onDeleteAccountTapped(userId: userId)
    }

    func onErrorDismissed() {
        // Swift 側の preflight エラー（KMP state に持たない）を消去する
        error = nil
        // KMP 側のエラーも消去する（KMP 側は冪等：既に nil なら no-op）
        kotlin.onErrorDismissed()
    }

    // MARK: - 処理完了待ち

    /// `onSignOutTapped()` / `onDeleteAccountTapped(userId:)` 呼び出し直後の完了を待つ。
    ///
    /// KMP の `state` を **`observationTask` とは独立に**購読する。これにより、待っている間に
    /// `AccountView` が pop されて `apply(_:)` が止まっても完了を取りこぼさない。
    ///
    /// KMP 側は各アクションの呼び出し時点で**同期的に** `isProcessing = true` にする
    /// （`AccountViewModel.markProcessingStarted`）ため、購読開始時には必ず true が観測できる。
    /// よって「開始を待つ」相は不要で、**最初の `isProcessing == false` がそのまま完了**を意味する。
    ///
    /// タイムアウトは設けない。KMP 側は成功・失敗のどちらでも必ず `isProcessing = false` を
    /// emit するため、待ち続けても取り残されない。むしろ旧実装の 30 秒上限は、記録が多い
    /// ユーザーのアカウント削除（全 Visit の Firestore 削除）で超えうる実害があった。
    ///
    /// - Returns: `true` = エラーなく完了。`false` = エラーあり、または `kotlin.clear()` で
    ///   スコープが破棄されて Flow が終了した
    func awaitProcessingCompletion() async -> Bool {
        for await state in kotlin.state {
            guard !state.isProcessing else { continue }
            return state.error == nil
        }
        // スコープ破棄で Flow が終了した（完了は確認できていない）
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
