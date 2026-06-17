package com.noricoffee.repository

import com.noricoffee.domain.model.AuthAccount
import kotlinx.coroutines.flow.Flow

/**
 * Firebase Auth を抽象化したリポジトリ。
 *
 * 実装は各プラットフォームの公式 SDK で行う:
 * - iOS: `iosApp/iosApp/FirebaseRepositories/AuthRepositoryIosImpl.swift`
 * - Android: `shared/data-firebase/androidMain`
 *
 * 起動時に [signInAnonymouslyIfNeeded] を呼び、得られた uid を以降のクエリで利用する想定。
 *
 * ## アカウントライフサイクル
 *
 * - **初回起動**: [signInAnonymouslyIfNeeded] → 匿名 uid でローカル / リモートを初期化
 * - **アップグレード（Sign in with Apple）**: [linkWithApple] → uid 不変のままプロバイダを紐付け
 * - **サインアウト / アカウント削除**: uid が変わるため、呼び出し元（iOS アプリ層）が
 *   [signInAnonymouslyIfNeeded] を再度呼んで新規匿名 uid を取得し直す必要がある
 */
interface AuthRepository {

    /**
     * 現在の uid を返す。未サインインの場合は匿名サインインを実行してから uid を返す。
     *
     * Swift から呼び出されるため `@Throws(Exception::class)` を付与し、`NSError` として
     * 受け取れるようにする（[docs/kmp-bridge.md](../../../../../docs/kmp-bridge.md) 参照）。
     */
    @Throws(Exception::class)
    suspend fun signInAnonymouslyIfNeeded(): String

    /**
     * uid の変化を観測する Flow。
     *
     * - サインイン状態のとき: 現在の uid
     * - サインアウト状態のとき: `null`
     *
     * UI 層は本 Flow を購読し、uid が確定してから [VisitRepository] のクエリを呼ぶ。
     */
    fun observeUserId(): Flow<String?>

    /**
     * 現在のアカウント情報（[AuthAccount]）の変化を観測する Flow。
     *
     * - サインイン中: [AuthAccount]（uid / isAnonymous / providerLabel / email を含む）
     * - サインアウト中: `null`
     *
     * SKIE により Swift 側では `AsyncSequence` として扱える。
     * Swift で「実装する」際のシグネチャは生 Obj-C プロトコル形式になる点に注意
     * （[docs/kmp-bridge.md] §SKIE は呼び出し方向限定 参照）。
     */
    fun observeAccount(): Flow<AuthAccount?>

    /**
     * 現在の匿名アカウントに Sign in with Apple の資格情報をリンクし、アップグレードする。
     *
     * - uid は変わらない（データ引き継ぎが前提）
     * - 成功時は更新後の [AuthAccount] を返す
     * - 失敗時は例外を投げる（呼び出し元 ViewModel で `runCatching` して `UIState.error` に詰めること）
     *
     * iOS 側では Apple サインイン UI（ASAuthorization フロー）で取得した
     * `idToken` / `rawNonce` をそのまま渡す。
     * Android では Apple サインイン UI が存在しないため、実装は
     * `UnsupportedOperationException("Apple sign-in is iOS only")` を投げるスタブになる。
     *
     * @param idToken Apple ID サービスから取得した JWT トークン
     * @param rawNonce Apple サインイン要求時に生成した nonce（平文）
     * @return アップグレード後の [AuthAccount]
     */
    @Throws(Exception::class)
    suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount

    /**
     * 現在のアカウントをサインアウトする。
     *
     * サインアウト後は uid が無効になる。呼び出し元（iOS アプリ層）は
     * [signInAnonymouslyIfNeeded] を再度呼んで新規匿名 uid で再起動すること。
     */
    @Throws(Exception::class)
    suspend fun signOut()

    /**
     * Firebase Auth からユーザー本体を削除する。
     *
     * **前提**: このメソッドを呼ぶ前に、呼び出し元の UseCase（[com.noricoffee.domain.usecase.DeleteAccountUseCase]）
     * が対象 uid の全 Visit をローカル / リモートから削除済みであること。
     *
     * 写真ファイル（端末 Documents 内）の削除は **iOS 側の責務**（PhotoFileStore が担う）であり、
     * KMP 共通層では扱わない。
     *
     * 削除後は uid が無効になる。呼び出し元（iOS アプリ層）は
     * [signInAnonymouslyIfNeeded] を再度呼んで新規匿名 uid で再起動すること。
     */
    @Throws(Exception::class)
    suspend fun deleteAuthUser()
}
