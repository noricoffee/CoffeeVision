package com.noricoffee.repository

import kotlinx.coroutines.flow.Flow

/**
 * Firebase Auth を抽象化したリポジトリ。
 *
 * 実装は各プラットフォームの公式 SDK で行う:
 * - iOS: `iosApp/iosApp/FirebaseRepositories/AuthRepositoryIosImpl.swift`
 * - Android: `shared/data-firebase/androidMain`
 *
 * 起動時に [signInAnonymouslyIfNeeded] を呼び、得られた uid を以降のクエリで利用する想定。
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
}
