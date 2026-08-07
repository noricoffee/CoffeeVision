package com.noricoffee.feature.account

import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.repository.AuthRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * アカウント管理画面の ViewModel。
 *
 * ## 責務
 * - [AuthRepository.observeAccount] を購読し、現在のアカウント情報を [UIState.account] に反映する
 * - Sign in with Apple でのアップグレード（[onAppleCredentialReceived]）
 * - サインアウト（[onSignOutTapped]）
 * - アカウント削除（[onDeleteAccountTapped]）— [DeleteAccountUseCase] 経由で全 Visit を先に削除する
 *
 * ## サインアウト / 削除後の再起動
 * サインアウト / 削除後は uid が変わるため、iOS アプリ層（AppState 等）が
 * [com.noricoffee.AppContainer.startInitialSync] を再度呼んで新規匿名 uid を確定する必要がある。
 * 本 ViewModel からは直接再起動しない（AppContainer への参照を持たない設計）。
 *
 * ## 完了検知の契約（プラットフォーム層向け）
 * 各アクションの完了は **[UIState.isProcessing] の true → false 遷移**で判定する。
 * [onSignOutTapped] / [onDeleteAccountTapped] / [onAppleCredentialReceived] は
 * **戻る時点で必ず `isProcessing = true` を反映済み**にする（[markProcessingStarted] 参照）。
 * したがって呼び出し側は「呼んだ直後から [state] を購読し、最初の `isProcessing == false`
 * を待つ」だけでよく、開始を待つためのポーリングや猶予時間は不要。
 * 完了時の成否は同じ emit の [UIState.error] が null かどうかで判断する。
 *
 * ## CoroutineScope の注意
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param authRepository アカウント情報の観測・操作を担うリポジトリ
 * @param deleteAccountUseCase アカウント削除 UseCase（全 Visit 削除 → Auth 削除）
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class AccountViewModel(
    private val authRepository: AuthRepository,
    private val deleteAccountUseCase: DeleteAccountUseCase,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * アカウント管理画面の UI 状態。
     *
     * @property account 現在のアカウント情報。サインアウト中は null
     * @property isProcessing アップグレード / サインアウト / 削除などの非同期処理が実行中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val account: AuthAccount? = null,
        val isProcessing: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 各操作の Job。再起動時に前回 Job をキャンセルして連打に対応する。
    private var actionJob: Job? = null

    init {
        // ViewModel 生成時にアカウント情報の購読を開始する
        viewModelScope.launch {
            authRepository.observeAccount().collect { account ->
                _state.update { it.copy(account = account) }
            }
        }
    }

    /**
     * Sign in with Apple フローが完了し、資格情報を受け取ったときに呼ぶ。
     *
     * iOS 側の ASAuthorization フローで取得した [idToken] / [rawNonce] をそのまま渡す。
     * [AuthRepository.linkWithApple] を呼び、匿名アカウントを Apple アカウントにアップグレードする。
     * uid は変わらない（データ引き継ぎ前提）。
     *
     * @param idToken Apple ID サービスから取得した JWT トークン
     * @param rawNonce Apple サインイン要求時に生成した nonce（平文）
     */
    fun onAppleCredentialReceived(idToken: String, rawNonce: String) {
        actionJob?.cancel()
        markProcessingStarted()
        actionJob = viewModelScope.launch {
            try {
                val account = authRepository.linkWithApple(idToken, rawNonce)
                _state.update { it.copy(account = account, isProcessing = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isProcessing = false,
                        error = e.message ?: "アップグレードに失敗しました",
                    )
                }
            }
        }
    }

    /**
     * サインアウトボタンタップ時に呼ぶ。
     *
     * サインアウト後は uid が無効になる。iOS アプリ層は本操作の完了を検知し
     * [com.noricoffee.AppContainer.startInitialSync] を再度呼んで新規匿名 uid を確定すること。
     */
    fun onSignOutTapped() {
        actionJob?.cancel()
        markProcessingStarted()
        actionJob = viewModelScope.launch {
            try {
                authRepository.signOut()
                _state.update { it.copy(isProcessing = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isProcessing = false,
                        error = e.message ?: "サインアウトに失敗しました",
                    )
                }
            }
        }
    }

    /**
     * アカウント削除ボタンタップ時に呼ぶ。
     *
     * [DeleteAccountUseCase] を呼び、以下の順序でアカウントを削除する:
     * 1. 全 Visit をローカル DB + Firestore から削除
     * 2. Firebase Auth ユーザー本体を削除
     *
     * 写真ファイル（端末ローカル）の削除は **iOS 側（PhotoFileStore）の責務**であり、
     * 本 ViewModel からは行わない。
     *
     * 削除後は uid が無効になる。iOS アプリ層は本操作の完了を検知し
     * [com.noricoffee.AppContainer.startInitialSync] を再度呼んで新規匿名 uid を確定すること。
     */
    fun onDeleteAccountTapped(userId: String) {
        actionJob?.cancel()
        markProcessingStarted()
        actionJob = viewModelScope.launch {
            try {
                deleteAccountUseCase(userId)
                _state.update { it.copy(isProcessing = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isProcessing = false,
                        error = e.message ?: "アカウントの削除に失敗しました",
                    )
                }
            }
        }
    }

    /**
     * 各アクションの開始を [UIState.isProcessing] に**同期的に**反映する。
     *
     * ## なぜ [viewModelScope] の launch の外で立てるのか
     *
     * iOS 側（`AccountViewModelBridge.awaitProcessingCompletion()`）は、サインアウト /
     * 削除の完了を [state] の購読で待つ。launch の内側で立てると、コルーチンがディスパッチ
     * されるまで [UIState.isProcessing] が false のままで、購読を開始した iOS 側が
     * **開始前の false を「完了」と誤読する**。呼び出し直後に必ず true が観測できるよう、
     * ここだけは同期で更新する。
     *
     * ## 呼び出し側の前提
     *
     * 直前に `actionJob?.cancel()` を実行していること。順序を逆にすると、キャンセルされた
     * 前 Job の後始末が本メソッドの後に走りうる。なお前 Job の
     * `catch (CancellationException)` は [UIState.isProcessing] を戻さない —
     * cancel は必ず「次のアクション開始」（= 本メソッド）か [clear] とセットで起きるため、
     * そこで false に戻すと直後に立てた true を非同期に打ち消してしまう。
     */
    private fun markProcessingStarted() {
        _state.update { it.copy(isProcessing = true, error = null) }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null) }
    }

    /**
     * 画面破棄時に呼ぶ。内部の viewModelScope をキャンセルして全コルーチンを停止する。
     *
     * iOS Bridge の deinit で呼ぶこと（タブ常駐 VM のため onDisappear では不要）。
     * キャンセル後に各メソッドが呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}
