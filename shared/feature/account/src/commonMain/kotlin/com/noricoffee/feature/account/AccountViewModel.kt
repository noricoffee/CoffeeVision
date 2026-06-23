package com.noricoffee.feature.account

import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.repository.AuthRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
    private val scope: CoroutineScope,
) {

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
        scope.launch {
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
        actionJob = scope.launch {
            _state.update { it.copy(isProcessing = true, error = null) }
            try {
                val account = authRepository.linkWithApple(idToken, rawNonce)
                _state.update { it.copy(account = account, isProcessing = false) }
            } catch (e: CancellationException) {
                _state.update { it.copy(isProcessing = false) }
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
        actionJob = scope.launch {
            _state.update { it.copy(isProcessing = true, error = null) }
            try {
                authRepository.signOut()
                _state.update { it.copy(isProcessing = false) }
            } catch (e: CancellationException) {
                _state.update { it.copy(isProcessing = false) }
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
        actionJob = scope.launch {
            _state.update { it.copy(isProcessing = true, error = null) }
            try {
                deleteAccountUseCase(userId)
                _state.update { it.copy(isProcessing = false) }
            } catch (e: CancellationException) {
                _state.update { it.copy(isProcessing = false) }
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
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null) }
    }
}
